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
        if let scene = context?.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
            userDefaults.set(Date(), forKey: lastPromptDateKey)
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
} 