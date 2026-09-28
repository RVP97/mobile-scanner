import CoreLocation
import MapKit

/// One-shot, when-in-use location for "Remember where I scanned". Only the Settings toggle ever
/// asks for permission; stamping a record silently does nothing without it.
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private var locationWaiters: [CheckedContinuation<CLLocation?, Never>] = []
    private var authorizationWaiters: [CheckedContinuation<Bool, Never>] = []
    private var requestGeneration = 0

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    var isAuthorized: Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: true
        default: false
        }
    }

    var isDenied: Bool {
        switch manager.authorizationStatus {
        case .denied, .restricted: true
        default: false
        }
    }

    /// Asks for when-in-use access if it hasn't been decided yet. Returns whether access is granted.
    func requestAuthorization() async -> Bool {
        guard manager.authorizationStatus == .notDetermined else { return isAuthorized }
        return await withCheckedContinuation { continuation in
            authorizationWaiters.append(continuation)
            manager.requestWhenInUseAuthorization()
        }
    }

    /// Fills the record's place and coordinates in the background. No-op without permission.
    func stamp(_ record: ScanRecord) async {
        guard isAuthorized, let location = await currentLocation() else { return }
        record.latitude = location.coordinate.latitude
        record.longitude = location.coordinate.longitude
        record.placeName = await PlaceNamer.name(for: location)
    }

    private func currentLocation() async -> CLLocation? {
        if let recent = manager.location, recent.timestamp.timeIntervalSinceNow > -30, recent.horizontalAccuracy <= 100 {
            return recent
        }
        return await withCheckedContinuation { continuation in
            locationWaiters.append(continuation)
            guard locationWaiters.count == 1 else { return }
            requestGeneration += 1
            let generation = requestGeneration
            manager.requestLocation()
            Task {
                try? await Task.sleep(for: .seconds(10))
                if generation == self.requestGeneration { self.finishLocation(nil) }
            }
        }
    }

    private func finishLocation(_ location: CLLocation?) {
        let waiters = locationWaiters
        locationWaiters.removeAll()
        waiters.forEach { $0.resume(returning: location) }
    }

    // MARK: CLLocationManagerDelegate (delivered on the main thread, where the manager was made)

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        MainActor.assumeIsolated { finishLocation(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated { finishLocation(nil) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            guard self.manager.authorizationStatus != .notDetermined else { return }
            let granted = isAuthorized
            let waiters = authorizationWaiters
            authorizationWaiters.removeAll()
            waiters.forEach { $0.resume(returning: granted) }
        }
    }
}
