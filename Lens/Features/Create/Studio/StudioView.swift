import SwiftData
import SwiftUI

/// "Make it yours": live preview on a neutral stage, a scannability meter that re-reads every
/// change, and tools along the bottom.
struct StudioView: View {
    @State private var model: StudioModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismissCreate) private var dismissCreate
    @Environment(\.modelContext) private var modelContext

    init(document: CodeDocument) {
        _model = State(initialValue: StudioModel(document: document))
    }

    var body: some View {
        Group {
            if sizeClass == .regular {
                HStack(spacing: 0) {
                    VStack(spacing: 12) {
                        stage
                        ScannabilityMeter(model: model)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    controls
                        .frame(width: 400)
                        .background(Color(.secondarySystemGroupedBackground))
                }
            } else {
                VStack(spacing: 0) {
                    stage
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    ScannabilityMeter(model: model)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    controls
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text("Make it yours").font(.headline)
                    Text(verbatim: "\(model.document.title) · \(String(localized: model.document.kind.title))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismissCreate() }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ExportBar(model: model)
        }
        .task(id: model.verificationKey) {
            // Debounce: let a color drag settle before rendering and decoding again.
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            await model.verify()
        }
        .onAppear { model.modelContext = modelContext }
    }

    private var stage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
            CodeCanvas(scene: model.scene)
                .padding(model.isLinear ? 16 : 20)
                .accessibilityElement()
                .accessibilityAddTraits(.isImage)
                .accessibilityLabel(Text("\(model.document.symbology.displayName) for \(model.document.title)"))
        }
        .frame(maxHeight: sizeClass == .regular ? 560 : .infinity)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .layoutPriority(-1)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if model.isQR { LooksRow(model: model) }
            if model.tools.count > 1 {
                Picker("Tool", selection: $model.tool) {
                    ForEach(model.tools) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
            }
            ScrollView {
                toolPanel
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 150, maxHeight: sizeClass == .regular ? .infinity : 210)
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var toolPanel: some View {
        switch model.tool {
        case .dots: DotsTool(model: model)
        case .corners: CornersTool(model: model)
        case .color: ColorTool(model: model)
        case .logo: LogoTool(model: model)
        case .frame: FrameTool(model: model)
        }
    }
}

#Preview("Wi-Fi QR") {
    NavigationStack {
        StudioView(document: CodeDocument(
            raw: "WIFI:T:WPA;S:Casa Chen;P:correct horse;;",
            symbology: .qr,
            payload: .wifi(WiFiNetwork(ssid: "Casa Chen", password: "correct horse")),
            title: "Casa Chen",
            caption: "Scan to join Casa Chen"
        ))
    }
    .modelContainer(for: [ScanRecord.self, SavedStyle.self], inMemory: true)
}

#Preview("EAN-13") {
    NavigationStack {
        StudioView(document: CodeDocument(
            raw: "4006381333931", symbology: .ean13, payload: .product(gtin: "4006381333931"),
            title: "4006381333931", caption: "Scan for product details"
        ))
    }
    .modelContainer(for: [ScanRecord.self, SavedStyle.self], inMemory: true)
}
