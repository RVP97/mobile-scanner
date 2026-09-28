import SwiftUI

/// A place outside the app where Lens can live, with how to put it there.
enum EverywhereShortcut: String, CaseIterable, Identifiable {
    case controlCenter
    case actionButton
    case lockScreen

    var id: String { rawValue }

    /// Shortcuts this device and OS can actually use.
    static func available(isPhone: Bool, supportsControls: Bool) -> [EverywhereShortcut] {
        allCases.filter { shortcut in
            switch shortcut {
            case .controlCenter: supportsControls
            case .actionButton: isPhone
            case .lockScreen: true
            }
        }
    }

    static var availableHere: [EverywhereShortcut] {
        available(isPhone: UIDevice.current.userInterfaceIdiom == .phone, supportsControls: supportsControls)
    }

    /// Controls (Control Center, Lock Screen buttons, Action button) arrived in iOS 18.
    static var supportsControls: Bool {
        if #available(iOS 18.0, *) { return true }
        return false
    }

    var title: LocalizedStringKey {
        switch self {
        case .controlCenter: "Control Center"
        case .actionButton: "Action Button"
        case .lockScreen: "Lock Screen"
        }
    }

    var summary: LocalizedStringKey {
        switch self {
        case .controlCenter: "Swipe down, tap Scan."
        case .actionButton: "Press and hold to scan."
        case .lockScreen: "Scan without unlocking."
        }
    }

    var buttonTitle: LocalizedStringKey {
        switch self {
        case .actionButton: "Set Up"
        case .controlCenter, .lockScreen: "Add"
        }
    }

    /// Steps in Settings or on the Lock Screen. Apps can't add these themselves, so we guide.
    var steps: [LocalizedStringKey] {
        let hasControls = Self.supportsControls
        switch self {
        case .controlCenter:
            return [
                "Swipe down from the top-right corner to open Control Center.",
                "Touch and hold an empty spot, then tap Add a Control.",
                "Search for Lunet and choose Scan Code.",
            ]
        case .actionButton where hasControls:
            return [
                "Open Settings and tap Action Button.",
                "Swipe to Controls, then tap Choose a Control.",
                "Search for Lunet and choose Scan Code.",
            ]
        case .actionButton:
            return [
                "Open Settings and tap Action Button.",
                "Swipe to Shortcut, then tap Choose a Shortcut.",
                "Choose Scan Code from Lunet.",
            ]
        case .lockScreen where hasControls:
            return [
                "Touch and hold the Lock Screen, then tap Customize.",
                "Tap Lock Screen, then tap − on the flashlight or camera button.",
                "Tap +, search for Lunet, and choose Scan Code.",
            ]
        case .lockScreen:
            return [
                "Touch and hold the Lock Screen, then tap Customize.",
                "Tap Lock Screen, then tap the area below the time.",
                "Choose Lunet, then add the Scan widget.",
            ]
        }
    }
}
