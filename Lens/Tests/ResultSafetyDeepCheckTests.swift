import Foundation
import Testing
@testable import Lens

/// Scripted network: fixed responses per URL and method, RDAP JSON per domain. Records every call.
final class FakeSafetyNetwork: SafetyNetwork {
    var routes: [String: HTTPProbe] = [:]
    /// Methods that fail for a URL ("HEAD" → 405 by default for servers that refuse HEAD).
    var headStatus: [String: Int] = [:]
    var registrations: [String: String] = [:]
    var offline = false
    private(set) var probes: [String] = []
    private(set) var lookups: [String] = []

    func probe(_ url: URL, method: String) async throws -> HTTPProbe {
        probes.append("\(method) \(url.absoluteString)")
        if offline { throw URLError(.notConnectedToInternet) }
        if method == "HEAD", let status = headStatus[url.absoluteString] { return HTTPProbe(status: status) }
        return routes[url.absoluteString] ?? HTTPProbe(status: 200)
    }

    func data(from url: URL) async throws -> Data {
        lookups.append(url.absoluteString)
        if offline { throw URLError(.notConnectedToInternet) }
        let domain = url.lastPathComponent
        guard let date = registrations[domain] else { throw URLError(.fileDoesNotExist) }
        return Data("""
        {"objectClassName":"domain","ldhName":"\(domain)","events":[
          {"eventAction":"last changed","eventDate":"2026-01-01T00:00:00Z"},
          {"eventAction":"registration","eventDate":"\(date)"}
        ]}
        """.utf8)
    }
}

@Suite("SafetyAnalyzer · deep check")
struct ResultSafetyDeepCheckTests {
    /// 28 Sep 2026, 12:00 UTC.
    let now = Date(timeIntervalSince1970: 1_790_596_800)

    /// Each test uses its own host so the in-memory cache never leaks between tests.
    private func run(_ url: String, _ network: FakeSafetyNetwork) async -> SafetyVerdict {
        await SafetyAnalyzer.fullCheck(URL(string: url)!, network: network, now: now)
    }

    @Test func establishedDirectLinkIsSafe() async {
        let network = FakeSafetyNetwork()
        network.registrations["atlas-safe.co"] = "2019-03-02T18:21:11Z"
        let verdict = await run("https://atlas-safe.co/menu", network)
        #expect(verdict.level == .safe)
        #expect(verdict.redirectChain.isEmpty)
        #expect(verdict.findings.map(\.title) == ["HTTPS", "No redirects", "Domain since 2019"])
        #expect(network.lookups == ["https://rdap.org/domain/atlas-safe.co"])
    }

    @Test func quishingChainIsDangerous() async {
        let network = FakeSafetyNetwork()
        network.routes["https://bit.ly/3xQdeep"] = HTTPProbe(status: 301, location: "https://paypa1-login.com/start")
        network.routes["https://paypa1-login.com/start"] = HTTPProbe(status: 302, location: "/verify?id=9")
        network.registrations["paypa1-login.com"] = "2026-09-25T08:00:00.123Z"

        let verdict = await run("https://bit.ly/3xQdeep", network)
        #expect(verdict.level == .danger)
        #expect(verdict.redirectChain.map(\.absoluteString) == [
            "https://paypa1-login.com/start",
            "https://paypa1-login.com/verify?id=9",
        ])
        #expect(verdict.destination.absoluteString == "https://paypa1-login.com/verify?id=9")
        let titles = verdict.findings.map(\.title)
        #expect(titles.contains("Registered 3 days ago"))
        #expect(titles.contains("Imitates paypal.com"))
        #expect(titles.contains("Short link"))
        #expect(!verdict.findings.contains { $0.detail == "The destination is hidden until it opens." })
        #expect(verdict.findings.first?.level == .danger)
    }

    @Test func shortLinkToEstablishedSiteIsSafe() async {
        let network = FakeSafetyNetwork()
        network.routes["https://qrco.de/menu42"] = HTTPProbe(status: 302, location: "https://menu.atlas-short.co/")
        network.registrations["atlas-short.co"] = "2018-06-01T00:00:00Z"
        let verdict = await run("https://qrco.de/menu42", network)
        #expect(verdict.level == .safe)
        #expect(verdict.findings.contains { $0.title == "Short link" && $0.detail == "Opens menu.atlas-short.co" })
    }

    @Test func redirectToAnotherSiteIsCaution() async {
        let network = FakeSafetyNetwork()
        network.routes["https://atlas-redirect.co/"] = HTTPProbe(status: 301, location: "https://elsewhere-example.net/")
        network.registrations["elsewhere-example.net"] = "2015-01-01T00:00:00Z"
        let verdict = await run("https://atlas-redirect.co/", network)
        #expect(verdict.level == .caution)
        #expect(verdict.findings.first?.title == "Redirects elsewhere")
    }

    @Test func redirectWithinSameSiteIsFine() async {
        let network = FakeSafetyNetwork()
        network.routes["http://atlas-same.co/"] = HTTPProbe(status: 301, location: "https://www.atlas-same.co/")
        network.registrations["atlas-same.co"] = "2015-01-01T00:00:00Z"
        let verdict = await run("http://atlas-same.co/", network)
        #expect(verdict.level == .safe, "HTTP upgraded to HTTPS: \(verdict.findings.map(\.title))")
        #expect(verdict.redirectChain.count == 1)
    }

    @Test func headRefusedFallsBackToGET() async {
        let network = FakeSafetyNetwork()
        network.headStatus["https://atlas-head.co/x"] = 405
        network.routes["https://atlas-head.co/x"] = HTTPProbe(status: 302, location: "https://atlas-head.co/y")
        let verdict = await run("https://atlas-head.co/x", network)
        #expect(network.probes.prefix(2) == ["HEAD https://atlas-head.co/x", "GET https://atlas-head.co/x"])
        #expect(verdict.redirectChain.map(\.absoluteString) == ["https://atlas-head.co/y"])
    }

    @Test func stopsAfterEightHops() async {
        let network = FakeSafetyNetwork()
        for hop in 0..<20 {
            network.routes["https://atlas-loop.co/\(hop)"] = HTTPProbe(status: 302, location: "https://atlas-loop.co/\(hop + 1)")
        }
        let verdict = await run("https://atlas-loop.co/0", network)
        #expect(verdict.redirectChain.count == RedirectResolver.maxHops)
    }

    @Test func redirectLoopStops() async {
        let network = FakeSafetyNetwork()
        network.routes["https://atlas-cycle.co/a"] = HTTPProbe(status: 302, location: "https://atlas-cycle.co/b")
        network.routes["https://atlas-cycle.co/b"] = HTTPProbe(status: 302, location: "https://atlas-cycle.co/a")
        let verdict = await run("https://atlas-cycle.co/a", network)
        #expect(verdict.redirectChain.map(\.absoluteString) == ["https://atlas-cycle.co/b", "https://atlas-cycle.co/a"])
    }

    @Test func redirectIntoJavascriptIsDangerous() async {
        let network = FakeSafetyNetwork()
        network.routes["https://atlas-js.co/"] = HTTPProbe(status: 302, location: "javascript:alert(1)")
        let verdict = await run("https://atlas-js.co/", network)
        #expect(verdict.level == .danger)
        #expect(verdict.findings.contains { $0.title == "Runs code" })
    }

    @Test func offlineFallsBackToHeuristicsAndIsNotCached() async {
        let network = FakeSafetyNetwork()
        network.offline = true
        let offline = await run("https://atlas-offline.co/", network)
        #expect(offline.level == .safe)
        #expect(offline.findings.map(\.title) == ["HTTPS"])

        network.offline = false
        network.registrations["atlas-offline.co"] = "2020-01-01T00:00:00Z"
        let online = await run("https://atlas-offline.co/", network)
        #expect(online.findings.map(\.title).contains("No redirects"))
    }

    @Test func resultsAreCachedPerURLAndDomain() async {
        let network = FakeSafetyNetwork()
        network.registrations["atlas-cache.co"] = "2020-01-01T00:00:00Z"
        _ = await run("https://atlas-cache.co/a", network)
        _ = await run("https://atlas-cache.co/a", network)
        _ = await run("https://atlas-cache.co/b", network)
        #expect(network.probes.filter { $0.hasSuffix("/a") }.count == 1)
        #expect(network.lookups.count == 1)
    }

    @Test(arguments: [(0, "Registered today"), (3, "Registered 3 days ago"), (40, "Registered recently"), (400, "Domain since 2025")])
    func domainAgeCopy(days: Int, title: String) {
        let registered = now.addingTimeInterval(-Double(days) * 86_400)
        #expect(SafetySignal.domainAge(registered: registered, now: now).finding.title == title)
    }

    @Test func recentDomainPlusAnotherWarningEscalates() async {
        let network = FakeSafetyNetwork()
        network.registrations["atlas-new.zip"] = "2026-08-20T00:00:00Z"
        let verdict = await run("https://atlas-new.zip/", network)
        #expect(verdict.level == .danger)
        #expect(verdict.findings.first { $0.title == "Registered recently" }?.level == .danger)
    }

    @Test func rdapParsing() {
        let json = Data(#"{"events":[{"eventAction":"registration","eventDate":"1997-09-15T04:00:00Z"}]}"#.utf8)
        #expect(DomainAgeLookup.registrationDate(fromRDAP: json) == Date(timeIntervalSince1970: 874_296_000))
        #expect(DomainAgeLookup.registrationDate(fromRDAP: Data("{}".utf8)) == nil)
        #expect(DomainAgeLookup.registrationDate(fromRDAP: Data("not json".utf8)) == nil)
    }
}
