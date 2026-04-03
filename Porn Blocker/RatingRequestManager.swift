import Foundation
import StoreKit
import SwiftUI
import UIKit

@MainActor
final class RatingRequestManager: ObservableObject {
    static let shared = RatingRequestManager()
    
    @Published var showReviewPrompt = false

    private let userDefaults = UserDefaults.standard
    private let minLaunchesBeforePrompt = 5
    private let minDaysBetweenPrompts = 90
    private let firstUseDelayDays = 3
    
    // Your App Store ID
    let appStoreID = "6749251520"

    private let launchesKey = "appLaunchCount"
    private let lastPromptDateKey = "lastRatingPromptDate"
    private let firstInstallDateKey = "firstInstallDate"
    private let dismissPermanentlyKey = "reviewPromptDismissedPermanently"

    private init() {
        if userDefaults.object(forKey: firstInstallDateKey) == nil {
            userDefaults.set(Date(), forKey: firstInstallDateKey)
        }
    }

    func userDismissedReview() {
        userDefaults.set(true, forKey: dismissPermanentlyKey)
    }

    func trackLaunch() {
        let launches = userDefaults.integer(forKey: launchesKey) + 1
        userDefaults.set(launches, forKey: launchesKey)
    }

    func maybePromptForReview(context: UIApplication? = nil) {
        guard shouldPrompt() else { return }
        
        let actualContext = context ?? UIApplication.shared
        
        if let scene = actualContext.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
            userDefaults.set(Date(), forKey: lastPromptDateKey)
            
            // Wait slightly before showing our custom prompt as a follow-up
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.showReviewPrompt = true
            }
        } else {
            self.showReviewPrompt = true
        }
    }
    
    func promptForReviewDirectly() {
        self.showReviewPrompt = true
    }
    
    private func openAppStoreReview() {
        let reviewURL = "https://apps.apple.com/app/id\(appStoreID)?action=write-review"
        
        if let url = URL(string: reviewURL) {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    print("Failed to open App Store review URL")
                }
            }
        }
    }

    private func shouldPrompt() -> Bool {
        if userDefaults.bool(forKey: dismissPermanentlyKey) { return false }
        
        let launches = userDefaults.integer(forKey: launchesKey)
        guard launches >= minLaunchesBeforePrompt else { return false }

        if let firstInstall = userDefaults.object(forKey: firstInstallDateKey) as? Date {
            let daysSinceInstall = Calendar.current.dateComponents([.day], from: firstInstall, to: Date()).day ?? 0
            if daysSinceInstall < firstUseDelayDays { return false }
        }

        if let lastPrompt = userDefaults.object(forKey: lastPromptDateKey) as? Date {
            let days = Calendar.current.dateComponents([.day], from: lastPrompt, to: Date()).day ?? 0
            if days < minDaysBetweenPrompts { return false }
        }

        return true
    }
    
    private var launches: Int {
        return userDefaults.integer(forKey: launchesKey)
    }
}
