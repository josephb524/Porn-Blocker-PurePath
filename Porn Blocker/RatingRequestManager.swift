import Foundation
import StoreKit
import SwiftUI
import UIKit

/// Review prompts. Two paths, still mutually exclusive — now by
/// `ReviewScheduler` (shared, byte-identical across apps) rather than by
/// convention: Apple's native sheet on its 90-day cadence, the custom
/// `ReviewPromptView` card every 30 days, never both in one session, and a
/// 14-day gap after whichever fired last. Settings' "Rate the App" opens the
/// App Store review page directly.
@MainActor
final class RatingRequestManager: ObservableObject {
    static let shared = RatingRequestManager()

    @Published var showReviewPrompt = false

    private let store = ReviewStore()
    private let policy: ReviewPolicy = {
        var p = ReviewPolicy.standard
        p.minimumLaunches = 5
        p.minimumPrimaryActions = 0
        p.minimumSecondaryActions = 0
        p.minimumDaysSinceInstall = 3
        return p
    }()
    private var promptedThisSession = false

    // Your App Store ID
    let appStoreID = "6749251520"

    private let launchesKey = "appLaunchCount"
    // Legacy keys from the previous engine, migrated once in init.
    private let legacyLastPromptDateKey = "lastRatingPromptDate"
    private let legacyFirstInstallDateKey = "firstInstallDate"
    private let legacyDismissPermanentlyKey = "reviewPromptDismissedPermanently"

    private init() {
        store.migrateIfNeeded { store in
            let d = store.defaults
            if store.date(ReviewStoreKeys.lastNativePromptDate) == nil, let last = d.object(forKey: self.legacyLastPromptDateKey) as? Date {
                store.set(last, for: ReviewStoreKeys.lastNativePromptDate)
            }
            if let installed = d.object(forKey: self.legacyFirstInstallDateKey) as? Date {
                store.set(installed, for: ReviewStoreKeys.installDate)
            }
            if d.bool(forKey: self.legacyDismissPermanentlyKey) {
                d.set(self.policy.maxCustomDismissals, forKey: ReviewStoreKeys.customDismissCount)
            }
        }
    }

    var writeReviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    func trackLaunch() {
        let launches = store.defaults.integer(forKey: launchesKey) + 1
        store.defaults.set(launches, forKey: launchesKey)
    }

    private var state: ReviewState {
        let d = store.defaults
        return ReviewState(
            launches: d.integer(forKey: launchesKey),
            installDate: store.date(ReviewStoreKeys.installDate),
            lastNativePrompt: store.date(ReviewStoreKeys.lastNativePromptDate),
            lastCustomPrompt: store.date(ReviewStoreKeys.lastCustomPromptDate),
            customDismissals: d.integer(forKey: ReviewStoreKeys.customDismissCount),
            didLeaveReview: d.bool(forKey: ReviewStoreKeys.didLeaveReview),
            promptedThisSession: promptedThisSession
        )
    }

    /// Auto path, called on `didBecomeActive`. Asks the scheduler; shows
    /// Apple's sheet or the custom card, never both in one session. If no
    /// foreground scene exists we skip; iOS will fire `didBecomeActive` again.
    func maybePromptForReview(context: UIApplication? = nil) {
        switch ReviewScheduler.decide(state, policy: policy) {
        case .native:
            let actualContext = context ?? UIApplication.shared
            guard let scene = actualContext.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }
            promptedThisSession = true
            store.set(Date(), for: ReviewStoreKeys.lastNativePromptDate)
            AppStore.requestReview(in: scene)
        case .custom:
            promptedThisSession = true
            store.set(Date(), for: ReviewStoreKeys.lastCustomPromptDate)
            showReviewPrompt = true
        case nil:
            break
        }
    }

    /// Settings' "Rate the App" and the card's Rate button: straight to the
    /// App Store review page. Someone who went there is never shown the card again.
    func openWriteReview() {
        store.defaults.set(true, forKey: ReviewStoreKeys.didLeaveReview)
        showReviewPrompt = false
        if let url = writeReviewURL {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    Log.debug("Failed to open App Store review URL")
                }
            }
        }
    }

    /// "No, thanks" on the card. Twice and the card never returns.
    func userDismissedReview() {
        let d = store.defaults
        d.set(d.integer(forKey: ReviewStoreKeys.customDismissCount) + 1, forKey: ReviewStoreKeys.customDismissCount)
    }
}
