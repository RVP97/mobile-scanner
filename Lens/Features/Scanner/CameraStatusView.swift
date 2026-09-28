import SwiftUI

/// Calm, inline explanations for when the live camera can't run.
struct CameraStatusView: View {
    enum Kind: Equatable {
        case denied
        case restricted
        case unavailable
        case interrupted(ScannerCamera.Interruption)
    }

    var kind: Kind
    var onOpenSettings: () -> Void
    var onScanPhotos: () -> Void

    var body: some View {
        switch kind {
        case .interrupted(let reason):
            Label(interruptionMessage(reason), systemImage: "pause.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .lensGlass(.regular, in: Capsule())
        default:
            ScrollView {
                blocked
                    .frame(maxWidth: 360)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .defaultScrollAnchor(.center)
        }
    }

    private var blocked: some View {
        VStack(spacing: 16) {
            Image(systemName: kind == .unavailable ? "camera" : "video.slash")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                if kind == .denied {
                    Button("Open Settings", action: onOpenSettings)
                        .lensGlassButtonStyle(prominent: true)
                        .tint(Palette.accent)
                        .controlSize(.large)
                }
                Button(action: onScanPhotos) {
                    Label("Scan from Photos", systemImage: "photo.on.rectangle")
                }
                .lensGlassButtonStyle(prominent: kind != .denied)
                .tint(kind == .denied ? .white : Palette.accent)
                .controlSize(.large)
            }
            .padding(.top, 8)
        }
        .foregroundStyle(.white)
    }

    private var title: LocalizedStringKey {
        switch kind {
        case .denied: "Camera access is off"
        case .restricted: "Camera is restricted"
        default: "Camera unavailable"
        }
    }

    private var message: LocalizedStringKey {
        switch kind {
        case .denied: "Turn on camera access in Settings to scan codes live. You can still scan a code in a photo."
        case .restricted: "This device limits camera use. You can still scan a code in a photo."
        default: "Lens can’t use a camera right now. You can still scan a code in a photo."
        }
    }

    private func interruptionMessage(_ reason: ScannerCamera.Interruption) -> LocalizedStringKey {
        switch reason {
        case .inUseByAnotherApp: "Another app is using the camera"
        case .multitasking: "Camera paused while multitasking"
        case .systemPressure: "Camera paused to cool down"
        case .other: "Camera paused"
        }
    }
}

#Preview("Denied") {
    ZStack {
        Color.black.ignoresSafeArea()
        CameraStatusView(kind: .denied, onOpenSettings: {}, onScanPhotos: {})
    }
    .environment(\.colorScheme, .dark)
}
