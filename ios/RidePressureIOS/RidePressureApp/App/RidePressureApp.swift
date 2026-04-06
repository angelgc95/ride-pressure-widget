import SwiftUI

@main
struct RidePressureApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = RidePressureStore()

    var body: some Scene {
        WindowGroup {
            RidePressureRootView(store: store)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task {
                        await store.refreshIfNeeded()
                    }
                }
        }
    }
}
