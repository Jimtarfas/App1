import Foundation

/// A virtual TV drawn inside the app, so every control can be tried without a TV on the network.
@Observable
@MainActor
final class DemoTV {
    static let shared = DemoTV()
    static let columns = 4
    static let apps: [TVApp] = [
        TVApp(id: "movies", name: "Movies", symbol: "film", paletteIndex: 0),
        TVApp(id: "series", name: "Series", symbol: "play.tv", paletteIndex: 4),
        TVApp(id: "music", name: "Music", symbol: "music.note", paletteIndex: 1),
        TVApp(id: "sports", name: "Sports", symbol: "sportscourt", paletteIndex: 3),
        TVApp(id: "news", name: "News", symbol: "newspaper", paletteIndex: 5),
        TVApp(id: "kids", name: "Kids", symbol: "teddybear", paletteIndex: 6),
        TVApp(id: "photos", name: "Photos", symbol: "photo.on.rectangle", paletteIndex: 2),
        TVApp(id: "live", name: "Live TV", symbol: "antenna.radiowaves.left.and.right", paletteIndex: 7),
    ]

    var isOn = true
    var focus = 0
    var openApp: TVApp?
    var isPlaying = true
    var volume = 18
    var isMuted = false
    var channel = 7
    var searchText = ""
    var banner: String?

    @ObservationIgnored private var bannerTask: Task<Void, Never>?
    @ObservationIgnored private var digits = ""
    @ObservationIgnored private var digitTask: Task<Void, Never>?

    func press(_ key: RemoteKey) {
        if key == .power {
            isOn.toggle()
            return
        }
        guard isOn else { return }
        switch key {
        case .up: moveFocus(by: -Self.columns)
        case .down: moveFocus(by: Self.columns)
        case .left: moveFocus(by: -1)
        case .right: moveFocus(by: 1)
        case .select:
            if openApp == nil { launch(Self.apps[focus]) } else { togglePlayback() }
        case .back:
            if openApp != nil { openApp = nil } else { searchText = "" }
        case .home:
            openApp = nil
            focus = 0
        case .menu: show("Options")
        case .info: show(openApp.map { "Now on: \($0.name)" } ?? "Home screen")
        case .volumeUp:
            volume = min(volume + 1, 100)
            isMuted = false
            show("Volume \(volume)")
        case .volumeDown:
            volume = max(volume - 1, 0)
            show("Volume \(volume)")
        case .mute:
            isMuted.toggle()
            show(isMuted ? "Muted" : "Volume \(volume)")
        case .channelUp:
            channel += 1
            tuneLive()
        case .channelDown:
            channel = max(channel - 1, 1)
            tuneLive()
        case .digit(let number): enterDigit(number)
        case .playPause: togglePlayback()
        case .rewind: if openApp != nil { show("Rewind") }
        case .fastForward: if openApp != nil { show("Fast forward") }
        case .power: break
        }
    }

    func launch(_ app: TVApp) {
        isOn = true
        openApp = app
        isPlaying = true
        if let index = Self.apps.firstIndex(of: app) { focus = index }
    }

    func setSearch(_ text: String) {
        openApp = nil
        searchText = text
    }

    func show(_ text: String) {
        banner = text
        bannerTask?.cancel()
        bannerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            self?.banner = nil
        }
    }

    private func moveFocus(by delta: Int) {
        guard openApp == nil else { return }
        let next = focus + delta
        let sameRow = next / Self.columns == focus / Self.columns
        guard Self.apps.indices.contains(next), abs(delta) != 1 || sameRow else { return }
        focus = next
    }

    private func togglePlayback() {
        guard openApp != nil else { return }
        isPlaying.toggle()
        show(isPlaying ? "Play" : "Paused")
    }

    private func tuneLive() {
        if let live = Self.apps.last { launch(live) }
        show("Channel \(channel)")
    }

    private func enterDigit(_ number: Int) {
        digits = String((digits + "\(number)").suffix(3))
        show("Channel \(digits)")
        digitTask?.cancel()
        digitTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self, let value = Int(self.digits) else { return }
            self.channel = max(value, 1)
            self.digits = ""
            self.tuneLive()
        }
    }
}

@MainActor
final class DemoController: TVController {
    let device: TVDevice
    var supportsNumberPad: Bool { true }

    private let tv = DemoTV.shared

    init(device: TVDevice = .demo) {
        self.device = device
    }

    func connect() async throws {
        try await Task.sleep(for: .milliseconds(350))
        tv.isOn = true
    }

    func disconnect() {}

    func send(_ key: RemoteKey) async throws {
        tv.press(key)
    }

    func updateText(from old: String, to new: String) async throws {
        tv.setSearch(new)
    }

    func submitText() async throws {
        tv.show(tv.searchText.isEmpty ? "Search" : "Searching \u{201C}\(tv.searchText)\u{201D}")
    }

    func installedApps() async throws -> [TVApp] {
        DemoTV.apps
    }

    func launch(_ app: TVApp) async throws {
        tv.launch(app)
    }
}
