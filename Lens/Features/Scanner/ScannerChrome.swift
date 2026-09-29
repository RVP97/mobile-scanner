import AVFoundation
import SwiftUI

/// Torch on the left, the lens switcher on the right, floating over the top of the camera.
struct ScannerTopBar: View {
    var camera: ScannerCamera

    var body: some View {
        LensGlassContainer(spacing: 12) {
            HStack(spacing: 12) {
                torch
                Spacer(minLength: 0)
                if let profile = camera.capabilities?.zoom, !profile.presets.isEmpty, camera.status == .running {
                    ZoomCapsule(profile: profile, zoom: camera.displayZoom) { camera.setZoom($0) }
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    @ViewBuilder
    private var torch: some View {
        if camera.capabilities?.hasTorch == true && camera.status == .running {
            torchButton
        } else {
            Color.clear.frame(width: 48, height: 48)
        }
    }

    private var torchButton: some View {
        Button(action: camera.toggleTorch) {
            Image(systemName: camera.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(camera.isTorchOn ? Color.yellow : Color.white)
                .modifier(CircleControl())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(camera.isTorchOn ? "Turn Flashlight Off" : "Turn Flashlight On")
    }
}

/// Photos · Close · Multi-scan, with Close exactly where Home's Scan lens was. During the last
/// seconds before the scanner closes by itself, a ring drains around Close.
struct ScannerBottomRow: View {
    /// The countdown ring's fill (1 → 0), or nil when it's hidden.
    var countdown: Double?
    @Binding var isMultiScanActive: Bool
    var canScanPasteboard: Bool
    var canFlip: Bool
    var onClose: () -> Void
    var onPhotos: () -> Void
    var onPasteboard: () -> Void
    var onFlip: () -> Void

    static let closeDiameter: CGFloat = 72

    var body: some View {
        LensGlassContainer(spacing: 24) {
            HStack(spacing: 40) {
                photos
                close
                multi
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var photos: some View {
        Button(action: onPhotos) {
            Image(systemName: "photo.on.rectangle")
                .foregroundStyle(.white)
                .modifier(CircleControl(diameter: 56))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scan from Photos")
        .contextMenu {
            if canScanPasteboard {
                Button("Scan Copied Image", systemImage: "doc.on.clipboard", action: onPasteboard)
            }
            if canFlip {
                Button("Switch Camera", systemImage: "arrow.triangle.2.circlepath.camera", action: onFlip)
            }
        }
    }

    private var close: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Self.closeDiameter, height: Self.closeDiameter)
                .contentShape(.circle)
                .lensGlass(.regular, in: Circle(), interactive: true)
                .overlay {
                    if let countdown {
                        Circle()
                            .trim(from: 0, to: countdown)
                            .stroke(Palette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .padding(-5)
                            .transition(.opacity)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close Camera")
        .accessibilityValue(countdown == nil ? Text("") : Text("Closing soon"))
    }

    private var multi: some View {
        Button {
            isMultiScanActive.toggle()
        } label: {
            Image(systemName: isMultiScanActive ? "square.stack.3d.up.fill" : "square.stack.3d.up")
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(isMultiScanActive ? Palette.onTint : .white)
                .modifier(CircleControl(diameter: 56, tint: isMultiScanActive ? Palette.accent : nil))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isMultiScanActive)
        .accessibilityLabel("Multi-scan")
        .accessibilityValue(isMultiScanActive ? Text("On") : Text("Off"))
        .accessibilityAddTraits(isMultiScanActive ? .isSelected : [])
    }
}

/// A glass circle for icon controls over the camera.
private struct CircleControl: ViewModifier {
    var diameter: CGFloat = 48
    var tint: Color?

    func body(content: Content) -> some View {
        content
            .font(.system(size: 18, weight: .semibold))
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .lensGlass(.regular, in: Circle(), interactive: true, tint: tint)
    }
}

/// ".5  1×  2" — the lens switcher.
struct ZoomCapsule: View {
    var profile: ZoomProfile
    var zoom: CGFloat
    var select: (CGFloat) -> Void

    var body: some View {
        let active = profile.activePreset(for: zoom)
        HStack(spacing: 2) {
            ForEach(profile.presets, id: \.self) { preset in
                let isActive = preset == active
                Button {
                    select(preset)
                } label: {
                    Text(verbatim: isActive ? "\(ZoomProfile.label(for: zoom))×" : ZoomProfile.label(for: preset))
                        .font(.footnote.weight(.semibold).monospacedDigit())
                        .foregroundStyle(isActive ? Palette.accent : .white)
                        .frame(width: 36, height: 36)
                        .background(isActive ? Color.black.opacity(0.35) : .clear, in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Zoom \(ZoomProfile.label(for: preset))×"))
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .padding(2)
        .lensGlass(.regular, in: Capsule())
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .animation(.snappy(duration: 0.2), value: active)
    }
}

/// A transient glass capsule under the top controls.
struct ScannerToast: View {
    var toast: ScanCoordinator.Toast

    var body: some View {
        Label {
            Text(toast.message)
        } icon: {
            Image(systemName: toast.symbol)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .lensGlass(.regular, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

#Preview("Bottom row") {
    ZStack {
        Color.gray
        ScannerBottomRow(
            countdown: 0.6, isMultiScanActive: .constant(true), canScanPasteboard: false, canFlip: false,
            onClose: {}, onPhotos: {}, onPasteboard: {}, onFlip: {}
        )
    }
    .environment(\.colorScheme, .dark)
}
