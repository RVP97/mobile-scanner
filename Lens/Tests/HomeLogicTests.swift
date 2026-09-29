import Foundation
import Testing
@testable import Lens

struct HomeCodeShelfTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return calendar
    }()

    func date(_ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: m, day: d, hour: h))!
    }

    /// Monday 28 Sep 2026.
    var now: Date { date(9, 28, 9) }

    @Test func newestFirstWithoutTrips() {
        let entries = [
            CodeShelf.Entry(raw: "a", createdAt: date(9, 1)),
            CodeShelf.Entry(raw: "b", createdAt: date(9, 20)),
            CodeShelf.Entry(raw: "c", createdAt: date(9, 10)),
        ]
        #expect(CodeShelf.order(entries, now: now, calendar: calendar) == [1, 2, 0])
    }

    @Test func upcomingTripRisesToTheFront() {
        let entries = [
            CodeShelf.Entry(raw: "wifi", createdAt: date(9, 27)),
            CodeShelf.Entry(raw: "later", createdAt: date(8, 1), tripDate: date(10, 4)),
            CodeShelf.Entry(raw: "soon", createdAt: date(7, 1), tripDate: date(9, 30)),
        ]
        #expect(CodeShelf.order(entries, now: now, calendar: calendar) == [2, 1, 0])
    }

    @Test func pastAndFarTripsKeepTheirPlace() {
        let entries = [
            CodeShelf.Entry(raw: "past", createdAt: date(9, 1), tripDate: date(9, 2)),
            CodeShelf.Entry(raw: "far", createdAt: date(9, 5), tripDate: date(12, 20)),
            CodeShelf.Entry(raw: "today", createdAt: date(6, 1), tripDate: date(9, 28, 6)),
        ]
        #expect(CodeShelf.order(entries, now: now, calendar: calendar) == [2, 1, 0])
    }

    @Test func sameContentShowsOnce() {
        let entries = [
            CodeShelf.Entry(raw: "WIFI:S:Casa;;", createdAt: date(9, 1)),
            CodeShelf.Entry(raw: "WIFI:S:Casa;;", createdAt: date(9, 20)),
        ]
        #expect(CodeShelf.order(entries, now: now, calendar: calendar) == [1])
    }

    @MainActor @Test func savedBoardingPassHasItsFlightDay() {
        let record = ScanRecord(
            raw: "M1CHEN/MAYA           EABC123 MEXSFONR 0412 275Y014A0025 100",
            symbology: .pdf417, kind: .travel, title: "NR 412"
        )
        let day = record.tripDate(near: now, calendar: calendar).map { calendar.dateComponents([.month, .day], from: $0) }
        #expect(day?.month == 10 && day?.day == 2)
    }
}

struct HomeIdleClockTests {
    @Test func expiresAfterTheTimeout() {
        let clock = ScannerIdleClock(now: 100)
        #expect(!clock.isExpired(at: 129.9))
        #expect(clock.isExpired(at: 130))
        #expect(clock.remaining(at: 110) == 20)
    }

    @Test func warnsDuringTheLastSeconds() {
        let clock = ScannerIdleClock(now: 0)
        #expect(!clock.isWarning(at: 24.9))
        #expect(clock.isWarning(at: 25.5))
        #expect(clock.warningProgress(at: 27.5) == 0.5)
        #expect(!clock.isWarning(at: 30))
    }

    @Test func activityStartsTheWaitOver() {
        var clock = ScannerIdleClock(now: 0)
        clock.reset(at: 28)
        #expect(clock.remaining(at: 28) == 30)
        #expect(!clock.isWarning(at: 30))
    }

    @Test func pausedTimeDoesNotCount() {
        var clock = ScannerIdleClock(now: 0)
        clock.pause(at: 10)
        #expect(clock.remaining(at: 500) == 20)
        clock.resume(at: 500)
        #expect(clock.remaining(at: 505) == 15)
        #expect(clock.isExpired(at: 520))
    }
}

@MainActor
struct HomeRoutingTests {
    @Test func scanLinkOpensTheCamera() throws {
        let model = AppModel()
        model.handle(url: try #require(URL(string: "lunet://scan")))
        #expect(model.isScannerPresented)
        #expect(!model.isMultiScanActive)
    }

    @Test(arguments: ["lunet", "ojito", "lens", "scanner"])
    func everySchemeOpensTheCamera(_ scheme: String) throws {
        let model = AppModel()
        model.handle(url: try #require(URL(string: "\(scheme)://scan?mode=multi")))
        #expect(model.isScannerPresented)
        #expect(model.isMultiScanActive)
    }

    @Test func historyLinkPushesHistory() {
        let model = AppModel()
        model.handle(url: LensDeepLink.history.url)
        #expect(model.path == [.history])
        #expect(!model.isScannerPresented)
    }

    @Test func createWaitsForTheScannerToClose() {
        let model = AppModel()
        model.openScanner(multi: false)
        model.handle(url: LensDeepLink.create.url)
        #expect(model.isScannerClosing)
        #expect(model.modal == nil)
        model.scannerDidClose()
        #expect(!model.isScannerPresented)
    }

    @Test func closingTheResultClosesTheCamera() {
        let model = AppModel()
        model.openScanner(multi: false)
        model.show(.sampleText)
        model.dismissResult()
        #expect(model.sheet == nil)
        #expect(model.isScannerClosing)
    }

    @Test func scanAnotherKeepsTheCamera() {
        let model = AppModel()
        model.openScanner(multi: false)
        model.show(.sampleText)
        model.scanAnother()
        #expect(model.sheet == nil)
        #expect(model.isScannerPresented && !model.isScannerClosing)
    }

    @Test func resultOverHomeJustCloses() {
        let model = AppModel()
        model.show(.sampleText)
        model.dismissResult()
        #expect(model.sheet == nil)
        #expect(!model.isScannerPresented)
    }
}
