import Foundation

/// The day groups History is sectioned into. "This Week" is a rolling window (2–6 days ago)
/// so it's never empty just because today is Monday.
enum HistoryBucket: CaseIterable, Hashable {
    case today, yesterday, thisWeek, earlier

    var title: LocalizedStringResource {
        switch self {
        case .today: "Today"
        case .yesterday: "Yesterday"
        case .thisWeek: "This Week"
        case .earlier: "Earlier"
        }
    }

    /// Half-open range of `createdAt` values that fall in this bucket. Today is open-ended so a
    /// record stamped slightly in the future (clock changes) still shows up first.
    func range(now: Date, calendar: Calendar = .current) -> Range<Date> {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? yesterday
        switch self {
        case .today: return today..<Date.distantFuture
        case .yesterday: return yesterday..<today
        case .thisWeek: return weekStart..<yesterday
        case .earlier: return Date.distantPast..<weekStart
        }
    }

    static func bucket(for date: Date, now: Date, calendar: Calendar = .current) -> HistoryBucket {
        allCases.first { $0.range(now: now, calendar: calendar).contains(date) } ?? .earlier
    }

    /// Compact trailing stamp for a row: "9:41" today and yesterday, "Mon" this week, "Sep 21" earlier
    /// ("Sep 21, 2024" in another year).
    static func stamp(for date: Date, now: Date = .now, calendar: Calendar = .current, locale: Locale = .current) -> String {
        switch bucket(for: date, now: now, calendar: calendar) {
        case .today, .yesterday:
            return date.formatted(Date.FormatStyle(locale: locale, calendar: calendar).hour().minute())
        case .thisWeek:
            return date.formatted(Date.FormatStyle(locale: locale, calendar: calendar).weekday(.abbreviated))
        case .earlier:
            let sameYear = calendar.isDate(date, equalTo: now, toGranularity: .year)
            let style = Date.FormatStyle(locale: locale, calendar: calendar).month(.abbreviated).day()
            return date.formatted(sameYear ? style : style.year())
        }
    }
}
