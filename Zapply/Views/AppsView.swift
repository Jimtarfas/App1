import SwiftUI
import UIKit

struct AppsView: View {
    @Environment(TVManager.self) private var tvs
    @Environment(AppRouter.self) private var router

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                if !tvs.isConnected {
                    ContentUnavailableView {
                        Label("No TV connected", systemImage: "tv.slash")
                    } description: {
                        Text("Connect to a TV to open its apps from here.")
                    } actions: {
                        Button("Find TVs") { router.tab = .tvs }
                            .buttonStyle(.borderedProminent)
                    }
                } else if tvs.apps.isEmpty {
                    if tvs.isLoadingApps {
                        ProgressView("Loading apps…")
                    } else {
                        ContentUnavailableView {
                            Label("No apps found", systemImage: "square.grid.2x2")
                        } description: {
                            Text("Your TV didn't share its app list. Try again in a moment.")
                        } actions: {
                            Button("Try Again") { Task { await tvs.refreshApps() } }
                                .buttonStyle(.bordered)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(tvs.apps) { app in
                                Button { tvs.launch(app) } label: { AppTile(app: app) }
                                    .buttonStyle(PressScaleStyle())
                            }
                        }
                        .padding(20)
                    }
                    .refreshable { await tvs.refreshApps() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Apps")
        }
    }
}

private struct AppTile: View {
    let app: TVApp
    @State private var icon: UIImage?

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Rectangle().fill(AppPalette.color(for: app).gradient)
                if let icon {
                    Image(uiImage: icon)
                        .resizable()
                        .scaledToFill()
                } else if let symbol = app.symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    Text(String(app.name.prefix(1)).uppercased())
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .aspectRatio(4 / 3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.stroke))
            Text(app.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Open \(app.name)")
        .task(id: app.iconURL) {
            if let url = app.iconURL { icon = await IconLoader.shared.image(at: url) }
        }
    }
}

/// Loads app icons served by the TV (which may use a self-signed certificate) and keeps them in memory.
actor IconLoader {
    static let shared = IconLoader()
    private var cache: [URL: UIImage] = [:]

    func image(at url: URL) async -> UIImage? {
        if let cached = cache[url] { return cached }
        guard let (data, _) = try? await TVNetwork.session.data(from: url), let image = UIImage(data: data) else { return nil }
        cache[url] = image
        return image
    }
}
