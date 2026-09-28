import MapKit
import SwiftUI

/// `geo:` — a map snippet with a pin, the coordinates, and "Open in Maps".
struct LocationResultView: View {
    var point: GeoPoint
    var result: ScanResult
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if point.hasCoordinates {
                Map(initialPosition: .region(region), interactionModes: []) {
                    Marker(point.label.isEmpty ? String(localized: "Location") : point.label,
                           systemImage: "mappin", coordinate: coordinate)
                        .tint(CodeKind.location.tint)
                }
                .frame(height: 180)
                .clipShape(.rect(cornerRadius: 20, style: .continuous))
                .accessibilityLabel(Text("Map of \(point.label.isEmpty ? point.coordinateText : point.label)"))

                // Without a label the coordinates are already the header.
                if !point.label.isEmpty {
                    ResultCard {
                        DetailRow(label: "Coordinates", value: point.coordinateText, monospaced: true)
                    }
                }
            }

            ResultPrimaryButton(title: "Open in Maps", symbol: "map.fill", tint: CodeKind.location.tint) {
                if let mapsURL { openURL(mapsURL) }
            }

            ResultActionRow(result: result, copyText: point.hasCoordinates ? "\(point.latitude), \(point.longitude)" : point.label)
        }
    }

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
    }

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(center: coordinate, latitudinalMeters: 800, longitudinalMeters: 800)
    }

    private var mapsURL: URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        var items: [URLQueryItem] = []
        if point.hasCoordinates { items.append(URLQueryItem(name: "ll", value: "\(point.latitude),\(point.longitude)")) }
        if !point.label.isEmpty { items.append(URLQueryItem(name: "q", value: point.label)) }
        components?.queryItems = items
        return components?.url
    }
}

#if DEBUG
#Preview { ResultPreview(.sampleLocation) }
#endif
