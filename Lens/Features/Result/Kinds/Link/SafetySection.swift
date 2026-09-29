import SwiftUI

/// "Safety  [Looks safe]" with one row per finding. Starts as "Checking…" and settles on the verdict.
struct SafetySection: View {
    var verdict: SafetyVerdict?
    var isChecking: Bool

    var body: some View {
        ResultCard {
            HStack {
                MicroLabel("Safety")
                Spacer()
                pill
            }
            if let findings = verdict?.findings, !findings.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(findings) { finding in
                        FindingRow(finding: finding)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .animation(.smooth, value: verdict)
        .animation(.smooth, value: isChecking)
    }

    @ViewBuilder private var pill: some View {
        if isChecking {
            StatusPill(text: "Checking…", symbol: "shield", tint: .secondary)
                .symbolEffect(.pulse, isActive: true)
                .transition(.opacity)
        } else {
            let level = verdict?.level ?? .unknown
            StatusPill(text: level.pillText, symbol: level.pillSymbol, tint: level.tint)
                .contentTransition(.symbolEffect(.replace))
                .transition(.opacity)
        }
    }
}

struct FindingRow: View {
    var finding: SafetyVerdict.Finding

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: finding.symbol)
                .flipsForRightToLeftLayoutDirection(finding.symbol.hasSuffix(".right"))
                .font(.body.weight(.semibold))
                .foregroundStyle(finding.level.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(finding.title)
                    .font(.body.weight(.semibold))
                if !finding.detail.isEmpty {
                    Text(finding.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
