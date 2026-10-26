import Foundation

/// Owns the saved TVs, the active connection and network scans.
@Observable
@MainActor
final class TVManager {
    /// One instance shared by the app, Siri and Shortcuts.
    static let shared = TVManager()

    enum Status: Equatable {
        case idle
        case connecting
        case connected
        case failed(String)
    }

    private(set) var saved: [TVDevice] = []
    private(set) var discovered: [TVDevice] = []
    private(set) var current: TVDevice?
    private(set) var status: Status = .idle
    private(set) var apps: [TVApp] = []
    private(set) var isLoadingApps = false
    private(set) var isScanning = false
    private(set) var hasScanned = false
    private(set) var scanProgress = 0.0
    /// A short message shown as a toast, such as "Opening Movies…".
    var notice: String?

    @ObservationIgnored private var controller: (any TVController)?
    @ObservationIgnored private var commandQueue: Task<Void, Never>?

    private static let savedKey = "savedTVs"
    private static let lastKey = "lastTVID"

    var isConnected: Bool { status == .connected }
    var supportsNumberPad: Bool { controller?.supportsNumberPad ?? false }
    var newlyDiscovered: [TVDevice] {
        discovered.filter { found in !saved.contains { $0.id == found.id } }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.savedKey),
           let devices = try? JSONDecoder().decode([TVDevice].self, from: data) {
            saved = devices
        }
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "demo") {
            Task { await connect(.demo) }
            return
        }
        if UserDefaults.standard.bool(forKey: "sampleTVs") {
            loadSampleTVs()
            return
        }
        #endif
        let lastID = UserDefaults.standard.string(forKey: Self.lastKey)
        if let last = saved.first(where: { $0.id == lastID }) {
            Task { await connect(last) }
        }
    }

    /// The free plan keeps one TV; adding a different one needs Premium. The demo TV is always free.
    func requiresPremium(_ device: TVDevice, isPremium: Bool) -> Bool {
        guard !isPremium, device.platform != .demo else { return false }
        let realTVs = saved.filter { $0.platform != .demo }
        return !realTVs.isEmpty && !realTVs.contains { $0.id == device.id }
    }

    func connect(_ device: TVDevice) async {
        controller?.disconnect()
        let controller = Self.makeController(for: device)
        self.controller = controller
        current = device
        status = .connecting
        apps = []
        UserDefaults.standard.set(device.id, forKey: Self.lastKey)
        do {
            try await controller.connect()
            guard self.controller === controller else { return }
            status = .connected
            remember(device)
            await refreshApps()
        } catch {
            guard self.controller === controller else { return }
            status = .failed(Self.describe(error))
        }
    }

    func reconnect() async {
        if let current { await connect(current) }
    }

    func forget(_ device: TVDevice) {
        saved.removeAll { $0.id == device.id }
        PairingStore.clear(for: device)
        persist()
        guard current?.id == device.id else { return }
        controller?.disconnect()
        controller = nil
        current = nil
        status = .idle
        apps = []
        UserDefaults.standard.removeObject(forKey: Self.lastKey)
    }

    func send(_ key: RemoteKey) {
        Haptics.tap()
        Speech.say(key.spokenName)
        enqueue { try await $0.send(key) }
    }

    /// Runs one command and waits for it to finish, reconnecting to the last TV first if needed.
    /// Used by routines, Siri and Shortcuts, which may run while the app is in the background.
    func perform(_ work: (any TVController) async throws -> Void) async throws {
        if !isConnected {
            let lastID = UserDefaults.standard.string(forKey: Self.lastKey)
            guard let device = current ?? saved.first(where: { $0.id == lastID }) ?? saved.first else { throw TVError.noTV }
            await connect(device)
        }
        guard let controller, isConnected else {
            if case .failed(let message) = status { throw TVCommandFailure(message: message) }
            throw TVError.unreachable
        }
        try await work(controller)
    }

    /// Opens a TV app by name, matching the exact name first, then any app whose name contains it.
    func openApp(named name: String) async throws {
        try await perform { _ in }
        if apps.isEmpty { await refreshApps() }
        let target = name.trimmingCharacters(in: .whitespaces)
        guard let app = apps.first(where: { $0.name.localizedCaseInsensitiveCompare(target) == .orderedSame })
            ?? apps.first(where: { $0.name.localizedCaseInsensitiveContains(target) }) else {
            throw TVError.appNotFound(target)
        }
        try await perform { try await $0.launch(app) }
    }

    func updateText(from old: String, to new: String) {
        enqueue { try await $0.updateText(from: old, to: new) }
    }

    func submitText() {
        enqueue { try await $0.submitText() }
    }

    func launch(_ app: TVApp) {
        Haptics.tap()
        notice = "Opening \(app.name)…"
        enqueue { try await $0.launch(app) }
    }

    func refreshApps() async {
        guard let controller, isConnected else { return }
        isLoadingApps = true
        defer { isLoadingApps = false }
        if let list = try? await controller.installedApps() {
            apps = list
        }
    }

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0
        discovered = []
        for await event in NetworkScanner.scan() {
            switch event {
            case .progress(let value):
                scanProgress = value
            case .found(let device):
                discovered.append(device)
                refreshSavedDetails(from: device)
            }
        }
        discovered.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        isScanning = false
        hasScanned = true
    }

    /// Checks one address the user typed. Falls back to the brand they picked if the TV doesn't answer a probe.
    func device(atHost host: String, platform: TVPlatform?) async -> TVDevice? {
        if let found = await NetworkScanner.probe(host, timeout: 3) { return found }
        guard let platform else { return nil }
        return TVDevice(name: "\(platform.brand) TV", model: nil, host: host, platform: platform)
    }

    // MARK: - Private

    private func enqueue(_ work: @escaping (any TVController) async throws -> Void) {
        guard let controller, isConnected else {
            notice = current == nil ? "Choose a TV in the TVs tab first." : "Not connected. Tap Reconnect."
            return
        }
        // Commands run one after another so key presses and typing arrive in order.
        let previous = commandQueue
        commandQueue = Task {
            await previous?.value
            do {
                try await work(controller)
            } catch {
                guard self.controller === controller else { return }
                self.handleCommandError(error)
            }
        }
    }

    private func handleCommandError(_ error: Error) {
        switch error {
        case TVError.rokuLimited, TVError.unsupported, TVError.badResponse, TVError.appNotFound:
            notice = Self.describe(error)
        default:
            controller?.disconnect()
            status = .failed("Lost the connection to \(current?.name ?? "your TV"). Make sure it's on, then reconnect.")
        }
    }

    private func remember(_ device: TVDevice) {
        if let index = saved.firstIndex(where: { $0.id == device.id }) {
            saved[index] = device
        } else {
            saved.append(device)
        }
        persist()
    }

    /// Keeps saved names in sync if someone renamed their TV.
    private func refreshSavedDetails(from device: TVDevice) {
        guard let index = saved.firstIndex(where: { $0.id == device.id }), saved[index] != device else { return }
        saved[index] = device
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: Self.savedKey)
        }
    }

    #if DEBUG
    /// Example TVs for App Store screenshots (`-sampleTVs YES`), driven by the demo TV.
    private func loadSampleTVs() {
        saved = [
            TVDevice(name: "Living Room TV", model: "Streaming player", host: "192.168.1.23", platform: .roku),
            TVDevice(name: "Bedroom TV", model: "Smart TV", host: "192.168.1.41", platform: .samsung),
        ]
        discovered = saved + [TVDevice(name: "Kitchen TV", model: "webOS", host: "192.168.1.57", platform: .lg)]
        hasScanned = true
        current = saved[0]
        controller = DemoController(device: saved[0])
        status = .connected
        apps = DemoTV.apps
    }
    #endif

    private static func makeController(for device: TVDevice) -> any TVController {
        switch device.platform {
        case .roku: RokuController(device: device)
        case .samsung: SamsungController(device: device)
        case .lg: LGController(device: device)
        case .demo: DemoController()
        }
    }

    static func describe(_ error: Error) -> String {
        if let error = error as? TVError { return error.errorDescription ?? "" }
        if error is URLError { return TVError.unreachable.errorDescription ?? "" }
        return error.localizedDescription
    }
}

/// A connection failure with the message already shown in the app, so Siri can say the same thing.
struct TVCommandFailure: LocalizedError, CustomLocalizedStringResourceConvertible {
    let message: String
    var errorDescription: String? { message }
    var localizedStringResource: LocalizedStringResource { "\(message)" }
}
