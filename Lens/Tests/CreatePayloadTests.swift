import Foundation
import Testing
@testable import Lens

@MainActor
struct CreatePayloadTests {
    // MARK: Wi-Fi

    @Test func wifiEscapesSpecialCharacters() {
        let network = WiFiNetwork(ssid: #"Casa "Chen"; 2,4:GHz\"#, password: "p;a,s:s", security: .wpa)
        #expect(PayloadComposer.wifi(network) == #"WIFI:T:WPA;S:Casa \"Chen\"\; 2\,4\:GHz\\;P:p\;a\,s\:s;;"#)
    }

    @Test func openHiddenNetworkOmitsPassword() {
        let network = WiFiNetwork(ssid: "Lobby", password: "ignored", security: .open, isHidden: true)
        #expect(PayloadComposer.wifi(network) == "WIFI:T:nopass;S:Lobby;H:true;;")
    }

    // MARK: vCard

    @Test func vCardIsVersion3WithEscapedValues() {
        var card = ContactCard(givenName: "Maya", familyName: "Chen")
        card.organization = "Atlas, Coffee; Co"
        card.phones = ["+1 415 555 0100"]
        card.emails = ["maya@atlas-coffee.co"]
        card.note = "Line one\nLine two \\ done"
        let lines = PayloadComposer.vCard(card).components(separatedBy: "\r\n")
        #expect(lines.first == "BEGIN:VCARD")
        #expect(lines[1] == "VERSION:3.0")
        #expect(lines.contains("N:Chen;Maya;;;"))
        #expect(lines.contains("FN:Maya Chen"))
        #expect(lines.contains(#"ORG:Atlas\, Coffee\; Co"#))
        #expect(lines.contains("TEL;TYPE=CELL:+1 415 555 0100"))
        #expect(lines.contains("EMAIL;TYPE=INTERNET:maya@atlas-coffee.co"))
        #expect(lines.contains(#"NOTE:Line one\nLine two \\ done"#))
        #expect(lines.last == "END:VCARD")
    }

    // MARK: Event

    @Test func timedEventUsesUTC() {
        let start = Date(timeIntervalSince1970: 1_790_000_000)  // 2026-09-21 14:13:20 UTC
        let event = CalendarEvent(title: "Launch, party", start: start, end: start.addingTimeInterval(3600), location: "Atlas; Coffee")
        let text = PayloadComposer.event(event)
        #expect(text.contains("SUMMARY:Launch\\, party"))
        #expect(text.contains("DTSTART:20260921T141320Z"))
        #expect(text.contains("DTEND:20260921T151320Z"))
        #expect(text.contains("LOCATION:Atlas\\; Coffee"))
        #expect(text.hasPrefix("BEGIN:VEVENT") && text.hasSuffix("END:VEVENT"))
    }

    @Test func allDayEventEndsNextDay() {
        let zone = TimeZone(identifier: "America/Mexico_City")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 12))!
        let text = PayloadComposer.event(CalendarEvent(title: "Fair", start: day, end: day, isAllDay: true), timeZone: zone)
        #expect(text.contains("DTSTART;VALUE=DATE:20261003"))
        #expect(text.contains("DTEND;VALUE=DATE:20261004"))
    }

    // MARK: URIs

    @Test func emailEncodesQueryStrictly() {
        let text = PayloadComposer.email(EmailMessage(to: "hi@lens.app", subject: "Q&A = fun", body: "a+b"))
        #expect(text == "mailto:hi@lens.app?subject=Q%26A%20%3D%20fun&body=a%2Bb")
    }

    @Test func smsPhoneAndGeo() {
        #expect(PayloadComposer.sms(SMSMessage(number: "+1 (415) 555-0100", body: "Hi")) == "SMSTO:+14155550100:Hi")
        #expect(PayloadComposer.phone("415 555 0100") == "tel:4155550100")
        #expect(PayloadComposer.location(GeoPoint(latitude: 19.4326, longitude: -99.1332)) == "geo:19.432600,-99.133200")
        #expect(PayloadComposer.location(GeoPoint(latitude: 1, longitude: 2, label: "Café"))
            == "geo:1.000000,2.000000?q=1.000000,2.000000(Caf%C3%A9)")
    }

    @Test func linksGetHTTPS() {
        #expect(PayloadComposer.link("atlas-coffee.co/menu")?.absoluteString == "https://atlas-coffee.co/menu")
        #expect(PayloadComposer.link("http://example.com")?.absoluteString == "http://example.com")
        #expect(PayloadComposer.link("not a link") == nil)
        #expect(PayloadComposer.link("localhost:8080") != nil)
        #expect(PayloadComposer.link("atlas") == nil)
    }

    // MARK: Validation

    @Test func ean13AddsAndChecksCheckDigit() {
        #expect(SymbologyValidator.check("400638133393", for: .ean13).value == "4006381333931")
        #expect(SymbologyValidator.check("4006-3813-3393-1", for: .ean13).value == "4006381333931")
        guard case .invalid(_, let fix) = SymbologyValidator.check("4006381333930", for: .ean13) else {
            Issue.record("Wrong check digit should be invalid")
            return
        }
        #expect(fix?.replacement == "4006381333931")
        guard case .invalid = SymbologyValidator.check("12345", for: .ean13) else {
            Issue.record("Too short should be invalid")
            return
        }
    }

    @Test func upcERules() {
        #expect(SymbologyValidator.check("123456", for: .upcE).value == "01234565")
        #expect(SymbologyValidator.check("012345000065", for: .upcE).value == "01234565")
        #expect(SymbologyValidator.check("2123456", for: .upcE).value == nil)  // number system must be 0 or 1
    }

    @Test func formatSpecificRules() {
        #expect(SymbologyValidator.check("12345", for: .itf).value == nil)
        #expect(SymbologyValidator.check("lens", for: .code39).value == nil)
        #expect(SymbologyValidator.check("LENS-39", for: .code39).value == "LENS-39")
        #expect(SymbologyValidator.check("2", for: .pharmacode).value == nil)
        #expect(SymbologyValidator.check("131070", for: .pharmacode).value == "131070")
        #expect(SymbologyValidator.check("1234", for: .msi).value == "12344")
        #expect(SymbologyValidator.check("40156", for: .codabar).value == "A40156A")
        #expect(SymbologyValidator.check("B40156C", for: .codabar).value == "B40156C")
        #expect(SymbologyValidator.check("café", for: .code128).value == nil)
        #expect(SymbologyValidator.check("anything at all ✓", for: .dataMatrix).value != nil)
    }

    @Test func wifiDraftValidatesPasswordLength() {
        let draft = CreateDraft(intent: .wifi)
        draft.wifi.ssid = "Casa Chen"
        draft.wifi.password = "short"
        #expect(draft.outcome.document == nil)
        #expect(draft.issue(for: .password) != nil)
        draft.wifi.password = "correct horse"
        #expect(draft.outcome.document?.raw == "WIFI:T:WPA;S:Casa Chen;P:correct horse;;")
        #expect(draft.outcome.document?.caption == "Scan to join Casa Chen")
    }

    @Test func eventDraftOffersFixForBackwardsDates() throws {
        let draft = CreateDraft(intent: .event)
        draft.event.title = "Launch"
        draft.event.end = draft.event.start?.addingTimeInterval(-600)
        let issue = try #require(draft.issue(for: .eventDates))
        issue.fix?()
        #expect(draft.issue(for: .eventDates) == nil)
        #expect(draft.outcome.document != nil)
    }
}
