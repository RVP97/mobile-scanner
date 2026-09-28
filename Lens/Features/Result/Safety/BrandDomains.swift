import Foundation

/// A frequently impersonated organisation and the registrable domains it really uses.
struct Brand: Hashable {
    var name: String
    var domain: String
    var otherDomains: [String] = []
    /// Owns its name under country-code TLDs (google.de, amazon.co.uk), so those aren't suspicious.
    var global = false
    /// Its name is a common word or very short ("target", "x", "cash"). Only exact homographs count.
    var isCommonWord = false

    /// "paypal" for paypal.com, "santander" for santander.com.mx.
    var label: String { DomainRules.label(ofRegistrable: domain) }

    var ownedDomains: Set<String> { Set([domain] + otherDomains) }
}

/// ~150 domains that phishing most often imitates: banks, payments, big tech, carriers,
/// tolls/parking (the usual QR scams), crypto and government.
enum BrandDomains {
    static let all: [Brand] = [
        // Payments & fintech
        Brand(name: "PayPal", domain: "paypal.com", otherDomains: ["paypal.me", "paypalobjects.com"], global: true),
        Brand(name: "Venmo", domain: "venmo.com"),
        Brand(name: "Cash App", domain: "cash.app", otherDomains: ["cash.me", "squareup.com"], isCommonWord: true),
        Brand(name: "Zelle", domain: "zellepay.com", otherDomains: ["zelle.com"]),
        Brand(name: "Stripe", domain: "stripe.com", isCommonWord: true),
        Brand(name: "Square", domain: "squareup.com", otherDomains: ["square.com", "square.site"], isCommonWord: true),
        Brand(name: "Wise", domain: "wise.com", isCommonWord: true),
        Brand(name: "Revolut", domain: "revolut.com", global: true),
        Brand(name: "N26", domain: "n26.com"),
        Brand(name: "Klarna", domain: "klarna.com", global: true),
        Brand(name: "Afterpay", domain: "afterpay.com"),
        Brand(name: "Mercado Pago", domain: "mercadopago.com", otherDomains: ["mercadopago.com.mx", "mercadopago.com.ar", "mercadopago.com.br"], global: true),
        Brand(name: "Visa", domain: "visa.com", global: true, isCommonWord: true),
        Brand(name: "Mastercard", domain: "mastercard.com", global: true),
        Brand(name: "American Express", domain: "americanexpress.com", otherDomains: ["amex.com", "aexp.com"], global: true),
        Brand(name: "Discover", domain: "discover.com", isCommonWord: true),
        // US banks
        Brand(name: "Chase", domain: "chase.com", otherDomains: ["jpmorganchase.com", "jpmorgan.com"]),
        Brand(name: "Bank of America", domain: "bankofamerica.com", otherDomains: ["bofa.com"]),
        Brand(name: "Wells Fargo", domain: "wellsfargo.com", otherDomains: ["wf.com"]),
        Brand(name: "Citi", domain: "citi.com", otherDomains: ["citibank.com", "citigroup.com"], global: true),
        Brand(name: "Capital One", domain: "capitalone.com"),
        Brand(name: "U.S. Bank", domain: "usbank.com"),
        Brand(name: "PNC", domain: "pnc.com", isCommonWord: true),
        Brand(name: "Truist", domain: "truist.com"),
        Brand(name: "TD Bank", domain: "td.com", otherDomains: ["tdbank.com", "tdameritrade.com"], isCommonWord: true),
        Brand(name: "Navy Federal", domain: "navyfederal.org"),
        Brand(name: "USAA", domain: "usaa.com"),
        Brand(name: "Charles Schwab", domain: "schwab.com"),
        Brand(name: "Fidelity", domain: "fidelity.com"),
        Brand(name: "Vanguard", domain: "vanguard.com", isCommonWord: true),
        Brand(name: "Robinhood", domain: "robinhood.com"),
        Brand(name: "Ally", domain: "ally.com", isCommonWord: true),
        Brand(name: "Citizens Bank", domain: "citizensbank.com"),
        Brand(name: "Regions", domain: "regions.com", isCommonWord: true),
        // UK & Europe banks
        Brand(name: "HSBC", domain: "hsbc.com", otherDomains: ["hsbc.co.uk", "hsbc.com.mx"], global: true),
        Brand(name: "Barclays", domain: "barclays.co.uk", otherDomains: ["barclays.com", "barclaycard.co.uk"], global: true),
        Brand(name: "Lloyds Bank", domain: "lloydsbank.com", otherDomains: ["lloydsbank.co.uk"]),
        Brand(name: "NatWest", domain: "natwest.com"),
        Brand(name: "Santander", domain: "santander.com", otherDomains: ["santander.co.uk", "santander.com.mx", "santander.es"], global: true),
        Brand(name: "BBVA", domain: "bbva.com", otherDomains: ["bbva.mx", "bbva.es"], global: true),
        Brand(name: "ING", domain: "ing.com", otherDomains: ["ing.nl", "ing.de", "ing.es"], global: true, isCommonWord: true),
        Brand(name: "Deutsche Bank", domain: "deutsche-bank.de", otherDomains: ["db.com"]),
        Brand(name: "Commerzbank", domain: "commerzbank.de"),
        Brand(name: "Sparkasse", domain: "sparkasse.de"),
        Brand(name: "BNP Paribas", domain: "bnpparibas.com", otherDomains: ["bnpparibas.fr"]),
        Brand(name: "Société Générale", domain: "societegenerale.fr"),
        Brand(name: "CaixaBank", domain: "caixabank.es"),
        Brand(name: "Monzo", domain: "monzo.com"),
        Brand(name: "Starling Bank", domain: "starlingbank.com"),
        // Latin America banks & government
        Brand(name: "Banorte", domain: "banorte.com"),
        Brand(name: "Banamex", domain: "banamex.com", otherDomains: ["citibanamex.com"]),
        Brand(name: "Banco Azteca", domain: "bancoazteca.com.mx"),
        Brand(name: "Scotiabank", domain: "scotiabank.com", otherDomains: ["scotiabank.com.mx"], global: true),
        Brand(name: "Itaú", domain: "itau.com.br", otherDomains: ["itau.com"]),
        Brand(name: "Bradesco", domain: "bradesco.com.br"),
        Brand(name: "Nubank", domain: "nubank.com.br", otherDomains: ["nu.com.mx"]),
        Brand(name: "Bancolombia", domain: "bancolombia.com"),
        Brand(name: "SAT", domain: "sat.gob.mx", isCommonWord: true),
        Brand(name: "IMSS", domain: "imss.gob.mx"),
        Brand(name: "Mercado Libre", domain: "mercadolibre.com", otherDomains: ["mercadolibre.com.mx", "mercadolivre.com.br", "mercadolibre.com.ar"], global: true),
        // Canada & Australia
        Brand(name: "RBC", domain: "rbcroyalbank.com", otherDomains: ["rbc.com"]),
        Brand(name: "CIBC", domain: "cibc.com"),
        Brand(name: "BMO", domain: "bmo.com"),
        Brand(name: "Interac", domain: "interac.ca"),
        Brand(name: "Commonwealth Bank", domain: "commbank.com.au"),
        Brand(name: "Westpac", domain: "westpac.com.au"),
        Brand(name: "ANZ", domain: "anz.com", otherDomains: ["anz.com.au"]),
        // Big tech & accounts
        Brand(name: "Apple", domain: "apple.com", otherDomains: ["icloud.com", "me.com", "apple.co"], global: true),
        Brand(name: "iCloud", domain: "icloud.com", otherDomains: ["apple.com"]),
        Brand(name: "Google", domain: "google.com", otherDomains: ["gmail.com", "youtube.com", "goo.gl", "g.co"], global: true),
        Brand(name: "Gmail", domain: "gmail.com", otherDomains: ["google.com"]),
        Brand(name: "YouTube", domain: "youtube.com", otherDomains: ["youtu.be", "google.com"], global: true),
        Brand(name: "Microsoft", domain: "microsoft.com", otherDomains: ["live.com", "office.com", "outlook.com", "microsoftonline.com", "office365.com"], global: true),
        Brand(name: "Outlook", domain: "outlook.com", otherDomains: ["live.com", "microsoft.com", "office.com"]),
        Brand(name: "Office 365", domain: "office.com", otherDomains: ["office365.com", "microsoft.com", "microsoftonline.com"], isCommonWord: true),
        Brand(name: "Amazon", domain: "amazon.com", otherDomains: ["amzn.to", "amazon.co.uk", "aws.amazon.com"], global: true),
        Brand(name: "Netflix", domain: "netflix.com", global: true),
        Brand(name: "Facebook", domain: "facebook.com", otherDomains: ["fb.com", "fb.me", "meta.com"], global: true),
        Brand(name: "Instagram", domain: "instagram.com", global: true),
        Brand(name: "WhatsApp", domain: "whatsapp.com", otherDomains: ["wa.me", "whatsapp.net"], global: true),
        Brand(name: "Meta", domain: "meta.com", otherDomains: ["facebook.com"], isCommonWord: true),
        Brand(name: "X", domain: "x.com", otherDomains: ["twitter.com", "t.co"], isCommonWord: true),
        Brand(name: "Twitter", domain: "twitter.com", otherDomains: ["x.com", "t.co"]),
        Brand(name: "LinkedIn", domain: "linkedin.com", otherDomains: ["lnkd.in"], global: true),
        Brand(name: "TikTok", domain: "tiktok.com", global: true),
        Brand(name: "Snapchat", domain: "snapchat.com"),
        Brand(name: "Telegram", domain: "telegram.org", otherDomains: ["t.me"]),
        Brand(name: "Yahoo", domain: "yahoo.com", global: true),
        Brand(name: "Dropbox", domain: "dropbox.com"),
        Brand(name: "Adobe", domain: "adobe.com", global: true),
        Brand(name: "DocuSign", domain: "docusign.com", otherDomains: ["docusign.net"]),
        Brand(name: "Zoom", domain: "zoom.us", otherDomains: ["zoom.com"], isCommonWord: true),
        Brand(name: "Spotify", domain: "spotify.com", global: true),
        Brand(name: "Steam", domain: "steampowered.com", otherDomains: ["steamcommunity.com"]),
        Brand(name: "Epic Games", domain: "epicgames.com"),
        Brand(name: "Roblox", domain: "roblox.com"),
        Brand(name: "Discord", domain: "discord.com", otherDomains: ["discord.gg", "discordapp.com"]),
        Brand(name: "Uber", domain: "uber.com", global: true),
        Brand(name: "Airbnb", domain: "airbnb.com", global: true),
        Brand(name: "Booking.com", domain: "booking.com", global: true, isCommonWord: true),
        Brand(name: "Samsung", domain: "samsung.com", global: true),
        // Retail
        Brand(name: "eBay", domain: "ebay.com", global: true),
        Brand(name: "Walmart", domain: "walmart.com", otherDomains: ["walmart.com.mx"], global: true),
        Brand(name: "Target", domain: "target.com", isCommonWord: true),
        Brand(name: "Costco", domain: "costco.com", global: true),
        Brand(name: "Best Buy", domain: "bestbuy.com"),
        Brand(name: "Home Depot", domain: "homedepot.com"),
        Brand(name: "Shein", domain: "shein.com", global: true),
        Brand(name: "Temu", domain: "temu.com"),
        Brand(name: "AliExpress", domain: "aliexpress.com", otherDomains: ["alibaba.com"]),
        // Carriers & post
        Brand(name: "USPS", domain: "usps.com", otherDomains: ["usps.gov"]),
        Brand(name: "UPS", domain: "ups.com", global: true),
        Brand(name: "FedEx", domain: "fedex.com", global: true),
        Brand(name: "DHL", domain: "dhl.com", otherDomains: ["dhl.de"], global: true),
        Brand(name: "Royal Mail", domain: "royalmail.com"),
        Brand(name: "Evri", domain: "evri.com"),
        Brand(name: "Canada Post", domain: "canadapost-postescanada.ca", otherDomains: ["canadapost.ca"]),
        Brand(name: "Australia Post", domain: "auspost.com.au"),
        Brand(name: "Correos", domain: "correos.es", otherDomains: ["correosdemexico.gob.mx"]),
        Brand(name: "La Poste", domain: "laposte.fr"),
        Brand(name: "PostNL", domain: "postnl.nl"),
        Brand(name: "Deutsche Post", domain: "deutschepost.de"),
        Brand(name: "Estafeta", domain: "estafeta.com"),
        // Telecom
        Brand(name: "AT&T", domain: "att.com", isCommonWord: true),
        Brand(name: "Verizon", domain: "verizon.com", otherDomains: ["verizonwireless.com"]),
        Brand(name: "T-Mobile", domain: "t-mobile.com"),
        Brand(name: "Xfinity", domain: "xfinity.com", otherDomains: ["comcast.net", "comcast.com"]),
        Brand(name: "Telcel", domain: "telcel.com"),
        Brand(name: "Vodafone", domain: "vodafone.com", global: true),
        // Tolls & parking (common QR scams)
        Brand(name: "E-ZPass", domain: "e-zpassny.com", otherDomains: ["ezpassnj.com", "e-zpassiag.com"]),
        Brand(name: "SunPass", domain: "sunpass.com"),
        Brand(name: "FasTrak", domain: "bayareafastrak.org"),
        Brand(name: "TxTag", domain: "txtag.org"),
        Brand(name: "PayByPhone", domain: "paybyphone.com", global: true),
        Brand(name: "ParkMobile", domain: "parkmobile.io", otherDomains: ["parkmobile.com"]),
        Brand(name: "SpotHero", domain: "spothero.com"),
        // Crypto
        Brand(name: "Coinbase", domain: "coinbase.com"),
        Brand(name: "Binance", domain: "binance.com", global: true),
        Brand(name: "Kraken", domain: "kraken.com", isCommonWord: true),
        Brand(name: "Crypto.com", domain: "crypto.com", isCommonWord: true),
        Brand(name: "MetaMask", domain: "metamask.io"),
        Brand(name: "Ledger", domain: "ledger.com", isCommonWord: true),
        Brand(name: "Trezor", domain: "trezor.io"),
        Brand(name: "Blockchain.com", domain: "blockchain.com", isCommonWord: true),
        Brand(name: "OpenSea", domain: "opensea.io"),
        Brand(name: "Uniswap", domain: "uniswap.org"),
        Brand(name: "Phantom", domain: "phantom.app", isCommonWord: true),
        Brand(name: "Trust Wallet", domain: "trustwallet.com"),
        Brand(name: "Bitso", domain: "bitso.com"),
        // Government
        Brand(name: "IRS", domain: "irs.gov"),
        Brand(name: "Social Security", domain: "ssa.gov", isCommonWord: true),
        Brand(name: "Medicare", domain: "medicare.gov"),
        Brand(name: "USA.gov", domain: "usa.gov", isCommonWord: true),
        Brand(name: "HMRC", domain: "hmrc.gov.uk", otherDomains: ["gov.uk"]),
        Brand(name: "GOV.UK", domain: "gov.uk", isCommonWord: true),
        Brand(name: "DVLA", domain: "dvla.gov.uk"),
        Brand(name: "Service Canada", domain: "canada.ca", isCommonWord: true),
        Brand(name: "Australian Tax Office", domain: "ato.gov.au"),
        Brand(name: "myGov", domain: "my.gov.au"),
    ]

    /// Brand whose domain (or a domain it owns) this registrable domain is.
    static func owner(ofRegistrable registrable: String) -> Brand? {
        if let brand = byDomain[registrable] { return brand }
        // Global brands own their name under country codes (amazon.co.uk, google.de), not every new gTLD.
        let tld = DomainRules.topLevelDomain(registrable)
        guard tld.count == 2 || ["com", "net", "org"].contains(tld) else { return nil }
        let label = DomainRules.label(ofRegistrable: registrable)
        return all.first { $0.global && $0.label == label }
    }

    private static let byDomain: [String: Brand] = {
        var map: [String: Brand] = [:]
        for brand in all {
            for domain in brand.ownedDomains where map[domain] == nil { map[domain] = brand }
        }
        return map
    }()
}
