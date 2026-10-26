import Foundation

enum TVPlatform: String, Codable, CaseIterable, Sendable {
    case roku, samsung, lg, demo

    var brand: String {
        switch self {
        case .roku: "Roku"
        case .samsung: "Samsung"
        case .lg: "LG"
        case .demo: "Demo"
        }
    }

    var symbol: String {
        self == .demo ? "sparkles.tv" : "tv"
    }

    /// Samsung and LG ask for permission on the TV the first time a remote app connects.
    var pairingHint: String? {
        switch self {
        case .samsung: "If your TV asks, choose Allow to finish connecting."
        case .lg: "If your TV asks, choose Yes to accept this remote."
        default: nil
        }
    }
}

struct TVDevice: Codable, Hashable, Identifiable, Sendable {
    var name: String
    var model: String?
    var host: String
    var platform: TVPlatform

    var id: String { "\(platform.rawValue)@\(host)" }

    static let demo = TVDevice(name: "Demo TV", model: "Try every button without a TV", host: "demo", platform: .demo)
}

struct TVApp: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    var iconURL: URL?
    /// SF Symbol and tile color for the demo TV's built-in apps.
    var symbol: String?
    var paletteIndex: Int?
    /// Samsung's `app_type`, which picks how the app is launched.
    var launchKind: String?
}

enum RemoteKey: Hashable, Sendable {
    case up, down, left, right, select
    case back, home, menu, info, power
    case volumeUp, volumeDown, mute
    case channelUp, channelDown
    case playPause, rewind, fastForward
    case digit(Int)
}

/// Pairing tokens (Samsung) and client keys (LG) that let a TV skip its permission prompt next time.
enum PairingStore {
    private static func key(_ device: TVDevice) -> String { "pairing.\(device.id)" }

    static func token(for device: TVDevice) -> String? {
        UserDefaults.standard.string(forKey: key(device))
    }

    static func setToken(_ token: String, for device: TVDevice) {
        UserDefaults.standard.set(token, forKey: key(device))
    }

    static func clear(for device: TVDevice) {
        UserDefaults.standard.removeObject(forKey: key(device))
    }
}

enum TextDiff {
    /// How many characters to delete from the end of `old`, and what to append, to turn it into `new`.
    static func between(_ old: String, _ new: String) -> (delete: Int, insert: String) {
        let common = zip(old, new).prefix { $0 == $1 }.count
        return (old.count - common, String(new.dropFirst(common)))
    }
}

enum XMLValue {
    /// The text of the first `<tag>` element, for the small flat XML documents Roku returns.
    static func first(_ tag: String, in text: String) -> String? {
        guard let open = text.range(of: "<\(tag)>"),
              let close = text.range(of: "</\(tag)>", range: open.upperBound..<text.endIndex) else { return nil }
        let value = text[open.upperBound..<close.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
        return value.isEmpty ? nil : value
    }
}

enum IPv4 {
    static func parse(_ host: String) -> UInt32? {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var value: UInt32 = 0
        for part in parts {
            guard let octet = UInt8(part) else { return nil }
            value = value << 8 | UInt32(octet)
        }
        return value
    }

    static func string(_ value: UInt32) -> String {
        "\(value >> 24 & 255).\(value >> 16 & 255).\(value >> 8 & 255).\(value & 255)"
    }

    static func isPrivate(_ value: UInt32) -> Bool {
        value >> 24 == 10 || value >> 20 == 0xAC1 || value >> 16 == 0xC0A8 || value >> 16 == 0xA9FE
    }

    static func isPrivate(_ host: String) -> Bool {
        parse(host).map(isPrivate) ?? false
    }

    /// The phone's Wi-Fi address and netmask, preferring en0.
    static func localInterface() -> (address: UInt32, netmask: UInt32)? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(list) }

        var fallback: (UInt32, UInt32)?
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(entry.pointee.ifa_flags)
            guard let address = entry.pointee.ifa_addr, let mask = entry.pointee.ifa_netmask,
                  address.pointee.sa_family == UInt8(AF_INET),
                  flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }
            let ip = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt32(bigEndian: $0.pointee.sin_addr.s_addr) }
            let netmask = mask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { UInt32(bigEndian: $0.pointee.sin_addr.s_addr) }
            guard isPrivate(ip) else { continue }
            if String(cString: entry.pointee.ifa_name) == "en0" { return (ip, netmask) }
            if fallback == nil { fallback = (ip, netmask) }
        }
        return fallback
    }

    /// Every other address on the local subnet, capped at a /24 so a scan stays quick.
    static func localSubnetHosts() -> [String] {
        guard let (address, mask) = localInterface() else { return [] }
        let netmask = max(mask, 0xFFFF_FF00)
        let network = address & netmask
        let broadcast = network | ~netmask
        guard broadcast > network + 1 else { return [] }
        return (network + 1..<broadcast).filter { $0 != address }.map(string)
    }
}
