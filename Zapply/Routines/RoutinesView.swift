import AppIntents
import SwiftUI

struct RoutinesView: View {
    @Environment(RoutineStore.self) private var routines
    @Environment(TVManager.self) private var tvs
    @Environment(SubscriptionStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var editing: Routine?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(routines.routines) { routine in
                        RoutineRow(routine: routine, isRunning: routines.runningID == routine.id) {
                            run(routine)
                        } edit: {
                            editing = routine
                        }
                    }
                    .onDelete { routines.delete(at: $0) }
                    Button {
                        if routines.canAdd(isPremium: store.isPremium) {
                            editing = Routine(name: "", symbol: RoutineStore.symbols[2], steps: [])
                        } else {
                            router.paywall = .routines
                        }
                    } label: {
                        HStack {
                            Label("New Routine", systemImage: "plus.circle.fill")
                            Spacer()
                            if !routines.canAdd(isPremium: store.isPremium) { LockBadge() }
                        }
                    }
                } footer: {
                    Text("A routine presses several buttons for you in one tap, like muting and switching off the TV at bedtime. Free accounts can keep \(RoutineStore.freeLimit) routines.")
                }
                .listRowBackground(Theme.surface)

                Section {
                    SiriTipView(intent: TurnOffTVIntent())
                        .siriTipViewStyle(.dark)
                        .listRowInsets(EdgeInsets())
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Things you can say")
                            .font(.subheadline.weight(.semibold))
                        ForEach(["\u{201C}Turn off the TV with Zapply\u{201D}", "\u{201C}Mute the TV with Zapply\u{201D}",
                                 "\u{201C}Turn the TV up with Zapply\u{201D}", "\u{201C}Run Bedtime in Zapply\u{201D}"], id: \.self) { phrase in
                            Label(phrase, systemImage: "mic.fill")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    ShortcutsLink()
                        .shortcutsLinkStyle(.automaticOutline)
                        .frame(maxWidth: .infinity)
                } header: {
                    Text("Siri & Shortcuts")
                } footer: {
                    Text("Voice commands use the TV you connected to last. In the Shortcuts app you can also run routines automatically, for example at a set time.")
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Routines")
            .toolbar { EditButton() }
            .sheet(item: $editing) { routine in
                RoutineEditor(routine: routine) { routines.save($0) }
            }
        }
    }

    private func run(_ routine: Routine) {
        Haptics.tap()
        Task {
            do {
                try await routines.run(routine, on: tvs)
                tvs.notice = "\(routine.name) finished"
            } catch {
                tvs.notice = TVManager.describe(error)
            }
        }
    }
}

private struct RoutineRow: View {
    let routine: Routine
    let isRunning: Bool
    let run: () -> Void
    let edit: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: edit) {
                HStack(spacing: 14) {
                    Image(systemName: routine.symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 46, height: 46)
                        .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(routine.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(routine.steps.map(\.summary).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit routine")
            Spacer(minLength: 8)
            Button(action: run) {
                if isRunning {
                    ProgressView().tint(.white)
                } else {
                    Label("Run", systemImage: "play.fill")
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(.headline)
            .buttonStyle(.borderedProminent)
            .disabled(isRunning)
            .accessibilityLabel("Run \(routine.name)")
        }
        .padding(.vertical, 6)
    }
}

/// Creates or edits a routine. Changes are kept only when Save is tapped.
struct RoutineEditor: View {
    let onSave: (Routine) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(TVManager.self) private var tvs
    @State private var draft: Routine
    @State private var appName = ""
    @State private var text = ""
    @State private var askingForApp = false
    @State private var askingForText = false

    init(routine: Routine, onSave: @escaping (Routine) -> Void) {
        self.onSave = onSave
        _draft = State(initialValue: routine)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Movie night", text: $draft.name)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(RoutineStore.symbols, id: \.self) { symbol in
                                Button { draft.symbol = symbol } label: {
                                    Image(systemName: symbol)
                                        .font(.system(size: 18, weight: .semibold))
                                        .frame(width: 44, height: 44)
                                        .background(draft.symbol == symbol ? Theme.accent : Theme.surfacePressed,
                                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(draft.symbol == symbol ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section {
                    ForEach($draft.steps) { $step in
                        StepRow(step: $step)
                    }
                    .onDelete { draft.steps.remove(atOffsets: $0) }
                    .onMove { draft.steps.move(fromOffsets: $0, toOffset: $1) }
                    Menu {
                        Menu("Press a Button") {
                            ForEach(RemoteKey.routineKeys, id: \.self) { key in
                                Button { add(.press(key, times: 1)) } label: { Label(key.spokenName, systemImage: key.symbol) }
                            }
                        }
                        Button { appName = ""; askingForApp = true } label: { Label("Open an App…", systemImage: "square.grid.2x2") }
                        Button { add(.wait(seconds: 2)) } label: { Label("Wait", systemImage: "hourglass") }
                        Button { text = ""; askingForText = true } label: { Label("Type Text…", systemImage: "keyboard") }
                    } label: {
                        Label("Add Step", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Steps")
                } footer: {
                    Text("Steps run from top to bottom. Add a short wait after opening an app so the TV has time to load it.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(draft.name.isEmpty ? "New Routine" : draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, .constant(.active))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty || draft.steps.isEmpty)
                }
            }
            .alert("Open an App", isPresented: $askingForApp) {
                TextField("App name", text: $appName)
                Button("Add") { if !appName.isEmpty { add(.openApp(name: appName)) } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(tvs.apps.isEmpty ? "Type the app's name as it appears on your TV." :
                        "Apps on your TV: \(tvs.apps.prefix(8).map(\.name).joined(separator: ", ")).")
            }
            .alert("Type Text", isPresented: $askingForText) {
                TextField("Text to type", text: $text)
                Button("Add") { if !text.isEmpty { add(.type(text: text)) } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The text is typed into whatever search or text box is open on the TV.")
            }
        }
    }

    private func add(_ action: RoutineStep.Action) {
        draft.steps.append(RoutineStep(action: action))
    }
}

private struct StepRow: View {
    @Binding var step: RoutineStep

    var body: some View {
        switch step.action {
        case .press(let key, let times):
            Stepper(value: Binding(get: { times }, set: { step.action = .press(key, times: $0) }), in: 1...10) {
                Label(times > 1 ? "\(key.spokenName) × \(times)" : key.spokenName, systemImage: key.symbol)
            }
        case .wait(let seconds):
            Stepper(value: Binding(get: { seconds }, set: { step.action = .wait(seconds: $0) }), in: 1...30) {
                Label("Wait \(seconds) s", systemImage: "hourglass")
            }
        case .openApp, .type:
            Label(step.summary, systemImage: step.symbol)
        }
    }
}
