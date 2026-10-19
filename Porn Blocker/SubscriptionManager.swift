import Foundation
import StoreKit
import SwiftUI

/// What the user owns, reduced to the facts the app gates on. Pure, so the
/// gating rules are unit-tested (`EntitlementsTests`).
struct Entitlements: Equatable {
    /// An active Premium subscription (monthly / yearly): everything.
    var hasPremiumSubscription = false
    var premiumExpiry: Date? = nil
    /// The one-time Lifetime purchase: protection, but not Buddy chat.
    var ownsLifetime = false
    /// The Buddy Chat add-on subscription: chat only. Sold to Lifetime owners
    /// so they needn't buy Premium again just to get the chat.
    var hasBuddySubscription = false
    var buddyExpiry: Date? = nil

    /// Safari blocking, Safe Browse, custom lists, whitelist.
    var protectionUnlocked: Bool { hasPremiumSubscription || ownsLifetime }
    /// Buddy chat. Never Lifetime alone — the chat costs money per message, so
    /// it only ever comes with a subscription.
    var buddyUnlocked: Bool { hasPremiumSubscription || hasBuddySubscription }
    /// When protection ends, as the Safari extension is told. `nil` for
    /// Lifetime owners: a Premium subscription lapsing while the app is closed
    /// must not disarm Safari for someone who owns protection outright.
    var protectionExpiry: Date? { ownsLifetime ? nil : premiumExpiry }
}

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    /// Everything the user owns. The gating flags below all derive from it, so
    /// they can never disagree with each other.
    @Published private(set) var entitlements = Entitlements() {
        didSet {
            if oldValue != entitlements {
                Log.debug("🔄 Entitlements changed — protection: \(oldValue.protectionUnlocked) → \(entitlements.protectionUnlocked), chat: \(oldValue.buddyUnlocked) → \(entitlements.buddyUnlocked), lifetime: \(entitlements.ownsLifetime)")
            }
        }
    }
    /// Protection is unlocked — by Premium **or** the Lifetime purchase. Gates
    /// every paid feature except Buddy chat, which gates on `hasBuddyAccess`.
    /// The name predates Lifetime: read it as "has premium protection".
    var isSubscribed: Bool { entitlements.protectionUnlocked }
    /// Buddy chat is unlocked — by Premium or the Buddy Chat add-on, never by
    /// Lifetime alone.
    var hasBuddyAccess: Bool { entitlements.buddyUnlocked }
    var ownsLifetime: Bool { entitlements.ownsLifetime }
    /// The Premium subscription's expiry. What the Safari extension is told is
    /// `protectionExpiryDate`.
    var expiryDate: Date? { entitlements.premiumExpiry }
    /// See `Entitlements.protectionExpiry`.
    var protectionExpiryDate: Date? { entitlements.protectionExpiry }
    /// `false` until the first `checkSubscriptionStatus()` completes — i.e. until
    /// StoreKit has actually been asked. Distinguishes "not subscribed" from
    /// "don't know yet" so the UI can avoid flashing an alarm state, and so the
    /// content blocker is never downgraded on a status we haven't resolved.
    @Published private(set) var hasResolvedStatus = false
    /// StoreKit hasn't answered and the launch cache can't vouch for the
    /// status: nothing was ever resolved on this install, or the cached
    /// Premium subscription is past its cached expiry and has most likely
    /// renewed. Someone the last check found without protection isn't
    /// "unknown" — they see that answer at once, not a "checking" card on
    /// every launch.
    var protectionStatusUnknown: Bool {
        !isSubscribed && !hasResolvedStatus && !cacheIsConclusive
    }
    /// Set once, by `seedFromCache()`.
    private var cacheIsConclusive = false
    /// Available products — Premium, Lifetime and the Buddy Chat add-on —
    /// cheapest first.
    @Published private(set) var products: [Product] = []
    /// Products whose free trial *this Apple ID* can still take. An intro
    /// offer existing is not the user being eligible: someone who already
    /// used the trial would read "Start Free Trial" and be charged at once.
    @Published private(set) var trialEligibleProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String? = nil

    /// Apple-signed JWS of the subscription that includes chat (Premium, else
    /// the Buddy Chat add-on). Sent to the chat Worker as `signedTransaction`
    /// — `nil` when chat isn't unlocked. Never the Lifetime purchase: the
    /// Worker rejects it.
    @Published private(set) var signedTransactionJWS: String? = nil
    /// That transaction's original (first-purchase) identifier — useful for
    /// per-user rate limiting on the Worker.
    @Published private(set) var originalTransactionID: UInt64? = nil

    // Auto-renewal specific properties
    @Published private(set) var autoRenewalEnabled = true
    @Published private(set) var nextRenewalDate: Date? = nil
    @Published private(set) var renewalStatus: RenewalStatus = .unknown
    @Published private(set) var daysUntilRenewal: Int? = nil

    // Product IDs — must match the products configured in App Store Connect.
    // `nonisolated` so the background transaction listener can read them.
    private nonisolated static let monthlyProductID = "monthlyPornBlocker"
    private nonisolated static let yearlyProductID = "pornBlocker"
    /// Non-consumable. Deliberately absent from the Worker's
    /// `VALID_PRODUCT_IDS` — Lifetime doesn't include chat.
    private nonisolated static let lifetimeProductID = "lifetimePornBlocker"
    /// The Buddy Chat add-on. Its own subscription group, so it never shows up
    /// as a cheaper switch from Premium in Settings → Subscriptions.
    private nonisolated static let buddyMonthlyProductID = "buddyChatMonthly"
    private nonisolated static let buddyYearlyProductID = "buddyChatYearly"
    private nonisolated static let premiumSubscriptionIDs: Set<String> = [monthlyProductID, yearlyProductID]
    private nonisolated static let buddySubscriptionIDs: Set<String> = [buddyMonthlyProductID, buddyYearlyProductID]
    private nonisolated static let productIDs: Set<String> =
        premiumSubscriptionIDs.union(buddySubscriptionIDs).union([lifetimeProductID])
    private var updateListenerTask: Task<Void, Never>? = nil
    private var expirationCheckTimer: Timer?

    private init() {
        // Seed from the last *resolved* status before anything reads us —
        // StoreKit's answer is async, and without this every launch renders at
        // least one frame as "not subscribed".
        seedFromCache()
        updateListenerTask = listenForTransactions()
        startExpirationTimer()
        // Entitlements are on-device and resolve fast; products need the network
        // and are only needed by the paywall. Running them in separate tasks
        // keeps the status check from queueing behind an App Store round-trip.
        Task { await checkSubscriptionStatus() }
        Task { await loadProducts() }
    }

    // MARK: - Status Cache

    /// Keys are owned solely by this type. Deliberately **not** the app-group
    /// keys `BlocklistManager` mirrors for the extension — those are written
    /// before StoreKit resolves and would seed a stale `false`. The first pair
    /// is Premium's; it was named before Lifetime and the add-on existed.
    private static let cachedActiveKey = "cachedSubscriptionActive"
    private static let cachedExpiryKey = "cachedSubscriptionExpiry"
    private static let cachedLifetimeKey = "cachedLifetimeOwned"
    private static let cachedBuddyActiveKey = "cachedBuddySubscriptionActive"
    private static let cachedBuddyExpiryKey = "cachedBuddySubscriptionExpiry"

    /// Whether a cached status should be trusted as still active. Requires a
    /// known expiry in the future, so an optimistic `true` can never outlive the
    /// subscription it was cached from.
    nonisolated static func cachedStatusIsActive(flag: Bool, expiry: TimeInterval?, now: Date) -> Bool {
        guard flag, let expiry else { return false }
        return expiry > now.timeIntervalSince1970
    }

    /// Whether the cache's answer can stand until StoreKit's arrives (see
    /// `protectionStatusUnknown`). `premiumFlag` is the cached Premium flag —
    /// `nil` when nothing was ever resolved on this install — and
    /// `premiumSeeded` whether `cachedStatusIsActive` trusted it. A flag
    /// still set but no longer trusted is a subscription past its cached
    /// expiry: most likely renewed, so not a known "no".
    nonisolated static func cacheIsConclusive(premiumFlag: Bool?, premiumSeeded: Bool) -> Bool {
        premiumFlag == false || premiumSeeded
    }

    private func seedFromCache() {
        let defaults = UserDefaults.standard
        let now = Date()
        var seed = Entitlements()
        // A Lifetime purchase never expires, so it needs no expiry gate — a
        // refund is caught by the launch check like any other change.
        seed.ownsLifetime = defaults.bool(forKey: Self.cachedLifetimeKey)
        if let expiry = Self.cachedActiveExpiry(flagKey: Self.cachedActiveKey, expiryKey: Self.cachedExpiryKey, now: now) {
            seed.hasPremiumSubscription = true
            seed.premiumExpiry = expiry
        }
        if let expiry = Self.cachedActiveExpiry(flagKey: Self.cachedBuddyActiveKey, expiryKey: Self.cachedBuddyExpiryKey, now: now) {
            seed.hasBuddySubscription = true
            seed.buddyExpiry = expiry
        }
        cacheIsConclusive = Self.cacheIsConclusive(
            premiumFlag: defaults.object(forKey: Self.cachedActiveKey) as? Bool,
            premiumSeeded: seed.hasPremiumSubscription
        )
        guard seed != Entitlements() else { return }
        entitlements = seed
        Log.debug("💾 Seeded entitlements from cache — protection: \(seed.protectionUnlocked), chat: \(seed.buddyUnlocked), lifetime: \(seed.ownsLifetime)")
    }

    /// A cached subscription's expiry, when `cachedStatusIsActive` trusts it.
    private static func cachedActiveExpiry(flagKey: String, expiryKey: String, now: Date) -> Date? {
        let defaults = UserDefaults.standard
        let expiry = defaults.object(forKey: expiryKey) as? TimeInterval
        guard cachedStatusIsActive(flag: defaults.bool(forKey: flagKey), expiry: expiry, now: now),
              let expiry else { return nil }
        return Date(timeIntervalSince1970: expiry)
    }

    /// Records entitlements we actually got from StoreKit — the flag and the
    /// cache move together so they can't drift. Never called from `init`; the
    /// caller invokes it *before* posting `.subscriptionStatusChanged` so
    /// observers already see a resolved status.
    private func markStatusResolved() {
        hasResolvedStatus = true

        let defaults = UserDefaults.standard
        func setExpiry(_ date: Date?, forKey key: String) {
            if let date {
                defaults.set(date.timeIntervalSince1970, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.set(entitlements.hasPremiumSubscription, forKey: Self.cachedActiveKey)
        setExpiry(entitlements.premiumExpiry, forKey: Self.cachedExpiryKey)
        defaults.set(entitlements.ownsLifetime, forKey: Self.cachedLifetimeKey)
        defaults.set(entitlements.hasBuddySubscription, forKey: Self.cachedBuddyActiveKey)
        setExpiry(entitlements.buddyExpiry, forKey: Self.cachedBuddyExpiryKey)
    }

    deinit {
        updateListenerTask?.cancel()
        expirationCheckTimer?.invalidate()
    }

    // MARK: - Expiration Timer

    private func startExpirationTimer() {
        // Re-check expiration hourly as a safety net. Real-time subscription
        // changes already arrive through `Transaction.updates`, so a tight
        // interval here would only drain the battery.
        expirationCheckTimer = Timer.scheduledTimer(withTimeInterval: 3600.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.checkSubscriptionStatus()
            }
        }
    }

    // MARK: - Product Loading

    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            let sorted = loaded.sorted { $0.price < $1.price }
            // Resolve eligibility before publishing either value, so the
            // paywall never renders the prices with the trial still unknown
            // ("Subscribe Now" flashing into "Start Free Trial").
            var eligible = Set<String>()
            for product in sorted where product.freeTrialText != nil {
                // Per subscription group, per Apple ID: false once this
                // account has ever subscribed or taken a trial in the group.
                if await product.subscription?.isEligibleForIntroOffer == true {
                    eligible.insert(product.id)
                }
            }
            trialEligibleProductIDs = eligible
            products = sorted
            Log.debug("Trial offers: \(sorted.filter { $0.freeTrialText != nil }.map(\.id)), eligible: \(eligible.sorted())")
            if products.isEmpty {
                errorMessage = String(localized: "Subscription products not found")
                Log.debug("❌ No subscription products loaded")
            } else {
                Log.debug("✅ Loaded \(products.count) products: \(products.map(\.id))")
            }
        } catch {
            errorMessage = String(localized: "Failed to load products: \(error.localizedDescription)")
            Log.debug("❌ Error loading products: \(error)")
        }
        isLoading = false
    }

    // MARK: - Purchase Flow

    func purchase(_ product: Product) async throws {
        isLoading = true
        errorMessage = nil

        // Use defer to ensure isLoading is always reset
        defer {
            isLoading = false
        }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)

                // Re-derive everything from current entitlements, which
                // already include this purchase, rather than from this one
                // transaction: it may be the Lifetime purchase, which must not
                // replace the chat Worker's subscription JWS.
                await checkSubscriptionStatus()

                // Finish the transaction
                await transaction.finish()

                Log.debug("✅ Purchase successful!")

            case .userCancelled:
                Log.debug("🚫 User cancelled purchase")
                throw SubscriptionError.userCancelled

            case .pending:
                Log.debug("⏳ Purchase pending")
                throw SubscriptionError.purchasePending

            @unknown default:
                Log.debug("❌ Unknown purchase result")
                throw SubscriptionError.unknown
            }
        } catch {
            errorMessage = error.localizedDescription
            Log.debug("❌ Purchase failed: \(error)")
            throw error
        }
    }

    // MARK: - Restore Purchases

    func restore() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()

            if isSubscribed || hasBuddyAccess {
                Log.debug("✅ Purchases restored successfully")
            } else {
                errorMessage = String(localized: "No active subscription found")
                Log.debug("⚠️ No active subscription found")
            }
        } catch {
            errorMessage = String(localized: "Failed to restore: \(error.localizedDescription)")
            Log.debug("❌ Restore failed: \(error)")
        }

        isLoading = false
    }

    // MARK: - Subscription Status

    func checkSubscriptionStatus() async {
        Log.debug("🔍 Checking subscription status at \(Date())")
        var found = Entitlements()
        var premium: (transaction: StoreKit.Transaction, jws: String)?
        var buddy: (transaction: StoreKit.Transaction, jws: String)?

        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }

            if transaction.productID == Self.lifetimeProductID {
                found.ownsLifetime = true
                Log.debug("✅ Lifetime purchase owned")
                continue
            }

            // Subscription must have an expiration in the future; non-expiring
            // entries shouldn't happen for these auto-renewables but we accept
            // them defensively.
            if let expiry = transaction.expirationDate, expiry <= Date() { continue }

            if Self.premiumSubscriptionIDs.contains(transaction.productID) {
                premium = (transaction, result.jwsRepresentation)
            } else if Self.buddySubscriptionIDs.contains(transaction.productID) {
                buddy = (transaction, result.jwsRepresentation)
            }
            Log.debug("✅ Active subscription: \(transaction.productID), expiry: \(transaction.expirationDate?.description ?? "none")")
        }

        found.hasPremiumSubscription = premium != nil
        found.premiumExpiry = premium?.transaction.expirationDate
        found.hasBuddySubscription = buddy != nil
        found.buddyExpiry = buddy?.transaction.expirationDate

        // Proof of entitlement for the chat Worker comes from whichever
        // subscription includes chat.
        let chatGrant = premium ?? buddy
        signedTransactionJWS = chatGrant?.jws
        originalTransactionID = chatGrant?.transaction.originalID
        updateAutoRenewalInfo(from: chatGrant?.transaction)

        entitlements = found
        Log.debug("📱 Status — protection: \(found.protectionUnlocked), chat: \(found.buddyUnlocked), lifetime: \(found.ownsLifetime), premium expiry: \(found.premiumExpiry?.description ?? "none")")

        markStatusResolved()

        // Let observers (BlocklistManager) re-sync the extension. Posted even
        // when nothing changed so a renewed expiry date propagates.
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }

    /// Renewal details for the active subscription — `nil` when there is none
    /// (including a Lifetime owner without the chat add-on).
    private func updateAutoRenewalInfo(from transaction: StoreKit.Transaction?) {
        guard let transaction else {
            autoRenewalEnabled = false
            nextRenewalDate = nil
            renewalStatus = .noSubscription
            daysUntilRenewal = nil
            return
        }

        // Both subscription groups are auto-renewable
        autoRenewalEnabled = true

        // Set next renewal date (same as expiration date for auto-renewable)
        nextRenewalDate = transaction.expirationDate

        // Calculate days until renewal
        if let nextRenewal = nextRenewalDate {
            let calendar = Calendar.current
            let days = calendar.dateComponents([.day], from: Date(), to: nextRenewal).day ?? 0
            daysUntilRenewal = max(0, days)

            // Determine renewal status
            if days <= 0 {
                renewalStatus = .expired
            } else if days <= 7 {
                renewalStatus = .renewingSoon
            } else if days <= 30 {
                renewalStatus = .active
            } else {
                renewalStatus = .active
            }
        } else {
            renewalStatus = .unknown
            daysUntilRenewal = nil
        }

        Log.debug("🔄 Auto-renewal info updated: \(renewalStatus.rawValue), \(daysUntilRenewal ?? 0) days until renewal")
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached { [weak self] in
            guard let self = self else { return }

            for await result in StoreKit.Transaction.updates {
                Log.debug("🔄 Transaction update received")
                do {
                    // Verify transaction inline
                    let transaction: StoreKit.Transaction
                    switch result {
                    case .unverified:
                        Log.debug("❌ Unverified transaction received")
                        throw SubscriptionError.failedVerification
                    case .verified(let verifiedTransaction):
                        transaction = verifiedTransaction
                        Log.debug("✅ Verified transaction: \(transaction.id) for product: \(transaction.productID)")
                    }

                    if Self.productIDs.contains(transaction.productID) {
                        Log.debug("🎯 Processing transaction for our product")
                        await self.checkSubscriptionStatus()
                    }

                    await transaction.finish()
                } catch {
                    Log.debug("❌ Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Transaction Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Helper Properties

    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyProductID } }
    var yearlyProduct: Product? { products.first { $0.id == Self.yearlyProductID } }
    var lifetimeProduct: Product? { products.first { $0.id == Self.lifetimeProductID } }
    var buddyMonthlyProduct: Product? { products.first { $0.id == Self.buddyMonthlyProductID } }
    var buddyYearlyProduct: Product? { products.first { $0.id == Self.buddyYearlyProductID } }
    /// Premium's plans, cheapest first — the paywall's side-by-side cards.
    var premiumPlans: [Product] { products.filter { Self.premiumSubscriptionIDs.contains($0.id) } }
    /// The Buddy Chat add-on's plans, cheapest first — sold to Lifetime owners.
    var buddyPlans: [Product] { products.filter { Self.buddySubscriptionIDs.contains($0.id) } }
    var hasLoadedProducts: Bool { !products.isEmpty }

    /// The trial text for `product`, but only when this Apple ID can still
    /// take the trial. Every trial mention in the UI goes through this.
    func trialText(for product: Product?) -> String? {
        guard let product, trialEligibleProductIDs.contains(product.id) else { return nil }
        return product.freeTrialText
    }

    /// Percentage `yearly` saves versus paying `monthly` for a year.
    func yearlySavingsPercent(monthly: Product?, yearly: Product?) -> Int? {
        guard let monthly, let yearly else { return nil }
        let monthlyAnnual = monthly.price * 12
        guard monthlyAnnual > 0 else { return nil }
        let saved = (monthlyAnnual - yearly.price) / monthlyAnnual
        let percent = Int((NSDecimalNumber(decimal: saved).doubleValue * 100).rounded())
        return percent > 0 ? percent : nil
    }

    // MARK: - Auto-Renewal Management

    func manageAutoRenewal() {
        // Open App Store subscription management
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    func checkRenewalStatus() async {
        await checkSubscriptionStatus()

        // Log renewal information
        if let days = daysUntilRenewal {
            Log.debug("🔄 Renewal status: \(renewalStatus.rawValue)")
            Log.debug("📅 Days until renewal: \(days)")

            if days <= 7 {
                Log.debug("⚠️ Subscription renewing soon!")
            }
        }
    }

    var renewalStatusDescription: String {
        switch renewalStatus {
        case .active:
            return String(localized: "Active")
        case .renewingSoon:
            return String(localized: "Renewing Soon")
        case .expired:
            return String(localized: "Expired")
        case .noSubscription:
            return String(localized: "No Subscription")
        case .notAutoRenewable:
            return String(localized: "Not Auto-Renewable")
        case .unknown:
            return String(localized: "Unknown")
        }
    }

    var renewalStatusColor: Color {
        switch renewalStatus {
        case .active:
            return .green
        case .renewingSoon:
            return .orange
        case .expired:
            return .red
        case .noSubscription:
            return .gray
        case .notAutoRenewable:
            return .blue
        case .unknown:
            return .gray
        }
    }

}

// MARK: - Subscription Errors

enum SubscriptionError: LocalizedError {
    case productNotLoaded
    case failedVerification
    case userCancelled
    case purchasePending
    case unknown

    var errorDescription: String? {
        switch self {
        case .productNotLoaded:
            return String(localized: "Subscription product not available")
        case .failedVerification:
            return String(localized: "Failed to verify purchase")
        case .userCancelled:
            return String(localized: "Purchase was cancelled")
        case .purchasePending:
            return String(localized: "Purchase is pending approval")
        case .unknown:
            return String(localized: "An unknown error occurred")
        }
    }
}

// MARK: - Renewal Status

enum RenewalStatus: String, CaseIterable {
    case active = "Active"
    case renewingSoon = "Renewing Soon"
    case expired = "Expired"
    case noSubscription = "No Subscription"
    case notAutoRenewable = "Not Auto-Renewable"
    case unknown = "Unknown"
}

// MARK: - Notifications

extension Notification.Name {
    /// Posted by `SubscriptionManager` whenever subscription status is
    /// (re-)evaluated. `BlocklistManager` observes this to re-sync the
    /// content blocker — keeping the two managers decoupled.
    static let subscriptionStatusChanged = Notification.Name("subscriptionStatusChanged")
}

// MARK: - Product Display Helpers

extension Product {
    /// The one-time Lifetime purchase — the app's only non-consumable.
    var isLifetime: Bool { type == .nonConsumable }

    /// The subscription period as a short noun, e.g. "month" or "year".
    var periodUnitText: String {
        guard let period = subscription?.subscriptionPeriod else { return "" }
        let plural = period.value > 1
        switch period.unit {
        case .day:   return plural ? String(localized: "\(period.value) days", comment: "Billing period after \"per\", e.g. \"per 3 months\"") : String(localized: "day", comment: "Billing period after \"per\", e.g. \"per day\"")
        case .week:  return plural ? String(localized: "\(period.value) weeks", comment: "Billing period after \"per\", e.g. \"per 3 months\"") : String(localized: "week", comment: "Billing period after \"per\", e.g. \"per week\"")
        case .month: return plural ? String(localized: "\(period.value) months", comment: "Billing period after \"per\", e.g. \"per 3 months\"") : String(localized: "month", comment: "Billing period after \"per\", e.g. \"per month\"")
        case .year:  return plural ? String(localized: "\(period.value) years", comment: "Billing period after \"per\", e.g. \"per 3 months\"") : String(localized: "year", comment: "Billing period after \"per\", e.g. \"per year\"")
        @unknown default: return ""
        }
    }

    /// A capitalized plan name derived from the period, e.g. "Monthly" / "Yearly".
    var planName: String {
        switch subscription?.subscriptionPeriod.unit {
        case .day:   return String(localized: "Daily")
        case .week:  return String(localized: "Weekly")
        case .month: return String(localized: "Monthly")
        case .year:  return String(localized: "Yearly")
        default:     return displayName
        }
    }

    /// A free-trial description if this product has a free-trial introductory
    /// offer, e.g. "7-day free trial"; otherwise `nil`.
    var freeTrialText: String? {
        guard let offer = subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let period = offer.period
        switch period.unit {
        case .day:   return String(localized: "\(period.value)-day free trial")
        case .week:  return String(localized: "\(period.value)-week free trial")
        case .month: return String(localized: "\(period.value)-month free trial")
        case .year:  return String(localized: "\(period.value)-year free trial")
        @unknown default: return nil
        }
    }
}

