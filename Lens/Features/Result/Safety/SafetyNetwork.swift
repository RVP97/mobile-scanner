import Foundation

/// The two network calls a deep check makes. Injected so tests never touch the network.
protocol SafetyNetwork {
    /// One request that does *not* follow redirects.
    func probe(_ url: URL, method: String) async throws -> HTTPProbe
    /// A JSON document (redirects followed).
    func data(from url: URL) async throws -> Data
}

struct HTTPProbe: Hashable {
    var status: Int
    var location: String?
}

/// Follows a link hop by hop, the way a browser would, without loading any page.
enum RedirectResolver {
    static let maxHops = 8

    /// Every URL after the original, ending with the real destination. Empty when it doesn't redirect;
    /// nil when the link couldn't be reached at all, so nothing can be said about where it goes.
    static func chain(from url: URL, network: some SafetyNetwork) async -> [URL]? {
        var hops: [URL] = []
        var current = url
        for _ in 0..<maxHops {
            guard ["http", "https"].contains(current.scheme?.lowercased() ?? "") else { break }
            guard let probe = await probe(current, network: network) else {
                if hops.isEmpty { return nil }
                break
            }
            guard (300...399).contains(probe.status),
                  let location = probe.location?.trimmed, !location.isEmpty,
                  let next = URL(string: location, relativeTo: current)?.absoluteURL,
                  next != current, !hops.contains(next)
            else { break }
            hops.append(next)
            current = next
        }
        return hops
    }

    /// HEAD first; servers that refuse HEAD get a GET whose body is never read.
    private static func probe(_ url: URL, network: some SafetyNetwork) async -> HTTPProbe? {
        if let head = try? await network.probe(url, method: "HEAD"), ![400, 403, 404, 405, 501].contains(head.status) {
            return head
        }
        return try? await network.probe(url, method: "GET")
    }
}

/// Registration date from RDAP (the successor to WHOIS), via the rdap.org bootstrap redirector.
enum DomainAgeLookup {
    static func registrationDate(for domain: String, network: some SafetyNetwork) async -> Date? {
        guard domain.allSatisfy(\.isASCII), domain.contains("."),
              let url = URL(string: "https://rdap.org/domain/\(domain)"),
              let data = try? await network.data(from: url)
        else { return nil }
        return registrationDate(fromRDAP: data)
    }

    static func registrationDate(fromRDAP data: Data) -> Date? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = object["events"] as? [[String: Any]]
        else { return nil }
        let registration = events.first { ($0["eventAction"] as? String)?.lowercased() == "registration" }
        guard let text = registration?["eventDate"] as? String else { return nil }
        return (try? Date(text, strategy: .iso8601))
            ?? (try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
    }
}

/// Real network: ephemeral (no cookies, no cache), 5-second timeouts, redirects handled by hand.
final class LiveSafetyNetwork: SafetyNetwork {
    static let shared = LiveSafetyNetwork()

    private let probingSession: URLSession
    private let lookupSession: URLSession

    private init() {
        probingSession = URLSession(configuration: Self.privateConfiguration(), delegate: RedirectBlocker(), delegateQueue: nil)
        lookupSession = URLSession(configuration: Self.privateConfiguration())
    }

    func probe(_ url: URL, method: String) async throws -> HTTPProbe {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
        request.httpMethod = method
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        let response: URLResponse
        if method == "GET" {
            let (bytes, received) = try await probingSession.bytes(for: request)
            bytes.task.cancel()
            response = received
        } else {
            response = try await probingSession.data(for: request).1
        }
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return HTTPProbe(status: http.statusCode, location: http.value(forHTTPHeaderField: "Location"))
    }

    func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
        request.setValue("application/rdap+json, application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await lookupSession.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    private static let userAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    private static func privateConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 5
        return configuration
    }
}

/// Stops URLSession from following redirects so each hop can be inspected.
private nonisolated final class RedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
