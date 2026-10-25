import Foundation

/// Roku External Control Protocol: plain HTTP on port 8060.
@MainActor
final class RokuController: TVController {
    let device: TVDevice
    var supportsNumberPad: Bool { false }

    private var base: String { "http://\(device.host):8060" }

    init(device: TVDevice) {
        self.device = device
    }

    func connect() async throws {
        let (data, response) = try await TVNetwork.session.data(from: URL(string: base + "/query/device-info")!)
        guard (response as? HTTPURLResponse)?.statusCode == 200, !data.isEmpty else { throw TVError.unreachable }
    }

    func disconnect() {}

    func send(_ key: RemoteKey) async throws {
        try await post("/keypress/\(Self.keyName(key))")
    }

    func updateText(from old: String, to new: String) async throws {
        let diff = TextDiff.between(old, new)
        for _ in 0..<diff.delete {
            try await post("/keypress/Backspace")
        }
        for character in diff.insert {
            let literal = String(character).addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            try await post("/keypress/Lit_\(literal)")
        }
    }

    func submitText() async throws {
        try await post("/keypress/Enter")
    }

    func installedApps() async throws -> [TVApp] {
        let (data, _) = try await TVNetwork.session.data(from: URL(string: base + "/query/apps")!)
        return RokuAppList.parse(data).map { app in
            TVApp(id: app.id, name: app.name, iconURL: URL(string: "\(base)/query/icon/\(app.id)"))
        }
    }

    func launch(_ app: TVApp) async throws {
        let id = app.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? app.id
        try await post("/launch/\(id)")
    }

    private func post(_ path: String) async throws {
        guard let url = URL(string: base + path) else { throw TVError.badResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (_, response) = try await TVNetwork.session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 403 { throw TVError.rokuLimited }
        guard (200..<300).contains(status) else { throw TVError.badResponse }
    }

    private static func keyName(_ key: RemoteKey) -> String {
        switch key {
        case .up: "Up"
        case .down: "Down"
        case .left: "Left"
        case .right: "Right"
        case .select: "Select"
        case .back: "Back"
        case .home: "Home"
        case .menu, .info: "Info"
        case .power: "Power"
        case .volumeUp: "VolumeUp"
        case .volumeDown: "VolumeDown"
        case .mute: "VolumeMute"
        case .channelUp: "ChannelUp"
        case .channelDown: "ChannelDown"
        case .playPause: "Play"
        case .rewind: "Rev"
        case .fastForward: "Fwd"
        case .digit(let number): "Lit_\(number)"
        }
    }
}

/// Parses `/query/apps`: `<apps><app id="12" type="appl" version="1.0">Name</app>…</apps>`.
private final class RokuAppList: NSObject, XMLParserDelegate {
    private var apps: [(id: String, name: String)] = []
    private var currentID: String?
    private var text = ""

    static func parse(_ data: Data) -> [(id: String, name: String)] {
        let list = RokuAppList()
        let parser = XMLParser(data: data)
        parser.delegate = list
        parser.parse()
        return list.apps
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        guard elementName == "app" else { return }
        currentID = attributes["id"]
        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        guard elementName == "app", let id = currentID else { return }
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { apps.append((id, name)) }
        currentID = nil
    }
}
