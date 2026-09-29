import AVFoundation
import SwiftUI

/// First-run experience: what Lens is, why it's safe, the camera ask, a real first scan,
/// and the shortcuts that make it fast. Always skippable.
struct OnboardingFlow: View {
    @AppStorage(Pref.onboardingDone) private var onboardingDone = false
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var systemScheme

    @State private var steps = OnboardingStep.steps(cameraStatus: AVCaptureDevice.authorizationStatus(for: .video))
    @State private var index = 0
    /// A real code scanned during onboarding; its result opens over Home once we're done.
    @State private var firstScan: ScanResult?

    private var step: OnboardingStep { steps[index] }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            page
                .id(step)
                .transition(pageTransition)
        }
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .environment(\.colorScheme, step.prefersDarkAppearance ? .dark : systemScheme)
        .onAppear {
#if DEBUG
            if let step = QAHarness.onboardingStep, let start = steps.firstIndex(of: step) { index = start }
#endif
        }
    }

    @ViewBuilder
    private var page: some View {
        switch step {
        case .welcome:
            WelcomeStep(onContinue: advance)
        case .answers:
            AnswersStep(onContinue: advance)
        case .safety:
            SafetyStep(onContinue: advance)
        case .camera:
            CameraStep(onContinue: advance)
        case .firstScan:
            FirstScanStep { result in
                firstScan = result
                advance()
            } onSkip: {
                advance()
            }
        case .everywhere:
            EverywhereStep(onFinish: finish)
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            OnboardingProgress(count: steps.count, current: index)
            Button("Skip", action: finish)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .opacity(step == .everywhere ? 0 : 1)
                .disabled(step == .everywhere)
        }
        .padding(.leading, 24)
        .padding(.trailing, 12)
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func advance() {
        guard index < steps.count - 1 else { return finish() }
        withAnimation(.smooth(duration: 0.45)) { index += 1 }
    }

    /// On to Home, with the first scan's result waiting if there was one.
    private func finish() {
        onboardingDone = true
        guard let firstScan else { return }
        Task {
            try? await Task.sleep(for: AppModel.presentationHandoff)
            model.show(firstScan)
        }
    }
}

#Preview {
    OnboardingFlow()
        .environment(AppModel())
}
