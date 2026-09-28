import Foundation

/// The first `VEVENT` of an iCalendar object (with or without the `VCALENDAR` wrapper).
enum EventParser {
    static func parse(_ raw: String) -> CalendarEvent? {
        let lines = ContentLines.parse(raw)
        guard let begin = lines.firstIndex(where: { $0.name == "BEGIN" && $0.raw.trimmed.uppercased() == "VEVENT" }) else {
            return nil
        }
        var event = CalendarEvent(title: "")
        for line in lines[(begin + 1)...] {
            if line.name == "END", line.raw.trimmed.uppercased() == "VEVENT" { break }
            switch line.name {
            case "SUMMARY": event.title = line.text.trimmed
            case "LOCATION": event.location = line.text.trimmed
            case "DESCRIPTION": event.notes = line.text.trimmed
            case "DTSTART":
                if let parsed = date(line) {
                    event.start = parsed.date
                    event.isAllDay = parsed.isAllDay
                }
            case "DTEND":
                event.end = date(line)?.date
            default: break
            }
        }
        return event
    }

    /// `20261001` (all-day), `20261001T073500` (floating, local), `…Z` (UTC) or with `TZID=`.
    static func date(_ line: ContentLine) -> (date: Date, isAllDay: Bool)? {
        let value = line.raw.trimmed
        let digits = value.filter(\.isASCIIDigit)
        guard digits.count >= 8,
              let year = Int(digits.prefix(4)),
              let month = Int(digits.dropFirst(4).prefix(2)),
              let day = Int(digits.dropFirst(6).prefix(2))
        else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        let isAllDay = line.params["VALUE"]?.uppercased() == "DATE" || !value.uppercased().contains("T")
        if value.uppercased().hasSuffix("Z") {
            calendar.timeZone = .gmt
        } else if let tzid = line.params["TZID"], let zone = TimeZone(identifier: tzid) {
            calendar.timeZone = zone
        } else {
            calendar.timeZone = .current
        }

        var components = DateComponents(year: year, month: month, day: day)
        if !isAllDay, digits.count >= 12 {
            components.hour = Int(digits.dropFirst(8).prefix(2))
            components.minute = Int(digits.dropFirst(10).prefix(2))
            components.second = digits.count >= 14 ? Int(digits.dropFirst(12).prefix(2)) : 0
        }
        guard let date = calendar.date(from: components) else { return nil }
        return (date, isAllDay)
    }
}
