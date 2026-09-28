import AVFoundation

/// The screens of onboarding, in order.
enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case answers
    case safety
    case camera
    case firstScan
    case everywhere

    var id: Int { rawValue }

    /// The steps to show. Camera priming only makes sense while the system prompt can still
    /// appear; once the user has answered it, the first scan explains any missing access.
    static func steps(cameraStatus: AVAuthorizationStatus) -> [OnboardingStep] {
        allCases.filter { $0 != .camera || cameraStatus == .notDetermined }
    }

    /// The first scan runs over the live camera, which is always dark.
    var prefersDarkAppearance: Bool { self == .firstScan }
}
