import Foundation
import StoreKit
import SwiftUI

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published private(set) var isSubscribed = false {
        didSet {
            if oldValue != isSubscribed {
                Log.debug("🔄 Subscription status changed: \(oldValue) → \(isSubscribed)")
            }
        }
    }
    @Published private(set) var expiryDate: Date? = nil
    /// Available subscription products, cheapest first.
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String? = nil

    /// Apple-signed JWS for the active subscription. Sent to the chat Worker
    /// as proof of entitlement — `nil` when not subscribed.
    @Published private(set) var signedTransactionJWS: String? = nil
    /// The transaction's original (first-purchase) identifier — useful for
    /// per-user rate limiting on the Worker.
    @Published private(set) var originalTransactionID: UInt64? = nil
    
    // Auto-renewal specific properties
    @Published private(set) var autoRenewalEnabled = true
    @Published private(set) var nextRenewalDate: Date? = nil
    @Published private(set) var renewalStatus: RenewalStatus = .unknown
    @Published private(set) var daysUntilRenewal: Int? = nil
    
    // Product IDs — must match the auto-renewable subscriptions configured in
    // App Store Connect. `nonisolated` so the background transaction listener
    // can read them.
    private nonisolated static let monthlyProductID = "pornBlockerMonthly"
    private nonisolated static let yearlyProductID = "pornBlocker"
    private nonisolated static let productIDs: Set<String> = [monthlyProductID, yearlyProductID]
    private var updateListenerTask: Task<Void, Never>? = nil
    private var expirationCheckTimer: Timer?

    private init() {
        updateListenerTask = listenForTransactions()
        startExpirationTimer()
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
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
            products = loaded.sorted { $0.price < $1.price }
            if products.isEmpty {
                errorMessage = "Subscription products not found"
                Log.debug("❌ No subscription products loaded")
            } else {
                Log.debug("✅ Loaded \(products.count) products: \(products.map(\.id))")
            }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
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

                // Capture the Apple-signed JWS — the chat Worker uses it as
                // proof of entitlement.
                signedTransactionJWS = verification.jwsRepresentation
                originalTransactionID = transaction.originalID

                // Update subscription status
                await updateSubscriptionStatus(from: transaction)

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
            
            if isSubscribed {
                Log.debug("✅ Subscription restored successfully")
            } else {
                errorMessage = "No active subscription found"
                Log.debug("⚠️ No active subscription found")
            }
        } catch {
            errorMessage = "Failed to restore: \(error.localizedDescription)"
            Log.debug("❌ Restore failed: \(error)")
        }
        
        isLoading = false
    }

    // MARK: - Subscription Status
    
    func checkSubscriptionStatus() async {
        Log.debug("🔍 Checking subscription status at \(Date())")
        var foundActive = false
        var latestTransaction: StoreKit.Transaction?
        var latestJWS: String?

        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }

            // Subscription must have an expiration in the future; non-expiring
            // entries shouldn't happen for these auto-renewables but we accept
            // them defensively.
            let isActive: Bool
            if let expiry = transaction.expirationDate {
                isActive = expiry > Date()
            } else {
                isActive = true
            }
            guard isActive else { continue }

            latestTransaction = transaction
            latestJWS = result.jwsRepresentation
            foundActive = true
            Log.debug("✅ Active subscription: \(transaction.productID), expiry: \(transaction.expirationDate?.description ?? "none")")
        }

        if foundActive, let transaction = latestTransaction {
            // Capture proof of entitlement for the chat Worker.
            signedTransactionJWS = latestJWS
            originalTransactionID = transaction.originalID
            await updateSubscriptionStatus(from: transaction)
        } else {
            await setSubscriptionExpired()
        }
    }
    
    private func updateSubscriptionStatus(from transaction: StoreKit.Transaction) async {
        let wasSubscribed = isSubscribed
        isSubscribed = true
        expiryDate = transaction.expirationDate

        // Update auto-renewal information
        await updateAutoRenewalInfo(from: transaction)

        if let expiry = expiryDate {
            Log.debug("✅ Active subscription until: \(expiry)")
        } else {
            Log.debug("✅ Active subscription (no expiry)")
        }
        if !wasSubscribed {
            Log.debug("🎉 Subscription activated!")
        }

        // Let observers (BlocklistManager) re-sync the extension. Posted even
        // when `isSubscribed` is unchanged so a renewed expiry date propagates.
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }
    
    private func setSubscriptionExpired() async {
        let wasSubscribed = isSubscribed
        isSubscribed = false
        expiryDate = nil
        signedTransactionJWS = nil
        originalTransactionID = nil

        // Reset auto-renewal info when no subscription found.
        autoRenewalEnabled = false
        nextRenewalDate = nil
        renewalStatus = .noSubscription
        daysUntilRenewal = nil

        if wasSubscribed {
            Log.debug("🚨 Subscription expired or not found — blocking disabled")
        } else {
            Log.debug("📱 No active subscription found")
        }

        // Let observers (BlocklistManager) re-sync the extension.
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }
    
    private func updateAutoRenewalInfo(from transaction: StoreKit.Transaction) async {
        // For subscription products, we can assume they are auto-renewable
        // since we're only dealing with subscription products in this app
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
    var hasLoadedProducts: Bool { !products.isEmpty }

    /// Percentage saved by the yearly plan versus paying monthly for a year.
    var yearlySavingsPercent: Int? {
        guard let monthly = monthlyProduct, let yearly = yearlyProduct else { return nil }
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
            return "Active"
        case .renewingSoon:
            return "Renewing Soon"
        case .expired:
            return "Expired"
        case .noSubscription:
            return "No Subscription"
        case .notAutoRenewable:
            return "Not Auto-Renewable"
        case .unknown:
            return "Unknown"
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
            return "Subscription product not available"
        case .failedVerification:
            return "Failed to verify purchase"
        case .userCancelled:
            return "Purchase was cancelled"
        case .purchasePending:
            return "Purchase is pending approval"
        case .unknown:
            return "An unknown error occurred"
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
    /// The subscription period as a short noun, e.g. "month" or "year".
    var periodUnitText: String {
        guard let period = subscription?.subscriptionPeriod else { return "" }
        let plural = period.value > 1
        switch period.unit {
        case .day:   return plural ? "\(period.value) days" : "day"
        case .week:  return plural ? "\(period.value) weeks" : "week"
        case .month: return plural ? "\(period.value) months" : "month"
        case .year:  return plural ? "\(period.value) years" : "year"
        @unknown default: return ""
        }
    }

    /// A capitalized plan name derived from the period, e.g. "Monthly" / "Yearly".
    var planName: String {
        switch subscription?.subscriptionPeriod.unit {
        case .day:   return "Daily"
        case .week:  return "Weekly"
        case .month: return "Monthly"
        case .year:  return "Yearly"
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
        case .day:   return "\(period.value)-day free trial"
        case .week:  return "\(period.value)-week free trial"
        case .month: return "\(period.value)-month free trial"
        case .year:  return "\(period.value)-year free trial"
        @unknown default: return nil
        }
    }
}

