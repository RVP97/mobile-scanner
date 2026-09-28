import AVFoundation
import SwiftUI

/// Explains the camera ask before the system prompt appears.
struct CameraStep: View {
    var onContinue: () -> Void

    @State private var isRequesting = false

    var body: some View {
        OnboardingPage {
            VStack(spacing: 32) {
                CameraIllustration()
                OnboardingTitle(
                    title: "Lens needs your camera to read codes",
                    subtitle: "Reads codes. Ignores the rest."
                )
                VStack(alignment: .leading, spacing: 20) {
                    reassurance("Only while the app is open", symbol: "iphone")
                    reassurance("Nothing is recorded or uploaded", symbol: "video.slash")
                    reassurance("You can scan from Photos instead", symbol: "photo.on.rectangle")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } actions: {
            Button("Allow Camera", action: requestAccess)
                .buttonStyle(.primaryAction())
                .disabled(isRequesting)
            Button("Not Now", action: onContinue)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func reassurance(_ text: LocalizedStringKey, symbol: String) -> some View {
        Label {
            Text(text)
                .font(.body)
        } icon: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 28)
        }
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

/// The viewfinder around a blurred scene, with only the code in focus.
private struct CameraIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(white: 0.12))
            ZStack {
                Circle().fill(Color(red: 0.78, green: 0.52, blue: 0.3)).frame(width: 120).offset(x: -60, y: -40)
                Circle().fill(Color(red: 0.35, green: 0.5, blue: 0.45)).frame(width: 110).offset(x: 70, y: 50)
                Capsule().fill(Color(red: 0.9, green: 0.84, blue: 0.72)).frame(width: 150, height: 44).offset(x: 30, y: -70)
            }
            .blur(radius: 22)
            .clipShape(.rect(cornerRadius: 28, style: .continuous))

            Image(systemName: "qrcode")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(.black)
                .padding(10)
                .background(.white, in: .rect(cornerRadius: 10, style: .continuous))

            ViewfinderBrackets()
                .fill(.white)
                .frame(width: 130, height: 130)
        }
        .frame(width: 200, height: 200)
        .environment(\.colorScheme, .dark)
        .accessibilityHidden(true)
    }
}

#Preview {
    CameraStep {}
}
