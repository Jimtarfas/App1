import AppIntents

// Voice control: Siri phrases and Shortcuts actions that work without opening the app.
// They act on the TV that was connected last.

enum TVButtonOption: String, AppEnum {
    case power, volumeUp, volumeDown, mute, channelUp, channelDown, home, back, ok, playPause, up, down, left, right

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "TV Button"
    static let caseDisplayRepresentations: [TVButtonOption: DisplayRepresentation] = [
        .power: "Power", .volumeUp: "Volume Up", .volumeDown: "Volume Down", .mute: "Mute",
        .channelUp: "Channel Up", .channelDown: "Channel Down", .home: "Home", .back: "Back", .ok: "OK",
        .playPause: "Play/Pause", .up: "Up", .down: "Down", .left: "Left", .right: "Right",
    ]

    var key: RemoteKey {
        switch self {
        case .power: .power
        case .volumeUp: .volumeUp
        case .volumeDown: .volumeDown
        case .mute: .mute
        case .channelUp: .channelUp
        case .channelDown: .channelDown
        case .home: .home
        case .back: .back
        case .ok: .select
        case .playPause: .playPause
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        }
    }
}

@MainActor
private enum IntentActions {
    /// Presses a key on the last TV and returns that TV's name for Siri's reply.
    static func press(_ key: RemoteKey, times: Int = 1) async throws -> String {
        let tvs = TVManager.shared
        for index in 0..<max(times, 1) {
            try await tvs.perform { try await $0.send(key) }
            if index < times - 1 { try? await Task.sleep(for: .milliseconds(200)) }
        }
        return tvs.current?.name ?? "your TV"
    }
}

struct TurnOffTVIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn Off TV"
    static let description = IntentDescription("Switches off the TV you used last in Zapply.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let name = try await IntentActions.press(.power)
        return .result(dialog: "Turned off \(name).")
    }
}

struct MuteTVIntent: AppIntent {
    static let title: LocalizedStringResource = "Mute TV"
    static let description = IntentDescription("Mutes or unmutes the TV you used last in Zapply.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let name = try await IntentActions.press(.mute)
        return .result(dialog: "Pressed mute on \(name).")
    }
}

struct VolumeUpIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn TV Volume Up"
    static let description = IntentDescription("Raises the volume on the TV you used last in Zapply.")

    @Parameter(title: "Steps", default: 3, inclusiveRange: (1, 20))
    var steps: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let name = try await IntentActions.press(.volumeUp, times: steps)
        return .result(dialog: "Turned \(name) up.")
    }
}

struct VolumeDownIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn TV Volume Down"
    static let description = IntentDescription("Lowers the volume on the TV you used last in Zapply.")

    @Parameter(title: "Steps", default: 3, inclusiveRange: (1, 20))
    var steps: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let name = try await IntentActions.press(.volumeDown, times: steps)
        return .result(dialog: "Turned \(name) down.")
    }
}

struct PressTVButtonIntent: AppIntent {
    static let title: LocalizedStringResource = "Press TV Button"
    static let description = IntentDescription("Presses any remote button on the TV you used last in Zapply.")

    @Parameter(title: "Button")
    var button: TVButtonOption

    @Parameter(title: "Times", default: 1, inclusiveRange: (1, 20))
    var times: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Press \(\.$button) \(\.$times) times")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = try await IntentActions.press(button.key, times: times)
        return .result()
    }
}

struct OpenTVAppIntent: AppIntent {
    static let title: LocalizedStringResource = "Open App on TV"
    static let description = IntentDescription("Opens an app on the TV you used last in Zapply, by name.")

    @Parameter(title: "App Name")
    var appName: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await TVManager.shared.openApp(named: appName)
        return .result(dialog: "Opening \(appName).")
    }
}

struct RoutineEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Routine"
    static let defaultQuery = RoutineQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct RoutineQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [RoutineEntity] {
        await MainActor.run {
            RoutineStore.shared.routines.filter { identifiers.contains($0.id) }.map { RoutineEntity(id: $0.id, name: $0.name) }
        }
    }

    func suggestedEntities() async throws -> [RoutineEntity] {
        await MainActor.run {
            RoutineStore.shared.routines.map { RoutineEntity(id: $0.id, name: $0.name) }
        }
    }
}

struct RunRoutineIntent: AppIntent {
    static let title: LocalizedStringResource = "Run Routine"
    static let description = IntentDescription("Runs one of your Zapply routines on the TV you used last.")

    @Parameter(title: "Routine")
    var routine: RoutineEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let saved = RoutineStore.shared.routines.first(where: { $0.id == routine.id }) else {
            return .result(dialog: "That routine no longer exists.")
        }
        try await RoutineStore.shared.run(saved, on: TVManager.shared)
        return .result(dialog: "\(saved.name) is done.")
    }
}

struct ZapplyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: TurnOffTVIntent(),
                    phrases: ["Turn off the TV with \(.applicationName)", "Switch off my TV with \(.applicationName)"],
                    shortTitle: "Turn Off TV", systemImageName: "power")
        AppShortcut(intent: MuteTVIntent(),
                    phrases: ["Mute the TV with \(.applicationName)", "Mute my TV with \(.applicationName)"],
                    shortTitle: "Mute TV", systemImageName: "speaker.slash.fill")
        AppShortcut(intent: VolumeUpIntent(),
                    phrases: ["Turn the TV up with \(.applicationName)", "Make the TV louder with \(.applicationName)"],
                    shortTitle: "TV Volume Up", systemImageName: "speaker.wave.3.fill")
        AppShortcut(intent: VolumeDownIntent(),
                    phrases: ["Turn the TV down with \(.applicationName)", "Make the TV quieter with \(.applicationName)"],
                    shortTitle: "TV Volume Down", systemImageName: "speaker.wave.1.fill")
        AppShortcut(intent: RunRoutineIntent(),
                    phrases: ["Run \(\.$routine) in \(.applicationName)", "Start \(\.$routine) with \(.applicationName)"],
                    shortTitle: "Run Routine", systemImageName: "list.bullet.rectangle")
        AppShortcut(intent: OpenTVAppIntent(),
                    phrases: ["Open an app on the TV with \(.applicationName)"],
                    shortTitle: "Open TV App", systemImageName: "square.grid.2x2")
    }
}
