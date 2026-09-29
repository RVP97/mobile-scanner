import SwiftUI

/// Under every result: keep it (pin to Home), where it was scanned, and, over the camera, the way
/// back to scanning.
struct ResultFooter: View {
    var result: ScanResult
    var offersScanAnother: Bool

    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { buttons }
                VStack(spacing: 12) { buttons }
            }
            .buttonStyle(FooterButtonStyle())

            if let placeName = result.placeName {
                Label("Scanned at \(placeName)", systemImage: "mappin.and.ellipse")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var buttons: some View {
        PinButton(result: result)
        if offersScanAnother {
            Button(action: model.scanAnother) {
                Label("Scan Another", systemImage: "qrcode.viewfinder")
            }
        }
    }
}

/// A quiet capsule: present, but clearly after the result's own actions.
private struct FooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(.fill.tertiary, in: .capsule)
            .contentShape(.capsule)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}
