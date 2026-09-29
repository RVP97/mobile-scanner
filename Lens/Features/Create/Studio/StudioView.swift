import SwiftData
import SwiftUI

/// "Make it yours": live preview on a neutral stage, a scannability meter that re-reads every
/// change, and tools along the bottom.
struct StudioView: View {
    @State private var model: StudioModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismissCreate) private var dismissCreate
    @Environment(\.modelContext) private var modelContext

    init(document: CodeDocument, style: CodeStyle = CodeStyle(), record: ScanRecord? = nil) {
        let model = StudioModel(document: document, style: style, record: record)
#if DEBUG
        if let tool = QAHarness.studioTool, model.tools.contains(tool) { model.tool = tool }
        if let style = QAHarness.studioStyle { model.style = style }
#endif
        _model = State(initialValue: model)
    }

    /// Reopens a code made earlier with its saved style; changes update that same entry.
    init(record: ScanRecord) {
        let style = CodeStyle.decoded(from: record.styleData) ?? CodeStyle()
        let document = CodeDocument(
            raw: record.raw,
            symbology: record.symbology,
            payload: PayloadParser.parse(record.raw, symbology: record.symbology),
            title: record.historyTitle,
            caption: style.caption
        )
        self.init(document: document, style: style, record: record)
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
                        .padding(.top, 12)
                        .padding(.bottom, 8)
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
                Button("Done") {
                    // A finished code lives on Home under "Your codes".
                    model.recordCreation()
                    dismissCreate()
                }
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
        .onDisappear { if model.editsSavedCode { model.recordCreation() } }
    }

    private var stage: some View {
        ZStack {
            StudioStage()
            CodeCanvas(scene: model.scene)
                .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
                .padding(model.isLinear ? 20 : 24)
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
            if model.tools.count > 1 {
                StudioToolBar(selection: $model.tool, tools: model.tools)
                    .padding(.horizontal, 16)
            }
            ScrollView {
                toolPanel
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 150, maxHeight: sizeClass == .regular ? .infinity : 230)
            .scrollBounceBehavior(.basedOnSize)
            .mask {
                // Content that continues below fades out instead of being cut by the export bar.
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 20)
                }
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var toolPanel: some View {
        switch model.tool {
        case .looks: LooksTool(model: model)
        case .dots: DotsTool(model: model)
        case .corners: CornersTool(model: model)
        case .color: ColorTool(model: model)
        case .logo: LogoTool(model: model)
        case .frame: FrameTool(model: model)
        }
    }
}

/// The neutral surface the code sits on: a quiet dot grid, like a design tool's canvas.
private struct StudioStage: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        shape
            .fill(Color(light: 0xE8E9ED, dark: 0x1F1F21))
            .overlay {
                Canvas { context, size in
                    let spacing: CGFloat = 16
                    var dots = Path()
                    var y = spacing / 2
                    while y < size.height {
                        var x = spacing / 2
                        while x < size.width {
                            dots.addEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
                            x += spacing
                        }
                        y += spacing
                    }
                    context.fill(dots, with: .style(.primary.opacity(0.1)))
                }
                .clipShape(shape)
            }
            .accessibilityHidden(true)
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
