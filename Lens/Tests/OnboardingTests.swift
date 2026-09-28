import AVFoundation
import Testing
@testable import Lens

struct OnboardingStepTests {
    @Test func cameraPrimingOnlyBeforeTheSystemPrompt() {
        #expect(OnboardingStep.steps(cameraStatus: .notDetermined) == OnboardingStep.allCases)
        for answered in [AVAuthorizationStatus.authorized, .denied, .restricted] {
            #expect(!OnboardingStep.steps(cameraStatus: answered).contains(.camera))
        }
    }

    @Test func firstScanIsTheOnlyDarkStep() {
        #expect(OnboardingStep.allCases.filter(\.prefersDarkAppearance) == [.firstScan])
    }
}

struct OnboardingWelcomeMotionTests {
    @Test func settlesOnTheIconPose() {
        let pose = WelcomeMotion.pose(at: WelcomeMotion.duration)
        #expect(pose.blades.allSatisfy { abs($0 - 1) < 0.0001 })
        #expect(abs(pose.pupil - 1) < 0.0001)
        #expect(abs(pose.openness - 1) < 0.0001)
        #expect(pose.spin == .zero)
    }

    @Test func startsShutWithTheIrisGathered() {
        let pose = WelcomeMotion.pose(at: 0)
        #expect(pose.openness < 0.05)
        #expect(pose.blades.allSatisfy { abs($0) < 0.0001 })
        #expect(abs(pose.pupil) < 0.0001)
    }

    @Test func blinksOnceAfterTheBloom() {
        let closedMoment = WelcomeMotion.blinkStart + WelcomeMotion.blinkClose
        #expect(WelcomeMotion.pose(at: closedMoment).openness < 0.1)
        #expect(WelcomeMotion.pose(at: WelcomeMotion.blinkStart - 0.01).openness == 1)
    }

    @Test func idleDriftIsSlow() {
        let later = WelcomeMotion.pose(at: WelcomeMotion.duration + 1)
        #expect(abs(later.spin.degrees) > 0)
        #expect(abs(later.spin.degrees) < 10)
    }
}
