import Foundation
import Testing
@testable import Lens

@Suite("Localization · locale-aware names")
struct LocalizationTests {
    @Test func gs1CountriesUseTheReadersLanguage() {
        #expect(GS1Prefixes.region(for: 300, locale: Locale(identifier: "en")) == "France")
        #expect(GS1Prefixes.region(for: 300, locale: Locale(identifier: "es")) == "Francia")
        #expect(GS1Prefixes.region(for: 400, locale: Locale(identifier: "fr")) == "Allemagne")
        #expect(GS1Prefixes.region(for: 750, locale: Locale(identifier: "es_MX")) == "México")
    }

    @Test func gs1LabelsAndGaps() {
        #expect(GS1Prefixes.region(for: 978) == "Book (ISBN)")
        #expect(GS1Prefixes.region(for: 489) == "Hong Kong")
        #expect(GS1Prefixes.region(for: 140) == nil)
    }

    @Test func coordinatesKeepCompassLetters() {
        let point = GeoPoint(latitude: 19.4326, longitude: -99.1332)
        #expect(point.coordinateText.hasSuffix("° W"))
        #expect(point.coordinateText.contains("° N"))
    }

    @Test func airportCitiesStayResolvable() {
        #expect(TravelDirectory.city(for: "mex") == "Mexico City")
        #expect(TravelDirectory.city(for: "ZZZ") == nil)
    }
}
