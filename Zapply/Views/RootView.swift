import SwiftUI

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @Environment(AppRouter.self) private var router

    var body: some View {
        Group {
            if hasOnboarded {
                MainTabView()
            } else {
                OnboardingView {
                    router.tab = .tvs
                    router.paywall = .upgrade
                    hasOnboarded = true
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            RemoteView()
                .tabItem { Label("Remote", systemImage: "av.remote.fill") }
                .tag(AppRouter.Tab.remote)
            AppsView()
                .tabItem { Label("Apps", systemImage: "square.grid.2x2.fill") }
                .tag(AppRouter.Tab.apps)
            DevicesView()
                .tabItem { Label("TVs", systemImage: "tv") }
                .tag(AppRouter.Tab.tvs)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppRouter.Tab.settings)
        }
        .overlay(alignment: .top) { NoticeToast() }
        .fullScreenCover(item: $router.paywall) { feature in
            PaywallView(feature: feature)
        }
    }
}

/// Brief status messages ("Opening Movies…") that fade out on their own.
struct NoticeToast: View {
    @Environment(TVManager.self) private var tvs

    var body: some View {
        ZStack {
            if let notice = tvs.notice {
                Text(notice)
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { tvs.notice = nil }
                    .task(id: notice) {
                        try? await Task.sleep(for: .seconds(3))
                        if tvs.notice == notice { tvs.notice = nil }
                    }
            }
        }
        .animation(.spring(duration: 0.3), value: tvs.notice)
    }
}
