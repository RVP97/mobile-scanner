import Foundation
import Testing
@testable import Lens

@Suite("PayloadParser · links, Wi-Fi, messages")
struct PayloadParserTests {
    // MARK: Links

    @Test func plainURLIsLink() {
        let payload = PayloadParser.parse("https://atlas-coffee.co/menu", symbology: .qr)
        #expect(payload.kind == .link)
        #expect(payload.displayTitle == "atlas-coffee.co")
        #expect(payload.displaySubtitle == "/menu")
    }

    @Test(arguments: [
        ("atlas-coffee.co/menu", "https://atlas-coffee.co/menu"),
        ("www.example.com", "https://www.example.com"),
        ("EXAMPLE.COM/PATH", "https://example.com/PATH"),
        ("shop.example.co.uk/item?id=4", "https://shop.example.co.uk/item?id=4"),
    ])
    func bareDomainBecomesHTTPSLink(raw: String, expected: String) {
        guard case .link(let url) = PayloadParser.parse(raw, symbology: .qr) else {
            Issue.record("\(raw) should be a link")
            return
        }
        #expect(url.absoluteString == expected)
    }

    @Test(arguments: ["hello", "Locker 214 — code 5591", "5591", "file.txt", "v1.2.3", "3.14", "hello.world2", "a.b"])
    func wordsAndNumbersStayText(raw: String) {
        #expect(PayloadParser.parse(raw, symbology: .qr).kind == .text)
    }

    @Test func uppercaseSchemeAndHostAreNormalised() {
        guard case .link(let url) = PayloadParser.parse("HTTPS://ATLAS-COFFEE.CO/MENU", symbology: .qr) else {
            Issue.record("expected link")
            return
        }
        #expect(url.scheme == "https")
        #expect(url.host() == "atlas-coffee.co")
    }

    @Test func javascriptIsKeptAsLinkForSafety() {
        #expect(PayloadParser.parse("javascript:alert(1)", symbology: .qr).kind == .link)
    }

    @Test func meBookmarkIsLink() {
        let payload = PayloadParser.parse("MEBKM:TITLE:Atlas;URL:https\\://atlas-coffee.co;;", symbology: .qr)
        guard case .link(let url) = payload else {
            Issue.record("expected link")
            return
        }
        #expect(url.absoluteString == "https://atlas-coffee.co")
    }

    @Test func surroundingWhitespaceIsIgnored() {
        #expect(PayloadParser.parse("  https://atlas-coffee.co \n", symbology: .qr).kind == .link)
    }

    // MARK: Wi-Fi

    @Test func wifiBasic() {
        let payload = PayloadParser.parse("WIFI:T:WPA;S:Atlas Guest;P:cortado-2019;;", symbology: .qr)
        #expect(payload == .wifi(WiFiNetwork(ssid: "Atlas Guest", password: "cortado-2019", security: .wpa)))
        #expect(payload.displayTitle == "Atlas Guest")
    }

    @Test func wifiFieldsInAnyOrderWithEscapes() {
        let raw = #"WIFI:P:pa\;ss\,wo\:rd\\;H:true;S:Caf\;e \"Norte\";T:WEP;;"#
        guard case .wifi(let network) = PayloadParser.parse(raw, symbology: .qr) else {
            Issue.record("expected wifi")
            return
        }
        #expect(network.ssid == #"Caf;e "Norte""#)
        #expect(network.password == #"pa;ss,wo:rd\"#)
        #expect(network.security == .wep)
        #expect(network.isHidden)
    }

    @Test(arguments: [
        ("WIFI:S:Open Cafe;T:nopass;;", WiFiNetwork.Security.open),
        ("WIFI:S:Open Cafe;;", .open),
        ("wifi:s:Lower;p:secret;;", .wpa),
        ("WIFI:T:WPA2-EAP;S:Corp;P:x;;", .wpa),
        ("WIFI:T:SAE;S:Home;P:x;;", .wpa),
    ])
    func wifiSecurity(raw: String, expected: WiFiNetwork.Security) {
        guard case .wifi(let network) = PayloadParser.parse(raw, symbology: .qr) else {
            Issue.record("expected wifi for \(raw)")
            return
        }
        #expect(network.security == expected)
    }

    @Test func wifiWithoutSSIDIsText() {
        #expect(PayloadParser.parse("WIFI:T:WPA;P:secret;;", symbology: .qr).kind == .text)
    }

    // MARK: Email, SMS, phone, geo

    @Test func mailtoWithQuery() {
        let payload = PayloadParser.parse("mailto:maya@studionorte.mx?subject=Hola%20Maya&body=See%20you", symbology: .qr)
        #expect(payload == .email(EmailMessage(to: "maya@studionorte.mx", subject: "Hola Maya", body: "See you")))
        #expect(payload.displaySubtitle == "Hola Maya")
    }

    @Test func matmsg() {
        let payload = PayloadParser.parse("MATMSG:TO:maya@studionorte.mx;SUB:Menu;BODY:Table 4\\; thanks;;", symbology: .qr)
        #expect(payload == .email(EmailMessage(to: "maya@studionorte.mx", subject: "Menu", body: "Table 4; thanks")))
    }

    @Test func bareEmailIsEmail() {
        #expect(PayloadParser.parse("maya@studionorte.mx", symbology: .qr).kind == .email)
    }

    @Test(arguments: [
        ("sms:+525512345678?body=Hola", "+525512345678", "Hola"),
        ("sms:+525512345678&body=Hola%20t%C3%BA", "+525512345678", "Hola tú"),
        ("SMSTO:+525512345678:Table 4 ready", "+525512345678", "Table 4 ready"),
        ("smsto:5551234", "5551234", ""),
        ("sms:+1555;?&body=Hi", "+1555", "Hi"),
    ])
    func sms(raw: String, number: String, body: String) {
        #expect(PayloadParser.parse(raw, symbology: .qr) == .sms(SMSMessage(number: number, body: body)))
    }

    @Test func tel() {
        let payload = PayloadParser.parse("tel:+52%2055%201234%205678", symbology: .qr)
        #expect(payload == .phone("+52 55 1234 5678"))
    }

    @Test func geoWithLabel() {
        let payload = PayloadParser.parse("geo:19.4194,-99.1621?q=Atlas%20Coffee", symbology: .qr)
        #expect(payload == .location(GeoPoint(latitude: 19.4194, longitude: -99.1621, label: "Atlas Coffee")))
        #expect(payload.displayTitle == "Atlas Coffee")
    }

    @Test func geoAndroidStyle() {
        let payload = PayloadParser.parse("geo:0,0?q=19.4194,-99.1621(Atlas Coffee)", symbology: .qr)
        #expect(payload == .location(GeoPoint(latitude: 19.4194, longitude: -99.1621, label: "Atlas Coffee")))
    }

    @Test func geoWithAltitudeAndNoLabel() {
        let payload = PayloadParser.parse("geo:19.4194,-99.1621,2240", symbology: .qr)
        #expect(payload == .location(GeoPoint(latitude: 19.4194, longitude: -99.1621)))
        #expect(payload.displayTitle == "19.4194° N, 99.1621° W")
    }

    @Test func geoOutOfRangeIsText() {
        #expect(PayloadParser.parse("geo:120,10", symbology: .qr).kind == .text)
    }

    @Test func emptyIsText() {
        #expect(PayloadParser.parse("   ", symbology: .qr).kind == .text)
    }
}
