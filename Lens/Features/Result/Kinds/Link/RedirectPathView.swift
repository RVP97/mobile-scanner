import SwiftUI

/// The link's journey as a vertical path: what the code shows → each hop → where it actually lands,
/// with lookalike letters highlighted in the real destination.
struct RedirectPathView: View {
    var verdict: SafetyVerdict

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
                PathStop(stop: stop, isLast: index == stops.count - 1)
            }
        }
    }

    private struct Stop {
        var caption: LocalizedStringKey
        var url: URL
        var isDestination: Bool
        /// Shown verbatim instead of the host, so tricks like "trusted.com@evil.co" stay visible.
        var printed: String? = nil
    }

    private var stops: [Stop] {
        let destination = verdict.destination
        // A userinfo trick "shows" the part before the @.
        let shown = verdict.original.user(percentEncoded: false).map { "\($0)" }
        var result: [Stop] = []
        if verdict.redirectChain.isEmpty {
            if shown != nil {
                result.append(Stop(caption: "Printed on the code", url: verdict.original, isDestination: false,
                                   printed: Self.printed(verdict.original)))
            }
            result.append(Stop(caption: "Actually opens", url: destination, isDestination: true))
            return result
        }
        result.append(Stop(caption: "Printed on the code", url: verdict.original, isDestination: false))
        for hop in verdict.redirectChain.dropLast() {
            let host = hop.host(percentEncoded: false) ?? ""
            let isShortener = DomainRules.shorteners.contains(DomainRules.registrableDomain(host))
            result.append(Stop(caption: isShortener ? "Hops through a link shortener" : "Redirects through",
                               url: hop, isDestination: false))
        }
        result.append(Stop(caption: "Actually opens", url: destination, isDestination: true))
        return result
    }

    /// The link as a person reads it off the code: no scheme, no trailing slash.
    private static func printed(_ url: URL) -> String {
        var text = url.absoluteString
        if let scheme = url.scheme, text.hasPrefix(scheme + "://") { text.removeFirst(scheme.count + 3) }
        if text.hasSuffix("/") { text.removeLast() }
        return text
    }

    private struct PathStop: View {
        var stop: Stop
        var isLast: Bool

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 0) {
                    Circle()
                        .fill(stop.isDestination ? Palette.danger : Color.secondary.opacity(0.5))
                        .frame(width: 10, height: 10)
                        .padding(.top, 5)
                    if !isLast {
                        Rectangle()
                            .fill(.separator)
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(width: 12)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(stop.caption)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let printed = stop.printed {
                        Text(printed)
                            .font(.body)
                            .fontDesign(.monospaced)
                            .lineLimit(3)
                            .textSelection(.enabled)
                    } else {
                        LookalikeHostText(url: stop.url, emphasized: stop.isDestination)
                    }
                }
                .padding(.bottom, isLast ? 0 : 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// A host with its imitation letters in red, plus the plain-language note ("That's a zero…").
struct LookalikeHostText: View {
    var url: URL
    var emphasized: Bool

    var body: some View {
        let host = Punycode.decodeHost(url.host(percentEncoded: false)?.lowercased() ?? "")
        let match = host.isEmpty ? nil : LookalikeDetector.match(host: host)

        VStack(alignment: .leading, spacing: 4) {
            Text(attributed(host.isEmpty ? url.absoluteString : host, flagged: Set(match?.flaggedOffsets ?? [])))
                .font(emphasized ? .title3.weight(.semibold) : .body)
                .fontDesign(.monospaced)
                .foregroundStyle(emphasized ? Palette.danger : .primary)
                .lineLimit(3)
                .textSelection(.enabled)
            if emphasized, let note = match?.note {
                Text(note)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.danger)
            }
        }
    }

    private func attributed(_ text: String, flagged: Set<Int>) -> AttributedString {
        var output = AttributedString()
        for (offset, character) in text.enumerated() {
            var piece = AttributedString(String(character))
            if flagged.contains(offset) {
                piece.backgroundColor = Palette.danger.opacity(0.2)
                piece.underlineStyle = .single
                piece.inlinePresentationIntent = .stronglyEmphasized
            }
            output += piece
        }
        return output
    }
}
