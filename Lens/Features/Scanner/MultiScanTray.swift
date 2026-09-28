import SwiftUI

/// Multi-scan collection over the camera: a fanned stack of the latest codes and "Done · N".
struct MultiScanTray: View {
    var codes: [ScanResult]
    var onDone: () -> Void

    var body: some View {
        if codes.isEmpty {
            hint
        } else {
            HStack(alignment: .bottom, spacing: 16) {
                Button(action: onDone) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("^[\(codes.count) code](inflect: true)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText(value: Double(codes.count)))
                        stack
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("^[\(codes.count) code](inflect: true) collected"))
                .accessibilityHint("Shows the list")

                Spacer(minLength: 0)

                Button(action: onDone) {
                    Text("Done · \(codes.count)")
                        .font(.headline)
                        .foregroundStyle(Palette.onTint)
                        .contentTransition(.numericText(value: Double(codes.count)))
                        .padding(.horizontal, 8)
                        .frame(minHeight: 36)
                }
                .lensGlassButtonStyle(prominent: true)
                .tint(Palette.accent)
                .controlSize(.large)
            }
        }
    }

    private var hint: some View {
        Label("Scan codes one after another", systemImage: "square.stack.3d.up")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .lensGlass(.regular, in: Capsule())
            .frame(maxWidth: .infinity)
    }

    /// Newest in front; the two before it fan out behind.
    private var stack: some View {
        let recent = Array(codes.suffix(3))
        return ZStack(alignment: .bottomLeading) {
            ForEach(Array(recent.enumerated()), id: \.element.id) { index, result in
                let depth = recent.count - 1 - index
                MiniCodeCard(result: result, isNewest: depth == 0)
                    .rotationEffect(.degrees([0, -5, 4][depth]), anchor: .bottom)
                    .offset(x: CGFloat(depth) * 10, y: CGFloat(depth) * -6)
                    .scaleEffect(1 - CGFloat(depth) * 0.04, anchor: .bottom)
                    .zIndex(Double(-depth))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.top, 12)
        .accessibilityHidden(true)
    }
}

private struct MiniCodeCard: View {
    var result: ScanResult
    var isNewest: Bool

    var body: some View {
        HStack(spacing: 10) {
            KindTile(kind: result.payload.kind, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(result.payload.kind.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(result.payload.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .padding(.trailing, 6)
        .frame(width: 188, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(isNewest ? 0.14 : 0.06))
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

#if DEBUG
#Preview("Multi-scan tray") {
    let samples: [ScanResult] = [
        ScanResult(code: ScannedCode(raw: "https://atlas-coffee.co/menu", symbology: .qr), payload: .link(URL(string: "https://atlas-coffee.co/menu")!)),
        ScanResult(code: ScannedCode(raw: "4006381333931", symbology: .ean13), payload: .product(gtin: "4006381333931")),
        ScanResult(
            code: ScannedCode(raw: "WIFI:S:Atlas Guest;T:WPA;P:cortado-2019;;", symbology: .qr),
            payload: .wifi(WiFiNetwork(ssid: "Atlas Guest", password: "cortado-2019"))
        ),
    ]
    ZStack(alignment: .bottom) {
        Color.gray.opacity(0.6)
        MultiScanTray(codes: samples, onDone: {})
            .padding(16)
    }
    .environment(\.colorScheme, .dark)
}
#endif
