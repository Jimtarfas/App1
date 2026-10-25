import Foundation

/// Finds TVs by probing every address on the local /24 for the Roku, Samsung and LG control ports.
/// Unicast probes only need Local Network permission (no multicast entitlement).
enum NetworkScanner {
    enum Event: Sendable {
        case progress(Double)
        case found(TVDevice)
    }

    private static let parallelHosts = 64

    static func scan() -> AsyncStream<Event> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                let hosts = IPv4.localSubnetHosts()
                guard !hosts.isEmpty else {
                    continuation.finish()
                    return
                }
                await withTaskGroup(of: TVDevice?.self) { group in
                    var next = 0
                    while next < min(parallelHosts, hosts.count) {
                        let host = hosts[next]
                        group.addTask { await probe(host) }
                        next += 1
                    }
                    var finished = 0
                    while let result = await group.next() {
                        finished += 1
                        continuation.yield(.progress(Double(finished) / Double(hosts.count)))
                        if let result { continuation.yield(.found(result)) }
                        if next < hosts.count, !Task.isCancelled {
                            let host = hosts[next]
                            group.addTask { await probe(host) }
                            next += 1
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func probe(_ host: String, timeout: TimeInterval = 1.5) async -> TVDevice? {
        async let roku = probeRoku(host, timeout)
        async let samsung = probeSamsung(host, timeout)
        async let lg = probeLG(host, timeout)
        if let device = await roku { return device }
        if let device = await samsung { return device }
        return await lg
    }

    private static func fetch(_ url: String, _ timeout: TimeInterval) async -> (Data, Int)? {
        guard let url = URL(string: url) else { return nil }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        guard let (data, response) = try? await TVNetwork.session.data(for: request) else { return nil }
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    private static func probeRoku(_ host: String, _ timeout: TimeInterval) async -> TVDevice? {
        guard let (data, status) = await fetch("http://\(host):8060/query/device-info", timeout), status == 200 else { return nil }
        let xml = String(decoding: data, as: UTF8.self)
        guard xml.contains("<device-info") else { return nil }
        let name = XMLValue.first("user-device-name", in: xml)
            ?? XMLValue.first("friendly-device-name", in: xml)
            ?? "Roku"
        let model = XMLValue.first("friendly-model-name", in: xml) ?? XMLValue.first("model-name", in: xml)
        return TVDevice(name: name, model: model, host: host, platform: .roku)
    }

    private static func probeSamsung(_ host: String, _ timeout: TimeInterval) async -> TVDevice? {
        guard let (data, status) = await fetch("http://\(host):8001/api/v2/", timeout), status == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let info = json["device"] as? [String: Any] ?? [:]
        let type = (info["type"] as? String) ?? (json["type"] as? String) ?? ""
        guard type.localizedCaseInsensitiveContains("samsung") else { return nil }
        let rawName = (info["name"] as? String) ?? (json["name"] as? String) ?? "Samsung TV"
        let name = rawName.replacingOccurrences(of: "[TV] ", with: "")
        return TVDevice(name: name, model: info["modelName"] as? String, host: host, platform: .samsung)
    }

    /// webOS answers a plain GET on its SSAP ports with "Hello world".
    private static func probeLG(_ host: String, _ timeout: TimeInterval) async -> TVDevice? {
        for url in ["http://\(host):3000/", "https://\(host):3001/"] {
            if let (data, _) = await fetch(url, timeout),
               String(decoding: data, as: UTF8.self).localizedCaseInsensitiveContains("hello world") {
                return TVDevice(name: "LG TV", model: "webOS", host: host, platform: .lg)
            }
        }
        return nil
    }
}
