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
            ScannerTorch(camera: camera)
        } else {
            Color.clear.frame(width: 48, height: 48)
        }
    }
}

/// The flashlight, when the camera has one.
struct ScannerTorch: View {
    var camera: ScannerCamera

    var body: some View {
        if camera.capabilities?.hasTorch == true && camera.status == .running {
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
}

/// Photos · Close · Multi-scan, centered low over the camera. During the last seconds before the
/// scanner closes by itself, a ring drains around Close.
struct ScannerBottomRow: View {
    var controls: ScannerControls

    static let closeDiameter: CGFloat = 72

    var body: some View {
        LensGlassContainer(spacing: 24) {
            HStack(spacing: 40) {
                controls.photos(diameter: 56)
                controls.close(diameter: Self.closeDiameter)
                controls.multi(diameter: 56)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// iPhone Duo, with the status bar down one side: every control stands in that column, as the system's
/// own bar buttons do there, so the camera keeps the rest of the display. The torch and zoom under
/// the clock, Close in the middle where the thumb holding that side rests, Photos and Multi-scan at
/// the foot.
struct ScannerRail: View {
    var camera: ScannerCamera
    var controls: ScannerControls

    static let width: CGFloat = 64

    var body: some View {
        LensGlassContainer(spacing: 16) {
            VStack(spacing: 14) {
                ScannerTorch(camera: camera)
                if let profile = camera.capabilities?.zoom, !profile.presets.isEmpty, camera.status == .running {
                    ZoomCapsule(profile: profile, zoom: camera.displayZoom, axis: .vertical) { camera.setZoom($0) }
                }
                Spacer(minLength: 16)
                controls.close(diameter: 60)
                Spacer(minLength: 16)
                controls.photos(diameter: 48)
                controls.multi(diameter: 48)
            }
        }
        .frame(width: Self.width)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}

/// The scanner's buttons, laid out by `ScannerBottomRow` or `ScannerRail`.
struct ScannerControls {
    /// The countdown ring's fill (1 → 0), or nil when it's hidden.
    var countdown: Double?
    var isMultiScanActive: Binding<Bool>
    var canScanPasteboard: Bool
    var canFlip: Bool
    var onClose: () -> Void
    var onPhotos: () -> Void
    var onPasteboard: () -> Void
    var onFlip: () -> Void

    func photos(diameter: CGFloat) -> some View {
        Button(action: onPhotos) {
            Image(systemName: "photo.on.rectangle")
                .foregroundStyle(.white)
                .modifier(CircleControl(diameter: diameter))
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

    func close(diameter: CGFloat) -> some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: diameter / 3, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: diameter, height: diameter)
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

    func multi(diameter: CGFloat) -> some View {
        let isActive = isMultiScanActive.wrappedValue
        return Button {
            isMultiScanActive.wrappedValue.toggle()
        } label: {
            Image(systemName: isActive ? "square.stack.3d.up.fill" : "square.stack.3d.up")
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(isActive ? Palette.onTint : .white)
                .modifier(CircleControl(diameter: diameter, tint: isActive ? Palette.accent : nil))
        }
        .buttonStyle(.plain)
        .lensFeedback(.selection, trigger: isActive)
        .accessibilityLabel("Multi-scan")
        .accessibilityValue(isActive ? Text("On") : Text("Off"))
        .accessibilityAddTraits(isActive ? .isSelected : [])
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

/// ".5  1×  2" — the lens switcher (top to bottom on iPhone Duo's rail).
struct ZoomCapsule: View {
    var profile: ZoomProfile
    var zoom: CGFloat
    /// Down the rail on iPhone Duo.
    var axis: Axis = .horizontal
    var select: (CGFloat) -> Void

    var body: some View {
        let active = profile.activePreset(for: zoom)
        let layout = axis == .horizontal ? AnyLayout(HStackLayout(spacing: 2)) : AnyLayout(VStackLayout(spacing: 2))
        layout {
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
        ScannerBottomRow(controls: ScannerControls(
            countdown: 0.6, isMultiScanActive: .constant(true), canScanPasteboard: false, canFlip: false,
            onClose: {}, onPhotos: {}, onPasteboard: {}, onFlip: {}
        ))
    }
    .environment(\.colorScheme, .dark)
}
