import Foundation

/// Everything that can be said about a URL without touching the network.
enum URLHeuristics {
    struct Report {
        var signals: [SafetySignal] = []
        /// Lowercase, punycode-decoded host. Nil for non-web URLs.
        var host: String?
        var lookalike: LookalikeMatch?
        var isHTTPS = false
    }

    static func analyze(_ url: URL) -> Report {
        switch url.scheme?.lowercased() {
        case "javascript": return Report(signals: [.script])
        case "data": return Report(signals: [.dataURI])
        case "http", "https": break
        default: return Report()
        }
        guard let rawHost = url.host(percentEncoded: false), !rawHost.isEmpty else { return Report() }

        let host = Punycode.decodeHost(rawHost.lowercased()).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        var report = Report(host: host, isHTTPS: url.scheme?.lowercased() == "https")
        report.signals.append(report.isHTTPS ? .https : .plainHTTP)

        if let user = url.user(percentEncoded: false), !user.isEmpty {
            report.signals.append(.userInfo(realHost: host))
        }
        if let port = url.port, ![80, 443].contains(port) {
            report.signals.append(.unusualPort(port))
        }
        if DomainRules.isIPAddress(host) {
            report.signals.append(.ipHost)
            return report
        }

        let registrable = DomainRules.registrableDomain(host)
        let isBrandOwned = BrandDomains.owner(ofRegistrable: registrable) != nil

        if !host.allSatisfy(\.isASCII) {
            let labels = host.split(separator: ".").map(String.init)
            report.signals.append(labels.contains(where: Confusables.mixesScripts) ? .mixedScripts : .internationalHost)
        }
        if let match = LookalikeDetector.match(host: host) {
            report.lookalike = match
            report.signals.append(.lookalike(match, registrable: registrable))
            report.signals.removeAll { $0.kind == .internationalHost }
        }
        if DomainRules.shorteners.contains(host) || DomainRules.shorteners.contains(registrable) {
            report.signals.append(.shortener)
        }
        let tld = DomainRules.topLevelDomain(host)
        if DomainRules.riskyTLDs.contains(tld) {
            report.signals.append(.riskyTLD(tld))
        }
        let hostingRegistrable = DomainRules.registrableDomain(host, sharedHosting: true)
        let extraLabels = host.split(separator: ".").count - hostingRegistrable.split(separator: ".").count
        if extraLabels >= 4 {
            report.signals.append(.deepSubdomains(registrable: registrable))
        }
        if !isBrandOwned, let word = lureWord(host: host, path: url.path(percentEncoded: false)) {
            report.signals.append(.lureWords(word))
        }
        return report
    }

    private static func lureWord(host: String, path: String) -> String? {
        let words = host.split(whereSeparator: { $0 == "." || $0 == "-" }).map(String.init)
        if let word = words.first(where: {
            DomainRules.lureWords.contains($0) || DomainRules.lureWords.contains(Confusables.skeleton($0))
        }) { return word }
        let lowerPath = path.lowercased()
        return DomainRules.lurePaths.first { lowerPath.contains($0) }
    }

    /// Worst level wins. `.safe` needs HTTPS and nothing suspicious; non-web URLs are `.unknown`.
    static func level(of signals: [SafetySignal]) -> SafetyVerdict.Level {
        let worst = signals.map(\.level).max() ?? .unknown
        if worst > .safe { return worst }
        return signals.contains { $0.kind == .https } ? .safe : .unknown
    }

    /// Promotes weak signals to danger when they appear together with anything else suspicious.
    static func escalated(_ signals: [SafetySignal]) -> [SafetySignal] {
        let suspicious = signals.filter { $0.level >= .caution }
        guard suspicious.count >= 2 else { return signals }
        return signals.map { signal in
            guard signal.escalates, signal.level == .caution else { return signal }
            var promoted = signal
            promoted.finding.level = .danger
            return promoted
        }
    }

    /// Danger first, then caution, then reassurances.
    static func ordered(_ signals: [SafetySignal]) -> [SafetySignal] {
        signals.enumerated().sorted { lhs, rhs in
            lhs.element.level != rhs.element.level ? lhs.element.level > rhs.element.level : lhs.offset < rhs.offset
        }
        .map(\.element)
    }
}
