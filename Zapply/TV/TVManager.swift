import Foundation

/// Owns the saved TVs, the active connection and network scans.
@Observable
@MainActor
final class TVManager {
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
        enqueue { try await $0.send(key) }
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
        case TVError.rokuLimited, TVError.unsupported, TVError.badResponse:
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

    private static func makeController(for device: TVDevice) -> any TVController {
        switch device.platform {
        case .roku: RokuController(device: device)
        case .samsung: SamsungController(device: device)
        case .lg: LGController(device: device)
        case .demo: DemoController()
        }
    }

    private static func describe(_ error: Error) -> String {
        if let error = error as? TVError { return error.errorDescription ?? "" }
        if error is URLError { return TVError.unreachable.errorDescription ?? "" }
        return error.localizedDescription
    }
}
