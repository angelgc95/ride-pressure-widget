import Foundation

struct OpenMeteoService {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
    }

    func searchCities(query: String) async throws -> [CitySelection] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "8"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components?.url else {
            throw AppError.invalidResponse("Could not build the geocoding request.")
        }

        let response: GeocodingResponse = try await httpClient.fetch(
            url: url,
            name: "Open-Meteo geocoding"
        )

        return (response.results ?? []).map { result in
            let resolvedID = result.id.map(String.init) ?? CitySelection.makeID(
                name: result.name,
                countryCode: result.countryCode,
                latitude: result.latitude,
                longitude: result.longitude
            )

            return CitySelection(
                id: resolvedID,
                name: result.name,
                country: result.country,
                countryCode: result.countryCode.uppercased(),
                latitude: result.latitude,
                longitude: result.longitude,
                timezone: result.timezone,
                admin1: result.admin1,
                population: result.population
            )
        }
    }

    func fetchWeather(for city: CitySelection) async throws -> WeatherSnapshot {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(city.latitude)),
            URLQueryItem(name: "longitude", value: String(city.longitude)),
            URLQueryItem(name: "current", value: [
                "temperature_2m",
                "apparent_temperature",
                "precipitation",
                "rain",
                "showers",
                "snowfall",
                "wind_speed_10m"
            ].joined(separator: ",")),
            URLQueryItem(name: "hourly", value: [
                "temperature_2m",
                "apparent_temperature",
                "precipitation_probability",
                "precipitation",
                "rain",
                "showers",
                "snowfall",
                "wind_speed_10m",
                "cloud_cover"
            ].joined(separator: ",")),
            URLQueryItem(name: "daily", value: [
                "temperature_2m_max",
                "temperature_2m_min",
                "precipitation_sum",
                "precipitation_hours",
                "wind_speed_10m_max"
            ].joined(separator: ",")),
            URLQueryItem(name: "timezone", value: city.timezone),
            URLQueryItem(name: "forecast_days", value: "7")
        ]

        guard let url = components?.url else {
            throw AppError.invalidResponse("Could not build the weather request.")
        }

        let response: ForecastResponse = try await httpClient.fetch(
            url: url,
            name: "Open-Meteo forecast"
        )

        return WeatherSnapshot(
            current: .init(
                time: response.current.time,
                temperature: response.current.temperature2M,
                apparentTemperature: response.current.apparentTemperature,
                precipitation: response.current.precipitation,
                windSpeed: response.current.windSpeed10M
            ),
            hourly: zip(response.hourly.time.indices, response.hourly.time).map { index, time in
                WeatherSnapshot.Hourly(
                    time: time,
                    temperature: response.hourly.temperature2M[index],
                    apparentTemperature: response.hourly.apparentTemperature[index],
                    precipitationProbability: response.hourly.precipitationProbability[index],
                    precipitation: response.hourly.precipitation[index],
                    rain: response.hourly.rain[index],
                    showers: response.hourly.showers[index],
                    snowfall: response.hourly.snowfall[index],
                    windSpeed: response.hourly.windSpeed10M[index],
                    cloudCover: response.hourly.cloudCover[index]
                )
            },
            daily: zip(response.daily.time.indices, response.daily.time).map { index, time in
                WeatherSnapshot.Daily(
                    time: time,
                    temperatureMax: response.daily.temperature2MMax[index],
                    temperatureMin: response.daily.temperature2MMin[index],
                    precipitationSum: response.daily.precipitationSum[index],
                    precipitationHours: response.daily.precipitationHours[index],
                    windSpeedMax: response.daily.windSpeed10MMax[index]
                )
            }
        )
    }
}

private struct GeocodingResponse: Decodable {
    let results: [GeocodingResult]?
}

private struct GeocodingResult: Decodable {
    let id: Int?
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String
    let timezone: String
    let admin1: String?
    let population: Int?
    let countryCode: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case latitude
        case longitude
        case country
        case timezone
        case admin1
        case population
        case countryCode = "country_code"
    }
}

private struct ForecastResponse: Decodable {
    struct Current: Decodable {
        let time: String
        let temperature2M: Double
        let apparentTemperature: Double
        let precipitation: Double
        let windSpeed10M: Double

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2M = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case precipitation
            case windSpeed10M = "wind_speed_10m"
        }
    }

    struct Hourly: Decodable {
        let time: [String]
        let temperature2M: [Double]
        let apparentTemperature: [Double]
        let precipitationProbability: [Double]
        let precipitation: [Double]
        let rain: [Double]
        let showers: [Double]
        let snowfall: [Double]
        let windSpeed10M: [Double]
        let cloudCover: [Double]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2M = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case precipitationProbability = "precipitation_probability"
            case precipitation
            case rain
            case showers
            case snowfall
            case windSpeed10M = "wind_speed_10m"
            case cloudCover = "cloud_cover"
        }
    }

    struct Daily: Decodable {
        let time: [String]
        let temperature2MMax: [Double]
        let temperature2MMin: [Double]
        let precipitationSum: [Double]
        let precipitationHours: [Double]
        let windSpeed10MMax: [Double]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2MMax = "temperature_2m_max"
            case temperature2MMin = "temperature_2m_min"
            case precipitationSum = "precipitation_sum"
            case precipitationHours = "precipitation_hours"
            case windSpeed10MMax = "wind_speed_10m_max"
        }
    }

    let current: Current
    let hourly: Hourly
    let daily: Daily
}
