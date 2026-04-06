import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject {
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func detectCurrentCity() async throws -> CitySelection {
        let location = try await requestCurrentLocation()
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)

        guard let placemark = placemarks.first else {
            throw AppError.reverseGeocodingFailed
        }

        let name = placemark.locality ??
            placemark.subAdministrativeArea ??
            placemark.administrativeArea ??
            placemark.country

        guard let resolvedName = name, let country = placemark.country else {
            throw AppError.reverseGeocodingFailed
        }

        let countryCode = placemark.isoCountryCode ?? "XX"
        let timezone = placemark.timeZone?.identifier ?? TimeZone.current.identifier

        return CitySelection(
            id: CitySelection.makeID(
                name: resolvedName,
                countryCode: countryCode,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ),
            name: resolvedName,
            country: country,
            countryCode: countryCode,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timezone: timezone,
            admin1: placemark.administrativeArea,
            population: nil
        )
    }

    private func requestCurrentLocation() async throws -> CLLocation {
        switch manager.authorizationStatus {
        case .notDetermined:
            try await requestAuthorization()
        case .restricted, .denied:
            throw AppError.locationDenied
        case .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            throw AppError.locationUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    private func requestAuthorization() async throws {
        try await withCheckedThrowingContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }
    
    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        guard let authorizationContinuation else { return }

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            authorizationContinuation.resume(returning: ())
            self.authorizationContinuation = nil
        case .restricted, .denied:
            authorizationContinuation.resume(throwing: AppError.locationDenied)
            self.authorizationContinuation = nil
        case .notDetermined:
            break
        @unknown default:
            authorizationContinuation.resume(throwing: AppError.locationUnavailable)
            self.authorizationContinuation = nil
        }
    }

    private func handleLocationUpdate(_ locations: [CLLocation]) {
        guard let location = locations.last, let locationContinuation else { return }
        locationContinuation.resume(returning: location)
        self.locationContinuation = nil
    }

    private func handleLocationError(_ error: Error) {
        guard let locationContinuation else { return }
        locationContinuation.resume(throwing: error)
        self.locationContinuation = nil
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            handleAuthorizationChange(manager.authorizationStatus)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            handleLocationUpdate(locations)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            handleLocationError(error)
        }
    }
}
