import Foundation

/// Samsung Tizen TVs (2016 and later): a WebSocket on 8002 (TLS, token-paired) or 8001 on older models.
@MainActor
final class SamsungController: TVController {
    let device: TVDevice
    var supportsNumberPad: Bool { true }

    private var socket: SocketConnection?
    private var handshake: Pending<Void>?
    private var appsRequest: Pending<[TVApp]>?
    private var isPlaying = true

    private static let clientName = Data("Zapply Remote".utf8).base64EncodedString()

    /// Common Tizen app IDs, probed over REST when the TV won't share its full app list.
    private static let knownApps: [(id: String, name: String)] = [
        ("3201907018807", "Netflix"), ("111299001912", "YouTube"), ("3201910019365", "Prime Video"),
        ("3201901017640", "Disney+"), ("3201807016597", "Apple TV"), ("3201606009684", "Spotify"),
        ("3201601007625", "Hulu"), ("3201512006963", "Plex"), ("3201707014489", "YouTube TV"),
        ("3201710014981", "Paramount+"), ("3202006020991", "Peacock"), ("org.tizen.browser", "Internet"),
    ]

    init(device: TVDevice) {
        self.device = device
    }

    func connect() async throws {
        var lastError: Error = TVError.unreachable
        for secure in [true, false] {
            do {
                try await open(secure: secure)
                return
            } catch TVError.denied {
                throw TVError.denied
            } catch {
                lastError = error
                socket?.close()
                socket = nil
            }
        }
        throw lastError
    }

    func disconnect() {
        socket?.close()
        socket = nil
    }

    func send(_ key: RemoteKey) async throws {
        try await sendKey(code(for: key))
    }

    func updateText(from old: String, to new: String) async throws {
        // The TV's input field takes the whole string, so send the current text each time.
        let encoded = Data(new.utf8).base64EncodedString()
        try await requireSocket().send(json: [
            "method": "ms.remote.control",
            "params": ["Cmd": encoded, "DataOfCmd": "base64", "TypeOfRemote": "SendInputString"],
        ])
    }

    func submitText() async throws {
        try await requireSocket().send(json: ["method": "ms.remote.control", "params": ["TypeOfRemote": "SendInputEnd"]])
    }

    func installedApps() async throws -> [TVApp] {
        let socket = try requireSocket()
        let request = Pending<[TVApp]>()
        appsRequest = request
        try await socket.send(json: ["method": "ms.channel.emit", "params": ["event": "ed.installedApp.get", "to": "host"]])
        let apps = (try? await request.wait(timeout: 6)) ?? []
        if !apps.isEmpty {
            return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return await probeKnownApps()
    }

    func launch(_ app: TVApp) async throws {
        if let kind = app.launchKind, let socket {
            try await socket.send(json: [
                "method": "ms.channel.emit",
                "params": ["event": "ed.apps.launch", "to": "host",
                           "data": ["appId": app.id, "action_type": kind == "2" ? "DEEP_LINK" : "NATIVE_LAUNCH"]],
            ])
        } else {
            var request = URLRequest(url: URL(string: "http://\(device.host):8001/api/v2/applications/\(app.id)")!)
            request.httpMethod = "POST"
            _ = try await TVNetwork.session.data(for: request)
        }
    }

    // MARK: - Connection

    private func open(secure: Bool) async throws {
        var components = URLComponents()
        components.scheme = secure ? "wss" : "ws"
        components.host = device.host
        components.port = secure ? 8002 : 8001
        components.path = "/api/v2/channels/samsung.remote.control"
        var query = [URLQueryItem(name: "name", value: Self.clientName)]
        if secure, let token = PairingStore.token(for: device) {
            query.append(URLQueryItem(name: "token", value: token))
        }
        components.queryItems = query
        guard let url = components.url else { throw TVError.unreachable }

        let socket = SocketConnection(url: url)
        let handshake = Pending<Void>()
        self.socket = socket
        self.handshake = handshake
        socket.onText = { [weak self] text in self?.handle(text) }
        socket.onClose = { [weak handshake] _ in handshake?.fail(TVError.unreachable) }
        socket.open()
        // Long enough for someone to find the TV remote and press Allow.
        try await handshake.wait(timeout: 30)
    }

    private func handle(_ text: String) {
        guard let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
              let event = json["event"] as? String else { return }
        switch event {
        case "ms.channel.connect":
            if let data = json["data"] as? [String: Any], let token = data["token"] {
                PairingStore.setToken("\(token)", for: device)
            }
            handshake?.succeed(())
        case "ms.channel.unauthorized":
            handshake?.fail(TVError.denied)
        case "ms.channel.timeOut":
            handshake?.fail(TVError.timedOut)
        case "ed.installedApp.get":
            let list = (json["data"] as? [String: Any])?["data"] as? [[String: Any]] ?? []
            appsRequest?.succeed(list.compactMap { item in
                guard let id = item["appId"] as? String, let name = item["name"] as? String else { return nil }
                return TVApp(id: id, name: name, launchKind: item["app_type"].map { "\($0)" } ?? "")
            })
        default:
            break
        }
    }

    private func requireSocket() throws -> SocketConnection {
        guard let socket else { throw TVError.unreachable }
        return socket
    }

    private func sendKey(_ code: String) async throws {
        try await requireSocket().send(json: [
            "method": "ms.remote.control",
            "params": ["Cmd": "Click", "DataOfCmd": code, "Option": "false", "TypeOfRemote": "SendRemoteKey"],
        ])
    }

    private func probeKnownApps() async -> [TVApp] {
        let host = device.host
        return await withTaskGroup(of: TVApp?.self) { group in
            for app in Self.knownApps {
                group.addTask {
                    guard let url = URL(string: "http://\(host):8001/api/v2/applications/\(app.id)"),
                          let (_, response) = try? await TVNetwork.session.data(from: url),
                          (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
                    return TVApp(id: app.id, name: app.name)
                }
            }
            var found: [TVApp] = []
            for await app in group {
                if let app { found.append(app) }
            }
            return found.sorted { $0.name < $1.name }
        }
    }

    private func code(for key: RemoteKey) -> String {
        switch key {
        case .up: return "KEY_UP"
        case .down: return "KEY_DOWN"
        case .left: return "KEY_LEFT"
        case .right: return "KEY_RIGHT"
        case .select: return "KEY_ENTER"
        case .back: return "KEY_RETURN"
        case .home: return "KEY_HOME"
        case .menu: return "KEY_MENU"
        case .info: return "KEY_INFO"
        case .power: return "KEY_POWER"
        case .volumeUp: return "KEY_VOLUP"
        case .volumeDown: return "KEY_VOLDOWN"
        case .mute: return "KEY_MUTE"
        case .channelUp: return "KEY_CHUP"
        case .channelDown: return "KEY_CHDOWN"
        case .rewind: return "KEY_REWIND"
        case .fastForward: return "KEY_FF"
        case .digit(let number): return "KEY_\(number)"
        case .playPause:
            isPlaying.toggle()
            return isPlaying ? "KEY_PLAY" : "KEY_PAUSE"
        }
    }
}
