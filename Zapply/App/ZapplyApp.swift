import SwiftUI

@main
struct ZapplyApp: App {
    @State private var store = SubscriptionStore()
    @State private var tvs = TVManager()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(tvs)
                .environment(router)
                .tint(Theme.accent)
                #if DEBUG
                .task { DemoAutoplay.shared.start(router: router, tvs: tvs, store: store) }
                #endif
        }
    }
}
