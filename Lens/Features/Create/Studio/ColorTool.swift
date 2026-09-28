import SwiftUI

struct ColorTool: View {
    @Bindable var model: StudioModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ToolHeader("Palette", note: Text("Checked against the background"))
            SwatchRow {
                ForEach(CodePalette.all) { palette in
                    PaletteSwatch(
                        palette: palette,
                        isSelected: model.style.paletteID == palette.id,
                        isLowContrast: contrast(of: palette) < ScannabilityChecker.minimumContrast
                    ) {
                        model.style.apply(palette: palette)
                    }
                }
                CustomSwatch(selection: colorBinding(\.foreground), isSelected: model.style.paletteID == nil)
            }
            if let flagged = lowContrastPalette {
                Label {
                    Text("**Low contrast** · \(String(localized: flagged.name)) is \(contrast(of: flagged).formatted(.number.precision(.fractionLength(1)))):1 on this background")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.footnote)
                .foregroundStyle(Palette.caution)
            }

            VStack(spacing: 0) {
                Toggle(isOn: $model.style.usesGradient.animation(.smooth)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gradient")
                        Text("Linear · corner to corner")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 10)
                if model.style.usesGradient {
                    Divider()
                    ColorPicker("End color", selection: colorBinding(\.gradientEnd), supportsOpacity: false)
                        .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 14)
            .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 16, style: .continuous))

            ToolHeader("Background")
                .padding(.top, 4)
            Picker("Background", selection: $model.style.background) {
                ForEach(CodeStyle.Background.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            if model.isLinear {
                Toggle("Show digits under the bars", isOn: $model.style.showsText)
                    .padding(.top, 4)
            }
        }
    }

    /// The selected palette if it's too faint for this background (the guardrail the design calls for).
    private var lowContrastPalette: CodePalette? {
        CodePalette.all.first { $0.id == model.style.paletteID && contrast(of: $0) < ScannabilityChecker.minimumContrast }
            ?? CodePalette.all.first { contrast(of: $0) < ScannabilityChecker.minimumContrast }
    }

    private func contrast(of palette: CodePalette) -> Double {
        var candidate = model.style
        candidate.apply(palette: palette)
        return ScannabilityChecker.contrast(for: candidate).ratio
    }

    private func colorBinding(_ keyPath: WritableKeyPath<CodeStyle, RGBAColor>) -> Binding<Color> {
        Binding {
            model.style[keyPath: keyPath].color
        } set: {
            model.style[keyPath: keyPath] = RGBAColor($0)
            if keyPath == \.foreground { model.style.paletteID = nil }
        }
    }
}

private struct PaletteSwatch: View {
    var palette: CodePalette
    var isSelected: Bool
    var isLowContrast: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(LinearGradient(colors: [palette.start.color, palette.end.color], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 1))
                    .frame(width: 42, height: 42)
                    .padding(4)
                    .overlay(Circle().strokeBorder(isSelected ? Palette.accent : .clear, lineWidth: 2.5))
                    .overlay(alignment: .topTrailing) {
                        if isLowContrast {
                            Image(systemName: "exclamationmark.circle.fill")
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 16))
                                .foregroundStyle(Palette.caution)
                                .background(Circle().fill(Color(.secondarySystemGroupedBackground)))
                        }
                    }
                Text(palette.name)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(minWidth: 56)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(palette.name))
        .accessibilityValue(isLowContrast ? Text("Low contrast") : Text(""))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// "Custom" opens the system color picker; the swatch shows the current custom ink.
private struct CustomSwatch: View {
    @Binding var selection: Color
    var isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ColorPicker(selection: $selection, supportsOpacity: false) {
                Text("Custom")
            }
            .labelsHidden()
            .scaleEffect(1.5)
            .frame(width: 42, height: 42)
            .padding(4)
            .overlay(Circle().strokeBorder(isSelected ? Palette.accent : .clear, lineWidth: 2.5))
            Text("Custom")
                .font(.caption2.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .frame(minWidth: 56)
    }
}
