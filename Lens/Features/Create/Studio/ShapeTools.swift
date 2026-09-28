import SwiftUI

/// Tool header: uppercase label with an optional trailing note.
struct ToolHeader: View {
    var title: LocalizedStringKey
    var note: Text?

    init(_ title: LocalizedStringKey, note: Text? = nil) {
        self.title = title
        self.note = note
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            MicroLabel(title)
            Spacer(minLength: 8)
            if let note {
                note.font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }
}

struct DotsTool: View {
    @Bindable var model: StudioModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ToolHeader("Dot shape", note: densityNote)
            SwatchRow {
                ForEach(CodeStyle.DotShape.allCases, id: \.self) { shape in
                    ShapeSwatch(title: shape.title, isSelected: model.style.dots == shape) {
                        model.style.dots = shape
                    } glyph: {
                        PathGlyph(path: ModuleGeometry.swatchDots(shape))
                    }
                }
            }

            ToolHeader("Error correction")
                .padding(.top, 4)
            Picker("Error correction", selection: $model.style.correction) {
                ForEach(CorrectionLevel.allCases, id: \.self) { level in
                    Text(verbatim: level.rawValue).tag(level)
                        .accessibilityLabel(Text(level.title))
                }
            }
            .pickerStyle(.segmented)
            .disabled(model.style.logo != .none)
            Text(correctionNote)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var densityNote: Text? {
        guard let count = model.moduleCount else { return nil }
        return Text("\(count) × \(count) modules · Level \(model.style.effectiveCorrection.rawValue)")
    }

    private var correctionNote: LocalizedStringResource {
        if model.style.logo != .none { return "A logo needs High, so Lens sets it for you." }
        let level = model.style.effectiveCorrection
        let size = minimumPrintSize.formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(1))))
        return "Still scans with \(level.recoveryPercent)% of it covered or scuffed. Print it \(size) or larger."
    }

    /// About half a millimetre per module (quiet zone included) reads from arm's length.
    private var minimumPrintSize: Measurement<UnitLength> {
        Measurement(value: Double((model.moduleCount ?? 21) + 8) * 0.05, unit: .centimeters)
    }
}

struct CornersTool: View {
    @Bindable var model: StudioModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ToolHeader("Frame", note: Text("Outer ring of the three eyes"))
            SwatchRow {
                ForEach(CodeStyle.EyeFrame.allCases, id: \.self) { frame in
                    ShapeSwatch(title: frame.title, isSelected: model.style.eyeFrame == frame) {
                        model.style.eyeFrame = frame
                    } glyph: {
                        PathGlyph(path: ModuleGeometry.swatchEye(frame: frame, pupil: model.style.eyePupil).frame, evenOdd: true)
                    }
                }
            }

            ToolHeader("Pupil", note: Text("The solid center"))
                .padding(.top, 4)
            SwatchRow {
                ForEach(CodeStyle.EyePupil.allCases, id: \.self) { pupil in
                    ShapeSwatch(title: pupil.title, isSelected: model.style.eyePupil == pupil) {
                        model.style.eyePupil = pupil
                    } glyph: {
                        PathGlyph(path: ModuleGeometry.swatchEye(frame: model.style.eyeFrame, pupil: pupil).pupil)
                            .padding(6)
                    }
                }
            }

            ToolHeader("Eye color")
                .padding(.top, 4)
            HStack(spacing: 12) {
                Picker("Eye color", selection: $model.style.accentEyes) {
                    Text("Match Dots").tag(false)
                    Text("Accent").tag(true)
                }
                .pickerStyle(.segmented)
                if model.style.accentEyes {
                    ColorPicker("Accent color", selection: colorBinding(\.eyeColor), supportsOpacity: false)
                        .labelsHidden()
                }
            }
        }
    }

    private func colorBinding(_ keyPath: WritableKeyPath<CodeStyle, RGBAColor>) -> Binding<Color> {
        Binding { model.style[keyPath: keyPath].color } set: { model.style[keyPath: keyPath] = RGBAColor($0) }
    }
}

/// Horizontally scrolling row of swatches that wraps to the tool's width when it can.
struct SwatchRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) { content }
                .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }
}
