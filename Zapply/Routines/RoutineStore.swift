import AppIntents
import Foundation

/// A named list of steps run on the TV in one tap, or by asking Siri.
struct Routine: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var symbol: String
    var steps: [RoutineStep]
}

struct RoutineStep: Codable, Hashable, Identifiable {
    enum Action: Codable, Hashable {
        case press(RemoteKey, times: Int)
        case openApp(name: String)
        case wait(seconds: Int)
        case type(text: String)
    }

    var id = UUID()
    var action: Action

    var summary: String {
        switch action {
        case .press(let key, let times): times > 1 ? "\(key.spokenName) × \(times)" : key.spokenName
        case .openApp(let name): "Open \(name)"
        case .wait(let seconds): "Wait \(seconds) s"
        case .type(let text): "Type \u{201C}\(text)\u{201D}"
        }
    }

    var symbol: String {
        switch action {
        case .press(let key, _): key.symbol
        case .openApp: "square.grid.2x2"
        case .wait: "hourglass"
        case .type: "keyboard"
        }
    }
}

@Observable
@MainActor
final class RoutineStore {
    static let shared = RoutineStore()
    /// Free accounts can keep this many routines; Premium removes the limit.
    static let freeLimit = 3
    static let symbols = ["moon.zzz.fill", "speaker.wave.1.fill", "film", "sun.max.fill", "sportscourt", "music.note",
                          "bed.double.fill", "cup.and.saucer.fill"]

    private(set) var routines: [Routine] = []
    private(set) var runningID: UUID?

    private static let key = "routines"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([Routine].self, from: data) {
            routines = saved
        } else {
            routines = Self.starters
        }
    }

    func save(_ routine: Routine) {
        if let index = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[index] = routine
        } else {
            routines.append(routine)
        }
        persist()
    }

    func delete(at offsets: IndexSet) {
        routines.remove(atOffsets: offsets)
        persist()
    }

    func canAdd(isPremium: Bool) -> Bool {
        isPremium || routines.count < Self.freeLimit
    }

    /// Runs every step in order, reconnecting to the last TV first if needed.
    func run(_ routine: Routine, on tvs: TVManager) async throws {
        runningID = routine.id
        defer { runningID = nil }
        for step in routine.steps {
            switch step.action {
            case .press(let key, let times):
                for _ in 0..<max(times, 1) {
                    try await tvs.perform { try await $0.send(key) }
                    try? await Task.sleep(for: .milliseconds(250))
                }
            case .openApp(let name):
                try await tvs.openApp(named: name)
            case .wait(let seconds):
                try? await Task.sleep(for: .seconds(seconds))
            case .type(let text):
                try await tvs.perform { controller in
                    try await controller.updateText(from: "", to: text)
                    try await controller.submitText()
                }
            }
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(routines) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
        ZapplyShortcuts.updateAppShortcutParameters()
    }

    private static let starters = [
        Routine(name: "Bedtime", symbol: "moon.zzz.fill", steps: [
            RoutineStep(action: .press(.mute, times: 1)),
            RoutineStep(action: .wait(seconds: 1)),
            RoutineStep(action: .press(.power, times: 1)),
        ]),
        Routine(name: "Quieter", symbol: "speaker.wave.1.fill", steps: [
            RoutineStep(action: .press(.volumeDown, times: 5)),
        ]),
    ]
}
