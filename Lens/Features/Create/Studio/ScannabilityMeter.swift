import SwiftUI

/// The trust signal under the preview: Verified / Low contrast / Won't scan, with a one-tap fix.
struct ScannabilityMeter: View {
    var model: StudioModel

    var body: some View {
        let state = MeterState(report: model.report, symbology: model.document.symbology)
        HStack(spacing: 12) {
            ZStack {
                if model.isChecking && model.report == nil {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: state.symbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(state.tint)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: 24)
            .accessibilityHidden(true)

            // One line when it fits; the detail drops below at large text sizes or long messages.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    title(state)
                    Text(verbatim: "·").foregroundStyle(.tertiary)
                    detail(state)
                }
                .lineLimit(1)
                VStack(alignment: .leading, spacing: 1) {
                    title(state)
                    detail(state)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(model.isChecking ? 0.6 : 1)
            .accessibilityElement(children: .combine)

            if let fix = state.fix {
                Button {
                    withAnimation(.smooth) { model.apply(fix) }
                } label: {
                    Text(fix.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.onTint)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 30)
                        .background(state.tint, in: .capsule)
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .fixedSize()
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, state.fix == nil ? 14 : 8)
        .frame(minHeight: 48)
        .background(state.tint.opacity(0.12), in: .rect(cornerRadius: 16, style: .continuous))
        .animation(.smooth(duration: 0.25), value: model.report)
        .sensoryFeedback(.warning, trigger: state.isProblem) { _, isProblem in isProblem }
    }

    private func title(_ state: MeterState) -> some View {
        Text(state.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(state.tint)
    }

    private func detail(_ state: MeterState) -> some View {
        Text(state.detail)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }
}

/// What the meter says for a given report.
private struct MeterState {
    var symbol: String
    var tint: Color
    var title: LocalizedStringResource
    var detail: LocalizedStringResource
    var fix: StudioFix?
    var isProblem = false

    init(report: ScannabilityChecker.Report?, symbology: Symbology) {
        guard let report else {
            self.init(symbol: "viewfinder", tint: .secondary, title: "Checking…", detail: "Reading it back like a camera would")
            return
        }
        let contrast = report.contrast.formatted(.number.precision(.fractionLength(1)))
        let time = max(report.duration / .seconds(1), 0.1).formatted(.number.precision(.fractionLength(1)))
        switch report.verdict {
        case .verified:
            self.init(symbol: "checkmark.seal.fill", tint: Palette.safe, title: "Verified",
                      detail: "Scans in \(time)s · Contrast \(contrast):1")
        case .lowContrast:
            self.init(symbol: "exclamationmark.triangle.fill", tint: Palette.caution, title: "Low contrast",
                      detail: "\(contrast):1 — may fail in dim light", fix: .darkenInk, isProblem: true)
        case .inverted:
            self.init(symbol: "exclamationmark.triangle.fill", tint: Palette.caution, title: "Light on dark",
                      detail: "Some scanners can't read inverted codes", fix: .darkenInk, isProblem: true)
        case .wontScan(let reason):
            let detail: LocalizedStringResource = switch reason {
            case .lowContrast: "Contrast is \(contrast):1. Codes need 3:1 or more."
            case .inverted: "Light modules on a light background can't be read."
            case .logo: "The logo covers too much of the code."
            case .unreadable: "These shapes are too far from squares for cameras."
            }
            let fix: StudioFix = switch reason {
            case .lowContrast, .inverted: .darkenInk
            case .logo: .removeLogo
            case .unreadable: .simplifyShapes
            }
            self.init(symbol: "xmark.octagon.fill", tint: Palette.danger, title: "Won't scan", detail: detail, fix: fix, isProblem: true)
        case .unverifiable:
            self.init(symbol: "info.circle.fill", tint: .secondary, title: "Can't check \(symbology.displayName) here",
                      detail: "Contrast \(contrast):1. Test it with the scanner it's for.")
        }
    }

    private init(symbol: String, tint: Color, title: LocalizedStringResource, detail: LocalizedStringResource, fix: StudioFix? = nil, isProblem: Bool = false) {
        self.symbol = symbol
        self.tint = tint
        self.title = title
        self.detail = detail
        self.fix = fix
        self.isProblem = isProblem
    }
}
