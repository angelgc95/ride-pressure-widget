import Foundation

actor MarketEngine {
    private let snapshotTTLHours = 6
    private let weatherService: OpenMeteoService
    private let snapshotArchive: SnapshotArchive
    private let providers: [any ProviderAdapter]

    init(
        weatherService: OpenMeteoService = OpenMeteoService(),
        snapshotArchive: SnapshotArchive = SnapshotArchive(),
        providers: [any ProviderAdapter] = [
            UberPublicAdapter(),
            StaticUnavailableAdapter(
                provider: .bolt,
                note: "No trustworthy public Bolt pricing or availability endpoint is configured in this build."
            ),
            StaticUnavailableAdapter(
                provider: .cabify,
                note: "No trustworthy public Cabify pricing or availability endpoint is configured in this build."
            ),
            StaticUnavailableAdapter(
                provider: .freenow,
                note: "No trustworthy public FREE NOW pricing or availability endpoint is configured in this build."
            )
        ]
    ) {
        self.weatherService = weatherService
        self.snapshotArchive = snapshotArchive
        self.providers = providers
    }

    func dashboard(for city: CitySelection, forceRefresh: Bool = false) async throws -> DashboardPayload {
        let weather = try await weatherService.fetchWeather(for: city)
        let latestSnapshot = await snapshotArchive.latestSnapshot(for: city.id)
        var workingSnapshot = latestSnapshot
        var staleReason: String?

        if forceRefresh || shouldRefresh(snapshot: latestSnapshot) {
            do {
                workingSnapshot = try await refreshObservedSnapshot(for: city, weather: weather)
            } catch {
                if latestSnapshot == nil {
                    throw error
                }
                staleReason = "Using the last stored snapshot because the upstream refresh failed."
            }
        }

        guard let snapshot = workingSnapshot else {
            throw AppError.invalidResponse("No market snapshot is available for this city.")
        }

        let staleHours = hoursSince(isoDate: snapshot.observedAt)
        let stale = staleHours >= snapshotTTLHours
        if stale && staleReason == nil {
            staleReason = "Observed market snapshot is \(staleHours)h old."
        }

        let hydratedProviders = snapshot.providerSnapshots.map {
            hydrateProviderFreshness(snapshot: $0, observedAt: snapshot.observedAt)
        }

        let current = ObservedSnapshot(
            city: city,
            observedAt: snapshot.observedAt,
            score: snapshot.score,
            tone: snapshot.tone,
            label: snapshot.label,
            summary: snapshot.summary,
            sourceBlend: snapshot.sourceBlend,
            confidence: snapshot.confidence,
            routeObservation: snapshot.routeObservation,
            breakdown: snapshot.breakdown,
            providerSnapshots: hydratedProviders
        )

        return DashboardPayload(
            city: city,
            lastUpdatedAt: current.observedAt,
            stale: stale,
            staleReason: staleReason,
            current: current,
            hourlyChart: buildHourlyChart(city: city, weather: weather, routeObservation: current.routeObservation),
            widgetContextChart: buildWidgetContextChart(
                city: city,
                weather: weather,
                routeObservation: current.routeObservation
            ),
            dailyChart: buildDailyChart(city: city, weather: weather, routeObservation: current.routeObservation),
            providerSnapshots: hydratedProviders,
            notes: [
                "Green, orange, and red provider states appear only when a real provider price is observed. Neutral cards mean limited or unsupported access.",
                "The city index is driven by real weather plus direct Uber route probes when available, layered with an explicit inferred demand curve."
            ]
        )
    }

    private func refreshObservedSnapshot(for city: CitySelection, weather: WeatherSnapshot) async throws -> ObservedSnapshot {
        let observedAt = Date()
        var providerSnapshots: [ProviderSnapshot] = []

        for provider in providers {
            let snapshot = await provider.observe(city: city, observedAt: observedAt)
            providerSnapshots.append(snapshot)
        }

        let routeObservation = providerSnapshots.first(where: { $0.provider == .uber })?.signals.routeObservation
        let snapshot = await buildObservedSnapshot(
            city: city,
            weather: weather,
            providerSnapshots: providerSnapshots,
            routeObservation: routeObservation,
            observedAt: observedAt
        )
        await snapshotArchive.save(snapshot)
        return snapshot
    }

    private func buildObservedSnapshot(
        city: CitySelection,
        weather: WeatherSnapshot,
        providerSnapshots: [ProviderSnapshot],
        routeObservation: RouteObservation?,
        observedAt: Date
    ) async -> ObservedSnapshot {
        let trafficHistory = median(await snapshotArchive.recentRouteMedians(for: city.id))
        let hydratedRouteObservation = routeObservation.map {
            RouteObservation(
                routeCount: $0.routeCount,
                validRouteCount: $0.validRouteCount,
                averageEtaSeconds: $0.averageEtaSeconds,
                averageDistanceMeters: $0.averageDistanceMeters,
                medianSecondsPerKm: $0.medianSecondsPerKm,
                baselineSecondsPerKm: trafficHistory,
                directness: $0.directness,
                note: $0.note
            )
        }

        let trafficScore = trafficPressureScore(routeObservation: hydratedRouteObservation)
        let weatherScore = weatherPressure(current: weather.current)
        let demandScore = demandPressure(for: observedAt, timeZoneID: city.timezone)
        let score = combineScore(
            trafficScore: trafficScore,
            weatherScore: weatherScore,
            demandScore: demandScore
        )
        let tone = toneFromScore(score)
        let observedAtString = ISO8601DateFormatter().string(from: observedAt)

        return ObservedSnapshot(
            city: city,
            observedAt: observedAtString,
            score: rounded(score),
            tone: tone,
            label: label(for: tone),
            summary: summary(for: tone, routeObservation: hydratedRouteObservation),
            sourceBlend: .mixed,
            confidence: confidence(blend: .mixed, trafficScore: trafficScore),
            routeObservation: hydratedRouteObservation,
            breakdown: SnapshotScoreBreakdown(
                trafficScore: trafficScore.map { rounded($0) },
                weatherScore: rounded(weatherScore),
                demandScore: rounded(demandScore),
                trafficWeight: trafficScore == nil ? 0 : 0.45,
                weatherWeight: trafficScore == nil ? 0.58 : 0.30,
                demandWeight: trafficScore == nil ? 0.42 : 0.25
            ),
            providerSnapshots: await annotateProviders(cityID: city.id, snapshots: providerSnapshots)
        )
    }

    private func annotateProviders(cityID: String, snapshots: [ProviderSnapshot]) async -> [ProviderSnapshot] {
        var annotated: [ProviderSnapshot] = []

        for snapshot in snapshots {
            guard let price = snapshot.signals.priceAmount else {
                annotated.append(snapshot)
                continue
            }

            let baseline = median(await snapshotArchive.recentProviderPrices(for: cityID, provider: snapshot.provider))

            guard let baseline, baseline > 0 else {
                annotated.append(
                    ProviderSnapshot(
                        provider: snapshot.provider,
                        supportLevel: .limited,
                        availabilityState: snapshot.availabilityState,
                        tone: .neutral,
                        statusLabel: "Observed",
                        observedAt: snapshot.observedAt,
                        sourceBlend: snapshot.sourceBlend,
                        note: "\(snapshot.note) First real price captured; waiting for a baseline window.",
                        freshnessHours: snapshot.freshnessHours,
                        signals: ProviderSignalDetails(
                            priceAmount: price,
                            currencyCode: snapshot.signals.currencyCode,
                            baselinePrice: nil,
                            relativeDelta: nil,
                            etaSeconds: snapshot.signals.etaSeconds,
                            distanceMeters: snapshot.signals.distanceMeters,
                            surgeIndicator: snapshot.signals.surgeIndicator,
                            routeObservation: snapshot.signals.routeObservation
                        )
                    )
                )
                continue
            }

            let delta = price / baseline - 1
            let tone: PressureTone
            let statusLabel: String

            if delta <= -0.08 {
                tone = .favorable
                statusLabel = "Cheaper"
            } else if delta >= 0.12 {
                tone = .unfavorable
                statusLabel = "Expensive"
            } else {
                tone = .normal
                statusLabel = "Normal"
            }

            annotated.append(
                ProviderSnapshot(
                    provider: snapshot.provider,
                    supportLevel: .supported,
                    availabilityState: .available,
                    tone: tone,
                    statusLabel: statusLabel,
                    observedAt: snapshot.observedAt,
                    sourceBlend: snapshot.sourceBlend,
                    note: "\(snapshot.note) \(deltaDescription(delta)).",
                    freshnessHours: snapshot.freshnessHours,
                    signals: ProviderSignalDetails(
                        priceAmount: price,
                        currencyCode: snapshot.signals.currencyCode,
                        baselinePrice: rounded(baseline),
                        relativeDelta: rounded(delta, decimals: 4),
                        etaSeconds: snapshot.signals.etaSeconds,
                        distanceMeters: snapshot.signals.distanceMeters,
                        surgeIndicator: snapshot.signals.surgeIndicator,
                        routeObservation: snapshot.signals.routeObservation
                    )
                )
            )
        }

        return annotated
    }

    private func buildHourlyChart(
        city: CitySelection,
        weather: WeatherSnapshot,
        routeObservation: RouteObservation?
    ) -> ChartSection {
        let points = buildHourlyPoints(
            city: city,
            weather: weather,
            routeObservation: routeObservation,
            startOffsetHours: 0,
            limit: 24,
            keyPrefix: "hour"
        )

        return ChartSection(
            title: "Hourly chart",
            subtitle: "Current city hour plus the next 23 hours. Scroll sideways to compare the full window.",
            points: points
        )
    }

    private func buildWidgetContextChart(
        city: CitySelection,
        weather: WeatherSnapshot,
        routeObservation: RouteObservation?
    ) -> ChartSection {
        let points = buildHourlyPoints(
            city: city,
            weather: weather,
            routeObservation: routeObservation,
            startOffsetHours: -1,
            limit: 14,
            keyPrefix: "widget-hour"
        )

        return ChartSection(
            title: "Widget hourly chart",
            subtitle: "Past hour, now, and the next 12 hours.",
            points: points
        )
    }

    private func buildDailyChart(
        city: CitySelection,
        weather: WeatherSnapshot,
        routeObservation: RouteObservation?
    ) -> ChartSection {
        let trafficScore = trafficPressureScore(routeObservation: routeObservation)

        let points = weather.daily.prefix(7).enumerated().compactMap { index, day -> ChartPoint? in
            guard let date = openMeteoDate(day.time, timeZoneID: city.timezone, format: "yyyy-MM-dd") else {
                return nil
            }

            let weatherScore = weatherPressure(day: day)
            let demandScore = average([8, 12, 18, 23].map { hour in
                Calendar.current.date(byAdding: .hour, value: hour, to: date).map {
                    demandPressure(for: $0, timeZoneID: city.timezone)
                } ?? 40
            })
            let score = combineScore(
                trafficScore: trafficScore,
                weatherScore: weatherScore,
                demandScore: demandScore
            )
            let components = scoreComponents(
                trafficScore: trafficScore,
                weatherScore: weatherScore,
                demandScore: demandScore
            )

            return ChartPoint(
                key: "day-\(index)",
                label: weekdayLabel(for: date, timeZoneID: city.timezone),
                timestamp: day.time,
                score: rounded(score),
                tone: toneFromScore(score),
                sourceBlend: .inferred,
                confidence: max(0, confidence(blend: .inferred, trafficScore: trafficScore) - 0.06),
                explanation: "Daily outlook blends forecast weather load with the latest observed route baseline and a weekday demand curve.",
                trafficScore: trafficScore.map { rounded($0) },
                weatherScore: rounded(weatherScore),
                demandScore: rounded(demandScore),
                trafficComponent: components.trafficComponent,
                weatherComponent: components.weatherComponent,
                demandComponent: components.demandComponent,
                neutralComponent: components.neutralComponent
            )
        }

        return ChartSection(
            title: "Daily chart",
            subtitle: "Next 7 days. This becomes more trustworthy as real snapshots accumulate for the city.",
            points: points
        )
    }

    private func buildHourlyPoints(
        city: CitySelection,
        weather: WeatherSnapshot,
        routeObservation: RouteObservation?,
        startOffsetHours: Int,
        limit: Int,
        keyPrefix: String
    ) -> [ChartPoint] {
        let trafficScore = trafficPressureScore(routeObservation: routeObservation)
        let cityCalendar = Calendar(identifier: .gregorian).settingTimeZone(city.timezone)
        let now = Date()
        let currentHourStart = cityCalendar.dateInterval(of: .hour, for: now)?.start ?? now
        let startDate = cityCalendar.date(byAdding: .hour, value: startOffsetHours, to: currentHourStart) ?? currentHourStart
        let matchingHours = weather.hourly.filter { entry in
            (openMeteoDate(entry.time, timeZoneID: city.timezone) ?? .distantPast) >= startDate
        }

        return matchingHours.prefix(limit).enumerated().compactMap { index, hour in
            guard let timestamp = openMeteoDate(hour.time, timeZoneID: city.timezone) else {
                return nil
            }

            let weatherScore = weatherPressure(hour: hour)
            let demandScore = demandPressure(for: timestamp, timeZoneID: city.timezone)
            let score = combineScore(
                trafficScore: trafficScore,
                weatherScore: weatherScore,
                demandScore: demandScore
            )
            let components = scoreComponents(
                trafficScore: trafficScore,
                weatherScore: weatherScore,
                demandScore: demandScore
            )

            return ChartPoint(
                key: "\(keyPrefix)-\(index)",
                label: hourlyAxisLabel(for: timestamp, timeZoneID: city.timezone),
                timestamp: hour.time,
                score: rounded(score),
                tone: toneFromScore(score),
                sourceBlend: .inferred,
                confidence: confidence(blend: .inferred, trafficScore: trafficScore),
                explanation: trafficScore == nil
                    ? "Forecast built from weather plus inferred local demand because direct route probes are unavailable."
                    : "Forecast combines live weather with the latest observed route basket and an inferred local demand curve.",
                trafficScore: trafficScore.map { rounded($0) },
                weatherScore: rounded(weatherScore),
                demandScore: rounded(demandScore),
                trafficComponent: components.trafficComponent,
                weatherComponent: components.weatherComponent,
                demandComponent: components.demandComponent,
                neutralComponent: components.neutralComponent
            )
        }
    }

    private func shouldRefresh(snapshot: ObservedSnapshot?) -> Bool {
        guard let snapshot else { return true }
        return hoursSince(isoDate: snapshot.observedAt) >= snapshotTTLHours
    }

    private func hydrateProviderFreshness(snapshot: ProviderSnapshot, observedAt: String) -> ProviderSnapshot {
        guard snapshot.availabilityState != .unsupported else {
            return ProviderSnapshot(
                provider: snapshot.provider,
                supportLevel: snapshot.supportLevel,
                availabilityState: snapshot.availabilityState,
                tone: snapshot.tone,
                statusLabel: snapshot.statusLabel,
                observedAt: snapshot.observedAt,
                sourceBlend: snapshot.sourceBlend,
                note: snapshot.note,
                freshnessHours: nil,
                signals: snapshot.signals
            )
        }

        let freshnessHours = hoursSince(isoDate: observedAt)

        if freshnessHours > snapshotTTLHours {
            return ProviderSnapshot(
                provider: snapshot.provider,
                supportLevel: snapshot.supportLevel,
                availabilityState: .stale,
                tone: snapshot.tone,
                statusLabel: snapshot.statusLabel,
                observedAt: snapshot.observedAt,
                sourceBlend: snapshot.sourceBlend,
                note: "\(snapshot.note) Last successful observation is \(freshnessHours)h old.",
                freshnessHours: freshnessHours,
                signals: snapshot.signals
            )
        }

        return ProviderSnapshot(
            provider: snapshot.provider,
            supportLevel: snapshot.supportLevel,
            availabilityState: snapshot.availabilityState,
            tone: snapshot.tone,
            statusLabel: snapshot.statusLabel,
            observedAt: snapshot.observedAt,
            sourceBlend: snapshot.sourceBlend,
            note: snapshot.note,
            freshnessHours: freshnessHours,
            signals: snapshot.signals
        )
    }

    private func trafficPressureScore(routeObservation: RouteObservation?) -> Double? {
        guard let routeObservation else { return nil }

        let absoluteScore = clamp(
            ((routeObservation.medianSecondsPerKm - 85) / (330 - 85)) * 100,
            min: 0,
            max: 100
        )

        guard let baseline = routeObservation.baselineSecondsPerKm, baseline > 0 else {
            return absoluteScore
        }

        let deltaRatio = routeObservation.medianSecondsPerKm / baseline - 1
        let relativeScore = clamp(50 + deltaRatio * 150, min: 0, max: 100)
        return clamp(absoluteScore * 0.55 + relativeScore * 0.45, min: 0, max: 100)
    }

    private func weatherPressure(current: WeatherSnapshot.Current) -> Double {
        let precipitationScore = clamp(current.precipitation * 18, min: 0, max: 55)
        let windScore = clamp((current.windSpeed - 12) * 2.4, min: 0, max: 24)
        let heatScore = clamp(abs(current.apparentTemperature - 19) * 1.35, min: 0, max: 21)
        return clamp(precipitationScore + windScore + heatScore, min: 0, max: 100)
    }

    private func weatherPressure(hour: WeatherSnapshot.Hourly) -> Double {
        let precipitationScore =
            clamp(hour.precipitationProbability * 0.38, min: 0, max: 38) +
            clamp(hour.precipitation * 14, min: 0, max: 34)
        let windScore = clamp((hour.windSpeed - 12) * 2.1, min: 0, max: 18)
        let cloudScore = clamp((hour.cloudCover - 60) * 0.18, min: 0, max: 10)
        let comfortScore = clamp(abs(hour.apparentTemperature - 19) * 1.2, min: 0, max: 16)
        return clamp(precipitationScore + windScore + cloudScore + comfortScore, min: 0, max: 100)
    }

    private func weatherPressure(day: WeatherSnapshot.Daily) -> Double {
        let rainScore = clamp(day.precipitationSum * 5.4, min: 0, max: 45)
        let durationScore = clamp(day.precipitationHours * 4.2, min: 0, max: 26)
        let windScore = clamp((day.windSpeedMax - 16) * 1.9, min: 0, max: 16)
        let comfortScore = clamp(
            max(abs(day.temperatureMax - 24), abs(day.temperatureMin - 12)) * 1.7,
            min: 0,
            max: 13
        )
        return clamp(rainScore + durationScore + windScore + comfortScore, min: 0, max: 100)
    }

    private func demandPressure(for date: Date, timeZoneID: String) -> Double {
        let calendar = Calendar(identifier: .gregorian).settingTimeZone(timeZoneID)
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)
        let weekend = weekday == 1 || weekday == 7

        if !weekend && (7...9).contains(hour) { return 74 }
        if !weekend && (17...20).contains(hour) { return 78 }
        if (weekday == 6 || weekday == 7) && (hour >= 22 || hour <= 2) { return 84 }
        if (1...5).contains(hour) { return 28 }
        if weekend && (11...17).contains(hour) { return 48 }
        return 40
    }

    private func combineScore(trafficScore: Double?, weatherScore: Double, demandScore: Double) -> Double {
        if let trafficScore {
            return clamp(trafficScore * 0.45 + weatherScore * 0.30 + demandScore * 0.25, min: 0, max: 100)
        }
        return clamp(weatherScore * 0.58 + demandScore * 0.42, min: 0, max: 100)
    }

    private func scoreComponents(
        trafficScore: Double?,
        weatherScore: Double,
        demandScore: Double
    ) -> (trafficComponent: Double, weatherComponent: Double, demandComponent: Double, neutralComponent: Double) {
        if let trafficScore {
            return (
                rounded(trafficScore * 0.45),
                rounded(weatherScore * 0.30),
                rounded(demandScore * 0.25),
                0
            )
        }

        return (
            0,
            rounded(weatherScore * 0.58),
            rounded(demandScore * 0.42),
            0
        )
    }

    private func toneFromScore(_ score: Double) -> PressureTone {
        if score <= 34 { return .favorable }
        if score <= 66 { return .normal }
        return .unfavorable
    }

    private func label(for tone: PressureTone) -> String {
        switch tone {
        case .favorable:
            return "Good idea now"
        case .normal:
            return "Normal conditions"
        case .unfavorable:
            return "Rough right now"
        case .neutral:
            return "Limited"
        }
    }

    private func summary(for tone: PressureTone, routeObservation: RouteObservation?) -> String {
        switch tone {
        case .favorable:
            return routeObservation != nil
                ? "Observed route friction is below usual city stress, and weather load is relatively light."
                : "Weather conditions are light enough that rides look comparatively favorable despite limited provider pricing access."
        case .normal:
            return routeObservation != nil
                ? "Traffic and weather are close to their normal city baseline."
                : "Current signals are balanced, but the model is leaning on weather plus inferred demand because provider pricing access is limited."
        case .unfavorable:
            return routeObservation != nil
                ? "Route timing and weather both point to elevated market pressure."
                : "Weather and demand proxies point to elevated pressure, but direct provider pricing is still limited."
        case .neutral:
            return "There is not enough information to classify current pressure."
        }
    }

    private func confidence(blend: SourceBlend, trafficScore: Double?) -> Double {
        switch blend {
        case .direct:
            return 0.88
        case .mixed:
            return trafficScore == nil ? 0.58 : 0.78
        case .inferred:
            return trafficScore == nil ? 0.44 : 0.64
        case .unavailable:
            return 0.2
        }
    }

    private func deltaDescription(_ delta: Double?) -> String {
        guard let delta else { return "No real price delta yet" }
        let percent = Int((delta * 100).rounded())
        let sign = percent > 0 ? "+" : ""
        return "\(sign)\(percent)% vs recent baseline"
    }

    private func hourlyAxisLabel(for date: Date, timeZoneID: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timeZoneID)
        formatter.dateFormat = "HH"
        return formatter.string(from: date)
    }

    private func weekdayLabel(for date: Date, timeZoneID: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timeZoneID)
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(1))
    }

    private func openMeteoDate(_ value: String, timeZoneID: String, format: String = "yyyy-MM-dd'T'HH:mm") -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timeZoneID)
        formatter.dateFormat = format
        return formatter.date(from: value)
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

    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.min(max, Swift.max(min, value))
    }

    private func rounded(_ value: Double, decimals: Int = 1) -> Double {
        let multiplier = pow(10.0, Double(decimals))
        return (value * multiplier).rounded() / multiplier
    }

    private func hoursSince(isoDate: String) -> Int {
        guard let date = ISO8601DateFormatter().date(from: isoDate) else { return snapshotTTLHours + 1 }
        return Calendar.current.dateComponents([.hour], from: date, to: Date()).hour ?? (snapshotTTLHours + 1)
    }
}

private extension Calendar {
    func settingTimeZone(_ timeZoneID: String) -> Calendar {
        var calendar = self
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        return calendar
    }
}
