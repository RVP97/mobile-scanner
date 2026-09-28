import Foundation
import Testing
@testable import Lens

@Suite("Result · action helpers")
struct ResultActionHelpersTests {
    // MARK: Product lookup parsing

    @Test func parsesOpenFoodFactsProduct() throws {
        let json = Data("""
        {"code":"4006381333931","status":1,"status_verbose":"product found","product":{
          "product_name":"Fine-liner Pen, 0.4mm, Black","brands":"Norte Supply Co.,Norte",
          "image_front_url":"https://images.example.org/front.jpg","quantity":"1 pc",
          "categories":"Office supplies, Writing instruments, Pens, en:fineliners"}}
        """.utf8)
        let info = try #require(ProductLookup.parse(json, source: "Open Products Facts"))
        #expect(info.name == "Fine-liner Pen, 0.4mm, Black")
        #expect(info.brand == "Norte Supply Co.")
        #expect(info.quantity == "1 pc")
        #expect(info.imageURL?.host() == "images.example.org")
        #expect(info.categories == ["Writing instruments", "Pens"])
        #expect(info.source == "Open Products Facts")
    }

    @Test func productNotFound() {
        let json = Data(#"{"code":"0000000000000","status":0,"status_verbose":"product not found"}"#.utf8)
        #expect(ProductLookup.parse(json, source: "Open Food Facts") == nil)
    }

    @Test func productWithOnlyBrandUsesBrandAsName() throws {
        let json = Data(#"{"status":1,"product":{"brands":"Atlas Coffee"}}"#.utf8)
        let info = try #require(ProductLookup.parse(json, source: "Open Food Facts"))
        #expect(info.name == "Atlas Coffee")
        #expect(info.brand.isEmpty)
    }

    @Test func emptyProductIsNotAMatch() {
        #expect(ProductLookup.parse(Data(#"{"status":1,"product":{"product_name":""}}"#.utf8), source: "x") == nil)
    }

    // MARK: Contact links

    @Test func telKeepsDialableCharacters() {
        #expect(ContactLinks.tel("+52 (55) 1234-5678")?.absoluteString == "tel:+525512345678")
        #expect(ContactLinks.tel("ext") == nil)
    }

    @Test func smsWithBody() {
        #expect(ContactLinks.sms("+1 555 0100", body: "Table 4 & 5?")?.absoluteString == "sms:+15550100&body=Table%204%20%26%205%3F")
        #expect(ContactLinks.sms("+1 555 0100")?.absoluteString == "sms:+15550100")
    }

    @Test func mailWithSubject() {
        let url = ContactLinks.mail("maya@studionorte.mx", subject: "Hola Maya")
        #expect(url?.absoluteString == "mailto:maya@studionorte.mx?subject=Hola%20Maya")
    }

    // MARK: Calendar drafts

    @Test func timedEventDraft() throws {
        let start = Date(timeIntervalSince1970: 1_790_874_000)
        let draft = try #require(CalendarDraft(CalendarEvent(title: "Cupping", start: start, end: nil, location: "Atlas")))
        #expect(draft.end == start.addingTimeInterval(3600))
        #expect(!draft.isAllDay)
        #expect(draft.location == "Atlas")
    }

    @Test func allDayDraftEndsOnLastDay() throws {
        let start = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 3)))
        let end = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 5)))
        let draft = try #require(CalendarDraft(CalendarEvent(title: "Fair", start: start, end: end, isAllDay: true)))
        #expect(Calendar.current.dateComponents([.day], from: draft.end).day == 4)
    }

    @Test func eventWithoutStartHasNoDraft() {
        #expect(CalendarDraft(CalendarEvent(title: "Someday")) == nil)
    }

    // MARK: Misc

    @Test func webSearchEncodesQuery() {
        #expect(WebSearch.url(for: "NR 412 flight status")?.absoluteString == "https://www.google.com/search?q=NR%20412%20flight%20status")
    }

    @Test func retailSymbologyForGTIN() {
        #expect(Symbology.retail(forGTIN: "96385074") == .ean8)
        #expect(Symbology.retail(forGTIN: "036000291452") == .upcA)
        #expect(Symbology.retail(forGTIN: "4006381333931") == .ean13)
    }

    @Test func walletIsNotOfferedUntilSigningExists() {
        #expect(!WalletPassService.isAvailable)
    }
}
