import SwiftUI
import UIKit

/// Full-screen code for showing to a scanner (gate agent, till, a friend's phone).
/// Screen brightness goes to maximum while it's up and comes back when it closes.
struct CodeCover: View {
    var raw: String
    var symbology: Symbology
    var title: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var brightness = BrightnessBoost()

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                SheetCloseButton { dismiss() }
                    .padding(.trailing, -8)
            }

            Spacer(minLength: 0)

            codeImage
                .padding(symbology.isTwoDimensional ? 24 : 20)
                .background(.white, in: .rect(cornerRadius: 24, style: .continuous))
                .accessibilityElement()
                .accessibilityLabel(Text("\(symbology.displayName) code"))
                .accessibilityValue(Text(raw))

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                Text(symbology.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Label("Brightness is turned up while this is open", systemImage: "sun.max.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .onAppear { brightness.raise() }
        .onDisappear { brightness.restore() }
        .onChange(of: scenePhase) { _, phase in
            phase == .active ? brightness.raise() : brightness.restore()
        }
    }

    @ViewBuilder private var codeImage: some View {
        let side: CGFloat = symbology.isTwoDimensional && symbology != .pdf417 ? 280 : 320
        if let image = CodeRenderer.image(raw: raw, symbology: symbology, dimension: side) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                // Hug the code's own shape, so a wide PDF417 or barcode isn't boxed in a square.
                .frame(width: fitted(image.size, in: side).width, height: fitted(image.size, in: side).height)
        } else {
            ContentUnavailableView("Can't draw this code", systemImage: "qrcode", description: Text(raw))
                .foregroundStyle(.black)
                .frame(width: side, height: side / 2)
        }
    }
}

/// The largest size with `size`'s aspect ratio that fits a `side`×`side` square.
private func fitted(_ size: CGSize, in side: CGFloat) -> CGSize {
    guard size.width > 0, size.height > 0 else { return CGSize(width: side, height: side) }
    let scale = min(side / size.width, side / size.height)
    return CGSize(width: size.width * scale, height: size.height * scale)
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
