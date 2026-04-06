import CoreLocation
import Foundation

protocol ProviderAdapter {
    var provider: ProviderID { get }
    func observe(city: CitySelection, observedAt: Date) async -> ProviderSnapshot
}

final class UberPublicAdapter: ProviderAdapter {
    private struct UberCoordinate: Encodable {
        let latitude: Double
        let longitude: Double
    }

    private struct UberRouteRequest: Encodable {
        struct Route: Encodable {
            let origin: UberCoordinate
            let destinations: [UberCoordinate]
        }

        let routes: [Route]
    }

    private struct UberRouteResponseItem: Decodable {
        let distance: Double
        let eta: Double
    }

    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
    }

    let provider: ProviderID = .uber

    func observe(city: CitySelection, observedAt: Date) async -> ProviderSnapshot {
        let radiusKm = max(1.6, min(city.population.map {
            if $0 > 1_500_000 { return 2.8 }
            if $0 > 500_000 { return 2.2 }
            return 1.8
        } ?? 1.8, 3.0))

        let bearings = stride(from: 0, to: 360, by: 45).map(Double.init)
        let routes = bearings.map { bearing in
            UberRouteRequest.Route(
                origin: .init(latitude: city.latitude, longitude: city.longitude),
                destinations: [offsetCoordinate(
                    latitude: city.latitude,
                    longitude: city.longitude,
                    bearingDegrees: bearing,
                    distanceKilometers: radiusKm
                )]
            )
        }

        let observedAtString = ISO8601DateFormatter().string(from: observedAt)

        do {
            let payload = try JSONEncoder().encode(UberRouteRequest(routes: routes))
            let url = URL(string: "https://m.uber.com/go/custom-api/navigation/route")!
            let response: [UberRouteResponseItem] = try await httpClient.fetch(
                url: url,
                name: "Uber public route probe",
                method: "POST",
                body: payload,
                headers: [
                    "Accept": "application/json",
                    "Referer": "https://m.uber.com/go/",
                    "x-csrf-token": "x",
                    "x-uber-rv-session-type": "desktop_session",
                    "x-uber-rv-initial-load-city-id": "0"
                ]
            )

            if let observation = buildRouteObservation(
                from: response,
                cityLatitude: city.latitude,
                cityLongitude: city.longitude,
                radiusKilometers: radiusKm
            ) {
                return ProviderSnapshot(
                    provider: provider,
                    supportLevel: .limited,
                    availabilityState: .limited,
                    tone: .neutral,
                    statusLabel: "Route only",
                    observedAt: observedAtString,
                    sourceBlend: .direct,
                    note: "Public Uber probes contribute direct route friction, but this build still does not expose a verified anonymous Uber fare.",
                    freshnessHours: 0,
                    signals: ProviderSignalDetails(
                        priceAmount: nil,
                        currencyCode: nil,
                        baselinePrice: nil,
                        relativeDelta: nil,
                        etaSeconds: observation.averageEtaSeconds.rounded(),
                        distanceMeters: observation.averageDistanceMeters.rounded(),
                        surgeIndicator: nil,
                        routeObservation: observation
                    )
                )
            }
        } catch {
            // Fall through to the limited neutral state below.
        }

        return ProviderSnapshot(
            provider: provider,
            supportLevel: .limited,
            availabilityState: .limited,
            tone: .neutral,
            statusLabel: "Route only",
            observedAt: observedAtString,
            sourceBlend: .direct,
            note: "The public Uber web flow returned no trustworthy anonymous fare for this city.",
            freshnessHours: 0,
            signals: ProviderSignalDetails()
        )
    }

    private func offsetCoordinate(
        latitude: Double,
        longitude: Double,
        bearingDegrees: Double,
        distanceKilometers: Double
    ) -> UberCoordinate {
        let radius = 6_371.0
        let bearing = bearingDegrees * .pi / 180
        let lat1 = latitude * .pi / 180
        let lon1 = longitude * .pi / 180
        let angularDistance = distanceKilometers / radius

        let lat2 = asin(
            sin(lat1) * cos(angularDistance) +
            cos(lat1) * sin(angularDistance) * cos(bearing)
        )
        let lon2 = lon1 + atan2(
            sin(bearing) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2)
        )

        return UberCoordinate(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }

    private func buildRouteObservation(
        from response: [UberRouteResponseItem],
        cityLatitude: Double,
        cityLongitude: Double,
        radiusKilometers: Double
    ) -> RouteObservation? {
        let directDistanceMeters = radiusKilometers * 1_000
        let validRoutes = response.filter { route in
            guard route.distance.isFinite, route.eta.isFinite else { return false }
            guard route.distance > 500, route.eta > 60 else { return false }
            let routeRatio = route.distance / directDistanceMeters
            return routeRatio >= 0.75 && routeRatio <= 3.5
        }

        guard validRoutes.count >= 2 else {
            return nil
        }

        let secondsPerKilometer = validRoutes.map { $0.eta / ($0.distance / 1_000) }

        return RouteObservation(
            routeCount: response.count,
            validRouteCount: validRoutes.count,
            averageEtaSeconds: average(validRoutes.map(\.eta)),
            averageDistanceMeters: average(validRoutes.map(\.distance)),
            medianSecondsPerKm: median(secondsPerKilometer) ?? 0,
            baselineSecondsPerKm: nil,
            directness: .direct,
            note: "Observed from \(validRoutes.count) canonical Uber route probes around \(String(format: "%.2f", cityLatitude)), \(String(format: "%.2f", cityLongitude))."
        )
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}

struct StaticUnavailableAdapter: ProviderAdapter {
    let provider: ProviderID
    let note: String

    func observe(city: CitySelection, observedAt: Date) async -> ProviderSnapshot {
        ProviderSnapshot(
            provider: provider,
            supportLevel: .unsupported,
            availabilityState: .unsupported,
            tone: .neutral,
            statusLabel: "Unsupported",
            observedAt: ISO8601DateFormatter().string(from: observedAt),
            sourceBlend: .unavailable,
            note: note,
            freshnessHours: nil,
            signals: ProviderSignalDetails()
        )
    }
}
