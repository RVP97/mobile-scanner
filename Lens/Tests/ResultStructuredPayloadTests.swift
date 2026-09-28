import Foundation
import Testing
@testable import Lens

@Suite("PayloadParser · contacts & events")
struct ResultContactEventTests {
    @Test func vCard3() {
        let raw = """
        BEGIN:VCARD
        VERSION:3.0
        N:Chen;Maya;;;
        FN:Maya Chen
        ORG:Studio Norte;Design
        TITLE:Product Designer
        TEL;TYPE=CELL:+52 55 1234 5678
        EMAIL;TYPE=WORK:maya@studionorte.mx
        URL:https://studionorte.mx
        ADR;TYPE=WORK:;;Av. Álvaro Obregón 99;Ciudad de México;CDMX;06700;México
        NOTE:Met at Atlas\\, Roma Norte\\nSecond line
        END:VCARD
        """
        guard case .contact(let card) = PayloadParser.parse(raw, symbology: .qr) else {
            Issue.record("expected contact")
            return
        }
        #expect(card.givenName == "Maya")
        #expect(card.familyName == "Chen")
        #expect(card.organization == "Studio Norte")
        #expect(card.jobTitle == "Product Designer")
        #expect(card.phones == ["+52 55 1234 5678"])
        #expect(card.emails == ["maya@studionorte.mx"])
        #expect(card.urls == ["https://studionorte.mx"])
        #expect(card.address == "Av. Álvaro Obregón 99, Ciudad de México, CDMX, 06700, México")
        #expect(card.note == "Met at Atlas, Roma Norte\nSecond line")
        #expect(card.initials == "MC")
        let payload = Payload.contact(card)
        #expect(payload.displayTitle == "Maya Chen")
        #expect(payload.displaySubtitle == "Product Designer · Studio Norte")
    }

    @Test func vCardFoldedLinesAndCRLF() {
        let raw = "BEGIN:VCARD\r\nVERSION:4.0\r\nFN:Maya\r\n  Chen\r\nNOTE:This is a long\r\n  note\r\nTEL;VALUE=uri:tel:+1-555-0100\r\nEND:VCARD"
        guard case .contact(let card) = PayloadParser.parse(raw, symbology: .qr) else {
            Issue.record("expected contact")
            return
        }
        #expect(card.givenName == "Maya")
        #expect(card.familyName == "Chen")
        #expect(card.note == "This is a long note")
        #expect(card.phones == ["+1-555-0100"])
    }

    @Test func vCard21QuotedPrintableAndBareParams() {
        let raw = """
        BEGIN:VCARD
        VERSION:2.1
        N;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:Pe=C3=B1a;Jos=C3=A9
        TEL;CELL;VOICE:5551234
        item1.EMAIL;INTERNET:jose@example.mx
        END:VCARD
        """
        guard case .contact(let card) = PayloadParser.parse(raw, symbology: .qr) else {
            Issue.record("expected contact")
            return
        }
        #expect(card.familyName == "Peña")
        #expect(card.givenName == "José")
        #expect(card.phones == ["5551234"])
        #expect(card.emails == ["jose@example.mx"])
    }

    @Test func vCardCompanyOnly() {
        let raw = "BEGIN:VCARD\nVERSION:3.0\nORG:Atlas Coffee\nTEL:+52 55 0000 0000\nEND:VCARD"
        let payload = PayloadParser.parse(raw, symbology: .qr)
        #expect(payload.displayTitle == "Atlas Coffee")
        #expect(payload.displaySubtitle == "+52 55 0000 0000")
    }

    @Test func meCard() {
        let raw = "MECARD:N:Chen,Maya;TEL:+525512345678;EMAIL:maya@studionorte.mx;ORG:Studio Norte;URL:https\\://studionorte.mx;NOTE:Hi\\, there;;"
        guard case .contact(let card) = PayloadParser.parse(raw, symbology: .qr) else {
            Issue.record("expected contact")
            return
        }
        #expect(card.familyName == "Chen")
        #expect(card.givenName == "Maya")
        #expect(card.phones == ["+525512345678"])
        #expect(card.urls == ["https://studionorte.mx"])
        #expect(card.note == "Hi, there")
        #expect(card.organization == "Studio Norte")
    }

    @Test func meCardNameWithoutComma() {
        guard case .contact(let card) = PayloadParser.parse("MECARD:N:Maya Chen;;", symbology: .qr) else {
            Issue.record("expected contact")
            return
        }
        #expect(card.fullName == "Maya Chen")
    }

    // MARK: Events

    @Test func vEventUTC() throws {
        let raw = """
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        SUMMARY:Cupping at Atlas
        DTSTART:20261001T170000Z
        DTEND:20261001T183000Z
        LOCATION:Atlas Coffee\\, Roma Norte
        DESCRIPTION:Bring a friend
        END:VEVENT
        END:VCALENDAR
        """
        guard case .event(let event) = PayloadParser.parse(raw, symbology: .qr) else {
            Issue.record("expected event")
            return
        }
        #expect(event.title == "Cupping at Atlas")
        #expect(event.location == "Atlas Coffee, Roma Norte")
        #expect(event.notes == "Bring a friend")
        #expect(!event.isAllDay)
        let start = try #require(event.start)
        #expect(start == Date(timeIntervalSince1970: 1_790_874_000))
        #expect(event.end == start.addingTimeInterval(90 * 60))
    }

    @Test func vEventAllDay() throws {
        let raw = "BEGIN:VEVENT\nSUMMARY:Market day\nDTSTART;VALUE=DATE:20261003\nDTEND;VALUE=DATE:20261004\nEND:VEVENT"
        guard case .event(let event) = PayloadParser.parse(raw, symbology: .qr) else {
            Issue.record("expected event")
            return
        }
        #expect(event.isAllDay)
        let start = try #require(event.start)
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour], from: start)
        #expect(parts.year == 2026 && parts.month == 10 && parts.day == 3 && parts.hour == 0)
        #expect(event.inclusiveEnd == start)
    }

    @Test func vEventWithTZID() throws {
        let raw = "BEGIN:VEVENT\nSUMMARY:Call\nDTSTART;TZID=America/Mexico_City:20261001T090000\nEND:VEVENT"
        guard case .event(let event) = PayloadParser.parse(raw, symbology: .qr) else {
            Issue.record("expected event")
            return
        }
        // Mexico City is UTC−6 all year since 2022.
        #expect(try #require(event.start) == Date(timeIntervalSince1970: 1_790_866_800))
    }

    @Test func vEventFloatingTimeIsLocal() throws {
        let raw = "BEGIN:VEVENT\nDTSTART:20261001T090000\nEND:VEVENT"
        guard case .event(let event) = PayloadParser.parse(raw, symbology: .qr) else {
            Issue.record("expected event")
            return
        }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: try #require(event.start))
        #expect(parts.hour == 9 && parts.minute == 0)
        #expect(Payload.event(event).displayTitle == "Event")
    }
}

@Suite("PayloadParser · travel, products, crypto, shipments")
struct ResultStructuredPayloadTests {
    /// Builds the fixed-width mandatory block of an IATA BCBP.
    private func bcbp(
        name: String = "CHEN/MAYA", pnr: String = "ABC123", from: String = "MEX", to: String = "SFO",
        carrier: String = "NR", flight: String = "0412", day: String = "275", cabin: String = "Y",
        seat: String = "014A", sequence: String = "0025"
    ) -> String {
        func pad(_ value: String, _ length: Int) -> String { value.padding(toLength: length, withPad: " ", startingAt: 0) }
        return "M1" + pad(name, 20) + "E" + pad(pnr, 7) + from + to + pad(carrier, 3) + pad(flight, 5)
            + day + cabin + pad(seat, 4) + pad(sequence, 5) + "1" + "00"
    }

    @Test func boardingPass() {
        let payload = PayloadParser.parse(bcbp(), symbology: .pdf417)
        let expected = BoardingPass(
            passengerName: "CHEN/MAYA", bookingReference: "ABC123", from: "MEX", to: "SFO", carrier: "NR",
            flightNumber: "412", dayOfYear: 275, cabin: "Y", seat: "14A", sequence: "25"
        )
        #expect(payload == .travel(expected))
        #expect(payload.displayTitle == "MEX → SFO · NR 412")
        #expect(payload.displaySubtitle == "Maya Chen · Seat 14A")
        #expect(expected.cabinName == "Economy")
    }

    @Test func iataSpecSample() {
        let raw = "M1DESMARAIS/LUC       EABC123 YULFRAAC 0834 326J001A0025 100"
        guard case .travel(let pass) = PayloadParser.parse(raw, symbology: .aztec) else {
            Issue.record("expected travel")
            return
        }
        #expect(pass.displayName == "Luc Desmarais")
        #expect(pass.flightDesignator == "AC 834")
        #expect(pass.seat == "1A")
        #expect(pass.cabinName == "Business")
        #expect(pass.airlineName == "Air Canada")
        #expect(TravelDirectory.city(for: pass.from) == "Montréal")
    }

    @Test func boardingPassWithConditionalDataStillParses() {
        let raw = bcbp() + ">5180 B1A 0000000000"
        #expect(PayloadParser.parse(raw, symbology: .qr).kind == .travel)
    }

    @Test func tooShortOrMalformedPassIsNotTravel() {
        #expect(PayloadParser.parse("M1CHEN/MAYA", symbology: .pdf417).kind != .travel)
        #expect(PayloadParser.parse(bcbp(from: "M3X"), symbology: .pdf417).kind != .travel)
        #expect(PayloadParser.parse(bcbp(day: "999"), symbology: .pdf417).kind != .travel)
    }

    @Test func julianDateResolvesNearestYear() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let pass = BoardingPass(passengerName: "", bookingReference: "", from: "MEX", to: "SFO", carrier: "NR",
                                flightNumber: "1", dayOfYear: 2, cabin: "", seat: "", sequence: "")
        // Scanned on 30 Dec 2026: day 2 is 2 Jan 2027, not 2 Jan 2026.
        let reference = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 30)))
        let date = try #require(pass.date(near: reference, calendar: calendar))
        #expect(calendar.dateComponents([.year, .month, .day], from: date) == DateComponents(year: 2027, month: 1, day: 2))

        let october = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 28)))
        var fall = pass
        fall.dayOfYear = 275
        let fallDate = try #require(fall.date(near: october, calendar: calendar))
        #expect(calendar.dateComponents([.year, .month, .day], from: fallDate) == DateComponents(year: 2026, month: 10, day: 2))
    }

    // MARK: Products

    @Test(arguments: [
        ("4006381333931", Symbology.ean13, "4006381333931"),
        ("0036000291452", .upcA, "036000291452"),
        ("036000291452", .upcA, "036000291452"),
        ("96385074", .ean8, "96385074"),
        ("04252614", .upcE, "042100005264"),
    ])
    func retailCodesAreProducts(raw: String, symbology: Symbology, gtin: String) {
        #expect(PayloadParser.parse(raw, symbology: symbology) == .product(gtin: gtin))
    }

    @Test func productDisplay() {
        let payload = Payload.product(gtin: "4006381333931")
        #expect(payload.displayTitle == "4 006381 333931")
        #expect(payload.displaySubtitle == "EAN-13 · Germany")
        #expect(GTIN.lookupCode("036000291452") == "0036000291452")
        #expect(GTIN.formatName("9780306406157") == "ISBN")
    }

    @Test func checkDigits() {
        #expect(GTIN.hasValidCheckDigit("4006381333931"))
        #expect(!GTIN.hasValidCheckDigit("4006381333932"))
        #expect(GTIN.hasValidCheckDigit("036000291452"))
        #expect(GTIN.hasValidCheckDigit("96385074"))
        #expect(GTIN.hasValidCheckDigit("10036000291459"))
        #expect(!GTIN.hasValidCheckDigit("12345"))
    }

    @Test func upcEExpansionRules() {
        #expect(GTIN.expandUPCE("04252614") == "042100005264")
        #expect(GTIN.expandUPCE("0123453") != nil)
        #expect(GTIN.expandUPCE("04252615") == nil) // wrong check digit
        #expect(GTIN.expandUPCE("24252614") == nil) // number system must be 0 or 1
    }

    @Test func gtinInQRNeedsValidCheckDigit() {
        #expect(PayloadParser.parse("4006381333931", symbology: .qr).kind == .product)
        #expect(PayloadParser.parse("4006381333932", symbology: .qr).kind == .text)
        #expect(PayloadParser.parse("96385074", symbology: .qr).kind == .text) // EAN-8 length only for linear codes
    }

    @Test func gs1ElementStringCarriesGTIN() {
        #expect(PayloadParser.parse("0104006381333931", symbology: .gs1DataBar) == .product(gtin: "4006381333931"))
        #expect(PayloadParser.parse("(01)04006381333931(17)261231", symbology: .dataMatrix) == .product(gtin: "4006381333931"))
    }

    @Test func invalidRetailCheckDigitIsStillProduct() {
        #expect(PayloadParser.parse("4006381333932", symbology: .ean13) == .product(gtin: "4006381333932"))
    }

    // MARK: Crypto

    @Test func bitcoinURI() {
        let payload = PayloadParser.parse("bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.01&label=Atlas", symbology: .qr)
        #expect(payload == .crypto(CryptoRequest(scheme: "bitcoin", address: "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq",
                                                 amount: "0.01", label: "Atlas")))
        #expect(payload.displaySubtitle == "Bitcoin · 0.01 BTC")
        #expect(payload.displayTitle == "bc1qar0s…zzwf5mdq")
    }

    @Test func ethereumEIP681() {
        let payload = PayloadParser.parse("ethereum:pay-0x742d35Cc6634C0532925a3b844Bc454e4438f44e@1?value=1e18", symbology: .qr)
        guard case .crypto(let request) = payload else {
            Issue.record("expected crypto")
            return
        }
        #expect(request.address == "0x742d35Cc6634C0532925a3b844Bc454e4438f44e")
        #expect(request.amount == "1e18")
    }

    @Test(arguments: [
        ("1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa", "bitcoin"),
        ("3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy", "bitcoin"),
        ("bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq", "bitcoin"),
        ("0x742d35Cc6634C0532925a3b844Bc454e4438f44e", "ethereum"),
    ])
    func bareAddresses(raw: String, scheme: String) {
        #expect(PayloadParser.parse(raw, symbology: .qr) == .crypto(CryptoRequest(scheme: scheme, address: raw)))
    }

    @Test(arguments: [
        "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNb", // checksum broken
        "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdx", // bech32 checksum broken
        "0x742d35Cc6634C0532925a3b844Bc454e4438f44", // 39 hex digits
    ])
    func lookalikeAddressesAreNotCrypto(raw: String) {
        #expect(PayloadParser.parse(raw, symbology: .qr).kind != .crypto)
    }

    // MARK: Shipments

    @Test(arguments: [
        ("1Z999AA10123456784", Symbology.qr, ShipmentCarrier.ups, "1Z999AA10123456784"),
        ("1z 999 aa1 0123 4567 84", .code128, .ups, "1Z999AA10123456784"),
        ("9400111899223197428490", .code128, .usps, "9400111899223197428490"),
        ("420941109400111899223197428490", .code128, .usps, "9400111899223197428490"),
        ("9622001900005105596800", .code128, .fedex, "9622001900005105596800"),
        ("123456789013", .code128, .fedex, "123456789013"),
        ("1234567890", .code128, .dhl, "1234567890"),
        ("JJD0099999999999999", .qr, .dhl, "JJD0099999999999999"),
        ("EA123456789US", .code128, .postal, "EA123456789US"),
    ])
    func trackingNumbers(raw: String, symbology: Symbology, carrier: ShipmentCarrier, number: String) {
        #expect(PayloadParser.parse(raw, symbology: symbology) == .shipment(number))
        #expect(ShipmentCarrier.detect(raw, symbology: symbology)?.carrier == carrier)
    }

    @Test func digitsInQRAreNotParcels() {
        #expect(PayloadParser.parse("1234567890", symbology: .qr).kind == .text)
        #expect(PayloadParser.parse("123456789013", symbology: .qr).kind == .text)
    }

    @Test func trackingURLs() {
        #expect(ShipmentCarrier.ups.trackingURL(for: "1Z999AA10123456784")?.host() == "www.ups.com")
        #expect(ShipmentCarrier.postal.trackingURL(for: "EA123456789US")?.host() == "tools.usps.com")
        #expect(Payload.shipment("1Z999AA10123456784").displaySubtitle == "UPS package")
    }
}
