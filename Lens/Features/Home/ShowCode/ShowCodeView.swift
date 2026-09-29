import SwiftUI
import UIKit

/// A code, full screen, for someone else to scan: the gate agent, the till, a guest's phone.
/// The screen goes to full brightness and stays awake while it's up.
struct ShowCodeView: View {
    let item: ShowCodeItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var brightness = BrightnessBoost()
    @State private var image: UIImage?
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// iPad shows the code larger, for scanning from across a counter.
    private var columnWidth: CGFloat { sizeClass == .regular ? 680 : 560 }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                BrightnessNote()
                if case .travel(let pass) = item.payload {
                    PassFace(pass: pass, image: image)
                    WalletPassButton(pass: pass, raw: item.raw, symbology: item.symbology)
                } else {
                    heading
                    CodePlate(image: image, symbology: item.symbology, label: Text("\(item.symbology.displayName) for \(item.title)"))
                    ShowCodeDetails(item: item)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: columnWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .defaultScrollAnchor(.center)
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .task(id: item.id) {
            let side: CGFloat = item.symbology.isTwoDimensional && item.symbology != .pdf417 ? 300 : 340
            image = CodeArtwork.image(for: item, dimension: sizeClass == .regular ? side * 1.5 : side)
        }
        .onAppear(perform: stayBright)
        .onDisappear(perform: restore)
        .onChange(of: scenePhase) { _, phase in
            phase == .active ? stayBright() : restore()
        }
    }

    private var heading: some View {
        VStack(spacing: 12) {
            KindTile(kind: item.kind, size: 52)
            VStack(spacing: 4) {
                Text(item.title)
                    .font(.title.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                Text(instruction)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
    }

    private var instruction: LocalizedStringKey {
        switch item.kind {
        case .wifi: "Scan with the Camera to join"
        case .link: "Scan with the Camera to open"
        case .contact: "Scan with the Camera to save the contact"
        case .event: "Scan with the Camera to add to Calendar"
        case .product: "Ready to scan at the register"
        default: "Ready to scan"
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            shareButton
            Button("Done") { dismiss() }
                .buttonStyle(.primaryAction())
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: columnWidth)
        .background(alignment: .top) {
            LinearGradient(
                colors: [Color(.systemGroupedBackground).opacity(0), Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .center
            )
            .padding(.top, -24)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        Group {
            if let image {
                let picture = Image(uiImage: image)
                ShareLink(item: picture, preview: SharePreview(item.title, image: picture)) { shareGlyph }
            } else {
                ShareLink(item: item.raw) { shareGlyph }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Share")
    }

    private var shareGlyph: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(Palette.accent)
            .frame(width: 54, height: 54)
            .contentShape(.circle)
            .lensGlass(.regular, in: Circle(), interactive: true)
    }

    private func stayBright() {
        brightness.raise()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func restore() {
        brightness.restore()
        UIApplication.shared.isIdleTimerDisabled = false
    }
}

/// A quiet reminder of why the screen just got brighter.
private struct BrightnessNote: View {
    var body: some View {
        Label("Full brightness while shown", systemImage: "sun.max.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .symbolRenderingMode(.multicolor)
            .padding(.horizontal, 12)
            .frame(minHeight: 30)
            .background(.fill.tertiary, in: .capsule)
    }
}

/// The code on a white plate with a generous quiet zone, whatever the appearance.
struct CodePlate: View {
    var image: UIImage?
    var symbology: Symbology
    var label: Text

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let isSquare = symbology.isTwoDimensional && symbology != .pdf417
        let scale: CGFloat = sizeClass == .regular ? 1.5 : 1
        Group {
            if let image {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.white
            }
        }
        .frame(maxWidth: (isSquare ? 300 : 340) * scale)
        .aspectRatio(image.map { $0.size.width / max($0.size.height, 1) } ?? 1, contentMode: .fit)
        .padding(isSquare ? 24 : 20)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.08), radius: 16, y: 6)
        }
        .accessibilityElement()
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel(label)
    }
}

/// Remembers the screen brightness, turns it all the way up, and puts it back.
@MainActor
struct BrightnessBoost {
    private var saved: CGFloat?

    mutating func raise() {
        guard saved == nil, let screen = Self.screen else { return }
        saved = screen.brightness
        screen.brightness = 1
    }

    mutating func restore() {
        guard let saved, let screen = Self.screen else { return }
        screen.brightness = saved
        self.saved = nil
    }

    private static var screen: UIScreen? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return (scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)?.screen
    }
}

#if DEBUG
#Preview("Wi-Fi") {
    ShowCodeView(item: ShowCodeItem(
        raw: "WIFI:T:WPA;S:Casa Chen;P:limonada-azul-27;;",
        symbology: .qr,
        payload: .wifi(WiFiNetwork(ssid: "Casa Chen", password: "limonada-azul-27")),
        title: "Casa Chen"
    ))
}

#Preview("Boarding pass") {
    ShowCodeView(item: ShowCodeItem(result: .sampleTravel))
}
#endif
