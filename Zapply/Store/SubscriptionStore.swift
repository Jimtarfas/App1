import Foundation
import StoreKit

/// One subscription option as the paywall shows it.
struct Plan: Identifiable, Equatable {
    let id: String
    let title: String
    /// The billed amount, e.g. "$29.99".
    let price: String
    /// "week" or "year".
    let period: String
    /// Free-trial length, only when this Apple ID is still eligible for it.
    let trialDays: Int?
    let product: Product?
}

@Observable
@MainActor
final class SubscriptionStore {
    static let weeklyID = "com.zapplyremote.app.premium.weekly"
    static let yearlyID = "com.zapplyremote.app.premium.yearly"
    static let productIDs = [yearlyID, weeklyID]

    enum PurchaseOutcome {
        case purchased, pending, cancelled
    }

    private(set) var plans: [Plan] = []
    private(set) var isPremium = false
    private(set) var isLoading = false
    /// How much cheaper the yearly plan is than 52 weeks of the weekly plan, in percent.
    private(set) var yearlySavings: Int?

    @ObservationIgnored private var updates: Task<Void, Never>?

    init() {
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await refreshEntitlements()
            await loadPlans()
        }
    }

    func loadPlans() async {
        isLoading = true
        defer { isLoading = false }
        if let products = try? await Product.products(for: Self.productIDs) {
            var loaded: [Plan] = []
            for id in Self.productIDs {
                if let product = products.first(where: { $0.id == id }) {
                    loaded.append(await Self.plan(for: product))
                }
            }
            plans = loaded
            if let yearly = products.first(where: { $0.id == Self.yearlyID }),
               let weekly = products.first(where: { $0.id == Self.weeklyID }), weekly.price > 0 {
                let ratio = NSDecimalNumber(decimal: yearly.price / (weekly.price * 52)).doubleValue
                yearlySavings = Int(((1 - ratio) * 100).rounded(.down))
            }
        }
        #if DEBUG
        if plans.isEmpty, UserDefaults.standard.bool(forKey: "demoPrices") {
            plans = Self.previewPlans
            yearlySavings = 88
        }
        #endif
    }

    func purchase(_ plan: Plan) async throws -> PurchaseOutcome {
        guard let product = plan.product else {
            #if DEBUG
            isPremium = true
            return .purchased
            #else
            return .cancelled
            #endif
        }
        switch try await product.purchase() {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return .cancelled }
            await transaction.finish()
            await refreshEntitlements()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    /// Syncs with the App Store and reports whether an active subscription was found.
    func restore() async throws -> Bool {
        try await AppStore.sync()
        await refreshEntitlements()
        return isPremium
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "premium") { active = true }
        #endif
        isPremium = active
    }

    private static func plan(for product: Product) async -> Plan {
        let subscription = product.subscription
        let isYearly = subscription?.subscriptionPeriod.unit == .year
        var trialDays: Int?
        if let offer = subscription?.introductoryOffer, offer.paymentMode == .freeTrial,
           await subscription?.isEligibleForIntroOffer ?? false {
            trialDays = offer.period.unit == .week ? offer.period.value * 7 : offer.period.value
        }
        return Plan(id: product.id, title: isYearly ? "Yearly" : "Weekly", price: product.displayPrice,
                    period: isYearly ? "year" : "week", trialDays: trialDays, product: product)
    }

    #if DEBUG
    /// Shown only in debug builds launched with `-demoPrices YES`, where StoreKit has no products.
    private static let previewPlans = [
        Plan(id: yearlyID, title: "Yearly", price: "$29.99", period: "year", trialDays: 3, product: nil),
        Plan(id: weeklyID, title: "Weekly", price: "$4.99", period: "week", trialDays: nil, product: nil),
    ]
    #endif
}
