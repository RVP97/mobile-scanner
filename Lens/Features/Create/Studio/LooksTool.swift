import SwiftData
import SwiftUI

/// Built-in presets, then the person's saved styles and "Save Style". Tap to apply;
/// long-press a saved style to rename or delete it.
struct LooksTool: View {
    var model: StudioModel
    @Query(sort: \SavedStyle.createdAt, order: .reverse) private var saved: [SavedStyle]
    @Environment(\.modelContext) private var modelContext

    @State private var naming: Naming?
    @State private var name = ""
    @State private var justSaved = 0

    /// What the name alert is for.
    private enum Naming: Identifiable {
        case new
        case rename(SavedStyle)

        var id: String {
            switch self {
            case .new: "new"
            case .rename(let style): style.id.uuidString
            }
        }
    }

    private let columns = [GridItem(.adaptive(minimum: 66), spacing: 8, alignment: .top)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ToolHeader("Presets")
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(StylePreset.all) { preset in
                    let applied = model.style.applyingPreset(preset.style)
                    look(title: Text(preset.name), style: applied, isSelected: applied == model.style) {
                        withAnimation(.smooth) { model.style = applied }
                    }
                }
            }

            ToolHeader("My Styles", note: saved.isEmpty ? Text("Save a look to reuse it") : nil)
                .padding(.top, 4)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(saved) { savedStyle in
                    if let style = CodeStyle.decoded(from: savedStyle.styleData) {
                        look(title: Text(verbatim: savedStyle.name), style: style,
                             isSelected: model.style.applyingLook(of: style) == model.style) { apply(style) }
                            .contextMenu {
                                Button {
                                    name = savedStyle.name
                                    naming = .rename(savedStyle)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    withAnimation(.smooth) { modelContext.delete(savedStyle) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                saveButton
            }
        }
        .alert(alertTitle, isPresented: Binding { naming != nil } set: { if !$0 { naming = nil } }) {
            TextField("Name", text: $name)
            Button("Cancel", role: .cancel) {}
            Button("Save") { commitName() }
        }
    }

    private var saveButton: some View {
        Button {
            name = ""
            naming = .new
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, height: 60)
                    .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.tertiary, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                    .padding(3)
                Text("Save Style")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: justSaved)
    }

    private var alertTitle: Text {
        if case .rename = naming { Text("Rename Style") } else { Text("Save Style") }
    }

    private func look(title: Text, style: CodeStyle, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                StyleThumbnail(style: style, logoImage: LogoImages.glyphMask(model.document.kind.symbol))
                    .overlay {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .strokeBorder(isSelected ? Palette.accent : .clear, lineWidth: 2.5)
                            .padding(-3)
                    }
                    .padding(3)
                title
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 64)
            }
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(Text("Applies this look"))
    }

    private func apply(_ look: CodeStyle) {
        withAnimation(.smooth) { model.style = model.style.applyingLook(of: look) }
    }

    private func commitName() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        switch naming {
        case .new:
            let fallback = String(localized: "Style \(saved.count + 1)")
            var look = model.style
            look.caption = ""
            modelContext.insert(SavedStyle(name: trimmed.isEmpty ? fallback : trimmed, styleData: look.encoded()))
            justSaved += 1
        case .rename(let style):
            if !trimmed.isEmpty { style.name = trimmed }
        case nil:
            break
        }
        naming = nil
    }
}
