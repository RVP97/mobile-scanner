import Foundation

/// Offline knowledge about domains: registrable domain, shorteners, TLDs scams favour.
enum DomainRules {
    /// Multi-label public suffixes we care about. Not the full Public Suffix List, but it covers
    /// the country second-levels people actually scan, so `bbva.com.mx` isn't treated as `com.mx`.
    static let multiPartSuffixes: Set<String> = [
        "co.uk", "org.uk", "me.uk", "ltd.uk", "plc.uk", "net.uk", "ac.uk", "gov.uk", "nhs.uk", "police.uk",
        "com.au", "net.au", "org.au", "edu.au", "gov.au", "asn.au", "id.au",
        "co.nz", "org.nz", "net.nz", "govt.nz", "ac.nz",
        "com.mx", "org.mx", "gob.mx", "edu.mx", "net.mx",
        "com.br", "net.br", "org.br", "gov.br", "edu.br",
        "com.ar", "gob.ar", "org.ar", "net.ar", "com.co", "gov.co", "org.co", "com.pe", "gob.pe",
        "com.ve", "com.ec", "com.uy", "com.py", "com.bo", "cl.cl", "com.gt", "com.sv", "com.hn",
        "com.ni", "com.pa", "co.cr", "com.do", "com.pr",
        "co.jp", "ne.jp", "or.jp", "ac.jp", "go.jp", "co.kr", "or.kr", "go.kr",
        "com.cn", "net.cn", "org.cn", "gov.cn", "com.hk", "org.hk", "gov.hk", "com.tw", "org.tw", "gov.tw",
        "com.sg", "gov.sg", "edu.sg", "com.my", "gov.my", "co.th", "go.th", "in.th", "co.id", "go.id",
        "or.id", "ac.id", "com.ph", "gov.ph", "com.vn", "gov.vn", "co.in", "net.in", "org.in", "gov.in",
        "ac.in", "com.pk", "gov.pk", "com.bd", "com.np", "com.lk",
        "co.za", "org.za", "gov.za", "co.ke", "or.ke", "com.ng", "gov.ng", "com.eg", "gov.eg", "co.ma",
        "com.tr", "gov.tr", "org.tr", "co.il", "org.il", "gov.il", "ac.il", "com.sa", "gov.sa",
        "com.qa", "gov.qa", "ae.org", "gov.ae", "com.kw", "com.lb",
        "com.ua", "gov.ua", "com.ru", "com.pl", "gov.pl", "com.es", "gob.es", "com.pt", "gov.pt",
        "com.gr", "gov.gr", "com.cy", "com.mt", "co.at", "or.at", "gv.at",
    ]

    /// Hosting platforms where anyone gets a subdomain. The subdomain is the "site".
    static let sharedHostingSuffixes: Set<String> = [
        "github.io", "gitlab.io", "herokuapp.com", "vercel.app", "netlify.app", "pages.dev", "workers.dev",
        "web.app", "firebaseapp.com", "blogspot.com", "wixsite.com", "weebly.com", "azurewebsites.net",
        "cloudfront.net", "appspot.com", "glitch.me", "repl.co", "ngrok.io", "ngrok-free.app",
        "square.site", "myshopify.com", "wordpress.com", "godaddysites.com", "webflow.io", "framer.website",
    ]

    /// "login.paypal.com.secure.io" → "secure.io". With `sharedHosting`, "evil.github.io".
    static func registrableDomain(_ host: String, sharedHosting: Bool = false) -> String {
        let labels = host.lowercased().split(separator: ".").map(String.init)
        guard labels.count > 2 else { return labels.joined(separator: ".") }
        let lastTwo = labels.suffix(2).joined(separator: ".")
        let suffixLength = multiPartSuffixes.contains(lastTwo) || (sharedHosting && sharedHostingSuffixes.contains(lastTwo)) ? 2 : 1
        return labels.suffix(suffixLength + 1).joined(separator: ".")
    }

    /// The name part of a registrable domain: "bbva" for "bbva.com.mx".
    static func label(ofRegistrable domain: String) -> String {
        domain.split(separator: ".").first.map(String.init) ?? domain
    }

    /// Labels in front of the registrable domain: ["paypal", "com"] for "paypal.com.secure.io".
    static func subdomainLabels(_ host: String) -> [String] {
        let labels = host.lowercased().split(separator: ".").map(String.init)
        let registrableCount = registrableDomain(host).split(separator: ".").count
        return Array(labels.dropLast(registrableCount))
    }

    static func topLevelDomain(_ host: String) -> String {
        host.lowercased().split(separator: ".").last.map(String.init) ?? ""
    }

    static func isIPAddress(_ host: String) -> Bool {
        let trimmed = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if trimmed.contains(":") { return true } // IPv6
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        if parts.count == 4, parts.allSatisfy({ UInt8($0) != nil }) { return true }
        // Single decimal or hex number hosts (http://3232235777, http://0xC0A80001) also resolve to IPs.
        return trimmed.isAllDigits || (trimmed.lowercased().hasPrefix("0x") && UInt32(trimmed.dropFirst(2), radix: 16) != nil)
    }

    static let shorteners: Set<String> = [
        "bit.ly", "bitly.com", "tinyurl.com", "t.co", "goo.gl", "ow.ly", "is.gd", "v.gd", "buff.ly", "rebrand.ly",
        "cutt.ly", "shorturl.at", "tiny.cc", "rb.gy", "bl.ink", "t.ly", "s.id", "lnkd.in", "shorte.st", "adf.ly",
        "tr.im", "soo.gd", "clck.ru", "qrco.de", "qr.codes", "qrcodes.pro", "l.ead.me", "scnv.io", "me-qr.com",
        "qr-code-generator.com", "qr1.be", "qrfy.com", "linktr.ee", "short.io", "dub.sh", "urlz.fr", "shorturl.gg",
        "t2m.io", "tinyl.io", "u.to", "x.gd", "surl.li", "bit.do", "chilp.it", "kutt.it",
    ]

    /// TLDs heavily over-represented in phishing and malware feeds.
    static let riskyTLDs: Set<String> = [
        "tk", "ml", "ga", "cf", "gq", "top", "xyz", "click", "zip", "mov", "country", "kim", "work", "loan",
        "men", "cam", "bond", "sbs", "cfd", "icu", "buzz", "monster", "quest", "rest", "fit", "surf", "lol",
        "cyou", "pw", "hair", "beauty", "autos", "boats", "yachts", "mom", "skin", "makeup",
    ]

    /// Words scammers put in hosts to look official or urgent.
    static let lureWords: Set<String> = [
        "login", "signin", "logon", "verify", "verification", "validate", "account", "accounts", "secure",
        "security", "update", "wallet", "unlock", "suspended", "confirm", "billing", "password", "recover",
        "recovery", "auth", "authenticate", "webscr", "banking", "payment", "pay", "refund", "claim", "reward",
        "prize", "airdrop", "seed", "support", "helpdesk", "toll", "tolls", "parking", "penalty", "customs",
        "redelivery", "reschedule", "invoice", "gift", "bonus", "kyc",
    ]

    /// Path fragments that only phishing kits tend to use.
    static let lurePaths = ["webscr", "wallet-connect", "walletconnect", "seed-phrase", "unlock-account",
                            "verify-account", "account-suspended", "secure-login", "update-billing"]
}
