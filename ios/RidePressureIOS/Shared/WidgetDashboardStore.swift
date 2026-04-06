import Foundation

struct WidgetDashboardStore {
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = UserDefaults(suiteName: RidePressureShared.appGroupID)) {
        self.defaults = defaults
    }

    func load() -> DashboardPayload? {
        guard let data = defaults?.data(forKey: RidePressureShared.widgetDashboardKey) else {
            return nil
        }

        return try? JSONDecoder().decode(DashboardPayload.self, from: data)
    }

    func save(_ dashboard: DashboardPayload) {
        guard let defaults else { return }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(dashboard)
            defaults.set(data, forKey: RidePressureShared.widgetDashboardKey)
        } catch {
            // If widget cache persistence fails, the main app still works.
        }
    }

    func clear() {
        defaults?.removeObject(forKey: RidePressureShared.widgetDashboardKey)
    }
}

struct WidgetSelectedCityStore {
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = UserDefaults(suiteName: RidePressureShared.appGroupID)) {
        self.defaults = defaults
    }

    func load() -> CitySelection? {
        guard let data = defaults?.data(forKey: RidePressureShared.widgetSelectedCityKey) else {
            return nil
        }

        return try? JSONDecoder().decode(CitySelection.self, from: data)
    }

    func save(_ city: CitySelection) {
        guard let defaults else { return }

        do {
            let data = try JSONEncoder().encode(city)
            defaults.set(data, forKey: RidePressureShared.widgetSelectedCityKey)
        } catch {
            // The app can still operate if the widget city cache is unavailable.
        }
    }

    func clear() {
        defaults?.removeObject(forKey: RidePressureShared.widgetSelectedCityKey)
    }
}
