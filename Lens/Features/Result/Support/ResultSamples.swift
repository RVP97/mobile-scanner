#if DEBUG
import SwiftUI

/// Fictional sample scans for previews (Atlas Coffee, Studio Norte, Norte Air…).
extension ScanResult {
    static func sample(_ raw: String, _ symbology: Symbology = .qr, place: String? = nil) -> ScanResult {
        ScanResult(
            code: ScannedCode(raw: raw, symbology: symbology),
            payload: PayloadParser.parse(raw, symbology: symbology),
            placeName: place
        )
    }

    static let sampleLink = sample("https://atlas-coffee.co/menu", place: "Atlas Coffee, Roma Norte")
    /// Userinfo trick: reads as atlas-coffee.co, opens n0rthbank-login.co. Flagged offline.
    static let sampleDanger = sample("https://atlas-coffee.co@n0rthbank-login.co/pay")
    static let sampleWiFi = sample("WIFI:T:WPA;S:Atlas Guest;P:cortado-2019;;")
    static let sampleProduct = sample("4006381333931", .ean13)
    static let sampleTravel = sample(
        "M1CHEN/MAYA           EABC123 MEXSFONR 0412 275Y014A0025 100", .pdf417
    )
    static let sampleContact = sample("""
        BEGIN:VCARD
        VERSION:3.0
        N:Chen;Maya;;;
        ORG:Studio Norte
        TITLE:Product Designer
        TEL;TYPE=CELL:+52 55 1234 5678
        EMAIL:maya@studionorte.mx
        URL:https://studionorte.mx
        END:VCARD
        """)
    static let sampleEvent = sample("""
        BEGIN:VEVENT
        SUMMARY:Cupping at Atlas
        DTSTART:20261001T170000Z
        DTEND:20261001T183000Z
        LOCATION:Atlas Coffee, Roma Norte
        DESCRIPTION:Three single origins from Oaxaca.
        END:VEVENT
        """)
    static let sampleLocation = sample("geo:19.4194,-99.1621?q=Atlas Coffee")
    static let sampleCrypto = sample("bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.002&label=Atlas%20Coffee")
    static let sampleShipment = sample("1Z999AA10123456784", .code128)
    static let sampleText = sample("Locker 214 — code 5591")
}

/// A result inside a sheet over a dark backdrop, the way it appears over the camera.
struct ResultPreview: View {
    var result: ScanResult
    init(_ result: ScanResult) { self.result = result }

    var body: some View {
        Color.black.ignoresSafeArea()
            .sheet(isPresented: .constant(true)) {
                ResultView(result: result)
                    .presentationDetents([AppModel.resultDetent, .large])
                    .presentationDragIndicator(.visible)
            }
            .environment(AppModel())
    }
}
#endif
