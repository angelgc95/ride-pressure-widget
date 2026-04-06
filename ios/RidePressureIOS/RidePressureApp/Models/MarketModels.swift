import Foundation

enum ProviderID: String, Codable, CaseIterable, Hashable, Identifiable {
    case uber
    case bolt
    case cabify
    case freenow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .uber:
            return "Uber"
        case .bolt:
            return "Bolt"
        case .cabify:
            return "Cabify"
        case .freenow:
            return "FREE NOW"
        }
    }
}

enum SourceBlend: String, Codable, Hashable {
    case direct
    case mixed
    case inferred
    case unavailable

    var label: String { rawValue.uppercased() }
}

enum SupportLevel: String, Codable, Hashable {
    case supported
    case limited
    case unsupported

    var label: String { rawValue.uppercased() }
}

enum AvailabilityState: String, Codable, Hashable {
    case available
    case limited
    case unsupported
    case stale
}

enum PressureTone: String, Codable, Hashable {
    case favorable
    case normal
    case unfavorable
    case neutral

    var statusLabel: String {
        switch self {
        case .favorable:
            return "Cheaper"
        case .normal:
            return "Normal"
        case .unfavorable:
            return "Expensive"
        case .neutral:
            return "Limited"
        }
    }
}

struct CitySelection: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let country: String
    let countryCode: String
    let latitude: Double
    let longitude: Double
    let timezone: String
    let admin1: String?
    let population: Int?

    var title: String {
        "\(name), \(country)"
    }

    static func makeID(
        name: String,
        countryCode: String,
        latitude: Double,
        longitude: Double
    ) -> String {
        let normalizedName = name
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "\(normalizedName)-\(countryCode.lowercased())-\(String(format: "%.2f", latitude))-\(String(format: "%.2f", longitude))"
    }
}

struct RouteObservation: Codable, Hashable {
    let routeCount: Int
    let validRouteCount: Int
    let averageEtaSeconds: Double
    let averageDistanceMeters: Double
    let medianSecondsPerKm: Double
    let baselineSecondsPerKm: Double?
    let directness: SourceBlend
    let note: String
}

struct ProviderSignalDetails: Codable, Hashable {
    var priceAmount: Double? = nil
    var currencyCode: String? = nil
    var baselinePrice: Double? = nil
    var relativeDelta: Double? = nil
    var etaSeconds: Double? = nil
    var distanceMeters: Double? = nil
    var surgeIndicator: String? = nil
    var routeObservation: RouteObservation? = nil
}

struct ProviderSnapshot: Codable, Hashable, Identifiable {
    let provider: ProviderID
    let supportLevel: SupportLevel
    let availabilityState: AvailabilityState
    let tone: PressureTone
    let statusLabel: String
    let observedAt: String?
    let sourceBlend: SourceBlend
    let note: String
    let freshnessHours: Int?
    let signals: ProviderSignalDetails

    var id: ProviderID { provider }
}

struct SnapshotScoreBreakdown: Codable, Hashable {
    let trafficScore: Double?
    let weatherScore: Double
    let demandScore: Double
    let trafficWeight: Double
    let weatherWeight: Double
    let demandWeight: Double
}

struct ObservedSnapshot: Codable, Hashable {
    let city: CitySelection
    let observedAt: String
    let score: Double
    let tone: PressureTone
    let label: String
    let summary: String
    let sourceBlend: SourceBlend
    let confidence: Double
    let routeObservation: RouteObservation?
    let breakdown: SnapshotScoreBreakdown
    let providerSnapshots: [ProviderSnapshot]
}

struct ChartPoint: Codable, Hashable, Identifiable {
    let key: String
    let label: String
    let timestamp: String
    let score: Double
    let tone: PressureTone
    let sourceBlend: SourceBlend
    let confidence: Double
    let explanation: String
    let trafficScore: Double?
    let weatherScore: Double
    let demandScore: Double
    let trafficComponent: Double
    let weatherComponent: Double
    let demandComponent: Double
    let neutralComponent: Double

    var id: String { key }
}

struct ChartSection: Codable, Hashable {
    let title: String
    let subtitle: String
    let points: [ChartPoint]
}

struct DashboardPayload: Codable, Hashable {
    let city: CitySelection
    let lastUpdatedAt: String?
    let stale: Bool
    let staleReason: String?
    let current: ObservedSnapshot
    let hourlyChart: ChartSection
    let widgetContextChart: ChartSection?
    let dailyChart: ChartSection
    let providerSnapshots: [ProviderSnapshot]
    let notes: [String]
}

struct WeatherSnapshot: Hashable {
    struct Current: Hashable {
        let time: String
        let temperature: Double
        let apparentTemperature: Double
        let precipitation: Double
        let windSpeed: Double
    }

    struct Hourly: Hashable {
        let time: String
        let temperature: Double
        let apparentTemperature: Double
        let precipitationProbability: Double
        let precipitation: Double
        let rain: Double
        let showers: Double
        let snowfall: Double
        let windSpeed: Double
        let cloudCover: Double
    }

    struct Daily: Hashable {
        let time: String
        let temperatureMax: Double
        let temperatureMin: Double
        let precipitationSum: Double
        let precipitationHours: Double
        let windSpeedMax: Double
    }

    let current: Current
    let hourly: [Hourly]
    let daily: [Daily]
}

enum AppError: LocalizedError {
    case invalidResponse(String)
    case locationDenied
    case locationUnavailable
    case reverseGeocodingFailed
    case noCitySelection

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let message):
            return message
        case .locationDenied:
            return "Location access is denied. Choose a city manually."
        case .locationUnavailable:
            return "Could not get your current location."
        case .reverseGeocodingFailed:
            return "Could not resolve your current city."
        case .noCitySelection:
            return "Choose a city to load the market pressure view."
        }
    }
}
