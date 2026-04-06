import AppIntents
import SwiftUI
import WidgetKit

struct RidePressureWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Ride Pressure"
    static var description = IntentDescription("Choose a city for the home-screen pressure widget, or leave it blank to mirror the app's current city.")

    @Parameter(title: "City")
    var city: String?
}

struct RidePressureEntry: TimelineEntry {
    let date: Date
    let dashboard: DashboardPayload?
}

struct RidePressureTimelineProvider: AppIntentTimelineProvider {
    typealias Intent = RidePressureWidgetIntent

    private let dashboardStore = WidgetDashboardStore()
    private let selectedCityStore = WidgetSelectedCityStore()
    private let weatherService = OpenMeteoService()
    private let marketEngine = MarketEngine()

    func placeholder(in context: Context) -> RidePressureEntry {
        RidePressureEntry(date: .now, dashboard: WidgetPreviewData.dashboard)
    }

    func snapshot(for configuration: RidePressureWidgetIntent, in context: Context) async -> RidePressureEntry {
        RidePressureEntry(date: .now, dashboard: dashboardStore.load() ?? WidgetPreviewData.dashboard)
    }

    func timeline(for configuration: RidePressureWidgetIntent, in context: Context) async -> Timeline<RidePressureEntry> {
        var dashboard = dashboardStore.load()
        let city = await resolveCity(for: configuration, fallbackDashboard: dashboard)

        if let city, shouldRefresh(dashboard: dashboard, for: city) {
            do {
                let refreshed = try await marketEngine.dashboard(for: city, forceRefresh: true)
                dashboardStore.save(refreshed)
                dashboard = refreshed
            } catch {
                // Keep the most recent stored snapshot if the widget refresh fails.
            }
        }

        return Timeline(
            entries: [RidePressureEntry(date: .now, dashboard: dashboard)],
            policy: .after(nextRefreshDate(from: dashboard))
        )
    }

    private func resolveCity(
        for configuration: RidePressureWidgetIntent,
        fallbackDashboard: DashboardPayload?
    ) async -> CitySelection? {
        let trimmed = (configuration.city ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty,
           let configuredResults = try? await weatherService.searchCities(query: trimmed),
           let configuredCity = configuredResults.first {
            return configuredCity
        }

        return selectedCityStore.load() ?? fallbackDashboard?.city
    }

    private func shouldRefresh(dashboard: DashboardPayload?, for city: CitySelection) -> Bool {
        guard let dashboard else { return true }
        guard dashboard.city.id == city.id else { return true }
        guard let lastUpdatedAt = dashboard.lastUpdatedAt,
              let date = ISO8601DateFormatter().date(from: lastUpdatedAt) else {
            return true
        }

        return dashboard.stale || Date().timeIntervalSince(date) >= 6 * 60 * 60
    }

    private func nextRefreshDate(from dashboard: DashboardPayload?) -> Date {
        guard let dashboard,
              let lastUpdatedAt = dashboard.lastUpdatedAt,
              let date = ISO8601DateFormatter().date(from: lastUpdatedAt) else {
            return Date().addingTimeInterval(30 * 60)
        }

        let nextWindow = date.addingTimeInterval(6 * 60 * 60)
        if nextWindow <= .now {
            return Date().addingTimeInterval(30 * 60)
        }

        return nextWindow
    }
}

struct RidePressureHomeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: RidePressureShared.widgetKind, intent: RidePressureWidgetIntent.self, provider: RidePressureTimelineProvider()) { entry in
            RidePressureWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Ride Pressure")
        .description("Shows a real city pressure snapshot on your home screen. Pick a city in the widget settings or mirror the app.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct RidePressureWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: RidePressureEntry

    var body: some View {
        Group {
            if let dashboard = entry.dashboard {
                switch family {
                case .systemSmall:
                    smallWidget(dashboard: dashboard)
                case .systemLarge:
                    largeWidget(dashboard: dashboard)
                default:
                    mediumWidget(dashboard: dashboard)
                }
            } else {
                emptyWidget
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(hex: "11161E"),
                    Color(hex: "0A0E14")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func smallWidget(dashboard: DashboardPayload) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text("RIDE PRESSURE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(RidePressurePalette.accent)

                Spacer(minLength: 8)

                Text(shortWidgetTimestamp(dashboard.lastUpdatedAt))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: "7B8796"))
            }

            Text(dashboard.city.name)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(Int(dashboard.current.score.rounded()).formatted())
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(dashboard.current.tone.tint)
                Text("/100")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "7B8796"))
            }

            Text("RATE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: "98A3B2"))

            Spacer(minLength: 0)

            Text("Last updated \(shortWidgetTimestamp(dashboard.lastUpdatedAt))")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: "9BA7B6"))
                .lineLimit(1)
        }
        .padding(16)
    }

    private func mediumWidget(dashboard: DashboardPayload) -> some View {
        let points = mediumWindowPoints(for: dashboard)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RIDE PRESSURE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(RidePressurePalette.accent)
                    Text(dashboard.city.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    Text("Updated \(shortWidgetTimestamp(dashboard.lastUpdatedAt))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: "7B8796"))

                    widgetPill(dashboard.current.tone.statusLabel, tone: dashboard.current.tone)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(Int(dashboard.current.score.rounded()).formatted())
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(dashboard.current.tone.tint)
                        Text("/100")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: "7B8796"))
                    }

                    Text("RATE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: "96A1B0"))

                    Text("Past 1h")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(hex: "6F7A88"))

                    Text("Now +3h")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(hex: "6F7A88"))
                }
                .frame(width: 84, alignment: .leading)

                mediumChartPanel(
                    points: points,
                    emphasisIndex: mediumEmphasisIndex(for: dashboard, points: points)
                )
            }

            Text("Past hour, now, and next 3h. \(dashboard.current.summary)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(hex: "B7C1CC"))
                .lineLimit(1)
        }
        .padding(16)
    }

    private func largeWidget(dashboard: DashboardPayload) -> some View {
        let points = largeWindowPoints(for: dashboard)

        return VStack(alignment: .leading, spacing: 14) {
            widgetHeader(city: dashboard.city.title, updatedAt: dashboard.lastUpdatedAt)

            HStack(alignment: .bottom, spacing: 10) {
                Text(Int(dashboard.current.score.rounded()).formatted())
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(dashboard.current.tone.tint)
                Text("/100")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "7B8796"))
                    .padding(.bottom, 8)
                widgetPill(dashboard.current.tone.statusLabel, tone: dashboard.current.tone)
                Spacer()
            }

            Text("Current hour and the next 12 hours. \(dashboard.current.summary)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: "B7C1CC"))
                .lineLimit(2)

            widgetChartCard(
                title: "NOW TO +12H",
                subtitle: "City pressure outlook",
                points: points,
                compact: false,
                emphasisIndex: 0
            )
        }
        .padding(16)
    }

    private var emptyWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RIDE PRESSURE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(RidePressurePalette.accent)

            Text("Pick a city in widget settings or open the app once to mirror its current city.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("The home-screen widget only shows real observed data. It never fills gaps with fake provider history.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "9BA7B6"))
        }
        .padding(18)
    }

    private func widgetHeader(city: String, updatedAt: String?) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("RIDE PRESSURE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(RidePressurePalette.accent)
                Text(city)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            Text("Updated \(shortWidgetTimestamp(updatedAt))")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(hex: "7B8796"))
                .multilineTextAlignment(.trailing)
        }
    }

    private func widgetChartCard(
        title: String,
        subtitle: String,
        points: [ChartPoint],
        compact: Bool,
        emphasisIndex: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(hex: "6C7786"))

            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: "96A1B0"))

            WidgetBarPlot(
                points: points,
                axisLabels: ("100", "avg", "0"),
                compact: compact,
                emphasisIndex: emphasisIndex
            )
        }
        .padding(12)
        .background(Color(hex: "11161F"))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        }
    }

    private func mediumChartPanel(points: [ChartPoint], emphasisIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PAST HOUR TO +3H")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(hex: "6C7786"))

            WidgetBarPlot(
                points: points,
                axisLabels: nil,
                compact: true,
                emphasisIndex: emphasisIndex
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(hex: "11161F"))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        }
    }

    private func widgetPill(_ label: String, tone: PressureTone) -> some View {
        Text(label.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tone.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tone.softFill)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(tone.softStroke, lineWidth: 1)
            }
    }

    private func shortWidgetTimestamp(_ updatedAt: String?) -> String {
        guard let updatedAt,
              let date = ISO8601DateFormatter().date(from: updatedAt) else {
            return "--:--"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func widgetContextPoints(for dashboard: DashboardPayload) -> [ChartPoint] {
        dashboard.widgetContextChart?.points ?? dashboard.hourlyChart.points
    }

    private func mediumWindowPoints(for dashboard: DashboardPayload) -> [ChartPoint] {
        Array(widgetContextPoints(for: dashboard).prefix(5))
    }

    private func largeWindowPoints(for dashboard: DashboardPayload) -> [ChartPoint] {
        let points = widgetContextPoints(for: dashboard)

        if dashboard.widgetContextChart != nil {
            return Array(points.dropFirst().prefix(13))
        }

        return Array(points.prefix(13))
    }

    private func mediumEmphasisIndex(for dashboard: DashboardPayload, points: [ChartPoint]) -> Int {
        guard !points.isEmpty else { return 0 }
        return dashboard.widgetContextChart == nil ? 0 : min(1, points.count - 1)
    }
}

private struct WidgetBarPlot: View {
    let points: [ChartPoint]
    let axisLabels: (top: String, average: String, bottom: String)?
    let compact: Bool
    let emphasisIndex: Int

    private var average: Double {
        guard !points.isEmpty else { return 0 }
        return points.map(\.score).reduce(0, +) / Double(points.count)
    }

    private var plotHeight: CGFloat {
        compact ? 54 : 86
    }

    private var yAxisWidth: CGFloat {
        guard axisLabels != nil else { return 0 }
        return compact ? 24 : 28
    }

    private var spacing: CGFloat {
        compact ? 6 : 7
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            HStack(alignment: .top, spacing: 10) {
                GeometryReader { proxy in
                    let averageY = plotHeight - plotHeight * CGFloat(widgetClamp(average, min: 0, max: 100) / 100)

                    ZStack(alignment: .topLeading) {
                        WidgetGridLines(averageY: averageY)

                        HStack(alignment: .bottom, spacing: spacing) {
                            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                                widgetBar(for: point, plotHeight: plotHeight, emphasized: index == emphasisIndex)
                            }
                        }
                    }
                }
                .frame(height: plotHeight)

                if let axisLabels {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(axisLabels.top)
                            .padding(.top, 1)
                        Spacer()
                        Text(axisLabels.average)
                        Spacer()
                        Text(axisLabels.bottom)
                    }
                    .font(.system(size: compact ? 9 : 10, weight: .medium))
                    .foregroundStyle(Color(hex: "7D8795"))
                    .frame(width: yAxisWidth, height: plotHeight)
                }
            }

            HStack(alignment: .top, spacing: 10) {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(points) { point in
                        Text(point.label)
                            .font(.system(size: compact ? 9 : 10, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color(hex: "8D98A8"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                    }
                }

                if axisLabels != nil {
                    Color.clear
                        .frame(width: yAxisWidth, height: 1)
                }
            }
        }
    }

    private func widgetBar(for point: ChartPoint, plotHeight: CGFloat, emphasized: Bool) -> some View {
        let cornerRadius = compact ? 3.0 : 5.0
        let fillHeight = max(0, plotHeight * CGFloat(point.score / 100))

        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.10))

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(point.tone.tint)
                .frame(height: fillHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            if emphasized {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

private func widgetClamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
    Swift.max(minValue, Swift.min(maxValue, value))
}

private struct WidgetGridLines: View {
    let averageY: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height

            ZStack(alignment: .topLeading) {
                ForEach([0.0, 0.5, 1.0], id: \.self) { ratio in
                    Path { path in
                        let y = height * ratio
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    }
                    .stroke(Color.white.opacity(ratio == 0.5 ? 0.08 : 0.06), lineWidth: 1)
                }

                Path { path in
                    path.move(to: CGPoint(x: 0, y: averageY))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: averageY))
                }
                .stroke(Color.white.opacity(0.34), style: StrokeStyle(lineWidth: 1.2, dash: [5, 5]))
            }
        }
    }
}

private enum WidgetPreviewData {
    static let dashboard = DashboardPayload(
        city: CitySelection(
            id: "malaga-es",
            name: "Malaga",
            country: "Spain",
            countryCode: "ES",
            latitude: 36.72,
            longitude: -4.42,
            timezone: "Europe/Madrid",
            admin1: "Andalusia",
            population: nil
        ),
        lastUpdatedAt: ISO8601DateFormatter().string(from: .now),
        stale: false,
        staleReason: nil,
        current: ObservedSnapshot(
            city: CitySelection(
                id: "malaga-es",
                name: "Malaga",
                country: "Spain",
                countryCode: "ES",
                latitude: 36.72,
                longitude: -4.42,
                timezone: "Europe/Madrid",
                admin1: "Andalusia",
                population: nil
            ),
            observedAt: ISO8601DateFormatter().string(from: .now),
            score: 54,
            tone: .normal,
            label: "Normal conditions",
            summary: "Price pressure is moderate. Weather is calm, but midday demand stays elevated.",
            sourceBlend: .mixed,
            confidence: 0.78,
            routeObservation: nil,
            breakdown: SnapshotScoreBreakdown(
                trafficScore: 62,
                weatherScore: 31,
                demandScore: 58,
                trafficWeight: 0.45,
                weatherWeight: 0.30,
                demandWeight: 0.25
            ),
            providerSnapshots: []
        ),
        hourlyChart: ChartSection(
            title: "Hourly chart",
            subtitle: "Next 24 hours",
            points: WidgetPreviewData.hourlyPoints
        ),
        widgetContextChart: ChartSection(
            title: "Widget hourly chart",
            subtitle: "Past hour, now, and the next 12 hours.",
            points: WidgetPreviewData.widgetContextPoints
        ),
        dailyChart: ChartSection(
            title: "Daily chart",
            subtitle: "Recent daily conditions",
            points: WidgetPreviewData.dailyPoints
        ),
        providerSnapshots: [],
        notes: []
    )

    static let dailyPoints: [ChartPoint] = [
        previewPoint("M", 32, .favorable),
        previewPoint("T", 36, .favorable),
        previewPoint("W", 28, .normal),
        previewPoint("T", 25, .normal),
        previewPoint("F", 21, .favorable),
        previewPoint("S", 26, .normal),
        previewPoint("S", 34, .unfavorable)
    ]

    static let hourlyPoints: [ChartPoint] = [
        previewPoint("23", 18, .normal),
        previewPoint("00", 27, .favorable),
        previewPoint("01", 23, .normal),
        previewPoint("02", 17, .favorable),
        previewPoint("03", 14, .favorable),
        previewPoint("04", 16, .normal),
        previewPoint("05", 19, .normal),
        previewPoint("06", 12, .favorable),
        previewPoint("07", 22, .unfavorable),
        previewPoint("08", 11, .favorable),
        previewPoint("09", 13, .normal),
        previewPoint("10", 14, .favorable)
    ]

    static let widgetContextPoints: [ChartPoint] = [
        previewPoint("22", 20, .normal),
        previewPoint("23", 18, .normal),
        previewPoint("00", 27, .favorable),
        previewPoint("01", 23, .normal),
        previewPoint("02", 17, .favorable),
        previewPoint("03", 14, .favorable),
        previewPoint("04", 16, .normal),
        previewPoint("05", 19, .normal),
        previewPoint("06", 12, .favorable),
        previewPoint("07", 22, .unfavorable),
        previewPoint("08", 11, .favorable),
        previewPoint("09", 13, .normal),
        previewPoint("10", 14, .favorable),
        previewPoint("11", 18, .normal)
    ]

    private static func previewPoint(_ label: String, _ score: Double, _ tone: PressureTone) -> ChartPoint {
        ChartPoint(
            key: UUID().uuidString,
            label: label,
            timestamp: ISO8601DateFormatter().string(from: .now),
            score: score,
            tone: tone,
            sourceBlend: .mixed,
            confidence: 0.78,
            explanation: "",
            trafficScore: score * 0.42,
            weatherScore: score * 0.28,
            demandScore: score * 0.30,
            trafficComponent: score * 0.42,
            weatherComponent: score * 0.28,
            demandComponent: score * 0.30,
            neutralComponent: 0
        )
    }
}
