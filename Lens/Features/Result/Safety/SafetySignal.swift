import Foundation

/// One thing the analyzer noticed, typed so rules can combine them before they become user-facing findings.
struct SafetySignal: Hashable {
    enum Kind: Hashable {
        case https, plainHTTP, script, dataURI, userInfo, ipHost, mixedScripts, internationalHost
        case lookalike(LookalikeMatch.Kind)
        case shortener, riskyTLD, deepSubdomains, lureWords, unusualPort
        case noRedirects, redirectsElsewhere, shortLinkResolved
        case newDomain, recentDomain, establishedDomain
    }

    var kind: Kind
    var finding: SafetyVerdict.Finding

    var level: SafetyVerdict.Level { finding.level }

    /// Weak on their own; alarming next to anything else suspicious.
    var escalates: Bool {
        switch kind {
        case .lookalike(.typo), .lookalike(.brandInName), .recentDomain: true
        default: false
        }
    }

    private init(_ kind: Kind, _ level: SafetyVerdict.Level, _ title: String, _ detail: String, _ symbol: String) {
        self.kind = kind
        finding = SafetyVerdict.Finding(level: level, title: title, detail: detail, symbol: symbol)
    }

    // MARK: Scheme & address

    static let https = SafetySignal(.https, .safe, String(localized: "HTTPS"),
                                    String(localized: "Encrypted connection"), "lock.fill")
    static let plainHTTP = SafetySignal(.plainHTTP, .caution, String(localized: "Not encrypted"),
                                        String(localized: "This page doesn't use HTTPS, so others on the network could see or change it."),
                                        "lock.open.fill")
    static let script = SafetySignal(.script, .danger, String(localized: "Runs code"),
                                     String(localized: "This isn't a web address. It runs a script when opened."),
                                     "chevron.left.forwardslash.chevron.right")
    static let dataURI = SafetySignal(.dataURI, .danger, String(localized: "Hidden page"),
                                      String(localized: "This carries a whole page inside the code instead of an address."),
                                      "doc.questionmark")

    static func userInfo(realHost: String) -> SafetySignal {
        SafetySignal(.userInfo, .danger, String(localized: "Hides the real address"),
                     String(localized: "Everything before the “@” is ignored. This opens \(realHost)."), "at")
    }

    static let ipHost = SafetySignal(.ipHost, .caution, String(localized: "Uses a raw IP address"),
                                     String(localized: "Real sites use names. Scam pages often don't."), "number")
    static let mixedScripts = SafetySignal(.mixedScripts, .danger, String(localized: "Mixes alphabets"),
                                           String(localized: "Letters from different alphabets can imitate a familiar name."),
                                           "character.textbox")
    static let internationalHost = SafetySignal(.internationalHost, .caution, String(localized: "Uses international letters"),
                                                String(localized: "Some of these letters can look like others."), "character")

    static func unusualPort(_ port: Int) -> SafetySignal {
        SafetySignal(.unusualPort, .caution, String(localized: "Unusual port"),
                     String(localized: "Opens on port \(port), which normal websites rarely use."), "point.3.connected.trianglepath.dotted")
    }

    // MARK: Lookalikes

    static func lookalike(_ match: LookalikeMatch, registrable: String) -> SafetySignal {
        let brand = match.brand
        return switch match.kind {
        case .homograph:
            SafetySignal(.lookalike(.homograph), .danger, String(localized: "Imitates \(brand.domain)"),
                         match.note ?? String(localized: "Some letters only look like the real name."), "theatermasks.fill")
        case .otherTLD:
            SafetySignal(.lookalike(.otherTLD), .danger, String(localized: "Not \(brand.name)'s address"),
                         String(localized: "\(brand.name) uses \(brand.domain)."), "theatermasks.fill")
        case .brandAsSubdomain:
            SafetySignal(.lookalike(.brandAsSubdomain), .danger, String(localized: "Pretends to be \(brand.domain)"),
                         String(localized: "The site you'd really visit is \(registrable)."), "theatermasks.fill")
        case .typo:
            SafetySignal(.lookalike(.typo), .caution, String(localized: "Looks like \(brand.domain)"),
                         String(localized: "A letter or two off from the real address."), "theatermasks.fill")
        case .brandInName:
            SafetySignal(.lookalike(.brandInName), .caution, String(localized: "Uses the \(brand.name) name"),
                         String(localized: "But it isn't \(brand.domain)."), "theatermasks.fill")
        }
    }

    // MARK: Domain shape

    static let shortener = SafetySignal(.shortener, .caution, String(localized: "Short link"),
                                        String(localized: "The destination is hidden until it opens."), "arrow.triangle.branch")

    static func riskyTLD(_ tld: String) -> SafetySignal {
        SafetySignal(.riskyTLD, .caution, String(localized: "Unusual ending"),
                     String(localized: "“.\(tld)” addresses are often used for scams."), "exclamationmark.triangle.fill")
    }

    static func deepSubdomains(registrable: String) -> SafetySignal {
        SafetySignal(.deepSubdomains, .caution, String(localized: "Unusually long address"),
                     String(localized: "Everything in front of \(registrable) can be used to hide the real site."),
                     "text.line.first.and.arrowtriangle.forward")
    }

    static func lureWords(_ word: String) -> SafetySignal {
        SafetySignal(.lureWords, .caution, String(localized: "Asks you to act"),
                     String(localized: "Words like “\(word)” on a site that isn't a known brand."), "key.fill")
    }

    // MARK: Deep check

    static let noRedirects = SafetySignal(.noRedirects, .safe, String(localized: "No redirects"),
                                          String(localized: "Opens as shown"), "arrow.right")

    static func redirectsElsewhere(to host: String) -> SafetySignal {
        SafetySignal(.redirectsElsewhere, .caution, String(localized: "Redirects elsewhere"),
                     String(localized: "Actually opens \(host)."), "arrow.turn.down.right")
    }

    static func shortLinkResolved(to host: String) -> SafetySignal {
        SafetySignal(.shortLinkResolved, .safe, String(localized: "Short link"),
                     String(localized: "Opens \(host)"), "arrow.triangle.branch")
    }

    static func domainAge(registered: Date, now: Date) -> SafetySignal {
        let days = max(0, Calendar.current.dateComponents([.day], from: registered, to: now).day ?? 0)
        if days < 7 {
            let title = days == 0 ? String(localized: "Registered today") : String(localized: "Registered \(days) days ago")
            return SafetySignal(.newDomain, .danger, title,
                                String(localized: "Scam sites are usually brand new."), "calendar.badge.exclamationmark")
        }
        if days < 90 {
            return SafetySignal(.recentDomain, .caution, String(localized: "Registered recently"),
                                String(localized: "This address is \(days) days old."), "calendar.badge.clock")
        }
        let year = Calendar.current.component(.year, from: registered)
        return SafetySignal(.establishedDomain, .safe, String(localized: "Domain since \(String(year))"),
                            String(localized: "Established"), "calendar")
    }
}
