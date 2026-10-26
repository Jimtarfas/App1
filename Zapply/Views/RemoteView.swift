import SwiftUI

struct RemoteView: View {
    @Environment(TVManager.self) private var tvs
    @Environment(SubscriptionStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(RemotePreferences.self) private var prefs

    var body: some View {
        @Bindable var router = router
        ScrollView {
            VStack(spacing: 16) {
                header
                if tvs.current?.platform == .demo {
                    DemoScreenView()
                        .padding(.horizontal, prefs.layout == .bigButtons ? 64 : 40)
                } else if !tvs.isConnected {
                    ConnectionCard()
                        .padding(.horizontal, 20)
                }
                switch prefs.layout {
                case .bigButtons: bigButtons
                case .full: fullRemote
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(prefs.background.ignoresSafeArea())
        .environment(\.keyColors, prefs.keyColors)
        .sheet(item: $router.remoteSheet) { sheet in
            switch sheet {
            case .keyboard: KeyboardSheet()
            case .numberPad: NumberPadSheet()
            }
        }
    }

    // MARK: - Layouts

    /// The default layout: fewer controls, each large and labeled, sized by the user's preference.
    private var bigButtons: some View {
        let scale = prefs.buttonSize.scale
        return VStack(spacing: 12 * scale) {
            HStack(spacing: 12) {
                labeled(.back, title: "Back", scale: scale)
                labeled(.home, title: "Home", scale: scale)
            }
            DPad(size: min(196 * scale, 280), press: press)
                .padding(.vertical, 2)
            HStack(spacing: 12) {
                labeled(.volumeDown, title: "Volume", symbol: "minus", scale: scale)
                labeled(.volumeUp, title: "Volume", symbol: "plus", scale: scale)
            }
            HStack(spacing: 12) {
                labeled(.mute, title: "Mute", scale: scale)
                labeled(.playPause, title: "Play/Pause", scale: scale)
            }
            HStack(spacing: 12) {
                LabeledKey(title: "Channel", symbol: "minus", scale: scale, isLocked: !store.isPremium) { channel(.channelDown) }
                    .accessibilityLabel("Channel down")
                LabeledKey(title: "Channel", symbol: "plus", scale: scale, isLocked: !store.isPremium) { channel(.channelUp) }
                    .accessibilityLabel("Channel up")
            }
            HStack(spacing: 12) {
                LabeledKey(title: "Keyboard", symbol: "keyboard", scale: scale, isLocked: !store.isPremium) {
                    openPremium(.keyboard) { router.remoteSheet = .keyboard }
                }
                LabeledKey(title: "Numbers", symbol: "textformat.123", scale: scale, isLocked: !store.isPremium) {
                    openPremium(.channels) { router.remoteSheet = .numberPad }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    /// Every control, in the classic remote arrangement.
    private var fullRemote: some View {
        VStack(spacing: 16) {
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
                        premiumKey("keyboard", label: "Keyboard", feature: .keyboard) { router.remoteSheet = .keyboard }
                    }
                    GridRow {
                        key(.info, "info.circle", label: "Info", size: 56)
                        premiumKey("textformat.123", label: "Number pad", feature: .channels) { router.remoteSheet = .numberPad }
                    }
                }
                Spacer()
                Rocker(title: "CH", up: .channelUp, down: .channelDown, isLocked: !store.isPremium, action: channel)
            }
            .padding(.horizontal, 30)
            HStack(spacing: 36) {
                key(.rewind, "backward.fill", label: "Rewind", size: 50)
                key(.playPause, "playpause.fill", label: "Play or pause", size: 50)
                key(.fastForward, "forward.fill", label: "Fast forward", size: 50)
            }
        }
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
                .buttonStyle(RoundKeyStyle(size: prefs.layout == .bigButtons ? 50 * prefs.buttonSize.scale : 50, tint: Theme.power))
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

    // MARK: - Actions

    private func press(_ key: RemoteKey) {
        guard tvs.current != nil else {
            router.tab = .tvs
            return
        }
        tvs.send(key)
    }

    private func channel(_ key: RemoteKey) {
        if store.isPremium {
            press(key)
        } else {
            router.paywall = .channels
        }
    }

    private func openPremium(_ feature: PremiumFeature, open: () -> Void) {
        Haptics.tap()
        if !store.isPremium {
            router.paywall = feature
        } else if tvs.isConnected {
            open()
        } else {
            tvs.notice = "Connect to a TV first."
        }
    }

    private func labeled(_ key: RemoteKey, title: String, symbol: String? = nil, scale: CGFloat) -> some View {
        LabeledKey(title: title, symbol: symbol ?? key.symbol, scale: scale) { press(key) }
            .accessibilityLabel(key.spokenName)
    }

    private func key(_ key: RemoteKey, _ symbol: String, label: String, size: CGFloat = 60) -> some View {
        Button { press(key) } label: { Image(systemName: symbol) }
            .buttonStyle(RoundKeyStyle(size: size))
            .accessibilityLabel(label)
    }

    private func premiumKey(_ symbol: String, label: String, feature: PremiumFeature, open: @escaping () -> Void) -> some View {
        Button {
            openPremium(feature, open: open)
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

/// A wide remote key showing an icon and a word, so nobody has to guess what a symbol means.
struct LabeledKey: View {
    let title: String
    let symbol: String
    var scale: CGFloat = 1
    var isLocked = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10 * scale) {
                Image(systemName: symbol)
                    .font(.system(size: 21 * scale, weight: .bold))
                Text(title)
                    .font(.system(size: 19 * scale, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 58 * scale)
            .contentShape(Rectangle())
        }
        .buttonStyle(LabeledKeyStyle())
        .overlay(alignment: .topTrailing) {
            if isLocked { LockBadge().offset(x: -8, y: 8) }
        }
        .accessibilityLabel(isLocked ? "\(title), Premium" : title)
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
