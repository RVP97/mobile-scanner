import Foundation

/// Parcel tracking numbers and where to track them.
enum ShipmentCarrier: String, CaseIterable {
    case ups, fedex, usps, dhl, postal

    var name: String {
        switch self {
        case .ups: "UPS"
        case .fedex: "FedEx"
        case .usps: "USPS"
        case .dhl: "DHL"
        case .postal: String(localized: "Postal service")
        }
    }

    func trackingURL(for number: String) -> URL? {
        let encoded = number.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? number
        return switch self {
        case .ups: URL(string: "https://www.ups.com/track?tracknum=\(encoded)")
        case .fedex: URL(string: "https://www.fedex.com/fedextrack/?trknbr=\(encoded)")
        case .usps: URL(string: "https://tools.usps.com/go/TrackConfirmAction?tLabels=\(encoded)")
        case .dhl: URL(string: "https://www.dhl.com/global-en/home/tracking/tracking-express.html?submit=1&tracking-id=\(encoded)")
        case .postal: number.hasSuffix("US") ? ShipmentCarrier.usps.trackingURL(for: number) : WebSearch.url(for: "track \(number)")
        }
    }

    /// Identifies a tracking number and returns it cleaned up (spaces removed, IMpb routing prefix dropped).
    /// Bare digit runs are only trusted from linear barcodes, where they can't be a phone number or a PIN.
    static func detect(_ raw: String, symbology: Symbology) -> (carrier: ShipmentCarrier, number: String)? {
        let compact = raw.filter { !$0.isWhitespace }.uppercased()

        if compact.wholeMatch(of: /1Z[0-9A-Z]{16}/) != nil { return (.ups, compact) }
        if compact.wholeMatch(of: /JJD\d{16,20}|JVGL\d{12,20}|GM\d{16,20}/) != nil { return (.dhl, compact) }
        if compact.wholeMatch(of: /[A-Z]{2}\d{9}[A-Z]{2}/) != nil { return (.postal, compact) } // UPU S10

        guard compact.isAllDigits else { return nil }
        let isLinear = !symbology.isTwoDimensional

        // USPS Intelligent Mail package barcode: "420" + ZIP (5 or 9) + 22-digit tracking number.
        if compact.hasPrefix("420"), [30, 34].contains(compact.count) {
            let tracking = String(compact.suffix(22))
            if tracking.first == "9" { return (.usps, tracking) }
        }
        switch compact.count {
        case 22 where compact.hasPrefix("96"): return (.fedex, compact)
        case 20...22 where compact.hasPrefix("9"): return (.usps, compact)
        case 20...22 where isLinear: return (.usps, compact)
        case 12 where isLinear, 15 where isLinear: return (.fedex, compact)
        case 10 where isLinear: return (.dhl, compact)
        default: return nil
        }
    }
}
