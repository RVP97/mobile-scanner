import SwiftUI

/// "Show code": a clean rendering of a History item, big enough for someone else to scan.
struct CodePreviewSheet: View {
    let record: ScanRecord

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let image = CodeRenderer.image(raw: record.raw, symbology: record.symbology, dimension: 280)

        NavigationStack {
            VStack(spacing: 24) {
                if let image {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 280, maxHeight: 280)
                        .padding(20)
                        // Codes need a light quiet zone to scan, whatever the appearance.
                        .background(.white, in: .rect(cornerRadius: 24, style: .continuous))
                        .accessibilityLabel(Text("\(record.symbology.displayName) for \(record.historyTitle)"))
                } else {
                    ContentUnavailableView(
                        "Can't Draw This Code",
                        systemImage: "exclamationmark.triangle",
                        description: Text("This content doesn't fit the \(record.symbology.displayName) format.")
                    )
                }
                Text(record.raw)
                    .font(.footnote)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .textSelection(.enabled)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(record.historyTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                if let image {
                    ToolbarItem(placement: .topBarLeading) {
                        let shared = Image(uiImage: image)
                        ShareLink(item: shared, preview: SharePreview(record.historyTitle, image: shared)) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#if DEBUG
#Preview {
    CodePreviewSheet(record: HistorySamples.records()[0])
        .modelContainer(HistorySamples.container)
}
#endif
