import SwiftUI

/// Everything collected in a multi-scan session (or found in one photo), shown in the sheet.
struct MultiScanReview: View {
    @Environment(AppModel.self) private var model
    @State private var copied = 0

    var body: some View {
        NavigationStack {
            Group {
                if model.multiScanCodes.isEmpty {
                    ContentUnavailableView(
                        "No Codes Yet",
                        systemImage: "square.stack.3d.up",
                        description: Text("Codes you scan in multi-scan collect here.")
                    )
                } else {
                    list
                }
            }
            .navigationTitle(Text("^[\(model.multiScanCodes.count) Code](inflect: true)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .sensoryFeedback(.success, trigger: copied)
    }

    private var list: some View {
        List {
            ForEach(model.multiScanCodes) { result in
                Button {
                    model.show(result)
                } label: {
                    MultiScanRow(result: result)
                }
                .tint(.primary)
            }
            .onDelete { offsets in
                model.multiScanCodes.remove(atOffsets: offsets)
                updateActivity()
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Clear", role: .destructive) {
                withAnimation(.smooth) { model.multiScanCodes.removeAll() }
                updateActivity()
            }
            .disabled(model.multiScanCodes.isEmpty)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Done", action: finish)
        }
        ToolbarItemGroup(placement: .bottomBar) {
            Button {
                UIPasteboard.general.string = allText
                copied += 1
            } label: {
                Label("Copy All", systemImage: "doc.on.doc")
            }
            .disabled(model.multiScanCodes.isEmpty)
            Spacer()
            ShareLink(item: allText) {
                Label("Share All", systemImage: "square.and.arrow.up")
            }
            .disabled(model.multiScanCodes.isEmpty)
        }
    }

    /// One code per line, as printed in the codes.
    private var allText: String {
        model.multiScanCodes.map(\.code.raw).joined(separator: "\n")
    }

    private func updateActivity() {
        guard model.isMultiScanActive else { return }
        let codes = model.multiScanCodes
        MultiScanActivity.update(
            count: codes.count,
            kinds: codes.map(\.payload.kind),
            latest: codes.last?.payload.displayTitle ?? ""
        )
    }

    /// Ends the session: the codes are already in History.
    private func finish() {
        model.isMultiScanActive = false
        model.multiScanCodes.removeAll()
        model.dismissResult()
    }
}

private struct MultiScanRow: View {
    var result: ScanResult

    var body: some View {
        HStack(spacing: 12) {
            KindTile(kind: result.payload.kind, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.payload.displayTitle)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text("\(Text(result.payload.kind.title)) · \(result.code.symbology.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Multi-scan review") {
    let model = AppModel()
    model.multiScanCodes = [
        ScanResult(code: ScannedCode(raw: "https://atlas-coffee.co/menu", symbology: .qr), payload: .link(URL(string: "https://atlas-coffee.co/menu")!)),
        ScanResult(code: ScannedCode(raw: "4006381333931", symbology: .ean13), payload: .product(gtin: "4006381333931")),
        ScanResult(
            code: ScannedCode(raw: "WIFI:S:Atlas Guest;T:WPA;P:cortado-2019;;", symbology: .qr),
            payload: .wifi(WiFiNetwork(ssid: "Atlas Guest", password: "cortado-2019"))
        ),
    ]
    return MultiScanReview()
        .environment(model)
}
#endif
