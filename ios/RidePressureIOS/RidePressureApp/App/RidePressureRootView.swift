import SwiftUI

struct RidePressureRootView: View {
    @ObservedObject var store: RidePressureStore

    @State private var showingLaunchOverlay = true
    @State private var hasBootstrapped = false
    @State private var hasScheduledAutomaticDetection = false

    var body: some View {
        ZStack {
            DashboardView(store: store)

            if showingLaunchOverlay {
                LaunchOverlayView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            guard !hasBootstrapped else { return }
            hasBootstrapped = true

            try? await Task.sleep(nanoseconds: 1_300_000_000)

            await store.loadInitialState()

            withAnimation(.easeOut(duration: 0.45)) {
                showingLaunchOverlay = false
            }
        }
        .task(id: showingLaunchOverlay) {
            guard !showingLaunchOverlay else { return }
            guard !hasScheduledAutomaticDetection else { return }

            hasScheduledAutomaticDetection = true

            try? await Task.sleep(nanoseconds: 1_750_000_000)
            guard !Task.isCancelled else { return }
            guard !store.isSearchPresented else { return }

            await store.runQueuedAutomaticDetectionIfNeeded()
        }
    }
}
