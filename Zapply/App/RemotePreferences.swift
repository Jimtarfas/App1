import AVFoundation
import SwiftUI
import UIKit

/// How the remote looks and sounds: layout, button size, contrast and spoken button names.
@Observable
@MainActor
final class RemotePreferences {
    static let shared = RemotePreferences()

    enum Layout: String, CaseIterable, Identifiable {
        case bigButtons, full

        var id: String { rawValue }
        var title: String { self == .bigButtons ? "Big Buttons" : "Full Remote" }
    }

    enum ButtonSize: String, CaseIterable, Identifiable {
        case standard, large, extraLarge

        var id: String { rawValue }

        var title: String {
            switch self {
            case .standard: "Standard"
            case .large: "Large"
            case .extraLarge: "Extra Large"
            }
        }

        var scale: CGFloat {
            switch self {
            case .standard: 1
            case .large: 1.15
            case .extraLarge: 1.32
            }
        }
    }

    var layout: Layout { didSet { store(layout.rawValue, "remoteLayout") } }
    var buttonSize: ButtonSize { didSet { store(buttonSize.rawValue, "buttonSize") } }
    var highContrast: Bool { didSet { store(highContrast, "highContrast") } }
    var speakButtons: Bool { didSet { store(speakButtons, "speakButtons") } }

    init() {
        let defaults = UserDefaults.standard
        layout = Layout(rawValue: defaults.string(forKey: "remoteLayout") ?? "") ?? .bigButtons
        buttonSize = ButtonSize(rawValue: defaults.string(forKey: "buttonSize") ?? "") ?? .large
        highContrast = defaults.bool(forKey: "highContrast")
        speakButtons = defaults.bool(forKey: "speakButtons")
    }

    var keyColors: KeyColors { highContrast ? .highContrast : .standard }
    var background: Color { highContrast ? .black : Theme.background }

    private func store(_ value: Any, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

/// Colors for remote keys. High contrast uses black keys with heavy white outlines.
struct KeyColors {
    let fill: Color
    let pressed: Color
    let foreground: Color
    let stroke: Color
    let strokeWidth: CGFloat
    let okFill: AnyShapeStyle
    let okForeground: Color

    static let standard = KeyColors(fill: Theme.surface, pressed: Theme.surfacePressed, foreground: .white,
                                    stroke: Theme.stroke, strokeWidth: 1, okFill: AnyShapeStyle(Theme.brand), okForeground: .white)
    static let highContrast = KeyColors(fill: .black, pressed: Color(white: 0.28), foreground: .white,
                                        stroke: .white, strokeWidth: 2.5, okFill: AnyShapeStyle(Color.yellow), okForeground: .black)
}

private struct KeyColorsKey: EnvironmentKey {
    static let defaultValue = KeyColors.standard
}

extension EnvironmentValues {
    var keyColors: KeyColors {
        get { self[KeyColorsKey.self] }
        set { self[KeyColorsKey.self] = newValue }
    }
}

/// Reads button names aloud for people who can't easily see the screen. Stays quiet while VoiceOver is on,
/// because VoiceOver already announces each button.
@MainActor
enum Speech {
    private static let synthesizer = AVSpeechSynthesizer()

    static func say(_ text: String) {
        guard RemotePreferences.shared.speakButtons, !UIAccessibility.isVoiceOverRunning else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
}
