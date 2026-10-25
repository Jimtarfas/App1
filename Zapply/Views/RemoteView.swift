import SwiftUI

struct RemoteView: View {
    @Environment(TVManager.self) private var tvs
    @Environment(SubscriptionStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var showKeyboard = false
    @State private var showNumberPad = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                if tvs.current?.platform == .demo {
                    DemoScreenView()
                        .padding(.horizontal, 40)
                } else if !tvs.isConnected {
                    ConnectionCard()
                        .padding(.horizontal, 20)
                }
                HStack(spacing: 28) {
                    key(.back, "arrow.uturn.backward", label: "Back")
                    key(.home, "house.fill", label: "Home")
                    key(.menu, "line.3.horizontal", label: "Menu")
                }
                DPad(press: press)
                HStack(alignment: .center) {
                    Rocker(title: "VOL", up: .volumeUp, down: .volumeDown, action: press)
                    Spacer()
                    Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                        GridRow {
                            key(.mute, "speaker.slash.fill", label: "Mute", size: 56)
                            premiumKey("keyboard", label: "Keyboard", feature: .keyboard) { showKeyboard = true }
                        }
                        GridRow {
                            key(.info, "info.circle", label: "Info", size: 56)
                            premiumKey("textformat.123", label: "Number pad", feature: .channels) { showNumberPad = true }
                        }
                    }
                    Spacer()
                    Rocker(title: "CH", up: .channelUp, down: .channelDown, isLocked: !store.isPremium) { key in
                        if store.isPremium { press(key) } else { router.paywall = .channels }
                    }
                }
                .padding(.horizontal, 30)
                HStack(spacing: 36) {
                    key(.rewind, "backward.fill", label: "Rewind", size: 50)
                    key(.playPause, "playpause.fill", label: "Play or pause", size: 50)
                    key(.fastForward, "forward.fill", label: "Fast forward", size: 50)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.background.ignoresSafeArea())
        .sheet(isPresented: $showKeyboard) { KeyboardSheet() }
        .sheet(isPresented: $showNumberPad) { NumberPadSheet() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { router.tab = .tvs } label: {
                HStack(spacing: 12) {
                    Image(systemName: tvs.current?.platform.symbol ?? "tv")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tvs.current?.name ?? "No TV connected")
                            .font(.headline)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Circle().fill(statusColor).frame(width: 7, height: 7)
                            Text(statusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Choose a TV")
            Spacer()
            Button { press(.power) } label: { Image(systemName: "power") }
                .buttonStyle(RoundKeyStyle(size: 50, tint: Theme.power))
                .accessibilityLabel("Power")
        }
        .padding(.horizontal, 20)
    }

    private var statusText: String {
        switch tvs.status {
        case .idle: "Tap to choose a TV"
        case .connecting: "Connecting…"
        case .connected: tvs.current?.platform == .demo ? "Demo mode" : "Connected"
        case .failed: "Not connected"
        }
    }

    private var statusColor: Color {
        switch tvs.status {
        case .connected: .green
        case .connecting: Theme.gold
        case .idle, .failed: .gray
        }
    }

    private func press(_ key: RemoteKey) {
        guard tvs.current != nil else {
            router.tab = .tvs
            return
        }
        tvs.send(key)
    }

    private func key(_ key: RemoteKey, _ symbol: String, label: String, size: CGFloat = 60) -> some View {
        Button { press(key) } label: { Image(systemName: symbol) }
            .buttonStyle(RoundKeyStyle(size: size))
            .accessibilityLabel(label)
    }

    private func premiumKey(_ symbol: String, label: String, feature: PremiumFeature, open: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            if !store.isPremium {
                router.paywall = feature
            } else if tvs.isConnected {
                open()
            } else {
                tvs.notice = "Connect to a TV first."
            }
        } label: {
            Image(systemName: symbol)
        }
        .buttonStyle(RoundKeyStyle(size: 56))
        .overlay(alignment: .topTrailing) {
            if !store.isPremium { LockBadge().offset(x: 3, y: -3) }
        }
        .accessibilityLabel(label)
    }
}

/// Shown above the remote while no real TV is connected.
private struct ConnectionCard: View {
    @Environment(TVManager.self) private var tvs
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(spacing: 10) {
            switch tvs.status {
            case .connecting:
                ProgressView()
                Text("Connecting to \(tvs.current?.name ?? "your TV")…")
                    .font(.subheadline.weight(.semibold))
                if let hint = tvs.current?.platform.pairingHint {
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            case .failed(let message):
                Image(systemName: "wifi.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(Theme.gold)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button("Reconnect") { Task { await tvs.reconnect() } }
                        .buttonStyle(.borderedProminent)
                    Button("Choose TV") { router.tab = .tvs }
                        .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            case .idle, .connected:
                Image(systemName: "tv.and.mediabox")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                Text("Connect your TV")
                    .font(.headline)
                Text("Your iPhone and TV need to be on the same Wi-Fi network.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Find TVs") { router.tab = .tvs }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
