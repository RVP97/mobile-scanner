import SwiftUI

/// A link: page preview, the safety check settling from "Checking…" to a verdict, and "Open <host>".
/// A link that needs care makes "Don't Open" the obvious choice; a dangerous one turns into the danger state.
struct LinkResultView: View {
    var url: URL
    var result: ScanResult
    @Binding var isDangerous: Bool

    @AppStorage(Pref.checkLinks) private var checkLinks = Pref.Default.checkLinks
    @AppStorage(Pref.deepLinkCheck) private var deepCheck = Pref.Default.deepLinkCheck
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    @State private var verdict: SafetyVerdict?
    @State private var isChecking = true
    @State private var preview: LinkPreview?
    @State private var confirmingOpen = false

    var body: some View {
        Group {
            if let verdict, verdict.level == .danger {
                DangerLinkView(verdict: verdict)
                    .transition(.opacity)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    LinkPreviewCard(url: url, preview: preview)
                    if checkLinks {
                        SafetySection(verdict: verdict, isChecking: isChecking)
                    }
                    if needsCare {
                        cautionActions
                    } else {
                        ResultPrimaryButton(title: "Open \(host)", symbol: "safari", tint: CodeKind.link.tint) {
                            openURL(url)
                        }
                    }
                    ResultActionRow(result: result, copyText: url.absoluteString)
                }
                .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: verdict?.level)
        .sensoryFeedback(.warning, trigger: verdict?.level == .danger) { _, isDanger in isDanger }
        .confirmationDialog("Open this link?", isPresented: $confirmingOpen, titleVisibility: .visible) {
            Button("Open \(host)") { openURL(url) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Lunet found something unusual about this link. Only continue if you trust whoever gave you the code.")
        }
        .task(id: url) { await check() }
    }

    private var host: String { url.displayHost ?? String(localized: "Link") }

    private var needsCare: Bool { verdict?.level == .caution }

    /// The safe choice is the big one; opening is still possible, one deliberate step away.
    private var cautionActions: some View {
        VStack(spacing: 4) {
            ResultPrimaryButton(title: "Don't Open", symbol: "hand.raised.fill", tint: Palette.ink) {
                model.dismissResult()
            }
            Button("Open Anyway…") { confirmingOpen = true }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.caution)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.rect)
                .buttonStyle(.plain)
        }
        .transition(.opacity)
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

        if verdict?.level != .danger { await loadPreview() }
    }

    /// Fetching the page reveals the scan to its server, so it follows the deep-check setting.
    private func loadPreview() async {
        guard deepCheck, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        preview = await LinkPreviewLoader.load(url)
    }
}

/// The page's icon and title when LinkPresentation finds them; until then (or without them) a
/// monogram of the site and the full address, so the card is never a generic globe.
struct LinkPreviewCard: View {
    var url: URL
    var preview: LinkPreview?

    var body: some View {
        ResultCard {
            HStack(alignment: .center, spacing: 12) {
                icon
                    .frame(width: 44, height: 44)
                    .clipShape(.rect(cornerRadius: 11, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    if let title = preview?.title, !title.isEmpty {
                        Text(title)
                            .font(.headline)
                            .lineLimit(2)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    Text(address)
                        .font(hasTitle ? .subheadline : .body)
                        .foregroundStyle(hasTitle ? .secondary : .primary)
                        .lineLimit(3)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
        }
        .animation(.smooth, value: preview)
    }

    private var hasTitle: Bool { preview?.title?.isEmpty == false }

    @ViewBuilder private var icon: some View {
        if let image = preview?.icon {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(image.size.width < 64 ? 6 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background.secondary)
                .transition(.opacity)
        } else {
            Text(monogram)
                .font(.title3.weight(.semibold))
                .foregroundStyle(CodeKind.link.tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.tileFill(.link))
        }
    }

    /// "atlas-coffee.co/menu" — the address without the scheme or a bare trailing slash.
    private var address: String {
        var text = url.absoluteString
        for prefix in ["https://", "http://"] where text.lowercased().hasPrefix(prefix) {
            text.removeFirst(prefix.count)
        }
        if text.hasPrefix("www.") { text.removeFirst(4) }
        if text.hasSuffix("/") { text.removeLast() }
        return text
    }

    /// First letter of the site's name ("A" for atlas-coffee.co), or a link glyph for odd hosts.
    private var monogram: String {
        let host = url.host(percentEncoded: false) ?? ""
        let name = DomainRules.registrableDomain(host).first { $0.isLetter || $0.isNumber }
        return name.map { String($0).uppercased() } ?? "#"
    }
}

#if DEBUG
#Preview { ResultPreview(.sampleLink) }
#Preview("Caution") { ResultPreview(.sampleCaution) }
#endif
