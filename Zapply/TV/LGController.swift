import Foundation

/// LG webOS TVs: SSAP requests over a WebSocket on 3001 (TLS) or 3000, plus a second
/// "pointer" socket for navigation buttons.
@MainActor
final class LGController: TVController {
    let device: TVDevice
    var supportsNumberPad: Bool { true }

    private var socket: SocketConnection?
    private var pointer: SocketConnection?
    private var registration: Pending<Void>?
    private var requests: [String: Pending<[String: Any]>] = [:]
    private var nextRequestID = 1
    private var isSecure = true
    private var isPlaying = true

    init(device: TVDevice) {
        self.device = device
    }

    func connect() async throws {
        var lastError: Error = TVError.unreachable
        for secure in [true, false] {
            do {
                try await open(secure: secure)
                isSecure = secure
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
        pointer?.close()
        socket?.close()
        pointer = nil
        socket = nil
    }

    func send(_ key: RemoteKey) async throws {
        switch key {
        case .power: try await request("ssap://system/turnOff")
        case .volumeUp: try await request("ssap://audio/volumeUp")
        case .volumeDown: try await request("ssap://audio/volumeDown")
        case .channelUp: try await request("ssap://tv/channelUp")
        case .channelDown: try await request("ssap://tv/channelDown")
        case .rewind: try await request("ssap://media.controls/rewind")
        case .fastForward: try await request("ssap://media.controls/fastForward")
        case .playPause:
            isPlaying.toggle()
            try await request(isPlaying ? "ssap://media.controls/play" : "ssap://media.controls/pause")
        case .up: try await button("UP")
        case .down: try await button("DOWN")
        case .left: try await button("LEFT")
        case .right: try await button("RIGHT")
        case .select: try await button("ENTER")
        case .back: try await button("BACK")
        case .home: try await button("HOME")
        case .menu: try await button("MENU")
        case .info: try await button("INFO")
        case .mute: try await button("MUTE")
        case .digit(let number): try await button("\(number)")
        }
    }

    func updateText(from old: String, to new: String) async throws {
        let diff = TextDiff.between(old, new)
        if diff.delete > 0 {
            try await request("ssap://com.webos.service.ime/deleteCharacters", payload: ["count": diff.delete])
        }
        if !diff.insert.isEmpty {
            try await request("ssap://com.webos.service.ime/insertText", payload: ["text": diff.insert, "replace": 0])
        }
    }

    func submitText() async throws {
        try await request("ssap://com.webos.service.ime/sendEnterKey")
    }

    func installedApps() async throws -> [TVApp] {
        let payload = try await request("ssap://com.webos.applicationManager/listLaunchPoints", awaitReply: true)
        let points = payload["launchPoints"] as? [[String: Any]] ?? []
        return points.compactMap { point in
            guard let id = point["id"] as? String, let title = point["title"] as? String else { return nil }
            let icon = (point["largeIcon"] as? String) ?? (point["icon"] as? String)
            return TVApp(id: id, name: title, iconURL: icon.flatMap(URL.init(string:)))
        }
    }

    func launch(_ app: TVApp) async throws {
        try await request("ssap://system.launcher/launch", payload: ["id": app.id])
    }

    // MARK: - Connection

    private func open(secure: Bool) async throws {
        let url = URL(string: secure ? "wss://\(device.host):3001" : "ws://\(device.host):3000")!
        let socket = SocketConnection(url: url)
        let registration = Pending<Void>()
        self.socket = socket
        self.registration = registration
        socket.onText = { [weak self] text in self?.handle(text) }
        socket.onClose = { [weak registration] _ in registration?.fail(TVError.unreachable) }
        socket.open()

        var payload = LGManifest.registration
        if let key = PairingStore.token(for: device) {
            payload["client-key"] = key
        }
        try await socket.send(json: ["type": "register", "id": "register_0", "payload": payload])
        // Long enough for someone to accept the prompt on the TV.
        try await registration.wait(timeout: 40)
    }

    private func handle(_ text: String) {
        guard let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { return }
        let type = json["type"] as? String
        let id = json["id"] as? String
        let payload = json["payload"] as? [String: Any] ?? [:]

        if id == "register_0" {
            switch type {
            case "registered":
                if let key = payload["client-key"] as? String {
                    PairingStore.setToken(key, for: device)
                }
                registration?.succeed(())
            case "error":
                registration?.fail(TVError.denied)
            default:
                break // A "response" here means the TV is showing its pairing prompt.
            }
            return
        }
        guard let id, let pending = requests.removeValue(forKey: id) else { return }
        if type == "error" {
            pending.fail(TVError.unsupported)
        } else {
            pending.succeed(payload)
        }
    }

    @discardableResult
    private func request(_ uri: String, payload: [String: Any]? = nil, awaitReply: Bool = false) async throws -> [String: Any] {
        guard let socket else { throw TVError.unreachable }
        let id = "req_\(nextRequestID)"
        nextRequestID += 1
        var message: [String: Any] = ["type": "request", "id": id, "uri": uri]
        if let payload { message["payload"] = payload }

        guard awaitReply else {
            try await socket.send(json: message)
            return [:]
        }
        let pending = Pending<[String: Any]>()
        requests[id] = pending
        defer { requests[id] = nil }
        try await socket.send(json: message)
        return try await pending.wait(timeout: 8)
    }

    private func button(_ name: String) async throws {
        try await pointerSocket().send("type:button\nname:\(name)\n\n")
    }

    private func pointerSocket() async throws -> SocketConnection {
        if let pointer { return pointer }
        let payload = try await request("ssap://com.webos.service.networkinput/getPointerInputSocket", awaitReply: true)
        guard let path = payload["socketPath"] as? String, var components = URLComponents(string: path) else {
            throw TVError.badResponse
        }
        if isSecure {
            components.scheme = "wss"
            components.port = 3001
        }
        guard let url = components.url else { throw TVError.badResponse }
        let pointer = SocketConnection(url: url)
        pointer.onClose = { [weak self] _ in self?.pointer = nil }
        pointer.open()
        self.pointer = pointer
        return pointer
    }
}

/// The unsigned registration manifest webOS accepts from remote apps. The permission list
/// matches the one used by the open-source aiowebostv client (Apache 2.0).
private enum LGManifest {
    static let registration: [String: Any] = [
        "forcePairing": false,
        "pairingType": "PROMPT",
        "manifest": [
            "appVersion": "1.1",
            "manifestVersion": 1,
            "permissions": [
                "APP_TO_APP", "CLOSE", "CONTROL_AUDIO", "CONTROL_DISPLAY", "CONTROL_INPUT_JOYSTICK",
                "CONTROL_INPUT_MEDIA_PLAYBACK", "CONTROL_INPUT_MEDIA_RECORDING", "CONTROL_INPUT_TEXT",
                "CONTROL_INPUT_TV", "CONTROL_MOUSE_AND_KEYBOARD", "CONTROL_POWER", "CONTROL_TV_SCREEN",
                "LAUNCH", "LAUNCH_WEBAPP", "READ_APP_STATUS", "READ_COUNTRY_INFO", "READ_CURRENT_CHANNEL",
                "READ_INPUT_DEVICE_LIST", "READ_INSTALLED_APPS", "READ_LGE_SDX", "READ_LGE_TV_INPUT_EVENTS",
                "READ_NETWORK_STATE", "READ_NOTIFICATIONS", "READ_POWER_STATE", "READ_RUNNING_APPS",
                "READ_SETTINGS", "READ_TV_CHANNEL_LIST", "READ_TV_CURRENT_TIME", "READ_UPDATE_INFO",
                "SEARCH", "TEST_OPEN", "TEST_PROTECTED", "TEST_SECURE", "UPDATE_FROM_REMOTE_APP",
                "WRITE_NOTIFICATION_ALERT", "WRITE_NOTIFICATION_TOAST", "WRITE_SETTINGS",
            ],
        ] as [String: Any],
    ]
}
