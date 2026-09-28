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
                } else {
                    Image(systemName: state.symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(state.tint)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: 28)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(state.tint)
                Text(state.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(model.isChecking ? 0.6 : 1)
            .accessibilityElement(children: .combine)

            if let fix = state.fix {
                Button {
                    withAnimation(.smooth) { model.apply(fix) }
                } label: {
                    Text(fix.title)
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(state.tint)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 60)
        .background(state.tint.opacity(0.1), in: .rect(cornerRadius: 18, style: .continuous))
        .animation(.smooth(duration: 0.25), value: model.report)
        .sensoryFeedback(.warning, trigger: state.isProblem) { _, isProblem in isProblem }
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
            self.init(symbol: "checkmark.seal.fill", tint: Palette.safe, title: "Verified · scans in \(time)s",
                      detail: "Contrast \(contrast):1 · Scans reliably")
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
