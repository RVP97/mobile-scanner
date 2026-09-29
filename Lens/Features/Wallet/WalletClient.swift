import CryptoKit
import DeviceCheck
import Foundation
import Security

/// Talks to the Lens wallet-service (`wallet-service/` in this repo), which signs Apple Wallet passes.
///
/// Every request is bound to this genuine app instance with App Attest:
///  1. once per install: `GET /challenge` → `attestKey(keyId, SHA256(challenge))` → `POST /attest`
///  2. per pass: `generateAssertion(keyId, SHA256(body))` → `POST /pass` with `X-Lens-Key-Id` / `X-Lens-Assertion`.
///
/// Requires the `com.apple.developer.devicecheck.appattest-environment` entitlement.
actor WalletClient {
    static let shared = WalletClient()

    nonisolated static let baseURL = URL(string: "https://bloom.vallepinto.com/lens/v1/")!

    enum WalletError: LocalizedError, Sendable, Equatable {
        /// App Attest isn't available (Simulator, very old hardware, or unsupported OS configuration).
        case unsupportedDevice
        case attestationFailed
        case rateLimited
        case serviceUnavailable
        case rejected(String)
        case invalidResponse
        case network

        var errorDescription: String? {
            switch self {
            case .unsupportedDevice:
                String(localized: "Adding to Wallet needs a real iPhone or iPad — App Attest isn't available on this device or in the Simulator.")
            case .attestationFailed:
                String(localized: "This copy of Lunet couldn't be verified. Try again later.")
            case .rateLimited:
                String(localized: "You've created a lot of passes recently. Try again in a little while.")
            case .serviceUnavailable:
                String(localized: "Adding to Wallet is temporarily unavailable.")
            case .rejected:
                String(localized: "This code can't be turned into a Wallet pass.")
            case .invalidResponse, .network:
                String(localized: "Couldn't reach the Wallet service. Check your connection and try again.")
            }
        }
    }

    private let baseURL: URL
    private let session: URLSession
    private let keychain: KeyIdStore
    private var attestation: Task<String, any Error>?

    init(baseURL: URL = WalletClient.baseURL, keychainService: String = "com.rvp97.scanner.wallet") {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        self.session = URLSession(configuration: config)
        self.keychain = KeyIdStore(service: keychainService)
    }

    nonisolated static var isSupported: Bool { DCAppAttestService.shared.isSupported }

    /// Returns the signed `.pkpass` bytes for `request`. Build a `PKPass` from them on the main actor.
    func passData(for request: WalletPassRequest) async throws -> Data {
        guard DCAppAttestService.shared.isSupported else { throw WalletError.unsupportedDevice }
        let body = try request.encodedBody()
        return try await requestPass(body: body, allowReattest: true)
    }

    /// Convenience for the Travel result screen: a signed boarding pass for a scanned IATA BCBP.
    func makeBoardingPass(_ pass: BoardingPass, raw: String, symbology: Symbology, color: WalletPassRequest.Palette? = .midnight) async throws -> Data {
        let request = try WalletPassRequest.boardingPass(pass, code: ScannedCode(raw: raw, symbology: symbology), color: color)
        return try await passData(for: request)
    }

    /// Forget the attested key (e.g. from a "Reset" debug action). A new one is attested on next use.
    func resetKey() {
        attestation?.cancel()
        attestation = nil
        keychain.delete()
    }

    // MARK: - Pass

    private func requestPass(body: Data, allowReattest: Bool) async throws -> Data {
        let keyId = try await attestedKeyId()
        let clientDataHash = Data(SHA256.hash(data: body))

        let assertion: Data
        do {
            assertion = try await DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: clientDataHash)
        } catch let error as DCError where (error.code == .invalidKey || error.code == .invalidInput) && allowReattest {
            // The stored key can't sign any more (app reinstalled or re-signed, restored to a new device, …):
            // App Attest reports this as invalidKey or invalidInput. Attest a fresh key once.
            resetKey()
            return try await requestPass(body: body, allowReattest: false)
        } catch let error as DCError where error.code == .serverUnavailable {
            throw WalletError.serviceUnavailable
        } catch {
            Self.debugLog("generateAssertion failed: \(error)")
            throw WalletError.attestationFailed
        }

        var req = URLRequest(url: baseURL.appending(path: "pass"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/vnd.apple.pkpass", forHTTPHeaderField: "Accept")
        req.setValue(keyId, forHTTPHeaderField: "X-Lens-Key-Id")
        req.setValue(assertion.base64EncodedString(), forHTTPHeaderField: "X-Lens-Assertion")
        req.httpBody = body

        let (data, http) = try await send(req)
        Self.debugLog("POST /pass -> \(http.statusCode) \(Self.errorCode(data) ?? "")")
        switch http.statusCode {
        case 200:
            guard http.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("application/vnd.apple.pkpass") == true,
                  !data.isEmpty else { throw WalletError.invalidResponse }
            return data
        case 401 where allowReattest && Self.errorCode(data) == "unknown_key":
            // Server forgot this key (retention purge / env switch): attest a fresh key once.
            resetKey()
            return try await requestPass(body: body, allowReattest: false)
        default:
            throw Self.map(status: http.statusCode, data: data)
        }
    }

    // MARK: - Attestation

    /// The keyId of an App Attest key the server has accepted, attesting a new one if needed.
    /// Concurrent callers share a single in-flight attestation.
    private func attestedKeyId() async throws -> String {
        if let keyId = keychain.read() { return keyId }
        if let attestation { return try await attestation.value }
        let task = Task { try await self.attestNewKey() }
        attestation = task
        defer { attestation = nil }
        return try await task.value
    }

    private func attestNewKey() async throws -> String {
        let service = DCAppAttestService.shared
        guard service.isSupported else { throw WalletError.unsupportedDevice }

        let challenge = try await fetchChallenge()
        let keyId: String
        let attestationObject: Data
        do {
            keyId = try await service.generateKey()
            attestationObject = try await service.attestKey(keyId, clientDataHash: Data(SHA256.hash(data: challenge.bytes)))
        } catch let error as DCError where error.code == .serverUnavailable {
            throw WalletError.serviceUnavailable
        } catch {
            Self.debugLog("generateKey/attestKey failed: \(error)")
            throw WalletError.attestationFailed
        }

        var req = URLRequest(url: baseURL.appending(path: "attest"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(AttestBody(
            keyId: keyId,
            attestation: attestationObject.base64EncodedString(),
            challenge: challenge.string
        ))
        let (data, http) = try await send(req)
        Self.debugLog("POST /attest -> \(http.statusCode) \(Self.errorCode(data) ?? "")")
        guard http.statusCode == 201 else { throw Self.map(status: http.statusCode, data: data) }
        keychain.write(keyId)
        return keyId
    }

    private func fetchChallenge() async throws -> (string: String, bytes: Data) {
        var req = URLRequest(url: baseURL.appending(path: "challenge"))
        req.httpMethod = "GET"
        let (data, http) = try await send(req)
        guard http.statusCode == 200 else { throw Self.map(status: http.statusCode, data: data) }
        guard let body = try? JSONDecoder().decode(ChallengeBody.self, from: data),
              let bytes = Data(base64URLEncoded: body.challenge), bytes.count == 32
        else { throw WalletError.invalidResponse }
        return (body.challenge, bytes)
    }

    // MARK: - HTTP

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw WalletError.invalidResponse }
            return (data, http)
        } catch let error as WalletError {
            throw error
        } catch {
            Self.debugLog("network error for \(request.url?.path() ?? ""): \(error)")
            throw WalletError.network
        }
    }

    /// Step-by-step trace in debug builds only; never logs keys, assertions or pass contents.
    private static func debugLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[Wallet]", message())
        #endif
    }

    private static func errorCode(_ data: Data) -> String? {
        (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
    }

    private static func map(status: Int, data: Data) -> WalletError {
        switch status {
        case 429: .rateLimited
        case 503: .serviceUnavailable
        case 401, 409: .attestationFailed
        case 400, 413: .rejected(errorCode(data) ?? "bad_request")
        default: .invalidResponse
        }
    }

    private struct ChallengeBody: Decodable { let challenge: String }
    private struct ErrorBody: Decodable { let error: String }
    private struct AttestBody: Encodable {
        let keyId: String
        let attestation: String
        let challenge: String
    }
}

// MARK: - Keychain

/// Persists the attested App Attest key identifier (not secret, but must survive relaunches and
/// never sync to other devices — App Attest keys are bound to this device).
nonisolated struct KeyIdStore: Sendable {
    let service: String
    let account = "appAttestKeyId"

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func write(_ value: String) {
        delete()
        var attrs = baseQuery
        attrs[kSecValueData as String] = Data(value.utf8)
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        attrs[kSecAttrSynchronizable as String] = false
        SecItemAdd(attrs as CFDictionary, nil)
    }

    func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

// MARK: - base64url

nonisolated extension Data {
    init?(base64URLEncoded s: String) {
        var b64 = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        b64 += String(repeating: "=", count: (4 - b64.count % 4) % 4)
        self.init(base64Encoded: b64)
    }
}
