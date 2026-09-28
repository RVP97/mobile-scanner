import CoreLocation
import MapKit

/// Turns a coordinate into a short, human place name: "Atlas Coffee, Roma Norte".
enum PlaceNamer {
    /// Points of interest farther than this from the scan aren't where the user was standing.
    static let pointOfInterestRadius: CLLocationDistance = 40

    struct Area: Equatable {
        /// Neighborhood when known, otherwise the city.
        var locality: String?
        /// Street-level name ("Orizaba 101").
        var street: String?
    }

    static func name(for location: CLLocation) async -> String? {
        async let poi = nearestPointOfInterest(to: location)
        async let area = area(for: location)
        return compose(pointOfInterest: await poi, area: await area)
    }

    /// Prefers the place you were at, then the street, qualified by the neighborhood.
    static func compose(pointOfInterest: String?, area: Area?) -> String? {
        let locality = area?.locality?.nonEmpty
        guard let lead = pointOfInterest?.nonEmpty ?? area?.street?.nonEmpty else { return locality }
        guard let locality, locality != lead else { return lead }
        return "\(lead), \(locality)"
    }

    // MARK: Lookups

    private static func nearestPointOfInterest(to location: CLLocation) async -> String? {
        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: pointOfInterestRadius)
        guard let items = try? await MKLocalSearch(request: request).start().mapItems else { return nil }
        return items
            .compactMap { item -> (name: String, distance: CLLocationDistance)? in
                guard let name = item.name, let itemLocation = coordinate(of: item) else { return nil }
                return (name, itemLocation.distance(from: location))
            }
            .filter { $0.distance <= pointOfInterestRadius }
            .min { $0.distance < $1.distance }?
            .name
    }

    private static func coordinate(of item: MKMapItem) -> CLLocation? {
        if #available(iOS 26.0, *) {
            item.location
        } else {
            item.placemark.location
        }
    }

    private static func area(for location: CLLocation) async -> Area? {
        if #available(iOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location),
                  let item = try? await request.mapItems.first
            else { return nil }
            let street = item.address?.shortAddress?.components(separatedBy: ",").first
            return Area(locality: item.addressRepresentations?.cityName, street: street ?? item.name)
        } else {
            guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
            let street = [placemark.thoroughfare, placemark.subThoroughfare].compactMap { $0 }.joined(separator: " ")
            return Area(locality: placemark.subLocality ?? placemark.locality, street: street.nonEmpty ?? placemark.name)
        }
    }
}

private extension String {
    /// `nil` for empty or whitespace-only strings.
    var nonEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
