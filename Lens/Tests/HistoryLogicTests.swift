import Foundation
import SwiftData
import Testing
@testable import Lens

struct HistoryBucketTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return calendar
    }()

    /// Wednesday 30 Sep 2026, 9:41.
    var now: Date { date(2026, 9, 30, 9, 41) }

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test func sectionsByDay() {
        #expect(HistoryBucket.bucket(for: date(2026, 9, 30, 0, 1), now: now, calendar: calendar) == .today)
        #expect(HistoryBucket.bucket(for: date(2026, 9, 29, 23, 59), now: now, calendar: calendar) == .yesterday)
        #expect(HistoryBucket.bucket(for: date(2026, 9, 29, 0, 0), now: now, calendar: calendar) == .yesterday)
        #expect(HistoryBucket.bucket(for: date(2026, 9, 28), now: now, calendar: calendar) == .thisWeek)
        #expect(HistoryBucket.bucket(for: date(2026, 9, 24, 0, 0), now: now, calendar: calendar) == .thisWeek)
        #expect(HistoryBucket.bucket(for: date(2026, 9, 23, 23, 59), now: now, calendar: calendar) == .earlier)
        #expect(HistoryBucket.bucket(for: date(2019, 1, 1), now: now, calendar: calendar) == .earlier)
    }

    @Test func futureDatesCountAsToday() {
        #expect(HistoryBucket.bucket(for: date(2026, 10, 2), now: now, calendar: calendar) == .today)
    }

    @Test func bucketsTileTimeWithoutGaps() {
        let ranges = HistoryBucket.allCases.map { $0.range(now: now, calendar: calendar) }
        for (newer, older) in zip(ranges, ranges.dropFirst()) {
            #expect(older.upperBound == newer.lowerBound)
        }
    }

    @Test func stamps() {
        let locale = Locale(identifier: "en_US")
        #expect(HistoryBucket.stamp(for: date(2026, 9, 28), now: now, calendar: calendar, locale: locale) == "Mon")
        #expect(HistoryBucket.stamp(for: date(2026, 9, 21), now: now, calendar: calendar, locale: locale) == "Sep 21")
        #expect(HistoryBucket.stamp(for: date(2025, 9, 21), now: now, calendar: calendar, locale: locale) == "Sep 21, 2025")
    }
}

struct HistoryCSVTests {
    @Test func plainFieldsStayBare() {
        #expect(HistoryCSV.escape("atlas-coffee.co") == "atlas-coffee.co")
    }

    @Test func delimitersQuotesAndNewlinesAreQuoted() {
        #expect(HistoryCSV.escape("Menu, Atlas") == "\"Menu, Atlas\"")
        #expect(HistoryCSV.escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(HistoryCSV.escape("BEGIN:VCARD\nEND:VCARD") == "\"BEGIN:VCARD\nEND:VCARD\"")
    }

    @Test func formulasAreDefused() {
        #expect(HistoryCSV.escape("=HYPERLINK(\"x\")") == "\"'=HYPERLINK(\"\"x\"\")\"")
        #expect(HistoryCSV.escape("+52 55 1234 5678") == "+52 55 1234 5678")
    }

    @Test func documentHasHeaderAndCRLFRows() {
        let row = HistoryCSV.Row(date: Date(timeIntervalSince1970: 0), kind: "Link", format: "QR Code",
                                 content: "https://atlas-coffee.co/menu", title: "Menu — Atlas Coffee",
                                 place: "Atlas Coffee, Roma Norte")
        let lines = HistoryCSV.document([row]).components(separatedBy: "\r\n")
        #expect(lines[0] == "Date,Kind,Format,Content,Title,Place")
        #expect(lines[1].hasSuffix(",Link,QR Code,https://atlas-coffee.co/menu,Menu — Atlas Coffee,\"Atlas Coffee, Roma Norte\""))
        #expect(lines.count == 3 && lines[2].isEmpty)
    }
}

struct HistoryReviewPrompterTests {
    @Test func promptsOncePerMilestone() {
        #expect(ReviewPrompter.milestone(scans: 4, lastPrompted: 0) == nil)
        #expect(ReviewPrompter.milestone(scans: 5, lastPrompted: 0) == 5)
        #expect(ReviewPrompter.milestone(scans: 12, lastPrompted: 5) == nil)
        #expect(ReviewPrompter.milestone(scans: 31, lastPrompted: 5) == 30)
        #expect(ReviewPrompter.milestone(scans: 400, lastPrompted: 0) == 150)
        #expect(ReviewPrompter.milestone(scans: 400, lastPrompted: 150) == nil)
    }
}

struct HistoryPlaceNamerTests {
    @Test func composesPlaceNames() {
        let area = PlaceNamer.Area(locality: "Roma Norte", street: "Orizaba 101")
        #expect(PlaceNamer.compose(pointOfInterest: "Atlas Coffee", area: area) == "Atlas Coffee, Roma Norte")
        #expect(PlaceNamer.compose(pointOfInterest: nil, area: area) == "Orizaba 101, Roma Norte")
        #expect(PlaceNamer.compose(pointOfInterest: nil, area: PlaceNamer.Area(locality: "Roma Norte")) == "Roma Norte")
        #expect(PlaceNamer.compose(pointOfInterest: "Atlas Coffee", area: nil) == "Atlas Coffee")
        #expect(PlaceNamer.compose(pointOfInterest: nil, area: nil) == nil)
    }
}

struct HistoryRecordWriterTests {
    let container = try! ModelContainer(for: ScanRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let defaults: UserDefaults = {
        let defaults = UserDefaults(suiteName: "HistoryRecordWriterTests-\(UUID())")!
        defaults.set(true, forKey: Pref.saveHistory)
        return defaults
    }()

    func result(_ raw: String, at date: Date) -> ScanResult {
        ScanResult(code: ScannedCode(raw: raw, symbology: .qr), payload: .text(raw), scannedAt: date)
    }

    func count() throws -> Int { try container.mainContext.fetchCount(FetchDescriptor<ScanRecord>()) }

    @Test func sameCodeWithinTenSecondsRefreshesTimestamp() throws {
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 1_000_000)
        let first = RecordWriter.save(result("Locker 214", at: start), origin: .scanned, style: nil, in: context, defaults: defaults)
        let again = RecordWriter.save(result("Locker 214", at: start.addingTimeInterval(6)), origin: .scanned, style: nil, in: context, defaults: defaults)
        #expect(first === again)
        #expect(again?.createdAt == start.addingTimeInterval(6))
        #expect(try count() == 1)
        #expect(defaults.integer(forKey: Pref.successfulScans) == 2)
    }

    @Test func sameCodeLaterOrDifferentCodeAddsRow() throws {
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 1_000_000)
        RecordWriter.save(result("A", at: start), origin: .scanned, style: nil, in: context, defaults: defaults)
        RecordWriter.save(result("A", at: start.addingTimeInterval(11)), origin: .scanned, style: nil, in: context, defaults: defaults)
        RecordWriter.save(result("B", at: start.addingTimeInterval(12)), origin: .scanned, style: nil, in: context, defaults: defaults)
        #expect(try count() == 3)
    }

    @Test func historyOffSkipsScansButKeepsCreatedCodes() throws {
        let context = container.mainContext
        defaults.set(false, forKey: Pref.saveHistory)
        let scanned = RecordWriter.save(result("A", at: .now), origin: .scanned, style: nil, in: context, defaults: defaults)
        let created = RecordWriter.save(result("B", at: .now), origin: .created, style: nil, in: context, defaults: defaults)
        #expect(scanned == nil)
        #expect(created != nil)
        #expect(defaults.integer(forKey: Pref.successfulScans) == 1)
    }
}
