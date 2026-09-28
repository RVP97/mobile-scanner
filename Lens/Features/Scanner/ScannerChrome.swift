import AVFoundation
import SwiftUI

/// Torch, multi-scan status and the "more" menu, floating over the top of the camera.
struct ScannerTopBar: View {
    var camera: ScannerCamera
    @Binding var isMultiScanActive: Bool
    var onCreate: () -> Void
    var onScanPhotos: () -> Void
    var onScanPasteboard: () -> Void
    var onSettings: () -> Void

    @Namespace private var glass

    var body: some View {
        LensGlassContainer(spacing: 12) {
            HStack(spacing: 12) {
                torch
                Spacer(minLength: 0)
                if isMultiScanActive {
                    multiScanBadge
                        .lensGlassID("multi", in: glass)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
                Spacer(minLength: 0)
                moreMenu
            }
        }
        .animation(.bouncy(duration: 0.35), value: isMultiScanActive)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    @ViewBuilder
    private var torch: some View {
        let hasTorch = camera.capabilities?.hasTorch == true && camera.status == .running
        Button(action: camera.toggleTorch) {
            Image(systemName: camera.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(camera.isTorchOn ? Color.yellow : Color.white)
                .modifier(CircleControl())
        }
        .buttonStyle(.plain)
        .opacity(hasTorch ? 1 : 0)
        .disabled(!hasTorch)
        .accessibilityLabel(camera.isTorchOn ? "Turn Flashlight Off" : "Turn Flashlight On")
        .accessibilityHidden(!hasTorch)
    }

    private var multiScanBadge: some View {
        Button {
            isMultiScanActive = false
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill")
                Text("Multi-scan")
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .lensGlass(.regular, in: Capsule(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Multi-scan on")
        .accessibilityHint("Turns multi-scan off")
    }

    private var moreMenu: some View {
        Menu {
            Section {
                Button(action: onCreate) {
                    Label("Create Code", systemImage: "qrcode")
                }
                Button(action: onScanPhotos) {
                    Label("Scan from Photos", systemImage: "photo.on.rectangle")
                }
                if UIPasteboard.general.hasImages {
                    Button(action: onScanPasteboard) {
                        Label("Scan Copied Image", systemImage: "doc.on.clipboard")
                    }
                }
            }
            Section {
                Toggle(isOn: $isMultiScanActive) {
                    Label("Multi-scan", systemImage: "square.stack.3d.up")
                }
                if camera.canFlip {
                    Button(action: camera.flip) {
                        Label(
                            camera.position == .back ? "Use Front Camera" : "Use Back Camera",
                            systemImage: "arrow.triangle.2.circlepath.camera"
                        )
                    }
                }
            }
            Button(action: onSettings) {
                Label("Settings", systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(.white)
                .modifier(CircleControl())
        }
        .accessibilityLabel("More")
    }
}

/// A 48pt glass circle for icon controls over the camera.
private struct CircleControl: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 48, height: 48)
            .contentShape(Circle())
            .lensGlass(.regular, in: Circle(), interactive: true)
    }
}

/// ".5  1×  2" — the lens switcher docked above the sheet.
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

#Preview("Zoom") {
    ZStack {
        Color.gray
        ZoomCapsule(
            profile: ZoomProfile(minimumDeviceFactor: 1, maximumDeviceFactor: 30, displayMultiplier: 0.5),
            zoom: 1.4,
            select: { _ in }
        )
    }
    .environment(\.colorScheme, .dark)
}
