import SwiftUI

// OWNER: Onboarding & Everywhere module.
struct OnboardingFlow: View {
    @AppStorage(Pref.onboardingDone) private var onboardingDone = false
    var body: some View {
        Button("Start") { onboardingDone = true }
    }
}
