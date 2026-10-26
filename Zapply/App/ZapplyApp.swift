import SwiftUI

@main
struct ZapplyApp: App {
    @State private var store = SubscriptionStore.shared
    @State private var tvs = TVManager.shared
    @State private var router = AppRouter()
    @State private var routines = RoutineStore.shared
    @State private var prefs = RemotePreferences.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(tvs)
                .environment(router)
                .environment(routines)
                .environment(prefs)
                .tint(Theme.accent)
                #if DEBUG
                .task { DemoAutoplay.shared.start(router: router, tvs: tvs, store: store) }
                #endif
        }
    }
}
