import SwiftUI

// OWNER: Create module.

/// Screens pushed inside the Create modal.
enum CreateRoute: Hashable {
    case compose(CreateIntent)
    case advanced(Symbology)
    case studio(CodeDocument)
    case formats
}

extension EnvironmentValues {
    /// Closes the whole Create modal from any pushed screen.
    @Entry var dismissCreate: DismissCreateAction = DismissCreateAction {}
}

struct DismissCreateAction {
    var action: () -> Void
    func callAsFunction() { action() }
}

/// Intent-first creation: pick what to share, fill it in, then make it yours.
struct CreateView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var path: [CreateRoute] = CreateView.initialPath

    var body: some View {
        NavigationStack(path: $path) {
            IntentPicker()
                .navigationDestination(for: CreateRoute.self) { route in
                    switch route {
                    case .compose(let intent):
                        ComposeView(draft: Self.draft(for: intent))
                    case .advanced(let format):
                        ComposeView(draft: CreateDraft(format: format))
                    case .studio(let document):
                        StudioView(document: document)
                    case .formats:
                        FormatPicker()
                    }
                }
        }
        .environment(\.dismissCreate, DismissCreateAction { dismiss() })
    }

    private static func draft(for intent: CreateIntent) -> CreateDraft {
        let draft = CreateDraft(intent: intent)
#if DEBUG
        QAHarness.fill(draft)
#endif
        return draft
    }

    private static var initialPath: [CreateRoute] {
#if DEBUG
        defer { QAHarness.createPath = [] }
        return QAHarness.createPath
#else
        return []
#endif
    }
}

/// The first screen: the four things people share most as big tiles, the rest as a list, then the
/// full format list for experts.
private struct IntentPicker: View {
    @Environment(\.dismissCreate) private var dismissCreate
    @Environment(\.dynamicTypeSize) private var typeSize

    private static let featured: [CreateIntent] = [.link, .wifi, .contact, .text]
    private static var more: [CreateIntent] { CreateIntent.allCases.filter { !featured.contains($0) } }

    private var columns: [GridItem] {
        let count = typeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Self.featured) { intent in
                        NavigationLink(value: CreateRoute.compose(intent)) {
                            IntentTile(intent: intent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                group(title: "More") {
                    ForEach(Self.more) { intent in
                        NavigationLink(value: CreateRoute.compose(intent)) {
                            IntentRow(title: Text(intent.title), subtitle: Text(intent.subtitle)) {
                                KindTile(kind: intent.kind, size: 36)
                            }
                        }
                        .buttonStyle(.plain)
                        if intent != Self.more.last {
                            Divider().padding(.leading, 64)
                        }
                    }
                }

                group(title: "Advanced") {
                    NavigationLink(value: CreateRoute.formats) {
                        IntentRow(
                            title: Text("Choose a Format"),
                            subtitle: Text("Code 128, Data Matrix, ITF-14, Codabar and more")
                        ) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)
                                .background(.fill.tertiary, in: .rect(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Create")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismissCreate() }
            }
        }
    }

    private func group<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MicroLabel(title)
                .padding(.leading, 16)
            VStack(spacing: 0) { content() }
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20, style: .continuous))
        }
    }
}

private struct IntentTile: View {
    var intent: CreateIntent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            KindTile(kind: intent.kind, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(intent.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(intent.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20, style: .continuous))
        .contentShape(.rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

/// A compact list row inside a grouped card: glyph, title and one line, chevron.
private struct IntentRow<Icon: View>: View {
    var title: Text
    var subtitle: Text
    @ViewBuilder var icon: Icon

    var body: some View {
        HStack(spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 1) {
                title
                    .font(.body)
                    .foregroundStyle(.primary)
                subtitle
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 56)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// Every format Lens can make, for people who know exactly what their label printer wants.
private struct FormatPicker: View {
    var body: some View {
        List {
            Section {
                ForEach(Symbology.generatable.filter(\.isTwoDimensional)) { row($0) }
            } header: {
                Text("2D codes")
            }
            Section {
                ForEach(Symbology.generatable.filter { !$0.isTwoDimensional }) { row($0) }
            } header: {
                Text("Barcodes")
            }
        }
        .navigationTitle("Formats")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ format: Symbology) -> some View {
        NavigationLink(value: CreateRoute.advanced(format)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(format.displayName)
                Text(format.usage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension Symbology {
    /// One line on what the format is for, shown in the format list.
    var usage: LocalizedStringResource {
        switch self {
        case .qr: "Links, Wi-Fi, anything. Every phone reads it."
        case .aztec: "Tickets and boarding passes"
        case .pdf417: "IDs and shipping labels"
        case .dataMatrix: "Tiny parts, healthcare, electronics"
        case .code128: "Shipping and inventory labels"
        case .ean13: "Retail products worldwide"
        case .ean8: "Small retail packages"
        case .upcA: "Retail products in North America"
        case .upcE: "Small packages in North America"
        case .code39: "Industry, badges and IDs"
        case .itf14: "Cartons and cases (GTIN-14)"
        case .itf: "Warehouses and logistics"
        case .msi: "Shelf labels and inventory"
        case .pharmacode: "Pharmaceutical packaging control"
        case .codabar: "Libraries, blood banks, couriers"
        case .microQR, .microPDF417, .code93, .gs1DataBar: "Read only"
        }
    }
}

#Preview {
    CreateView()
        .modelContainer(for: [ScanRecord.self, SavedStyle.self], inMemory: true)
}
