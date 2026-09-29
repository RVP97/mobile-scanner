import AVFoundation
import SwiftUI

/// Explains the camera ask before the system prompt appears.
struct CameraStep: View {
    var onContinue: () -> Void

    @State private var isRequesting = false

    var body: some View {
        OnboardingPage(centered: true) {
            VStack(spacing: 32) {
                CameraIllustration()
                OnboardingTitle(
                    title: "Lunet needs your camera to read codes",
                    subtitle: "Reads codes. Ignores the rest."
                )
                VStack(alignment: .leading, spacing: 16) {
                    reassurance("Only while Lunet is open", symbol: "iphone")
                    reassurance("Nothing is recorded or uploaded", symbol: "video.slash")
                    reassurance("Or scan from Photos instead", symbol: "photo.on.rectangle")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 20, style: .continuous))
            }
        } actions: {
            // App Review 5.1.1(iv): a neutral label, and the only way forward is the system prompt.
            Button("Continue", action: requestAccess)
                .buttonStyle(.primaryAction())
                .disabled(isRequesting)
        }
    }

    private func reassurance(_ text: LocalizedStringKey, symbol: String) -> some View {
        Label {
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 28)
        }
        .accessibilityElement(children: .combine)
    }

    private func requestAccess() {
        isRequesting = true
        Task {
            _ = await AVCaptureDevice.requestAccess(for: .video)
            isRequesting = false
            onContinue()
        }
    }
}

/// The viewfinder around a softly blurred scene, with only the code in focus. Light mode gets a
/// daylight scene so the illustration doesn't sit on the page as a heavy dark block.
private struct CameraIllustration: View {
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(isDark ? Color(white: 0.12) : Color(red: 0.93, green: 0.94, blue: 0.95))
            ZStack {
                Circle().fill(Color(red: 0.86, green: 0.62, blue: 0.4)).frame(width: 120).offset(x: -62, y: -44)
                Circle().fill(Color(red: 0.42, green: 0.6, blue: 0.54)).frame(width: 110).offset(x: 72, y: 54)
                Capsule().fill(Color(red: 0.95, green: 0.88, blue: 0.74)).frame(width: 150, height: 44).offset(x: 30, y: -72)
            }
            .opacity(isDark ? 1 : 0.55)
            .blur(radius: 24)
            .clipShape(.rect(cornerRadius: 32, style: .continuous))

            Image(systemName: "qrcode")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(.black)
                .padding(10)
                .background(.white, in: .rect(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(isDark ? 0 : 0.08), radius: 8, y: 2)

            ViewfinderBrackets()
                .fill(isDark ? Color.white : Palette.accent)
                .frame(width: 132, height: 132)
        }
        .frame(width: 208, height: 208)
        .accessibilityHidden(true)
    }
}

#Preview {
    CameraStep {}
}
