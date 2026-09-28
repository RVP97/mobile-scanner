import CoreLocation
import MapKit
import SwiftUI

/// Move the map under the pin, or jump to where you are.
struct LocationFields: View {
    @Bindable var draft: CreateDraft
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var locator = CurrentLocation()
    @State private var locating = false
    @State private var locationDenied = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            Map(position: $position) {
                UserAnnotation()
            }
            .mapStyle(.standard(pointsOfInterest: .including([.cafe, .restaurant, .park, .museum, .store])))
            .overlay {
                Image(systemName: "mappin")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Palette.tint(for: .location))
                    .offset(y: -17)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                let center = context.region.center
                draft.location = GeoPoint(latitude: center.latitude, longitude: center.longitude)
            }
            .frame(height: 280)
            .listRowInsets(EdgeInsets())
            .accessibilityLabel(Text("Map. Move it so the pin sits on the place to share."))

            Button {
                Task { await useCurrentLocation() }
            } label: {
                HStack {
                    Label("Use Current Location", systemImage: "location.fill")
                    Spacer()
                    if locating { ProgressView() }
                }
            }
            .disabled(locating)

            if locationDenied {
                HStack(alignment: .firstTextBaseline) {
                    Text("Location access is off for Ojito.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.borderless)
                }
            }
        } footer: {
            if let point = draft.location {
                Text(verbatim: String(format: "%.5f, %.5f", point.latitude, point.longitude))
                    .monospacedDigit()
            }
        }

        Section {
            TextField("Name (optional)", text: $draft.locationLabel)
        } footer: {
            Text("Scanning opens this spot in Maps.")
        }
    }

    private func useCurrentLocation() async {
        locating = true
        defer { locating = false }
        switch await locator.request() {
        case .success(let location):
            locationDenied = false
            withAnimation(.smooth) {
                position = .region(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 400, longitudinalMeters: 400))
            }
            draft.location = GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        case .denied:
            locationDenied = true
        case .unavailable:
            break
        }
    }
}

/// One-shot current location, asking for When In Use permission the first time.
final class CurrentLocation: NSObject, CLLocationManagerDelegate {
    enum Outcome {
        case success(CLLocation)
        case denied
        case unavailable
    }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Outcome, Never>?

    func request() async -> Outcome {
        continuation?.resume(returning: .unavailable)
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            proceed(with: manager.authorizationStatus)
        }
    }

    private func proceed(with status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted: finish(.denied)
        default: manager.requestLocation()
        }
    }

    private func finish(_ outcome: Outcome) {
        continuation?.resume(returning: outcome)
        continuation = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard self.continuation != nil, status != .notDetermined else { return }
            self.proceed(with: status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.finish(.success(location)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(.unavailable) }
    }
}
