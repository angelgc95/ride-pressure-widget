import Combine
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class RidePressureStore: ObservableObject {
    @Published var selectedCity: CitySelection?
    @Published var dashboard: DashboardPayload?
    @Published var searchResults: [CitySelection] = []
    @Published var query = ""
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var isDetecting = false
    @Published var isSearchPresented = false
    @Published var errorMessage: String?

    private let cityStorageKey = "ride-pressure-ios.selected-city"
    private let defaults: UserDefaults
    private let marketEngine: MarketEngine
    private let weatherService: OpenMeteoService
    private let locationService: LocationService
    private let widgetDashboardStore: WidgetDashboardStore
    private let widgetSelectedCityStore: WidgetSelectedCityStore
    private var hasLoaded = false
    private var hasQueuedAutomaticDetection = false

    init(
        defaults: UserDefaults = .standard,
        marketEngine: MarketEngine = MarketEngine(),
        weatherService: OpenMeteoService = OpenMeteoService(),
        widgetDashboardStore: WidgetDashboardStore = WidgetDashboardStore(),
        widgetSelectedCityStore: WidgetSelectedCityStore = WidgetSelectedCityStore()
    ) {
        self.defaults = defaults
        self.marketEngine = marketEngine
        self.weatherService = weatherService
        self.locationService = LocationService()
        self.widgetDashboardStore = widgetDashboardStore
        self.widgetSelectedCityStore = widgetSelectedCityStore
    }

    func loadInitialState() async {
        guard !hasLoaded else { return }
        hasLoaded = true

        if let storedCity = loadStoredCity() {
            selectedCity = storedCity
            await loadDashboard(for: storedCity)
            return
        }

        hasQueuedAutomaticDetection = true
    }

    func refreshIfNeeded() async {
        guard let selectedCity else { return }
        await loadDashboard(for: selectedCity)
    }

    func forceRefresh() async {
        guard let selectedCity else { return }
        await loadDashboard(for: selectedCity, forceRefresh: true)
    }

    func chooseCity(_ city: CitySelection) {
        hasQueuedAutomaticDetection = false
        selectedCity = city
        dashboard = nil
        persist(city: city)
        isSearchPresented = false
        query = ""
        searchResults = []

        Task {
            await loadDashboard(for: city)
        }
    }

    func detectCurrentCity() async {
        hasQueuedAutomaticDetection = false
        isDetecting = true
        errorMessage = nil

        defer { isDetecting = false }

        do {
            let city = try await locationService.detectCurrentCity()
            selectedCity = city
            dashboard = nil
            persist(city: city)
            await loadDashboard(for: city)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func runQueuedAutomaticDetectionIfNeeded() async {
        guard hasQueuedAutomaticDetection else { return }
        guard selectedCity == nil, !isDetecting else { return }

        await detectCurrentCity()
    }

    func cancelQueuedAutomaticDetection() {
        hasQueuedAutomaticDetection = false
    }

    func searchCities(matching query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            searchResults = try await weatherService.searchCities(query: trimmed)
        } catch {
            searchResults = []
        }
    }

    func clearSearchResults() {
        searchResults = []
    }

    private func loadDashboard(for city: CitySelection, forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let payload = try await marketEngine.dashboard(for: city, forceRefresh: forceRefresh)
            dashboard = payload
            widgetDashboardStore.save(payload)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: RidePressureShared.widgetKind)
            #endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadStoredCity() -> CitySelection? {
        guard let data = defaults.data(forKey: cityStorageKey) else {
            return widgetSelectedCityStore.load()
        }

        return (try? JSONDecoder().decode(CitySelection.self, from: data)) ?? widgetSelectedCityStore.load()
    }

    private func persist(city: CitySelection) {
        if let data = try? JSONEncoder().encode(city) {
            defaults.set(data, forKey: cityStorageKey)
        }
        widgetSelectedCityStore.save(city)
    }
}
