import LocalAuthentication
import SwiftUI

/// Face ID gate for History. Shared so opening a result from History and coming back doesn't
/// ask again; relocks whenever the app goes to the background.
@Observable
final class HistoryLock {
    static let shared = HistoryLock()

    private(set) var isUnlocked = false
    private(set) var isAuthenticating = false

    private init() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { HistoryLock.shared.lock() }
        }
    }

    func lock() { isUnlocked = false }

    /// Marks History open without asking again, e.g. right after the user authenticated to turn the lock on.
    func markUnlocked() { isUnlocked = true }

    /// Face ID (or the device passcode as fallback). Returns whether the user got in.
    @discardableResult
    func unlock(reason: String = String(localized: "Unlock your scan history.")) async -> Bool {
        guard !isAuthenticating else { return false }
        isAuthenticating = true
        defer { isAuthenticating = false }
        let granted = await Self.authenticate(reason: reason)
        if granted { isUnlocked = true }
        return granted
    }

    /// Whether this device can authenticate the owner at all (biometrics or passcode set).
    static var canAuthenticate: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return false }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}

/// The name and glyph of the device's owner authentication, for labels like "Require Face ID".
enum BiometryKind {
    case faceID, touchID, opticID, passcode

    static var current: BiometryKind {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .passcode
        }
    }

    var requireTitle: LocalizedStringResource {
        switch self {
        case .faceID: "Require Face ID"
        case .touchID: "Require Touch ID"
        case .opticID: "Require Optic ID"
        case .passcode: "Require Passcode"
        }
    }

    var symbol: String {
        switch self {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        case .passcode: "lock.fill"
        }
    }
}
