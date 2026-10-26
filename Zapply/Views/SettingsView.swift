import AppIntents
import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(SubscriptionStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(RemotePreferences.self) private var prefs
    @AppStorage(Haptics.key) private var haptics = true
    @State private var showManageSubscription = false
    @State private var isRestoring = false
    @State private var message: String?

    private var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "1.0") (\(info?["CFBundleVersion"] as? String ?? "1"))"
    }

    var body: some View {
        @Bindable var prefs = prefs
        NavigationStack {
            List {
                Section { premiumCard }
                    .listRowBackground(Theme.surface)

                Section("Subscription") {
                    Button {
                        Task { await restore() }
                    } label: {
                        HStack {
                            Label("Restore Purchases", systemImage: "arrow.clockwise")
                            Spacer()
                            if isRestoring { ProgressView() }
                        }
                    }
                    .disabled(isRestoring)
                    Button { showManageSubscription = true } label: {
                        Label("Manage Subscription", systemImage: "creditcard")
                    }
                }
                .listRowBackground(Theme.surface)

                Section {
                    Picker(selection: $prefs.layout) {
                        ForEach(RemotePreferences.Layout.allCases) { Text($0.title).tag($0) }
                    } label: {
                        Label("Remote Layout", systemImage: "rectangle.grid.1x2")
                    }
                    Picker(selection: $prefs.buttonSize) {
                        ForEach(RemotePreferences.ButtonSize.allCases) { Text($0.title).tag($0) }
                    } label: {
                        Label("Button Size", systemImage: "textformat.size")
                    }
                    Toggle(isOn: $prefs.highContrast) {
                        Label("High Contrast", systemImage: "circle.lefthalf.filled")
                    }
                    Toggle(isOn: $prefs.speakButtons) {
                        Label("Speak Button Names", systemImage: "speaker.wave.2.fill")
                    }
                    Toggle(isOn: $haptics) {
                        Label("Haptic Feedback", systemImage: "hand.tap")
                    }
                } header: {
                    Text("Remote")
                } footer: {
                    Text("Big Buttons shows the most-used controls, each with a word label. Speak Button Names reads each press aloud and stays quiet while VoiceOver is on.")
                }
                .listRowBackground(Theme.surface)

                Section {
                    SiriTipView(intent: MuteTVIntent())
                        .siriTipViewStyle(.dark)
                        .listRowInsets(EdgeInsets())
                    ShortcutsLink()
                        .shortcutsLinkStyle(.automaticOutline)
                        .frame(maxWidth: .infinity)
                } header: {
                    Text("Siri & Shortcuts")
                } footer: {
                    Text("Ask Siri to turn the TV off, mute it, or turn it up or down, or to run one of your routines.")
                }
                .listRowBackground(Theme.surface)

                Section("Help") {
                    NavigationLink { SupportedTVsView() } label: {
                        Label("Supported TVs", systemImage: "checkmark.seal")
                    }
                    Link(destination: Links.support) {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }
                    Link(destination: Links.privacy) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: Links.terms) {
                        Label("Terms of Use", systemImage: "doc.text")
                    }
                }
                .listRowBackground(Theme.surface)

                Section {
                } footer: {
                    Text("Zapply \(version)\nZapply is an independent app and isn't affiliated with Roku, Samsung or LG.")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .manageSubscriptionsSheet(isPresented: $showManageSubscription)
            .alert("Restore Purchases", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
        }
    }

    @ViewBuilder
    private var premiumCard: some View {
        if store.isPremium {
            HStack(spacing: 14) {
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Zapply Premium").font(.headline)
                    Text("Keyboard, channels, unlimited TVs and routines are unlocked.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        } else {
            Button { router.paywall = .upgrade } label: {
                HStack(spacing: 14) {
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upgrade to Premium").font(.headline).foregroundStyle(.white)
                        Text("Keyboard, channel controls, unlimited TVs and routines.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            message = try await store.restore()
                ? "Your Zapply Premium subscription is active again."
                : "No active Zapply Premium subscription was found for this Apple ID."
        } catch {
            message = "Restoring didn't work: \(error.localizedDescription)"
        }
    }
}

private struct SupportedTVsView: View {
    var body: some View {
        List {
            Section("Roku") {
                Text("All Roku streaming players and Roku TVs.")
                Text("Under Settings > System > Advanced system settings > Control by mobile apps, Network access must be set to Default.")
                    .foregroundStyle(.secondary)
            }
            Section("Samsung") {
                Text("Samsung Smart TVs from 2016 onward (Tizen).")
                Text("The first time you connect, choose Allow on the TV. If you chose Deny, open Settings > General > External Device Manager > Device Connection Manager > Device List on the TV and allow Zapply Remote.")
                    .foregroundStyle(.secondary)
            }
            Section("LG") {
                Text("LG Smart TVs running webOS.")
                Text("The first time you connect, accept the prompt on the TV. On some models you also need to turn on LG Connect Apps in the network settings.")
                    .foregroundStyle(.secondary)
            }
            Section("Good to know") {
                Text("Samsung and LG TVs can't be switched on over Wi-Fi by apps, so turn them on with the TV's own remote. Roku TVs with Fast TV Start can be switched on from Zapply.")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Supported TVs")
        .navigationBarTitleDisplayMode(.inline)
    }
}
