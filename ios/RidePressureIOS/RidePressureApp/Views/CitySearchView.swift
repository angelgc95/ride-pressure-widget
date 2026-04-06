import SwiftUI

struct CitySearchView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: RidePressureStore
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SEARCH CITY")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(RidePressurePalette.accent)

                        Text("Choose another city")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Manual city switching should stay fast. The app still favors real observed pressure signals over decorative data.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(RidePressurePalette.secondaryText)
                    }
                    .padding(20)
                    .background(Color(hex: "12161D"))
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color(hex: "64748B"))

                        TextField("Search any city", text: $store.query)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .focused($searchFocused)

                        if store.isSearching {
                            ProgressView()
                                .tint(.white)
                        }
                    }
                    .padding(16)
                    .background(Color(hex: "12161D"))
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    }

                    Button {
                        Task {
                            dismiss()
                            await store.detectCurrentCity()
                        }
                    } label: {
                        HStack {
                            Text("Use my current city")
                            Spacer()
                            if store.isDetecting {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(Color(hex: "132537"))
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 10) {
                        if store.query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 &&
                            store.searchResults.isEmpty &&
                            !store.isSearching {
                            Text("No matching city yet. Try another spelling or a nearby metro area.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: "94A3B8"))
                                .padding(8)
                        } else {
                            ForEach(store.searchResults) { city in
                                Button {
                                    store.chooseCity(city)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(city.name)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(.white)
                                            Text([city.admin1, city.country].compactMap { $0 }.joined(separator: ", "))
                                                .font(.system(size: 12))
                                                .foregroundStyle(Color(hex: "94A3B8"))
                                        }

                                        Spacer()

                                        if city.id == store.selectedCity?.id {
                                            PillBadge(
                                                label: "Current",
                                                fill: Color(hex: "0B2233"),
                                                stroke: RidePressurePalette.action.opacity(0.5),
                                                text: Color(hex: "7DD3FC")
                                            )
                                        }
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(city.id == store.selectedCity?.id ? Color(hex: "172031") : Color(hex: "10141B"))
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .stroke(
                                                city.id == store.selectedCity?.id ? RidePressurePalette.action.opacity(0.45) : Color.white.opacity(0.06),
                                                lineWidth: 1
                                            )
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(6)
                    .background(Color(hex: "0F131A"))
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    }
                }
                .padding(20)
            }
            .background(RidePressurePalette.screenBackground.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .task(id: store.query) {
                let trimmed = store.query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.count >= 2 else {
                    store.clearSearchResults()
                    return
                }

                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else { return }
                await store.searchCities(matching: trimmed)
            }
            .onAppear {
                searchFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}
