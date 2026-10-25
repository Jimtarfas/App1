import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            Image("BrandMark")
                .resizable()
                .frame(width: 104, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Theme.accent.opacity(0.45), radius: 24, y: 8)
            Text("Your iPhone is now\nyour TV remote")
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.top, 28)
            VStack(alignment: .leading, spacing: 22) {
                OnboardingRow(symbol: "wifi", title: "No setup", text: "Zapply finds TVs on your Wi-Fi network.")
                OnboardingRow(symbol: "tv", title: "Roku, Samsung and LG", text: "Works with Roku devices, Samsung Tizen TVs and LG webOS TVs.")
                OnboardingRow(symbol: "square.grid.2x2", title: "Apps in one tap", text: "Open your TV's apps right from your phone.")
            }
            .padding(.top, 36)
            .padding(.horizontal, 8)
            Spacer(minLength: 24)
            Button("Find My TV", action: onFinish)
                .buttonStyle(PrimaryButtonStyle())
            Text("Next, iOS asks to let Zapply find devices on your local network. It needs that to reach your TV.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
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
