import Foundation

/// Web links: explicit `http(s)://`, `javascript:`/`data:` (kept as links so Safety can stop them),
/// DoCoMo `MEBKM:` bookmarks, and bare domains like `atlas-coffee.co/menu`.
enum LinkParser {
    static func parse(_ raw: String) -> URL? {
        if raw.hasPrefixIgnoringCase("http://") || raw.hasPrefixIgnoringCase("https://") {
            return webURL(raw)
        }
        if raw.hasPrefixIgnoringCase("javascript:") || raw.hasPrefixIgnoringCase("data:") {
            return URL(string: raw) ?? URL(string: raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        }
        if raw.hasPrefixIgnoringCase("MEBKM:") {
            let url = EscapedFields.fields(raw.dropFirst(6)).first { $0.key == "URL" }?.value.trimmed
            return url.flatMap { parse($0) ?? bareDomain($0) }
        }
        if raw.hasPrefixIgnoringCase("URLTO:") || raw.hasPrefixIgnoringCase("URL:") {
            let value = String(raw.drop { $0 != ":" }.dropFirst()).trimmed
            return parse(value) ?? bareDomain(value)
        }
        return nil
    }

    /// `atlas-coffee.co/menu` → `https://atlas-coffee.co/menu`. Needs a real TLD, so
    /// "file.txt", "v1.2.3" and plain words stay text.
    static func bareDomain(_ raw: String) -> URL? {
        guard !raw.contains(where: \.isWhitespace), !raw.contains("@") else { return nil }
        let pattern = /^((?:[A-Za-z0-9](?:[A-Za-z0-9\-]{0,61}[A-Za-z0-9])?\.)+([A-Za-z]{2,24}))(?::\d{1,5})?(?:[\/?#]\S*)?$/
        guard let match = raw.wholeMatch(of: pattern),
              TopLevelDomains.isKnown(String(match.2).lowercased()),
              match.1.contains(where: \.isLetter)
        else { return nil }
        return webURL("https://" + raw)
    }

    /// Accepts uppercase schemes/hosts (QR alphanumeric mode) and unencoded characters.
    private static func webURL(_ raw: String) -> URL? {
        let url = URL(string: raw)
            ?? raw.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed.union(["#", "%"])).flatMap(URL.init(string:))
        guard let url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host, !host.isEmpty
        else { return nil }
        components.scheme = components.scheme?.lowercased()
        if host.contains(where: \.isUppercase) { components.host = host.lowercased() }
        return components.url ?? url
    }
}

enum TopLevelDomains {
    static func isKnown(_ tld: String) -> Bool {
        generic.contains(tld) || (tld.count == 2 && countryCodes.contains(tld))
    }

    static let generic: Set<String> = [
        "com", "org", "net", "edu", "gov", "mil", "int", "info", "biz", "name", "pro", "aero", "coop", "museum",
        "app", "dev", "page", "io", "ai", "xyz", "online", "site", "store", "shop", "tech", "blog", "cloud",
        "design", "digital", "agency", "studio", "art", "life", "live", "world", "today", "news", "media",
        "space", "website", "email", "link", "click", "top", "club", "vip", "fun", "games", "social",
        "menu", "restaurant", "cafe", "coffee", "bar", "pub", "pizza", "kitchen", "recipes", "wine", "beer",
        "events", "tickets", "travel", "hotel", "holiday", "tours", "flights", "rentals", "house", "homes",
        "realty", "estate", "properties", "health", "care", "clinic", "dental", "fitness", "yoga", "beauty",
        "fashion", "clothing", "shoes", "jewelry", "watch", "photo", "photography", "pics", "gallery",
        "music", "band", "audio", "video", "film", "movie", "tv", "radio", "stream", "show", "theater",
        "school", "academy", "college", "university", "education", "training", "courses", "study",
        "bank", "finance", "money", "capital", "fund", "insurance", "tax", "legal", "law", "attorney",
        "consulting", "services", "solutions", "systems", "network", "software", "codes", "tools",
        "company", "business", "group", "team", "center", "city", "town", "global", "international",
        "church", "community", "foundation", "charity", "green", "eco", "earth", "garden", "farm",
        "auto", "car", "cars", "bike", "taxi", "delivery", "express", "market", "sale", "deals", "discount",
        "gift", "gifts", "toys", "baby", "kids", "family", "pet", "pets", "dog", "vet",
        "work", "works", "jobs", "careers", "support", "help", "guide", "wiki", "zone", "plus", "one",
        "new", "wtf", "lol", "icu", "cam", "bond", "sbs", "cfd", "buzz", "monster", "quest", "rest",
        "fit", "surf", "loan", "men", "kim", "country", "zip", "mov", "cyou", "mobi", "asia", "berlin",
        "london", "nyc", "paris", "tokyo", "amsterdam", "barcelona", "madrid", "wien", "miami", "vegas",
        "eus", "cat", "gal", "scot", "wales", "swiss", "google", "apple", "amazon", "microsoft", "youtube",
    ]

    /// ISO 3166-1 alpha-2 country-code TLDs plus `uk`, `eu`, `ac`.
    static let countryCodes: Set<String> = Set(
        """
        ac ad ae af ag ai al am ao aq ar as at au aw ax az ba bb bd be bf bg bh bi bj bm bn bo br bs bt bw by bz
        ca cc cd cf cg ch ci ck cl cm cn co cr cu cv cw cx cy cz de dj dk dm do dz ec ee eg er es et eu fi fj fk
        fm fo fr ga gd ge gf gg gh gi gl gm gn gp gq gr gs gt gu gw gy hk hm hn hr ht hu id ie il im in io iq ir
        is it je jm jo jp ke kg kh ki km kn kp kr kw ky kz la lb lc li lk lr ls lt lu lv ly ma mc md me mg mh mk
        ml mm mn mo mp mq mr ms mt mu mv mw mx my mz na nc ne nf ng ni nl no np nr nu nz om pa pe pf pg ph pk pl
        pm pn pr ps pt pw py qa re ro rs ru rw sa sb sc sd se sg sh si sk sl sm sn so sr ss st sv sx sy sz tc td
        tf tg th tj tk tl tm tn to tr tt tv tw tz ua ug uk us uy uz va vc ve vg vi vn vu wf ws ye yt za zm zw
        """.split(whereSeparator: \.isWhitespace).map(String.init)
    )
}
