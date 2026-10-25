import SwiftUI

/// The circular direction pad. Taps on the arrows or a swipe across the pad both move.
struct DPad: View {
    var size: CGFloat = 212
    let press: (RemoteKey) -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.surface)
                .overlay(Circle().strokeBorder(Theme.stroke))
            arrow(.up, "chevron.up", label: "Up").offset(y: -size * 0.355)
            arrow(.down, "chevron.down", label: "Down").offset(y: size * 0.355)
            arrow(.left, "chevron.left", label: "Left").offset(x: -size * 0.355)
            arrow(.right, "chevron.right", label: "Right").offset(x: size * 0.355)
            Button { press(.select) } label: {
                Text("OK")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: size * 0.4, height: size * 0.4)
                    .background(Theme.brand, in: Circle())
                    .shadow(color: Theme.accent.opacity(0.45), radius: 14, y: 4)
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("OK")
        }
        .frame(width: size, height: size)
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                let dx = value.translation.width, dy = value.translation.height
                if abs(dx) > abs(dy) {
                    press(dx > 0 ? .right : .left)
                } else {
                    press(dy > 0 ? .down : .up)
                }
            }
        )
    }

    private func arrow(_ key: RemoteKey, _ symbol: String, label: String) -> some View {
        Button { press(key) } label: {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: size * 0.28, height: size * 0.28)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressFadeStyle())
        .accessibilityLabel(label)
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}

/// A tall +/− capsule for volume and channels.
struct Rocker: View {
    let title: String
    let up: RemoteKey
    let down: RemoteKey
    var isLocked = false
    let action: (RemoteKey) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button { action(up) } label: {
                Image(systemName: "plus")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("\(title) up")
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.secondary)
            Button { action(down) } label: {
                Image(systemName: "minus")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("\(title) down")
        }
        .buttonStyle(PressFadeStyle())
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 64, height: 136)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().strokeBorder(Theme.stroke))
        .overlay(alignment: .topTrailing) {
            if isLocked { LockBadge().offset(x: 4, y: -2) }
        }
    }
}

/// The virtual TV picture shown on the remote while the demo TV is connected.
struct DemoScreenView: View {
    private let tv = DemoTV.shared

    var body: some View {
        ZStack {
            Color.black
            if tv.isOn {
                Group {
                    if let app = tv.openApp {
                        playing(app)
                    } else {
                        home
                    }
                }
                .transition(.opacity)
            } else {
                Image(systemName: "power")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.2))
            }
            if tv.isOn, let banner = tv.banner {
                VStack {
                    Spacer()
                    Text(banner)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.65), in: Capsule())
                }
                .padding(10)
                .transition(.opacity)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 3))
        .shadow(color: Theme.accent.opacity(0.22), radius: 18, y: 6)
        .animation(.easeOut(duration: 0.16), value: tv.focus)
        .animation(.easeInOut(duration: 0.25), value: tv.openApp)
        .animation(.easeInOut(duration: 0.25), value: tv.isOn)
        .animation(.easeInOut(duration: 0.2), value: tv.banner)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Demo TV screen")
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                Text(tv.searchText.isEmpty ? "Search" : tv.searchText)
                    .lineLimit(1)
                Spacer()
                Text("DEMO")
                    .font(.system(size: 8, weight: .heavy))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Theme.accent.opacity(0.55), in: Capsule())
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white.opacity(tv.searchText.isEmpty ? 0.55 : 0.95))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.white.opacity(0.08), in: Capsule())
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: DemoTV.columns), spacing: 8) {
                ForEach(Array(DemoTV.apps.enumerated()), id: \.element.id) { index, app in
                    let isFocused = index == tv.focus
                    VStack(spacing: 4) {
                        Image(systemName: app.symbol ?? "app")
                            .font(.system(size: 16, weight: .semibold))
                        Text(app.name)
                            .font(.system(size: 8, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(AppPalette.color(for: app.name).gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white, lineWidth: isFocused ? 2.5 : 0))
                    .scaleEffect(isFocused ? 1.08 : 1)
                    .zIndex(isFocused ? 1 : 0)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            LinearGradient(colors: [Color(red: 0.07, green: 0.08, blue: 0.17), Color(red: 0.13, green: 0.08, blue: 0.24)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private func playing(_ app: TVApp) -> some View {
        ZStack {
            Rectangle().fill(AppPalette.color(for: app.name).gradient)
            VStack(spacing: 6) {
                Image(systemName: app.symbol ?? "play.rectangle")
                    .font(.system(size: 34, weight: .semibold))
                Text(app.id == "live" ? "Live TV · Channel \(tv.channel)" : app.name)
                    .font(.system(size: 14, weight: .bold))
                Image(systemName: tv.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12))
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            VStack {
                Spacer()
                Capsule()
                    .fill(.white.opacity(0.25))
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule().fill(.white).frame(width: proxy.size.width * 0.38)
                        }
                    }
            }
            .padding(12)
        }
    }
}
