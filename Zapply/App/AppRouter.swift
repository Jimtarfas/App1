import SwiftUI

/// Features that need Zapply Premium. Each one opens the paywall with its own headline.
enum PremiumFeature: String, Identifiable {
    case keyboard, channels, multipleTVs, routines, upgrade

    var id: String { rawValue }

    var headline: String {
        switch self {
        case .keyboard: "Type on your TV with your phone"
        case .channels: "Unlock channel controls"
        case .multipleTVs: "Control every TV at home"
        case .routines: "Create unlimited routines"
        case .upgrade: "Get the full remote"
        }
    }
}

@Observable
@MainActor
final class AppRouter {
    enum Tab: Hashable {
        case remote, apps, routines, tvs, settings
    }

    enum RemoteSheet: String, Identifiable {
        case keyboard, numberPad
        var id: String { rawValue }
    }

    var tab: Tab = .remote
    var paywall: PremiumFeature?
    var remoteSheet: RemoteSheet?

    init() {
        #if DEBUG
        // Launch arguments used to stage App Store screenshots, e.g. `-startTab apps`.
        switch UserDefaults.standard.string(forKey: "startTab") {
        case "apps": tab = .apps
        case "routines": tab = .routines
        case "tvs": tab = .tvs
        case "settings": tab = .settings
        default: break
        }
        if let feature = UserDefaults.standard.string(forKey: "showPaywall") {
            paywall = PremiumFeature(rawValue: feature)
        }
        #endif
    }
}
