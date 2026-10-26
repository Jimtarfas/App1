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

    @ObservationIgnored private var window: UIWindow?

    func start(router: AppRouter, tvs: TVManager, store: SubscriptionStore) {
        guard UserDefaults.standard.bool(forKey: "autoplay"), window == nil else { return }
        installOverlay()
        Task { await run(router: router, tvs: tvs, store: store) }
    }

    private func run(router: AppRouter, tvs: TVManager, store: SubscriptionStore) async {
        await pause(2.5)
        await tap(220, 825) {
            router.tab = .tvs
            router.paywall = .upgrade
            UserDefaults.standard.set(true, forKey: "hasOnboarded")
        }
        caption = "Subscription: prices, trial, Restore, Terms, Privacy"
        await pause(5)
        caption = nil
        await tap(36, 88) { router.paywall = nil }
        caption = "TVs on the same Wi-Fi are found automatically"
        await pause(4)
        caption = "No TV nearby? The Demo TV reacts to every button"
        await tap(143, tvs.hasScanned ? 448 : 434) {
            router.tab = .remote
            Task { await tvs.connect(.demo) }
        }
        await pause(1.5)
        caption = nil
        for (x, y, key) in [(296.0, 534.0, RemoteKey.right), (296, 534, .right), (220, 607, .down), (144, 534, .left),
                            (220, 534, .select), (62, 686, .volumeUp), (62, 686, .volumeUp), (62, 760, .volumeDown),
                            (220, 834, .playPause), (306, 834, .fastForward), (132, 382, .back), (220, 382, .home)] {
            await tap(x, y) { tvs.send(key) }
        }
        caption = "Premium controls show a padlock"
        await tap(256, 688) { router.paywall = .keyboard }
        await pause(3.5)
        caption = nil
        await tap(36, 88) { router.paywall = nil }
        await pause(0.6)
        caption = "Open your TV's apps"
        await tap(173, 900) { router.tab = .apps }
        await pause(1.5)
        await tap(359, 234) { if let music = DemoTV.apps.first(where: { $0.id == "music" }) { tvs.launch(music) } }
        await pause(0.8)
        await tap(79, 900) { router.tab = .remote }
        caption = nil
        await pause(2)

        caption = "With Premium (test subscription)"
        store.debugSetPremium(true)
        await pause(2)
        caption = "Type on the TV with the phone keyboard"
        await tap(256, 688) { router.remoteSheet = .keyboard }
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
        await tap(256, 760) { router.remoteSheet = .numberPad }
        await pause(1)
        await tap(135, 483) { tvs.send(.digit(1)) }
        await tap(220, 483) { tvs.send(.digit(2)) }
        await pause(1.8)
        await tap(319, 792) { tvs.send(.channelUp) }
        await pause(1.5)
        await tap(377, 408) { router.remoteSheet = nil }
        caption = "Restore, Manage Subscription, Privacy Policy, Terms"
        await tap(361, 900) { router.tab = .settings }
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
