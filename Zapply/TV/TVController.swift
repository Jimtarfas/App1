import Foundation

enum TVError: LocalizedError, CustomLocalizedStringResourceConvertible {
    case unreachable, denied, timedOut, unsupported, rokuLimited, badResponse
    case noTV
    case appNotFound(String)

    /// What Siri says when a voice command fails.
    var localizedStringResource: LocalizedStringResource {
        "\(errorDescription ?? "Something went wrong.")"
    }

    var errorDescription: String? {
        switch self {
        case .noTV:
            "No TV is set up yet. Open Zapply and choose your TV in the TVs tab."
        case .appNotFound(let name):
            "Couldn't find an app called \(name) on your TV."
        case .unreachable:
            "Couldn't reach the TV. Make sure it's on and connected to the same Wi-Fi network as your iPhone."
        case .denied:
            "The TV didn't allow the connection. Connect again and accept the prompt on your TV."
        case .timedOut:
            "The TV didn't answer in time. Check your TV for a prompt and try again."
        case .unsupported:
            "This TV doesn't support that action."
        case .rokuLimited:
            "Your Roku is blocking remote apps. On the Roku, open Settings > System > Advanced system settings > Control by mobile apps and set Network access to Default."
        case .badResponse:
            "The TV sent an unexpected response. Please try again."
        }
    }
}

/// One TV protocol (Roku ECP, Samsung Tizen, LG webOS, or the demo TV).
@MainActor
protocol TVController: AnyObject {
    var device: TVDevice { get }
    var supportsNumberPad: Bool { get }

    func connect() async throws
    func disconnect()
    func send(_ key: RemoteKey) async throws
    /// Mirrors an edit in the phone's text field onto the TV's on-screen keyboard.
    func updateText(from old: String, to new: String) async throws
    func submitText() async throws
    func installedApps() async throws -> [TVApp]
    func launch(_ app: TVApp) async throws
}

enum TVNetwork {
    /// Shared session for TV traffic. Samsung (8002) and LG (3001) serve TLS with self-signed
    /// certificates, which `LocalNetworkTrust` accepts for private LAN addresses only.
    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6
        config.waitsForConnectivity = false
        config.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: config, delegate: LocalNetworkTrust.shared, delegateQueue: nil)
    }()
}

final class LocalNetworkTrust: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = LocalNetworkTrust()

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let (disposition, credential) = evaluate(challenge)
        completionHandler(disposition, credential)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let (disposition, credential) = evaluate(challenge)
        completionHandler(disposition, credential)
    }

    private func evaluate(_ challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        let space = challenge.protectionSpace
        guard space.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = space.serverTrust, IPv4.isPrivate(space.host) else {
            return (.performDefaultHandling, nil)
        }
        return (.useCredential, URLCredential(trust: trust))
    }
}

/// Resolves once, with the first result delivered or a timeout.
@MainActor
final class Pending<Value> {
    private var continuation: CheckedContinuation<Value, Error>?
    private var result: Result<Value, Error>?

    func wait(timeout: TimeInterval) async throws -> Value {
        if let result { return try result.get() }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                self?.fail(TVError.timedOut)
            }
        }
    }

    func succeed(_ value: Value) { resolve(.success(value)) }
    func fail(_ error: Error) { resolve(.failure(error)) }

    private func resolve(_ outcome: Result<Value, Error>) {
        guard result == nil else { return }
        result = outcome
        continuation?.resume(with: outcome)
        continuation = nil
    }
}

/// A WebSocket that hands each text frame to `onText` until it closes.
@MainActor
final class SocketConnection {
    var onText: ((String) -> Void)?
    var onClose: ((Error) -> Void)?

    private let task: URLSessionWebSocketTask
    private var receiveLoop: Task<Void, Never>?

    init(url: URL) {
        task = TVNetwork.session.webSocketTask(with: url)
        task.maximumMessageSize = 8 * 1024 * 1024
    }

    func open() {
        task.resume()
        receiveLoop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    switch try await self.task.receive() {
                    case .string(let text): self.onText?(text)
                    case .data(let data): self.onText?(String(decoding: data, as: UTF8.self))
                    @unknown default: break
                    }
                } catch {
                    self.onClose?(error)
                    return
                }
            }
        }
    }

    func send(_ text: String) async throws {
        try await task.send(.string(text))
    }

    func send(json: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: json)
        try await send(String(decoding: data, as: UTF8.self))
    }

    func close() {
        receiveLoop?.cancel()
        task.cancel(with: .goingAway, reason: nil)
    }
}
