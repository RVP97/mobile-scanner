import Foundation

/// IATA Resolution 792 Bar Coded Boarding Pass, format `M`: the mandatory fixed-width block of the first leg.
///
///     M1CHEN/MAYA           EABC123 MEXSFONR 0412 275Y014A0025 100
///     ^ ^                   ^^      ^  ^  ^  ^    ^  ^^   ^
///     | legs                | PNR   |  |  |  |    |  |seat sequence
///     format   name (20)    e-tkt  from to carrier flight day cabin
enum BoardingPassParser {
    static let minimumLength = 58

    static func parse(_ raw: String) -> BoardingPass? {
        let characters = Array(raw)
        guard characters.count >= minimumLength,
              characters[0] == "M",
              characters[1].isASCIIDigit
        else { return nil }

        func field(_ start: Int, _ length: Int) -> String {
            String(characters[start..<(start + length)]).trimmed
        }

        let from = field(30, 3)
        let to = field(33, 3)
        let carrier = field(36, 3)
        let dayText = field(44, 3)
        guard isAirportCode(from), isAirportCode(to),
              !carrier.isEmpty, carrier.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }),
              let day = Int(dayText), (1...366).contains(day)
        else { return nil }

        return BoardingPass(
            passengerName: field(2, 20),
            bookingReference: field(23, 7),
            from: from,
            to: to,
            carrier: carrier,
            flightNumber: stripLeadingZeros(field(39, 5)),
            dayOfYear: day,
            cabin: field(47, 1),
            seat: stripLeadingZeros(field(48, 4)),
            sequence: stripLeadingZeros(field(52, 5))
        )
    }

    private static func isAirportCode(_ code: String) -> Bool {
        code.count == 3 && code.allSatisfy { $0.isASCII && $0.isLetter }
    }

    /// "0412" → "412", "014A" → "14A", "0000" → "0".
    private static func stripLeadingZeros(_ value: String) -> String {
        let stripped = value.drop { $0 == "0" }
        return stripped.isEmpty && !value.isEmpty ? "0" : String(stripped)
    }
}

extension BoardingPass {
    /// The pass only carries a day of year; pick the year that puts it closest to `reference`.
    func date(near reference: Date = .now, calendar: Calendar = .current) -> Date? {
        let year = calendar.component(.year, from: reference)
        let candidates = (year - 1...year + 1).compactMap { year -> Date? in
            guard let january1 = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
                  let date = calendar.date(byAdding: .day, value: dayOfYear - 1, to: january1),
                  calendar.component(.year, from: date) == year
            else { return nil }
            return date
        }
        return candidates.min { abs($0.timeIntervalSince(reference)) < abs($1.timeIntervalSince(reference)) }
    }

    /// "CHEN/MAYA MS" → "Maya Chen".
    var displayName: String {
        let parts = passengerName.split(separator: "/", maxSplits: 1).map { String($0).trimmed }
        guard parts.count == 2 else { return passengerName.capitalized }
        var given = parts[1]
        for title in [" MR", " MRS", " MS", " MISS", " MSTR", " DR"] where given.hasSuffix(title) {
            given = String(given.dropLast(title.count))
        }
        return "\(given.capitalized) \(parts[0].capitalized)".trimmed
    }

    /// "NR 412".
    var flightDesignator: String { "\(carrier) \(flightNumber)" }

    var cabinName: String {
        switch cabin.uppercased() {
        case "F", "A", "P": String(localized: "First")
        case "J", "C", "D", "I", "Z", "R": String(localized: "Business")
        case "W", "E": String(localized: "Premium Economy")
        case "": ""
        default: String(localized: "Economy")
        }
    }

    var airlineName: String? { TravelDirectory.airlines[carrier.uppercased()] }
}
