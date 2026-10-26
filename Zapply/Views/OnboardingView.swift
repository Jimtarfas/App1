import SwiftUI

/// Two short steps: what Zapply is for, then choosing a remote that's comfortable to see and use.
struct OnboardingView: View {
    var onFinish: () -> Void
    @State private var step = 0

    var body: some View {
        Group {
            if step == 0 {
                Welcome { withAnimation { step = 1 } }
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                ComfortSetup(onFinish: onFinish)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        #if DEBUG
        .onChange(of: DemoAutoplay.shared.onboardingStep) { _, newStep in
            if let newStep { withAnimation { step = newStep } }
        }
        #endif
    }
}

private struct Welcome: View {
    let next: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            Image("BrandMark")
                .resizable()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Theme.accent.opacity(0.45), radius: 24, y: 8)
                .accessibilityHidden(true)
            Text("A TV remote that's easy to see and easy to use")
                .font(.system(size: 30, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.top, 26)
            VStack(alignment: .leading, spacing: 22) {
                OnboardingRow(symbol: "textformat.size", title: "Big, labeled buttons",
                              text: "Every button says what it does, in the size you choose.")
                OnboardingRow(symbol: "mic.fill", title: "Control it with your voice",
                              text: "Ask Siri to turn off, mute or turn up the TV.")
                OnboardingRow(symbol: "list.bullet.rectangle", title: "One-tap routines",
                              text: "Mute and switch off at bedtime with a single tap.")
                OnboardingRow(symbol: "tv", title: "Roku, Samsung and LG",
                              text: "Finds your TV on the same Wi-Fi network.")
            }
            .padding(.top, 32)
            .padding(.horizontal, 6)
            Spacer(minLength: 24)
            Button("Continue", action: next)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 16)
    }
}

private struct ComfortSetup: View {
    let onFinish: () -> Void
    @Environment(RemotePreferences.self) private var prefs

    var body: some View {
        @Bindable var prefs = prefs
        VStack(spacing: 0) {
            Text("Make it comfortable")
                .font(.system(size: 30, weight: .bold))
                .padding(.top, 32)
            Text("You can change these any time in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            VStack(spacing: 18) {
                Picker("Button size", selection: $prefs.buttonSize) {
                    ForEach(RemotePreferences.ButtonSize.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    LabeledKey(title: "Volume", symbol: "plus", scale: prefs.buttonSize.scale) {}
                    LabeledKey(title: "Home", symbol: "house.fill", scale: prefs.buttonSize.scale) {}
                }
                .environment(\.keyColors, prefs.keyColors)
                .padding(16)
                .background(prefs.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Preview of \(prefs.buttonSize.title) buttons")
                .animation(.spring(duration: 0.25), value: prefs.buttonSize)

                VStack(spacing: 0) {
                    Toggle(isOn: $prefs.highContrast) {
                        Label("High contrast", systemImage: "circle.lefthalf.filled")
                    }
                    .padding(.vertical, 12)
                    Divider()
                    Toggle(isOn: $prefs.speakButtons) {
                        Label("Speak button names", systemImage: "speaker.wave.2.fill")
                    }
                    .padding(.vertical, 12)
                }
                .padding(.horizontal, 16)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.top, 28)

            Spacer(minLength: 20)
            Button("Find My TV", action: onFinish)
                .buttonStyle(PrimaryButtonStyle())
            Text("Next, iOS asks to let Zapply find devices on your local network. It needs that to reach your TV.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}

private struct OnboardingRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 46, height: 46)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
