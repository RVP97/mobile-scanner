import Foundation

/// Body of `POST /lens/v1/pass`. Mirrors `wallet-service/src/schema.ts` exactly — the server rejects
/// unknown keys, so keep both sides in sync.
nonisolated struct WalletPassRequest: Codable, Sendable, Equatable {
    enum PassType: String, Codable, Sendable {
        case boardingPass, eventTicket, storeCard, generic
    }

    /// The only formats Wallet renders. Everything Lens scans maps onto one of these.
    enum BarcodeFormat: String, Codable, Sendable {
        case qr = "QR"
        case pdf417 = "PDF417"
        case aztec = "Aztec"
        case code128 = "Code128"
    }

    /// Fixed server-side palette; arbitrary colors are not accepted.
    enum Palette: String, Codable, Sendable, CaseIterable {
        case midnight, graphite, ocean, forest, plum, ember, paper
    }

    struct Barcode: Codable, Sendable, Equatable {
        var message: String
        var format: BarcodeFormat
        var altText: String?
    }

    struct BoardingFields: Codable, Sendable, Equatable {
        var carrier: String
        var flightNumber: String
        var from: String
        var to: String
        /// YYYY-MM-DD
        var date: String
        /// HH:MM
        var boardingTime: String?
        var gate: String?
        var seat: String?
        var group: String?
        var passenger: String
    }

    struct EventFields: Codable, Sendable, Equatable {
        var title: String
        var venue: String?
        /// YYYY-MM-DD, or ISO 8601 date-time with offset.
        var date: String?
    }

    struct SimpleFields: Codable, Sendable, Equatable {
        var title: String
        var subtitle: String?
        var number: String?
    }

    enum Fields: Sendable, Equatable {
        case boardingPass(BoardingFields)
        case eventTicket(EventFields)
        case storeCard(SimpleFields)
        case generic(SimpleFields)

        var passType: PassType {
            switch self {
            case .boardingPass: .boardingPass
            case .eventTicket: .eventTicket
            case .storeCard: .storeCard
            case .generic: .generic
            }
        }
    }

    var fields: Fields
    var barcode: Barcode
    var color: Palette?
    /// ISO 8601 date-time with offset; makes the pass surface on the Lock Screen around that time.
    var relevantDate: String?

    var passType: PassType { fields.passType }

    init(fields: Fields, barcode: Barcode, color: Palette? = nil, relevantDate: String? = nil) {
        self.fields = fields
        self.barcode = barcode
        self.color = color
        self.relevantDate = relevantDate
    }

    private enum CodingKeys: String, CodingKey { case passType, barcode, color, relevantDate, fields }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        barcode = try c.decode(Barcode.self, forKey: .barcode)
        color = try c.decodeIfPresent(Palette.self, forKey: .color)
        relevantDate = try c.decodeIfPresent(String.self, forKey: .relevantDate)
        switch try c.decode(PassType.self, forKey: .passType) {
        case .boardingPass: fields = .boardingPass(try c.decode(BoardingFields.self, forKey: .fields))
        case .eventTicket: fields = .eventTicket(try c.decode(EventFields.self, forKey: .fields))
        case .storeCard: fields = .storeCard(try c.decode(SimpleFields.self, forKey: .fields))
        case .generic: fields = .generic(try c.decode(SimpleFields.self, forKey: .fields))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(passType, forKey: .passType)
        try c.encode(barcode, forKey: .barcode)
        try c.encodeIfPresent(color, forKey: .color)
        try c.encodeIfPresent(relevantDate, forKey: .relevantDate)
        switch fields {
        case .boardingPass(let f): try c.encode(f, forKey: .fields)
        case .eventTicket(let f): try c.encode(f, forKey: .fields)
        case .storeCard(let f), .generic(let f): try c.encode(f, forKey: .fields)
        }
    }

    /// Canonical bytes that get hashed into the App Attest assertion and sent verbatim.
    func encodedBody() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

// MARK: - Symbology → Wallet

nonisolated extension WalletPassRequest.BarcodeFormat {
    /// Wallet only renders QR, PDF417, Aztec and Code 128. Other 2-D codes are re-encoded as QR and
    /// every 1-D code (EAN/UPC, Code 39/93, ITF, Codabar, …) as Code 128 carrying the same message.
    init(symbology: Symbology) {
        switch symbology {
        case .qr, .microQR, .dataMatrix: self = .qr
        case .aztec: self = .aztec
        case .pdf417, .microPDF417: self = .pdf417
        case .code128, .ean13, .ean8, .upcA, .upcE, .code39, .code93, .itf14, .itf, .codabar, .gs1DataBar, .msi, .pharmacode:
            self = .code128
        }
    }
}

// MARK: - Builders from Lens models

nonisolated extension WalletPassRequest {
    enum BuildError: Error, Equatable {
        /// Code 128 can only carry printable ASCII (≤ 80 chars); the message can't be shown faithfully.
        case unrepresentableBarcode
        case missingField(String)
    }

    /// Wallet barcode for a scanned code, keeping the exact message.
    static func barcode(for code: ScannedCode, altText: String? = nil) throws(BuildError) -> Barcode {
        var format = BarcodeFormat(symbology: code.symbology)
        guard !code.raw.isEmpty, code.raw.utf16.count <= 2048 else { throw .unrepresentableBarcode }
        let message = code.raw
        if format == .code128 && !isCode128Safe(message) {
            // 1-D payloads are ASCII in practice; a non-ASCII/overlong one is shown as a QR rather than dropped.
            format = .qr
        }
        let alt = altText.map { clamp($0, 64) } ?? (format == .code128 ? clamp(message, 64) : nil)
        return Barcode(message: message, format: format, altText: alt?.isEmpty == true ? nil : alt)
    }

    /// Boarding pass from a parsed IATA BCBP. `referenceDate` resolves the pass's day-of-year to a real date.
    static func boardingPass(
        _ pass: BoardingPass,
        code: ScannedCode,
        color: Palette? = .midnight,
        referenceDate: Date = .now,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) throws(BuildError) -> WalletPassRequest {
        let from = pass.from.trimmingCharacters(in: .whitespaces).uppercased()
        let to = pass.to.trimmingCharacters(in: .whitespaces).uppercased()
        guard from.count == 3, from.allSatisfy(\.isASCIILetter) else { throw .missingField("from") }
        guard to.count == 3, to.allSatisfy(\.isASCIILetter) else { throw .missingField("to") }

        let carrier = clamp(pass.carrier.trimmingCharacters(in: .whitespaces), 32)
        guard !carrier.isEmpty else { throw .missingField("carrier") }

        var flight = pass.flightNumber.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        while flight.count > 1, flight.first == "0", flight.dropFirst().first?.isNumber == true { flight.removeFirst() }
        guard !flight.isEmpty, flight.count <= 8 else { throw .missingField("flightNumber") }

        let passenger = clamp(pass.passengerName, 64)
        guard !passenger.isEmpty else { throw .missingField("passenger") }

        var seat = pass.seat.trimmingCharacters(in: .whitespaces)
        while seat.count > 1, seat.first == "0" { seat.removeFirst() }

        let date = resolveDayOfYear(pass.dayOfYear, near: referenceDate, calendar: calendar)
        let fields = BoardingFields(
            carrier: carrier,
            flightNumber: flight,
            from: from,
            to: to,
            date: date,
            boardingTime: nil,
            gate: nil,
            seat: seat.isEmpty ? nil : clamp(seat, 6),
            group: nil,
            passenger: passenger
        )
        return WalletPassRequest(fields: .boardingPass(fields), barcode: try barcode(for: code), color: color)
    }

    /// Event ticket from a calendar payload (e.g. a scanned iCal/VEVENT ticket code).
    static func eventTicket(_ event: CalendarEvent, code: ScannedCode, color: Palette? = .plum) throws(BuildError) -> WalletPassRequest {
        let title = clamp(event.title, 64)
        guard !title.isEmpty else { throw .missingField("title") }
        let venue = clamp(event.location, 64)
        var dateString: String?
        var relevant: String?
        if let start = event.start {
            if event.isAllDay {
                dateString = isoDay(start)
            } else {
                let iso = isoDateTime(start)
                dateString = iso
                relevant = iso
            }
        }
        let fields = EventFields(title: title, venue: venue.isEmpty ? nil : venue, date: dateString)
        return WalletPassRequest(fields: .eventTicket(fields), barcode: try barcode(for: code), color: color, relevantDate: relevant)
    }

    /// Loyalty / membership card: typically a 1-D code on a card.
    static func storeCard(title: String, number: String? = nil, subtitle: String? = nil, code: ScannedCode, color: Palette? = .graphite) throws(BuildError) -> WalletPassRequest {
        let t = clamp(title, 64)
        guard !t.isEmpty else { throw .missingField("title") }
        let fields = SimpleFields(title: t, subtitle: subtitle.map { clamp($0, 64) }.nilIfEmpty, number: number.map { clamp($0, 40) }.nilIfEmpty)
        return WalletPassRequest(fields: .storeCard(fields), barcode: try barcode(for: code), color: color)
    }

    /// Any other code.
    static func generic(title: String, subtitle: String? = nil, code: ScannedCode, color: Palette? = .midnight) throws(BuildError) -> WalletPassRequest {
        let t = clamp(title, 64)
        guard !t.isEmpty else { throw .missingField("title") }
        let fields = SimpleFields(title: t, subtitle: subtitle.map { clamp($0, 64) }.nilIfEmpty, number: nil)
        return WalletPassRequest(fields: .generic(fields), barcode: try barcode(for: code), color: color)
    }

    // MARK: Helpers

    /// Trim, drop control / bidi-override / zero-width-space characters (the server rejects them; ZWJ is kept
    /// for emoji) and cap the length.
    static func clamp(_ s: String, _ max: Int) -> String {
        let banned: (Unicode.Scalar) -> Bool = { u in
            let v = u.value
            return v < 0x20 || (0x7F...0x9F).contains(v) || v == 0x200B
                || (0x202A...0x202E).contains(v) || (0x2066...0x2069).contains(v) || v == 0xFEFF
        }
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: s.unicodeScalars.filter { !banned($0) })
        let trimmed = String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
        // The server counts UTF-16 code units (JavaScript string length); never split a character.
        var out = ""
        var units = 0
        for ch in trimmed {
            units += ch.utf16.count
            if units > max { break }
            out.append(ch)
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    static func isCode128Safe(_ s: String) -> Bool {
        !s.isEmpty && s.count <= 80 && s.unicodeScalars.allSatisfy { (0x20...0x7E).contains($0.value) }
    }

    /// BCBP carries only the Julian day; pick the year that puts it closest to `reference`.
    static func resolveDayOfYear(_ day: Int, near reference: Date, calendar: Calendar) -> String {
        var cal = calendar
        cal.timeZone = TimeZone(identifier: "UTC")!
        let refYear = cal.component(.year, from: reference)
        let candidates: [Date] = [refYear - 1, refYear, refYear + 1].compactMap { year in
            guard let jan1 = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
                  let range = cal.range(of: .day, in: .year, for: jan1),
                  range.contains(day) else { return nil }
            return cal.date(byAdding: .day, value: day - 1, to: jan1)
        }
        let best = candidates.min { abs($0.timeIntervalSince(reference)) < abs($1.timeIntervalSince(reference)) } ?? reference
        let c = cal.dateComponents([.year, .month, .day], from: best)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    static func isoDay(_ date: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    static func isoDateTime(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = .current
        return f.string(from: date)
    }
}

extension WalletPassRequest {
    /// Picks the best pass style for a scanned code and its parsed payload.
    static func suggested(for code: ScannedCode, payload: Payload) throws(BuildError) -> WalletPassRequest {
        switch payload {
        case .travel(let bp):
            return try boardingPass(bp, code: code)
        case .event(let event):
            return try eventTicket(event, code: code)
        case .product(let gtin):
            return try storeCard(title: String(localized: "Card"), number: gtin, code: code)
        default:
            return try generic(title: code.symbology.displayName, subtitle: clamp(code.raw, 64), code: code)
        }
    }
}

nonisolated private extension Character {
    var isASCIILetter: Bool { isASCII && isLetter }
}

nonisolated private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        switch self {
        case .some(let s) where !s.isEmpty: s
        default: nil
        }
    }
}
