import SwiftData
import SwiftUI

/// "Your codes": what the person made and what they pinned, as Wallet-style cards that open full
/// screen for someone else to scan.
struct YourCodesSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(CodeShelf.descriptor) private var records: [ScanRecord]

    var body: some View {
        let codes = CodeShelf.arrange(records)
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "Your codes") {
                if !codes.isEmpty {
                    Button { model.openCreate() } label: {
                        Label("New Code", systemImage: "plus")
                    }
                }
            }
            .padding(.horizontal, 20)

            if codes.isEmpty {
                EmptyShelfCard { model.openCreate(.compose(.wifi)) }
                    .padding(.horizontal, 20)
            } else if typeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    ForEach(codes) { card(for: $0) }
                }
                .padding(.horizontal, 20)
            } else if sizeClass == .regular {
                grid(codes)
            } else {
                carousel(codes)
            }
        }
        // The "My Code" widget mirrors the front card of the shelf.
        .task(id: codes.first.map { "\($0.id)\($0.raw)" }) { syncWidget(with: codes.first) }
    }

    private func syncWidget(with record: ScanRecord?) {
        guard let record,
              let image = CodeRenderer.image(raw: record.raw, symbology: record.symbology, dimension: 240)
        else { return SharedCodeStore.clearPinnedCode() }
        SharedCodeStore.setPinnedCode(image: image, title: record.historyTitle)
    }

    private func carousel(_ codes: [ScanRecord]) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(codes) { record in
                    card(for: record)
                        .containerRelativeFrame(.horizontal) { length, _ in
                            // A lone card fills the row; otherwise the next one peeks in.
                            codes.count == 1 ? length : min(length - 36, 360)
                        }
                        .aspectRatio(1.586, contentMode: .fit)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .scrollClipDisabled()
    }

    /// iPad: every card in view, two to a row, like passes laid out on a table.
    private func grid(_ codes: [ScanRecord]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
            ForEach(codes) { record in
                card(for: record)
                    .aspectRatio(1.586, contentMode: .fit)
            }
        }
        .padding(.horizontal, 20)
    }

    private func card(for record: ScanRecord) -> some View {
        Button { model.codeOnDisplay = ShowCodeItem(record: record) } label: {
            CodeCard(record: record)
        }
        .buttonStyle(CardPressStyle())
        .shadow(color: record.kind.cardColor.opacity(0.22), radius: 12, y: 6)
        .contextMenu { menu(for: record) }
    }

    @ViewBuilder
    private func menu(for record: ScanRecord) -> some View {
        Button("Show Code", systemImage: "qrcode") { model.codeOnDisplay = ShowCodeItem(record: record) }
        ShareLink(item: record.raw) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        if record.origin == .created, Symbology.generatable.contains(record.symbology) {
            Button("Edit Style", systemImage: "paintbrush") { model.openCreate(.restyle(record)) }
        }
        if record.isPinned {
            Button("Unpin", systemImage: "pin.slash") {
                withAnimation(.snappy) { record.isPinned = false }
            }
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) {
            withAnimation(.snappy) { modelContext.delete(record) }
        }
    }
}

/// Title and an optional trailing action, shared by Home's sections.
struct HomeSectionHeader<Trailing: View>: View {
    var title: LocalizedStringKey
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            trailing
                .font(.body)
                .labelStyle(.titleOnly)
                .tint(Palette.accent)
        }
    }
}

/// A light press for cards: they sink a little, like something physical.
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

/// Before there's anything to show: an invitation to make the most useful code there is.
private struct EmptyShelfCard: View {
    var onCreateWiFi: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Share your Wi-Fi with a code")
                        .font(.headline)
                    Text("Guests point their camera and they’re on. No spelling out passwords.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                GhostCard()
                    .padding(.top, 4)
            }
            Button(action: onCreateWiFi) {
                Text("Create Wi-Fi Code")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.onTint)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(CodeKind.wifi.tint, in: .capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(CardPressStyle())
            .padding(.top, 16)

            Divider()
                .padding(.vertical, 16)

            Label("Pin any scan to keep it here.", systemImage: "pin")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20, style: .continuous))
    }
}

/// A small tilted Wi-Fi card, hinting at what will live here.
private struct GhostCard: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            CardSurface(color: CodeKind.wifi.cardColor)
            Image(systemName: "wifi")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(10)
            Image(systemName: "qrcode")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.black)
                .padding(3)
                .background(.white, in: .rect(cornerRadius: 5, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(8)
        }
        .frame(width: 92, height: 58)
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
        .rotationEffect(.degrees(-6))
        .shadow(color: CodeKind.wifi.cardColor.opacity(0.25), radius: 8, y: 4)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Codes") {
    ScrollView { YourCodesSection() }
        .background(Color(.systemGroupedBackground))
        .environment(AppModel())
        .modelContainer(HistorySamples.container)
}

#Preview("Empty") {
    ScrollView { YourCodesSection() }
        .background(Color(.systemGroupedBackground))
        .environment(AppModel())
        .modelContainer(for: ScanRecord.self, inMemory: true)
}
#endif
