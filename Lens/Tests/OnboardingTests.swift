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
        #expect(WelcomeMotion.pose(at: WelcomeMotion.duration) == .rest)
    }

    @Test func startsWithTheLensAwayAndOutOfFocus() {
        let pose = WelcomeMotion.pose(at: 0)
        #expect(pose.code == 0)
        #expect(pose.lensOpacity == 0)
        #expect(pose.lensOffset == WelcomeMotion.glideFrom)
        #expect(pose.focus == 0)
        #expect(pose.glint == 0)
    }

    @Test func finderSnapsPastFocusThenSettles() {
        let snaps = stride(from: WelcomeMotion.focusStart, through: WelcomeMotion.focusStart + WelcomeMotion.focusDuration, by: 0.01)
            .map { WelcomeMotion.pose(at: $0).focus }
        #expect(snaps.max()! > 1)
        #expect(abs(snaps.last! - 1) < 0.0001)
    }

    @Test func refractionSweepsOneFullTurn() {
        let nearEnd = WelcomeMotion.pose(at: WelcomeMotion.sweepStart + WelcomeMotion.sweepDuration * 0.999)
        #expect(nearEnd.refraction.degrees > 359)
        let midway = WelcomeMotion.pose(at: WelcomeMotion.sweepStart + WelcomeMotion.sweepDuration / 2)
        #expect(abs(midway.refraction.degrees - 180) < 0.0001)
        #expect(midway.spread > 1.5)
    }

    @Test func idleGlintsNowAndThenAndRestsBetween() {
        let restMoment = WelcomeMotion.duration + 1
        #expect(WelcomeMotion.pose(at: restMoment) == .rest)
        let glintMoment = WelcomeMotion.duration + WelcomeMotion.idlePeriod - WelcomeMotion.idleGlint / 2
        let glinting = WelcomeMotion.pose(at: glintMoment)
        #expect(glinting.glint > 1.2)
        #expect(glinting.lensOffset == .zero)
    }
}
