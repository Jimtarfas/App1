import SwiftUI
import UIKit

enum Theme {
    static let background = Color(red: 0.047, green: 0.055, blue: 0.098)
    static let surface = Color(red: 0.106, green: 0.118, blue: 0.188)
    static let surfacePressed = Color(red: 0.170, green: 0.186, blue: 0.290)
    static let stroke = Color.white.opacity(0.07)
    static let accent = Color(red: 0.36, green: 0.55, blue: 1.0)
    static let violet = Color(red: 0.60, green: 0.38, blue: 1.0)
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.30)
    static let power = Color(red: 1.0, green: 0.36, blue: 0.38)
    static let brand = LinearGradient(colors: [accent, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
}

enum Links {
    static let privacy = URL(string: "https://jimtarfas.github.io/zapply-remote/privacy.html")!
    static let support = URL(string: "https://jimtarfas.github.io/zapply-remote/support.html")!
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

enum Haptics {
    static let key = "hapticsEnabled"

    @MainActor
    static func tap() {
        guard UserDefaults.standard.object(forKey: key) as? Bool ?? true else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

/// Stable per-name colors for app tiles (String.hashValue changes between launches).
enum AppPalette {
    private static let colors: [Color] = [
        Color(red: 0.86, green: 0.20, blue: 0.27), Color(red: 0.20, green: 0.47, blue: 0.96),
        Color(red: 0.12, green: 0.66, blue: 0.52), Color(red: 0.95, green: 0.55, blue: 0.16),
        Color(red: 0.55, green: 0.33, blue: 0.95), Color(red: 0.10, green: 0.62, blue: 0.85),
        Color(red: 0.91, green: 0.30, blue: 0.62), Color(red: 0.33, green: 0.40, blue: 0.55),
    ]

    static func color(for app: TVApp) -> Color {
        app.paletteIndex.map { colors[$0 % colors.count] } ?? color(for: app.name)
    }

    static func color(for name: String) -> Color {
        let sum = name.unicodeScalars.reduce(UInt32(0)) { $0 &+ $1.value }
        return colors[Int(sum % UInt32(colors.count))]
    }
}

/// A round remote key with a soft press animation.
struct RoundKeyStyle: ButtonStyle {
    var size: CGFloat = 60
    var tint: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.36, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(Circle().fill(configuration.isPressed ? Theme.surfacePressed : Theme.surface))
            .overlay(Circle().strokeBorder(Theme.stroke))
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}

struct PressFadeStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButton(configuration: configuration)
    }

    private struct PrimaryButton: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Theme.brand, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}

/// A small gold padlock pinned to the corner of Premium-only controls.
struct LockBadge: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.black)
            .padding(5)
            .background(Circle().fill(Theme.gold))
            .accessibilityLabel("Premium")
    }
}
