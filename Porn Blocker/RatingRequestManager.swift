import Foundation
import StoreKit
import SwiftUI
import UIKit

@MainActor
final class RatingRequestManager {
    static let shared = RatingRequestManager()

    private let userDefaults = UserDefaults.standard
    private let minLaunchesBeforePrompt = 5
    private let minDaysBetweenPrompts = 90
    private let firstUseDelayDays = 3
    
    // Your App Store ID
    private let appStoreID = "6749251520"

    private let launchesKey = "appLaunchCount"
    private let lastPromptDateKey = "lastRatingPromptDate"
    private let firstInstallDateKey = "firstInstallDate"

    private init() {
        if userDefaults.object(forKey: firstInstallDateKey) == nil {
            userDefaults.set(Date(), forKey: firstInstallDateKey)
        }
    }

    func trackLaunch() {
        let launches = userDefaults.integer(forKey: launchesKey) + 1
        userDefaults.set(launches, forKey: launchesKey)
    }

    func maybePromptForReview(context: UIApplication? = UIApplication.shared) {
        guard shouldPrompt() else { return }
        
        // Try the system rating dialog first
        if let scene = context?.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
            userDefaults.set(Date(), forKey: lastPromptDateKey)
            
            // Set a fallback timer in case the system dialog doesn't appear or work
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.showFallbackRatingPrompt()
            }
        } else {
            // Fallback if no scene is available
            showFallbackRatingPrompt()
        }
    }
    
    func promptForReviewDirectly() {
        // Force show the custom rating prompt (for testing or manual triggering)
        showFallbackRatingPrompt()
    }
    
    private func showFallbackRatingPrompt() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let rootViewController = window.rootViewController else {
            // Last resort: open App Store directly
            openAppStoreReview()
            return
        }
        
        let alert = UIAlertController(
            title: "Enjoying Porn Blocker?",
            message: "Tap a star to rate it on the App Store. Your feedback helps us improve the app!",
            preferredStyle: .alert
        )
        
        // Add star rating buttons
        for rating in 1...5 {
            let starTitle = String(repeating: "⭐", count: rating)
            alert.addAction(UIAlertAction(title: starTitle, style: .default) { _ in
                self.openAppStoreReview()
            })
        }
        
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
        
        rootViewController.present(alert, animated: true)
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
        let launches = userDefaults.integer(forKey: launchesKey)
        guard launches >= minLaunchesBeforePrompt else { return false }

        // Ensure some days after first install
        if let firstInstall = userDefaults.object(forKey: firstInstallDateKey) as? Date {
            let daysSinceInstall = Calendar.current.dateComponents([.day], from: firstInstall, to: Date()).day ?? 0
            if daysSinceInstall < firstUseDelayDays { return false }
        }

        // Throttle prompts
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