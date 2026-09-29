#if DEBUG
import Foundation
import SwiftData

/// Realistic History for previews only.
enum HistorySamples {
    static let container: ModelContainer = {
        let container = try! ModelContainer(
            for: ScanRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        records().forEach(container.mainContext.insert)
        return container
    }()

    static func records(now: Date = .now) -> [ScanRecord] {
        let calendar = Calendar.current
        func at(daysAgo: Int, _ hour: Int, _ minute: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        let menu = ScanRecord(raw: "https://atlas-coffee.co/menu", symbology: .qr, kind: .link,
                              title: "Menu — Atlas Coffee", subtitle: "atlas-coffee.co", createdAt: at(daysAgo: 0, 9, 41))
        menu.placeName = "Atlas Coffee, Roma Norte"
        menu.safetyRaw = SafetyVerdict.Level.safe.rawValue

        let pen = ScanRecord(raw: "4006381333931", symbology: .ean13, kind: .product,
                             title: "Fine-liner Pen, 0.4mm, Black", subtitle: "Norte Supply Co.", createdAt: at(daysAgo: 0, 8, 12))

        let wifi = ScanRecord(raw: "WIFI:T:WPA;S:Atlas Guest;P:cortado-2019;;", symbology: .qr, kind: .wifi,
                              title: "Atlas Guest", subtitle: "Wi-Fi · WPA2", createdAt: at(daysAgo: 1, 19, 3))
        wifi.isPinned = true

        let maya = ScanRecord(raw: "BEGIN:VCARD\nVERSION:3.0\nN:Chen;Maya\nEND:VCARD", symbology: .qr, kind: .contact,
                              title: "Maya Chen", subtitle: "Product Designer · Studio Norte", createdAt: at(daysAgo: 1, 11, 27))

        let locker = ScanRecord(raw: "Locker 214 — code 5591", symbology: .qr, kind: .text,
                                title: "Locker 214 — code 5591", createdAt: at(daysAgo: 3, 17, 20))

        let shipment = ScanRecord(raw: "SHIP-88213-XK", symbology: .code128, kind: .shipment,
                                  title: "SHIP-88213-XK", subtitle: "Shipment label", createdAt: at(daysAgo: 9, 14, 5))

        let flight = ScanRecord(raw: "M1CHEN/MAYA           EABC123 MEXSFONR 0412 275Y014A0025 100", symbology: .pdf417, kind: .travel,
                                title: "NR 412 · MEX → SFO", subtitle: "Norte Air · Seat 14A", createdAt: at(daysAgo: 11, 6, 50))

        flight.isPinned = true

        let home = ScanRecord(raw: "WIFI:T:WPA;S:Casa Chen;P:limonada-azul-27;;", symbology: .qr, kind: .wifi, origin: .created,
                              title: "Casa Chen", subtitle: "Home network · WPA2", createdAt: at(daysAgo: 14, 10, 0))
        var homeStyle = CodeStyle()
        homeStyle.dots = .rounded
        homeStyle.eyeFrame = .rounded
        homeStyle.eyePupil = .rounded
        homeStyle.foreground = RGBAColor(hex: 0x14532A)
        homeStyle.logo = .kindGlyph
        homeStyle.paletteID = nil
        home.styleData = homeStyle.encoded()

        let card = ScanRecord(
            raw: "BEGIN:VCARD\nVERSION:3.0\nN:Chen;Maya\nFN:Maya Chen\nORG:Studio Norte\nTEL:+52 55 1234 5678\nEMAIL:maya@studionorte.mx\nEND:VCARD",
            symbology: .qr, kind: .contact, origin: .created,
            title: "Maya Chen", subtitle: "My card · Studio Norte", createdAt: at(daysAgo: 20, 9, 0)
        )

        let parking = ScanRecord(raw: "https://bit.ly/3xQpark", symbology: .qr, kind: .link,
                                 title: "n0rthbank-login.co", subtitle: "Parking meter · looks like northbank",
                                 createdAt: at(daysAgo: 2, 18, 34))
        parking.safetyRaw = SafetyVerdict.Level.danger.rawValue

        let flyer = ScanRecord(raw: "https://tinyurl.com/yoga-roma", symbology: .qr, kind: .link,
                               title: "Sunrise Yoga — Parque México", subtitle: "tinyurl.com · redirects twice",
                               createdAt: at(daysAgo: 3, 8, 15))
        flyer.safetyRaw = SafetyVerdict.Level.caution.rawValue

        return [menu, pen, wifi, maya, parking, flyer, locker, shipment, flight, home, card]
    }
}
#endif
