import SwiftUI

/// A link: page preview, the safety check settling from "Checking…" to a verdict, and "Open <host>".
/// Turns into the danger state when the check says so.
struct LinkResultView: View {
    var url: URL
    var result: ScanResult
    @Binding var isDangerous: Bool

    @AppStorage(Pref.checkLinks) private var checkLinks = Pref.Default.checkLinks
    @AppStorage(Pref.deepLinkCheck) private var deepCheck = Pref.Default.deepLinkCheck
    @Environment(\.openURL) private var openURL

    @State private var verdict: SafetyVerdict?
    @State private var isChecking = true
    @State private var preview: LinkPreview?

    var body: some View {
        Group {
            if let verdict, verdict.level == .danger {
                DangerLinkView(verdict: verdict)
                    .transition(.opacity)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    previewCard
                    if checkLinks {
                        SafetySection(verdict: verdict, isChecking: isChecking)
                    }
                    ResultPrimaryButton(title: "Open \(url.displayHost ?? "Link")", symbol: "safari", tint: CodeKind.link.tint) {
                        openURL(url)
                    }
                    ResultActionRow(result: result, copyText: url.absoluteString)
                }
                .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: verdict?.level)
        .sensoryFeedback(.warning, trigger: verdict?.level == .danger) { _, isDanger in isDanger }
        .task(id: url) { await check() }
    }

    private var previewCard: some View {
        ResultCard {
            HStack(spacing: 12) {
                Group {
                    if let icon = preview?.icon {
                        Image(uiImage: icon).resizable().scaledToFill()
                    } else {
                        Image(systemName: "globe")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 44, height: 44)
                .background(.fill.tertiary)
                .clipShape(.rect(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(preview?.title ?? url.displayHost ?? url.absoluteString)
                        .font(.headline)
                        .lineLimit(2)
                    Text(url.absoluteString.replacingOccurrences(of: "https://", with: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
        }
        .animation(.smooth, value: preview)
    }

    private func check() async {
        guard checkLinks else {
            isChecking = false
            return
        }
        let quick = SafetyAnalyzer.quickCheck(url)
        verdict = quick
        isDangerous = quick.level == .danger

        if deepCheck, ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            let full = await SafetyAnalyzer.fullCheck(url)
            verdict = full
            isDangerous = full.level == .danger
        }
        isChecking = false

        if deepCheck, verdict?.level != .danger {
            preview = await LinkPreviewLoader.load(url)
        }
    }
}

#if DEBUG
#Preview { ResultPreview(.sampleLink) }
#endif
