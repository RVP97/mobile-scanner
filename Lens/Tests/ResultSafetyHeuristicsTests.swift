import Foundation
import Testing
@testable import Lens

@Suite("SafetyAnalyzer · offline heuristics")
struct ResultSafetyHeuristicsTests {
    private func check(_ string: String) -> SafetyVerdict {
        SafetyAnalyzer.quickCheck(URL(string: string)!)
    }

    private func titles(_ verdict: SafetyVerdict) -> [String] { verdict.findings.map(\.title) }

    // MARK: Safe

    @Test(arguments: [
        "https://atlas-coffee.co/menu",
        "https://www.paypal.com/signin",
        "https://login.microsoftonline.com/common/oauth2",
        "https://amazon.co.uk/gp/cart",
        "https://www.google.de",
        "https://accounts.google.com/signin",
        "https://www.bbva.mx/personas.html",
        "https://www.santander.com.mx",
        "https://icloud.com/find",
    ])
    func legitimateHTTPSIsSafe(url: String) {
        let verdict = check(url)
        #expect(verdict.level == .safe, "\(url): \(titles(verdict))")
        #expect(verdict.findings.allSatisfy { $0.level == .safe })
    }

    @Test func safeVerdictExplainsHTTPS() {
        #expect(titles(check("https://atlas-coffee.co")) == ["HTTPS"])
    }

    // MARK: Scheme & address tricks

    @Test func plainHTTPIsCaution() {
        let verdict = check("http://atlas-coffee.co/menu")
        #expect(verdict.level == .caution)
        #expect(titles(verdict).contains("Not encrypted"))
    }

    @Test(arguments: ["javascript:alert(document.cookie)", "data:text/html;base64,PHNjcmlwdD4="])
    func scriptAndDataURIsAreDangerous(url: String) {
        #expect(check(url).level == .danger)
    }

    @Test func otherSchemesAreUnknown() {
        #expect(check("mailto:maya@studionorte.mx").level == .unknown)
    }

    @Test func userInfoTrickIsDangerous() {
        let verdict = check("https://www.paypal.com@evil-example.net/login")
        #expect(verdict.level == .danger)
        let finding = verdict.findings.first { $0.title == "Hides the real address" }
        #expect(finding?.detail.contains("evil-example.net") == true)
    }

    @Test(arguments: ["http://192.168.1.10/admin", "https://[2001:db8::1]/", "http://3232235777/", "http://0xC0A80001/"])
    func rawIPHostsAreCaution(url: String) {
        let verdict = check(url)
        #expect(verdict.level >= .caution)
        #expect(titles(verdict).contains("Uses a raw IP address"))
    }

    @Test func unusualPortIsCaution() {
        #expect(titles(check("https://atlas-coffee.co:8443/")).contains("Unusual port"))
        #expect(!titles(check("https://atlas-coffee.co:443/")).contains("Unusual port"))
    }

    // MARK: Lookalikes

    @Test(arguments: [
        ("https://paypa1.com/login", "paypal.com"),
        ("https://g00gle.com", "google.com"),
        ("https://rnicrosoft.com/account", "microsoft.com"),
        ("https://arnazon.com", "amazon.com"),
        ("https://xn--pple-43d.com", "apple.com"),
        ("https://www.xn--80ak6aa92e.com", "apple.com"), // all-Cyrillic "аррӏе"
        ("https://coinbase-l0gin.com/", "coinbase.com"),
        ("https://wel1sfargo.com", "wellsfargo.com"),
        ("https://faceb00k.com", "facebook.com"),
    ])
    func homographsAreDangerous(url: String, brand: String) {
        let verdict = check(url)
        #expect(verdict.level == .danger, "\(url): \(titles(verdict))")
        #expect(verdict.findings.contains { $0.title.contains(brand) || $0.detail.contains(brand) }, "\(url): \(titles(verdict))")
    }

    @Test func lookalikeCharactersAreFlaggedAndExplained() throws {
        let match = try #require(LookalikeDetector.match(host: "paypa1.com"))
        #expect(match.kind == .homograph)
        #expect(match.flaggedOffsets == [5])
        #expect(match.note == "That's the number one, not the letter “l”.")

        let zero = try #require(LookalikeDetector.match(host: "secure.g00gle.com"))
        #expect(zero.flaggedOffsets == [8, 9])
        #expect(zero.note == "That's a zero, not the letter “o”.")

        let cyrillic = try #require(LookalikeDetector.match(host: "аpple.com"))
        #expect(cyrillic.flaggedOffsets == [0])
        #expect(cyrillic.note?.contains("Cyrillic") == true)

        let digraph = try #require(LookalikeDetector.match(host: "rnicrosoft.com"))
        #expect(digraph.flaggedOffsets == [0, 1])
    }

    @Test func mixedScriptsAreFlagged() {
        #expect(Confusables.mixesScripts("аpple"))
        #expect(!Confusables.mixesScripts("apple"))
        #expect(!Confusables.mixesScripts("яндекс"))
        #expect(titles(check("https://xn--pple-43d.com")).contains("Mixes alphabets"))
    }

    @Test func brandAsSubdomainIsDangerous() {
        let verdict = check("https://paypal.com.secure-login.io/webscr")
        #expect(verdict.level == .danger)
        #expect(titles(verdict).contains("Pretends to be paypal.com"))
    }

    @Test func brandOnAnotherTLDIsDangerous() {
        #expect(check("https://chase.co/verify").level == .danger)
        #expect(titles(check("https://paypal.support")).contains("Not PayPal's address"))
    }

    @Test func brandInNameAloneIsCaution() {
        let verdict = check("https://netflix-fans.com/")
        #expect(verdict.level == .caution)
        #expect(titles(verdict).contains("Uses the Netflix name"))
    }

    @Test func brandInNameWithLureWordsEscalates() {
        let verdict = check("https://paypal-secure.io/")
        #expect(verdict.level == .danger)
        #expect(verdict.findings.first { $0.title == "Uses the PayPal name" }?.level == .danger)
    }

    @Test func typoSquatIsCaution() {
        let verdict = check("https://amazom.com")
        #expect(verdict.level == .caution)
        #expect(titles(verdict).contains("Looks like amazon.com"))
        #expect(check("http://amazom.com").level == .danger) // plus no HTTPS
    }

    @Test(arguments: [
        "https://a11y.com",          // not Ally Bank
        "https://targets-and-goals.com",
        "https://backups.example.com",
        "https://applebees.com",
        "https://cashback.example.com",
        "https://en.wikipedia.org/wiki/Chase",
        "https://startupschool.org",
    ])
    func ordinaryNamesAreNotLookalikes(url: String) {
        let verdict = check(url)
        #expect(verdict.level == .safe, "\(url): \(titles(verdict))")
    }

    @Test func brandListIsSubstantial() {
        #expect(BrandDomains.all.count >= 150)
        #expect(Set(BrandDomains.all.map(\.domain)).count == BrandDomains.all.count)
    }

    // MARK: Domain shape

    @Test(arguments: ["https://bit.ly/3xQabc", "https://tinyurl.com/abc", "https://qrco.de/bdX1"])
    func shortenersAreCaution(url: String) {
        let verdict = check(url)
        #expect(verdict.level == .caution)
        #expect(verdict.findings.first?.title == "Short link")
        #expect(verdict.findings.first?.detail == "The destination is hidden until it opens.")
    }

    @Test func riskyTLDIsCaution() {
        let verdict = check("https://free-coffee.zip")
        #expect(verdict.level == .caution)
        #expect(titles(verdict).contains("Unusual ending"))
    }

    @Test func excessiveSubdomainsAreCaution() {
        #expect(titles(check("https://a.b.c.d.atlas-coffee.co")).contains("Unusually long address"))
        #expect(!titles(check("https://menu.atlas-coffee.co")).contains("Unusually long address"))
        #expect(!titles(check("https://shop.atlas.github.io")).contains("Unusually long address"))
    }

    @Test func lureWordsOnUnknownDomainAreCaution() {
        let verdict = check("https://account-verify.example-bank.net")
        #expect(verdict.level == .caution)
        #expect(titles(verdict).contains("Asks you to act"))
        #expect(check("https://example.org/webscr?cmd=login").level == .caution)
    }

    @Test func findingsAreOrderedWorstFirst() {
        let verdict = check("http://paypa1.com")
        #expect(verdict.findings.first?.level == .danger)
        #expect(verdict.findings.map(\.level) == verdict.findings.map(\.level).sorted(by: >))
    }

    // MARK: Building blocks

    @Test func punycodeDecoding() {
        #expect(Punycode.decode("pple-43d") == "аpple")
        #expect(Punycode.decode("mnchen-3ya") == "münchen")
        #expect(Punycode.decodeHost("www.xn--mnchen-3ya.de") == "www.münchen.de")
        #expect(Punycode.decodeHost("atlas-coffee.co") == "atlas-coffee.co")
    }

    @Test func skeletons() {
        #expect(Confusables.skeleton("n0rthbank") == "northbank")
        #expect(Confusables.skeleton("vvellsfargo") == "wellsfargo")
        #expect(Confusables.skeleton("ΡayΡal") == "paypal")
        #expect(Confusables.skeleton("ｐａｙｐａｌ") == "paypal")
    }

    @Test func levenshtein() {
        #expect(Confusables.distance("amazon", "amazom") == 1)
        #expect(Confusables.distance("kitten", "sitting") == 3)
        #expect(Confusables.distance("paypal", "paypal") == 0)
        #expect(Confusables.distance("a", "abcdef", limit: 2) == 3)
    }

    @Test(arguments: [
        ("login.paypal.com.secure.io", "secure.io"),
        ("www.bbva.com.mx", "bbva.com.mx"),
        ("shop.example.co.uk", "example.co.uk"),
        ("example.com", "example.com"),
        ("a.b.c.gob.mx", "c.gob.mx"),
    ])
    func registrableDomain(host: String, expected: String) {
        #expect(DomainRules.registrableDomain(host) == expected)
    }

    @Test func sharedHostingSubdomainIsTheSite() {
        #expect(DomainRules.registrableDomain("evil.github.io", sharedHosting: true) == "evil.github.io")
        #expect(DomainRules.registrableDomain("evil.github.io") == "github.io")
    }
}
