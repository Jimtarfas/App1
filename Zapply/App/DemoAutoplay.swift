#if DEBUG
import SwiftUI
import UIKit

/// Plays a scripted walkthrough for the App Review demo video (`-autoplay YES`). Debug builds only.
/// Touch positions match the iPhone 17 Pro Max layout the video is recorded on.
@Observable
@MainActor
final class DemoAutoplay {
    static let shared = DemoAutoplay()

    var touch: CGPoint?
    var caption: String?
    /// Text the keyboard sheet should show, as if typed.
    var typedText: String?
    /// Moves onboarding to the given step.
    var onboardingStep: Int?

    @ObservationIgnored private var window: UIWindow?

    func start(router: AppRouter, tvs: TVManager, store: SubscriptionStore) {
        guard UserDefaults.standard.bool(forKey: "autoplay"), window == nil else { return }
        installOverlay()
        Task { await run(router: router, tvs: tvs, store: store) }
    }

    private func run(router: AppRouter, tvs: TVManager, store: SubscriptionStore) async {
        let prefs = RemotePreferences.shared
        await pause(3)
        await tap(220, 877) { onboardingStep = 1 }
        caption = "Pick a comfortable button size"
        await pause(1)
        await tap(350, 200) { prefs.buttonSize = .extraLarge }
        await pause(0.8)
        await tap(370, 376) { prefs.highContrast = true }
        await pause(1.2)
        await tap(370, 376) { prefs.highContrast = false }
        await tap(89, 200) { prefs.buttonSize = .standard }
        await pause(0.6)
        caption = nil
        await tap(220, 826) {
            router.tab = .tvs
            UserDefaults.standard.set(true, forKey: "hasOnboarded")
        }
        caption = "Finds Roku, Samsung and LG TVs on your Wi-Fi"
        await pause(3.5)
        caption = "No TV nearby? The Demo TV reacts to every button"
        await tap(143, tvs.hasScanned ? 448 : 434) {
            router.tab = .remote
            Task { await tvs.connect(.demo) }
        }
        await pause(1.5)
        caption = "Big buttons, each with a word label"
        for (x, y, key) in [(290.0, 502.0, RemoteKey.right), (290, 502, .right), (220, 571, .down), (220, 502, .select),
                            (322, 642, .volumeUp), (322, 642, .volumeUp), (116, 712, .mute), (322, 712, .playPause),
                            (322, 360, .home)] {
            await tap(x, y) { tvs.send(key) }
        }
        caption = "Premium controls show a padlock"
        await tap(322, 782) { router.paywall = .channels }
        await pause(4)
        caption = nil
        await tap(35, 88) { router.paywall = nil }
        await pause(0.6)

        caption = "One-tap routines, also by voice with Siri"
        await tap(220, 904) { router.tab = .routines }
        await pause(2.5)
        if let bedtime = RoutineStore.shared.routines.first {
            await tap(356, 211) {
                Task { try? await RoutineStore.shared.run(bedtime, on: tvs); tvs.notice = "\(bedtime.name) finished" }
            }
        }
        await pause(3)
        caption = "Bedtime muted the TV and switched it off"
        await tap(67, 904) { router.tab = .remote }
        await pause(2)
        caption = nil
        await tap(394, 92) { tvs.send(.power) }
        await pause(1)

        caption = "High contrast for low vision"
        await tap(372, 904) { router.tab = .settings }
        await pause(1)
        await tap(370, 634) { prefs.highContrast = true }
        await pause(0.8)
        await tap(67, 904) { router.tab = .remote }
        await pause(1)
        await tap(290, 502) { tvs.send(.right) }
        await pause(1)

        caption = "With Premium (test subscription)"
        store.debugSetPremium(true)
        await pause(2)
        caption = "Type on the TV with the phone keyboard"
        await tap(116, 851) { router.remoteSheet = .keyboard }
        await pause(1)
        var typed = ""
        for character in "cooking shows" {
            typed.append(character)
            typedText = typed
            try? await Task.sleep(for: .milliseconds(140))
        }
        await pause(1)
        await tap(368, 676) { tvs.submitText() }
        await pause(1.5)
        await tap(377, 491) { router.remoteSheet = nil }
        caption = "Channels and number pad"
        await tap(322, 851) { router.remoteSheet = .numberPad }
        await pause(1)
        await tap(135, 483) { tvs.send(.digit(1)) }
        await tap(220, 483) { tvs.send(.digit(2)) }
        await pause(2.3)
        await tap(319, 792) { tvs.send(.channelUp) }
        await pause(1.5)
        await tap(377, 408) { router.remoteSheet = nil }
        caption = "Restore, Manage Subscription, Privacy Policy, Terms"
        await tap(372, 904) { router.tab = .settings }
        await pause(4)
        caption = nil
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    /// Shows a touch marker at the point, then performs what tapping there does.
    private func tap(_ x: CGFloat, _ y: CGFloat, perform action: () -> Void) async {
        touch = CGPoint(x: x, y: y)
        await pause(0.35)
        action()
        await pause(0.25)
        touch = nil
        await pause(0.7)
    }

    private func installOverlay() {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        let host = UIHostingController(rootView: AutoplayOverlay(autoplay: self))
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.isHidden = false
        self.window = window
    }
}

private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

private struct AutoplayOverlay: View {
    let autoplay: DemoAutoplay

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            if let caption = autoplay.caption {
                Text(caption)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.black.opacity(0.8), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.25)))
                    .padding(.top, 60)
                    .transition(.opacity)
            }
            if let point = autoplay.touch {
                Circle()
                    .fill(.white.opacity(0.35))
                    .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 3))
                    .frame(width: 56, height: 56)
                    .position(point)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.18), value: autoplay.touch)
        .animation(.easeInOut(duration: 0.25), value: autoplay.caption)
    }
}
#endif
