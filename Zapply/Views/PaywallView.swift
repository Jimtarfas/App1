import SwiftUI

struct PaywallView: View {
    let feature: PremiumFeature
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID = SubscriptionStore.yearlyID
    @State private var isWorking = false
    @State private var message: String?

    private var selected: Plan? {
        store.plans.first { $0.id == selectedID } ?? store.plans.first
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 24) {
                    hero
                    benefits
                    plans
                    purchase
                    footer
                }
                .padding(.horizontal, 22)
                .padding(.top, 60)
                .padding(.bottom, 20)
            }
            .scrollBounceBehavior(.basedOnSize)

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .accessibilityLabel("Close")
            .padding(.leading, 18)
            .padding(.top, 8)
        }
        .background(
            ZStack {
                Theme.background
                Circle()
                    .fill(Theme.violet.opacity(0.35))
                    .frame(width: 420)
                    .blur(radius: 120)
                    .offset(y: -320)
            }
            .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
        .alert("Zapply Premium", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
        .task {
            if store.plans.isEmpty { await store.loadPlans() }
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 32))
                .foregroundStyle(Theme.gold)
                .frame(width: 74, height: 74)
                .background(Theme.surface, in: Circle())
                .overlay(Circle().strokeBorder(Theme.gold.opacity(0.35)))
            Text("ZAPPLY PREMIUM")
                .font(.footnote.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(Theme.gold)
            Text(feature.headline)
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 16) {
            Benefit(symbol: "keyboard", title: "Phone keyboard", text: "Type searches and sign-ins on your TV in seconds.")
            Benefit(symbol: "number.square", title: "Channels and number pad", text: "Channel up and down, plus direct number entry.")
            Benefit(symbol: "tv.and.mediabox", title: "Unlimited TVs", text: "Save and switch between every TV in your home.")
            Benefit(symbol: "list.bullet.rectangle", title: "Unlimited routines", text: "Run as many one-tap and Siri routines as you like.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var plans: some View {
        if store.plans.isEmpty {
            VStack(spacing: 12) {
                if store.isLoading {
                    ProgressView()
                } else {
                    Text("Prices couldn't be loaded. Check your internet connection and try again.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try Again") { Task { await store.loadPlans() } }
                        .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            VStack(spacing: 12) {
                ForEach(store.plans) { plan in
                    PlanCard(plan: plan, isSelected: plan.id == selected?.id) {
                        selectedID = plan.id
                    }
                }
            }
        }
    }

    private var purchase: some View {
        VStack(spacing: 10) {
            Button {
                Task { await buy() }
            } label: {
                if isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text(callToAction)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selected == nil || isWorking)
            if let selected {
                Text(priceTerms(selected))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 14) {
            HStack(spacing: 18) {
                Button("Restore Purchases") { Task { await restore() } }
                Link("Terms of Use", destination: Links.terms)
                Link("Privacy Policy", destination: Links.privacy)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white.opacity(0.8))
            Text("Payment is charged to your Apple ID when you confirm the purchase, or when the free trial ends. The subscription renews automatically at the same price and length unless you cancel at least 24 hours before the end of the current period. You can manage or cancel it in your App Store account settings. Any unused part of a free trial ends when you buy a subscription.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var callToAction: String {
        if let days = selected?.trialDays { return "Start \(days)-Day Free Trial" }
        return "Subscribe"
    }

    private func priceTerms(_ plan: Plan) -> String {
        if let days = plan.trialDays {
            return "Free for \(days) days, then \(plan.price) per \(plan.period). Cancel anytime."
        }
        return "\(plan.price) per \(plan.period), renews automatically. Cancel anytime."
    }

    private func buy() async {
        guard let plan = selected else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            switch try await store.purchase(plan) {
            case .purchased: dismiss()
            case .pending: message = "Your purchase is waiting for approval. Premium unlocks as soon as it's approved."
            case .cancelled: break
            }
        } catch {
            message = "The purchase couldn't be completed. \(error.localizedDescription)"
        }
    }

    private func restore() async {
        isWorking = true
        defer { isWorking = false }
        do {
            if try await store.restore() {
                dismiss()
            } else {
                message = "No active Zapply Premium subscription was found for this Apple ID."
            }
        } catch {
            message = "Restoring didn't work: \(error.localizedDescription)"
        }
    }
}

private struct Benefit: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

private struct PlanCard: View {
    let plan: Plan
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accent : .secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title).font(.headline)
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.price).font(.headline)
                    Text("per \(plan.period)").font(.caption).foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : Theme.stroke, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var summary: String {
        if let days = plan.trialDays { return "\(days) days free, then \(plan.price)/\(plan.period)" }
        return "\(plan.price) billed every \(plan.period)"
    }
}
