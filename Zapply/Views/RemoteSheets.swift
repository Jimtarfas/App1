import SwiftUI

/// Premium: type on the TV's on-screen keyboard from the phone.
struct KeyboardSheet: View {
    @Environment(TVManager.self) private var tvs
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var ignoreNextChange = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Open a search or text box on your TV, then type here. Letters appear on \(tvs.current?.name ?? "your TV") as you type.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Image(systemName: "keyboard")
                        .foregroundStyle(.secondary)
                    TextField("Type here", text: $text)
                        .focused($isFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.send)
                        .onSubmit(sendEnter)
                }
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                HStack(spacing: 12) {
                    Button {
                        if !text.isEmpty { text.removeLast() }
                    } label: {
                        Label("Delete", systemImage: "delete.left")
                    }
                    Button {
                        text = ""
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    Spacer()
                    Button(action: sendEnter) {
                        Label("Enter", systemImage: "return")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            .padding(20)
            .navigationTitle("Keyboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: text) { old, new in
                if ignoreNextChange {
                    ignoreNextChange = false
                    return
                }
                tvs.updateText(from: old, to: new)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.background)
        .onAppear { isFocused = true }
    }

    private func sendEnter() {
        tvs.submitText()
        // The text was entered on the TV, so clear the field without deleting it there.
        ignoreNextChange = !text.isEmpty
        text = ""
        isFocused = true
    }
}

/// Premium: channel up/down and direct number entry.
struct NumberPadSheet: View {
    @Environment(TVManager.self) private var tvs
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                if tvs.supportsNumberPad {
                    Grid(horizontalSpacing: 22, verticalSpacing: 14) {
                        ForEach(0..<3) { row in
                            GridRow {
                                ForEach(1...3, id: \.self) { column in digit(row * 3 + column) }
                            }
                        }
                        GridRow {
                            Color.clear.frame(width: 66, height: 66)
                            digit(0)
                            Color.clear.frame(width: 66, height: 66)
                        }
                    }
                } else {
                    Text("\(tvs.current?.platform.brand ?? "This TV") doesn't accept number keys from remote apps. Use channel up and down instead.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                HStack(spacing: 18) {
                    channelButton("CH −", key: .channelDown)
                    channelButton("CH +", key: .channelUp)
                }
                .padding(.horizontal, 24)
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .navigationTitle("Channels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.66), .large])
        .presentationBackground(Theme.background)
    }

    private func digit(_ number: Int) -> some View {
        Button("\(number)") { tvs.send(.digit(number)) }
            .buttonStyle(RoundKeyStyle(size: 66))
    }

    private func channelButton(_ title: String, key: RemoteKey) -> some View {
        Button { tvs.send(key) } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressFadeStyle())
        .foregroundStyle(.white)
    }
}
