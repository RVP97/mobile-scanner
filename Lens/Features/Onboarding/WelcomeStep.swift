import SwiftUI

struct WelcomeStep: View {
    var onContinue: () -> Void

    var body: some View {
        OnboardingPage(centered: true) {
            VStack(spacing: 32) {
                WelcomeHero()
                OnboardingTitle(
                    title: "Scan anything.\nKnow before you go.",
                    subtitle: "Lens reads any code, shows you where it really leads, and hands you the one thing to do next."
                )
            }
        } actions: {
            Button("Get Started", action: onContinue)
                .buttonStyle(.primaryAction())
        }
    }
}

#Preview {
    WelcomeStep {}
}
