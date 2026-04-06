import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: RidePressureStore
    @State private var isProviderSheetPresented = false
    @State private var isWidgetGuidePresented = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let dashboard = store.dashboard {
                        cityPicker(dashboard: dashboard)
                        summaryCard(dashboard: dashboard)
                        PressureChartCard(
                            title: dashboard.dailyChart.title,
                            subtitle: dashboard.dailyChart.subtitle,
                            points: dashboard.dailyChart.points,
                            kind: .daily
                        )
                        PressureChartCard(
                            title: dashboard.hourlyChart.title,
                            subtitle: dashboard.hourlyChart.subtitle,
                            points: dashboard.hourlyChart.points,
                            kind: .hourly
                        )
                    } else if store.isLoading || store.isDetecting {
                        loadingState
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "0E1219"),
                        RidePressurePalette.screenBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .sheet(isPresented: $store.isSearchPresented) {
                CitySearchView(store: store)
                    .presentationDetents([.large])
                    .presentationBackground(RidePressurePalette.screenBackground)
            }
            .sheet(isPresented: $isProviderSheetPresented) {
                providerSheet
                    .presentationDetents([.medium, .large])
                    .presentationBackground(RidePressurePalette.screenBackground)
            }
            .sheet(isPresented: $isWidgetGuidePresented) {
                widgetGuideSheet
                    .presentationDetents([.medium])
                    .presentationBackground(RidePressurePalette.screenBackground)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("REAL-TIME CITY PRESSURE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(RidePressurePalette.accent)

                    Text(headline)
                        .font(.system(size: store.dashboard == nil ? 24 : 20, weight: .bold))
                        .foregroundStyle(.white)
                        .lineSpacing(0.5)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button {
                    Task {
                        await store.forceRefresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
            }

            Text(heroSupportLine)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(RidePressurePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    PillBadge(
                        label: "Auto city",
                        fill: Color(hex: "0F221D"),
                        stroke: RidePressurePalette.favorable.opacity(0.5),
                        text: Color(hex: "8AF0B2")
                    )
                    PillBadge(
                        label: "Observed only",
                        fill: Color(hex: "141B25"),
                        stroke: Color(hex: "64748B").opacity(0.45),
                        text: Color(hex: "CBD5E1")
                    )
                    PillBadge(
                        label: "6h refresh",
                        fill: Color(hex: "1D1820"),
                        stroke: RidePressurePalette.normal.opacity(0.5),
                        text: Color(hex: "FFBF66")
                    )
                }
                .padding(.trailing, 4)
            }

            HStack(spacing: 10) {
                headerActionButton(title: "Configure widget", tint: RidePressurePalette.action) {
                    isWidgetGuidePresented = true
                }

                if store.dashboard != nil {
                    headerActionButton(title: "Providers", tint: RidePressurePalette.neutral) {
                        isProviderSheetPresented = true
                    }
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "141A23"),
                    Color(hex: "0E1219")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 18, y: 18)
    }

    private func cityPicker(dashboard: DashboardPayload) -> some View {
        HStack(spacing: 12) {
            Button {
                store.cancelQueuedAutomaticDetection()
                store.isSearchPresented = true
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CURRENT CITY")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: "64748B"))
                    Text(dashboard.city.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("Tap to search another city or use location again.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "94A3B8"))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .buttonStyle(.plain)

            Button {
                Task {
                    await store.detectCurrentCity()
                }
            } label: {
                if store.isDetecting {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 64, height: 40)
                } else {
                    PillBadge(
                        label: "Locate",
                        fill: Color(hex: "0B2233"),
                        stroke: RidePressurePalette.action.opacity(0.5),
                        text: Color(hex: "7DD3FC")
                    )
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "151A22"),
                    Color(hex: "10141B")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 20, y: 24)
    }

    private func summaryCard(dashboard: DashboardPayload) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("CURRENT INDEX")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(RidePressurePalette.tertiaryText)

            HStack(alignment: .bottom, spacing: 12) {
                Text(Int(dashboard.current.score.rounded()).formatted())
                    .font(.system(size: 58, weight: .bold))
                    .foregroundStyle(dashboard.current.tone.tint)
                Text("/100")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: "64748B"))
                    .padding(.bottom, 10)
                PillBadge(
                    label: dashboard.current.tone.statusLabel,
                    tone: dashboard.current.tone
                )
                .padding(.bottom, 10)
            }

            Text(dashboard.current.summary)
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "CBD5E1"))

            HStack(spacing: 10) {
                MetricTile(
                    label: "Traffic",
                    value: dashboard.current.breakdown.trafficScore.map { Int($0.rounded()).formatted() } ?? "n/a"
                )
                MetricTile(
                    label: "Weather",
                    value: Int(dashboard.current.breakdown.weatherScore.rounded()).formatted()
                )
                MetricTile(
                    label: "Demand",
                    value: Int(dashboard.current.breakdown.demandScore.rounded()).formatted()
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(lastUpdatedLine(for: dashboard))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "94A3B8"))

                HStack(spacing: 8) {
                    metaPill(dashboard.current.sourceBlend.label)
                    metaPill("CONF \(Int((dashboard.current.confidence * 100).rounded()))%")
                    if let observation = dashboard.current.routeObservation {
                        metaPill("\(observation.validRouteCount) ROUTES")
                    }
                }
            }
        }
        .padding(22)
        .background(Color(hex: "0D1117"))
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func metaPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(hex: "CBD5E1"))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
    }

    private func headerActionButton(title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.04))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(tint.opacity(0.35), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LOADING")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(RidePressurePalette.tertiaryText)

            ProgressView()
                .tint(.white)

            Text(store.isDetecting ? "Detecting your city..." : "Loading market pressure...")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)

            Text("The app only uses real route and weather data where available, and it keeps unsupported providers honest.")
                .font(.system(size: 13))
                .foregroundStyle(RidePressurePalette.secondaryText)

            if let selectedCity = store.selectedCity {
                Text(selectedCity.title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "8BA0B7"))
            }

            HStack(spacing: 10) {
                actionButton(title: "Search city", fill: Color(hex: "172031")) {
                    store.cancelQueuedAutomaticDetection()
                    store.isSearchPresented = true
                }

                if !store.isDetecting {
                    actionButton(title: "Use location", fill: Color(hex: "0B2233")) {
                        Task {
                            await store.detectCurrentCity()
                        }
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RidePressurePalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("READY TO TRACK A CITY")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(RidePressurePalette.tertiaryText)

            Text("Choose a city to start")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)

            Text(store.errorMessage ?? "Location detection can fail if permission is denied. Manual city search is always available.")
                .font(.system(size: 14))
                .foregroundStyle(RidePressurePalette.secondaryText)

            HStack(spacing: 10) {
                actionButton(title: "Use location", fill: Color(hex: "0B2233")) {
                    Task {
                        await store.detectCurrentCity()
                    }
                }

                actionButton(title: "Search city", fill: Color(hex: "172031")) {
                    store.cancelQueuedAutomaticDetection()
                    store.isSearchPresented = true
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RidePressurePalette.panel)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    private func actionButton(title: String, fill: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(fill)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var headline: String {
        guard let dashboard = store.dashboard else {
            return "See if rides in your city are favorable, normal, or expensive right now."
        }

        let toneWord: String
        switch dashboard.current.tone {
        case .favorable:
            toneWord = "favorable"
        case .normal:
            toneWord = "normal"
        case .unfavorable:
            toneWord = "rough"
        case .neutral:
            toneWord = "limited"
        }

        return "\(dashboard.city.name) is \(toneWord) right now."
    }

    private var heroSupportLine: String {
        if store.dashboard != nil {
            return "Daily history and upcoming hourly pressure are mapped below. Provider colors only change when a real price signal exists."
        }

        return "Use your location or search manually. The app stays honest about unsupported providers and stale observations."
    }

    private func lastUpdatedLine(for dashboard: DashboardPayload) -> String {
        guard let lastUpdatedAt = dashboard.lastUpdatedAt,
              let date = ISO8601DateFormatter().date(from: lastUpdatedAt) else {
            return "No snapshot yet"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: dashboard.city.timezone)
        formatter.dateFormat = "HH:mm z"

        let staleSuffix = dashboard.stale ? " · stale" : " · 6h refresh window"
        return "Last updated \(formatter.string(from: date))\(staleSuffix)"
    }

    private var providerSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if let dashboard = store.dashboard {
                    ProviderStatusCard(
                        providers: dashboard.providerSnapshots,
                        notes: dashboard.notes
                    )
                    .padding(20)
                } else {
                    Text("Provider status is available once a city snapshot has loaded.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(RidePressurePalette.secondaryText)
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(RidePressurePalette.screenBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Provider status")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isProviderSheetPresented = false
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }

    private var widgetGuideSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Home-screen widget setup")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text("There is no in-app widget editor on iPhone. Configure it from the home screen after adding the widget.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(RidePressurePalette.secondaryText)

                widgetGuideStep("1", "Go to the iPhone home screen.")
                widgetGuideStep("2", "Long-press the screen and tap Edit, then Add Widget.")
                widgetGuideStep("3", "Choose Ride Pressure.")
                widgetGuideStep("4", "Long-press the widget and tap Edit Widget.")
                widgetGuideStep("5", "Set the city field there.")

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RidePressurePalette.screenBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isWidgetGuidePresented = false
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }

    private func widgetGuideStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.06))
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
