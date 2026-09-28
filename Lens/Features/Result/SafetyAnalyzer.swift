import Foundation

// OWNER: Result module. Scanner uses `quickCheck` for Scan & Go. Keep signatures stable.
enum SafetyAnalyzer {
    /// Offline heuristics only. Instant.
    static func quickCheck(_ url: URL) -> SafetyVerdict {
        let report = URLHeuristics.analyze(url)
        return verdict(for: url, signals: report.signals)
    }

    /// Offline heuristics plus, when enabled, redirect resolution and domain age.
    static func fullCheck(_ url: URL) async -> SafetyVerdict {
        guard Pref.bool(Pref.deepLinkCheck, default: Pref.Default.deepLinkCheck) else { return quickCheck(url) }
        return await fullCheck(url, network: LiveSafetyNetwork.shared)
    }

    /// The deep check with an injectable network. Results are cached in memory for the session.
    static func fullCheck(_ url: URL, network: some SafetyNetwork, now: Date = .now) async -> SafetyVerdict {
        if let cached = cache.verdicts[url.absoluteString] { return cached }

        let original = URLHeuristics.analyze(url)
        guard let originalHost = original.host, !DomainRules.isIPAddress(originalHost) else {
            return verdict(for: url, signals: original.signals)
        }

        let resolved = await RedirectResolver.chain(from: url, network: network)
        let hops = resolved ?? []
        let destination = hops.last.map(URLHeuristics.analyze) ?? original
        var signals = resolved == nil
            ? original.signals
            : combine(original: original, destination: destination, redirected: !hops.isEmpty)

        if resolved != nil, let host = destination.host, !DomainRules.isIPAddress(host) {
            let registrable = DomainRules.registrableDomain(host)
            if let registered = await registrationDate(for: registrable, network: network) {
                signals.append(.domainAge(registered: registered, now: now))
            }
        }

        let result = verdict(for: url, signals: signals, chain: hops)
        if resolved != nil { cache.verdicts[url.absoluteString] = result } // offline: try again next time
        return result
    }

    /// The printed link's warnings (except those about being a short link or its scheme) plus
    /// everything about where it really lands.
    private static func combine(original: URLHeuristics.Report, destination: URLHeuristics.Report, redirected: Bool) -> [SafetySignal] {
        guard redirected else { return original.signals + [.noRedirects] }

        let carried = original.signals.filter { signal in
            signal.level > .safe && ![.shortener, .plainHTTP].contains(signal.kind)
        }
        var signals = carried
        for signal in destination.signals where !signals.contains(where: { $0.finding.title == signal.finding.title }) {
            signals.append(signal)
        }

        if let from = original.host, let to = destination.host {
            let fromDomain = DomainRules.registrableDomain(from)
            let toDomain = DomainRules.registrableDomain(to)
            let wasShortLink = original.signals.contains { $0.kind == .shortener }
            if wasShortLink {
                signals.append(.shortLinkResolved(to: to))
            } else if fromDomain != toDomain {
                signals.append(.redirectsElsewhere(to: to))
            }
        }
        return signals
    }

    private static func verdict(for url: URL, signals: [SafetySignal], chain: [URL] = []) -> SafetyVerdict {
        let final = URLHeuristics.ordered(URLHeuristics.escalated(signals))
        return SafetyVerdict(
            level: URLHeuristics.level(of: final),
            original: url,
            redirectChain: chain,
            findings: final.map(\.finding)
        )
    }

    private static func registrationDate(for domain: String, network: some SafetyNetwork) async -> Date? {
        if let cached = cache.registrations[domain] { return cached }
        let date = await DomainAgeLookup.registrationDate(for: domain, network: network)
        cache.registrations[domain] = date
        return date
    }

    // MARK: Cache

    private static var cache = Cache()

    private struct Cache {
        var verdicts: [String: SafetyVerdict] = [:]
        /// Keyed by registrable domain; `nil` values remember a failed lookup.
        var registrations: [String: Date?] = [:]
    }

    /// Forgets cached deep checks (tests, or after the user changes safety settings).
    static func resetCache() {
        cache = Cache()
    }
}
