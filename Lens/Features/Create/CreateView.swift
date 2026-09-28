import SwiftUI

// OWNER: Create module.

/// Screens pushed inside the Create modal.
enum CreateRoute: Hashable {
    case compose(CreateIntent)
    case advanced(Symbology)
    case studio(CodeDocument)
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
    @State private var path: [CreateRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            IntentPicker()
                .navigationDestination(for: CreateRoute.self) { route in
                    switch route {
                    case .compose(let intent):
                        ComposeView(draft: CreateDraft(intent: intent))
                    case .advanced(let format):
                        ComposeView(draft: CreateDraft(format: format))
                    case .studio(let document):
                        StudioView(document: document)
                    }
                }
        }
        .environment(\.dismissCreate, DismissCreateAction { dismiss() })
    }
}

/// The first screen: a grid of things people share, plus the full format list for experts.
private struct IntentPicker: View {
    @Environment(\.dismissCreate) private var dismissCreate
    @Environment(\.dynamicTypeSize) private var typeSize

    private var columns: [GridItem] {
        let count = typeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(CreateIntent.allCases) { intent in
                        NavigationLink(value: CreateRoute.compose(intent)) {
                            IntentTile(intent: intent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    MicroLabel("Advanced")
                        .padding(.leading, 4)
                    NavigationLink {
                        FormatPicker()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 32)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Choose a Format")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text("Code 128, Data Matrix, ITF-14, Codabar and more")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20, style: .continuous))
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
}

private struct IntentTile: View {
    var intent: CreateIntent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            KindTile(kind: intent.kind, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(intent.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
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
