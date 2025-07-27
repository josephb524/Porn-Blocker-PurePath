import Foundation
import StoreKit
import SwiftUI

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published private(set) var isSubscribed = false {
        didSet {
            // Notify BlocklistManager when subscription status changes
            if oldValue != isSubscribed {
                BlocklistManager.shared.updateSubscriptionStatus()
            }
        }
    }
    //@AppStorage("isUserSubscribed") private(set) var isSubscribed = false
    @Published private(set) var expiryDate: Date? = nil
    
    private let productID = "com.yourcompany.pornblocker.yearly" // Replace with your real product ID

    private var updateListenerTask: Task<Void, Never>? = nil

    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await checkSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func purchase() async throws {
        // Implement StoreKit purchase logic here
        // For now, just simulate a successful purchase
        isSubscribed = true
        expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
    }
    
    func restore() async {
        // Implement StoreKit restore logic here
        // For now, just simulate a successful restore
        isSubscribed = true
        expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
    }

    func checkSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productID,
               transaction.revocationDate == nil,
               transaction.expirationDate ?? .distantPast > Date() {
                DispatchQueue.main.async {
                    self.isSubscribed = true
                }
                return
            }
        }
        DispatchQueue.main.async {
            self.isSubscribed = false
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached {
            for await _ in Transaction.updates {
                await self.checkSubscriptionStatus()
            }
        }
    }
} 
