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
    /// appear, and the first scan only once access is granted. App Review 5.1.1(iv): after
    /// "Don't Allow", onboarding never mentions the camera again.
    static func steps(cameraStatus: AVAuthorizationStatus) -> [OnboardingStep] {
        allCases.filter { step in
            switch step {
            case .camera: cameraStatus == .notDetermined
            case .firstScan: cameraStatus == .notDetermined || cameraStatus == .authorized
            default: true
            }
        }
    }

    /// The first scan runs over the live camera, which is always dark.
    var prefersDarkAppearance: Bool { self == .firstScan }
}
