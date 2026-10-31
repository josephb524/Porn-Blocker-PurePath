import Foundation
import StoreKit
import SwiftUI
import UIKit

extension ReviewPolicy {
    /// Leaving the Protection tab: three launches and three days in, then the
    /// shared cooldowns. (Until 2026-10-31 the app asked on every
    /// `didBecomeActive` after five launches.)
    static let leavingProtection: ReviewPolicy = {
        var policy = ReviewPolicy.standard
        policy.minimumLaunches = 3
        policy.minimumPrimaryActions = 0
        policy.minimumSecondaryActions = 0
        policy.minimumDaysSinceInstall = 3
        return policy
    }()

    /// A streak milestone: reaching it is the engagement, so no launch count.
    /// Still never in the first three days — a start date backdated on install
    /// day can cross one — and every cooldown unchanged.
    static let milestoneMoment: ReviewPolicy = {
        var policy = ReviewPolicy.leavingProtection
        policy.minimumLaunches = 0
        return policy
    }()
}

/// Review prompts, asked at the app's best moments and never when it opens
/// (2026-10-31, Cairn's pattern — it asks at the Amen). `ReviewScheduler`
/// (shared, byte-identical across apps) picks Apple's native sheet (at most
/// every 90 days) or the custom `ReviewPromptView` card (every 30), never both
/// in one session and at least 14 days after whichever fired last.
///
/// - A streak milestone of 1 Week or more asks when its celebration closes.
/// - Someone with protection on and no streak running is asked when they
///   leave the Protection tab instead.
/// - Never on the day of a slip. A Rate tap — on the card or in Settings —
///   ends every ask, Apple's sheet included; "No, thanks" retires the card.
@MainActor
final class RatingRequestManager: ObservableObject {
    static let shared = RatingRequestManager()

    @Published var showReviewPrompt = false

    private let store = ReviewStore()
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
                d.set(ReviewPolicy.leavingProtection.maxCustomDismissals, forKey: ReviewStoreKeys.customDismissCount)
            }
        }
    }

    var writeReviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }

    /// Once per cold launch, from `Porn_BlockerApp.init`. Only counts.
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

    private var pornFreeHabit: TrackedHabit? {
        HabitManager.shared.habits.first { $0.id == HabitManager.pornFreeID }
    }

    // MARK: - Moments

    /// The streak milestone celebration closed (`StatsView`).
    func milestoneCelebrationClosed(days: Int) {
        guard Self.milestoneAsks(days: days) else { return }
        ask(policy: .milestoneMoment, reason: "\(days)-day milestone")
    }

    /// The user tapped from the Protection tab to another one (`MainTabView`).
    /// They just saw their protection status, and they're between tasks.
    func leftProtectionTab() {
        guard !promptedThisSession else { return }
        let streak = pornFreeHabit?.currentStreak ?? 0
        // Cheap checks first; the blocker's state is an async system call.
        guard Self.asksWhenLeavingProtection(protectionOn: SubscriptionManager.shared.isSubscribed, streak: streak) else { return }
        Task {
            let blockerOn = await BlocklistManager.shared.checkContentBlockerStatus()
            let protectionOn = SubscriptionManager.shared.isSubscribed && blockerOn
            guard Self.asksWhenLeavingProtection(protectionOn: protectionOn, streak: streak) else { return }
            ask(policy: .leavingProtection, reason: "left Protection")
        }
    }

    /// 1 Week and up. 1 Day comes with the very first check-in — often on
    /// install day, before the blocker has done anything — and again after
    /// every slip, which starts a new run. Users who set a start date in
    /// onboarding never see it at all.
    nonisolated static func milestoneAsks(days: Int) -> Bool { days >= 7 }

    /// Protection on (subscribed and the Safari blocker enabled) and no streak
    /// running. A streak waits for its milestone, so an ordinary tab switch
    /// never spends the cooldown the milestone is waiting for.
    nonisolated static func asksWhenLeavingProtection(protectionOn: Bool, streak: Int) -> Bool {
        protectionOn && streak == 0
    }

    // MARK: - Decision

    /// The shared scheduler plus this app's rules: never on the day of a slip,
    /// and someone who tapped Rate — on the card or in Settings — is never
    /// asked again, Apple's sheet included (the shared scheduler alone would
    /// still ask natively every 90 days).
    nonisolated static func decide(_ state: ReviewState, policy: ReviewPolicy,
                                   slippedToday: Bool, now: Date = Date()) -> ReviewPromptKind? {
        if slippedToday || state.didLeaveReview { return nil }
        return ReviewScheduler.decide(state, now: now, policy: policy)
    }

    /// Waits a second, so a closing celebration or a tab switch finishes and
    /// the moment is the user's first.
    private func ask(policy: ReviewPolicy, reason: String) {
        let kind = Self.decide(state, policy: policy, slippedToday: pornFreeHabit?.slippedToday == true)
        Log.debug("Review ask (\(reason)): \(kind.map { "\($0)" } ?? "nothing")")
        switch kind {
        case .native:
            promptedThisSession = true
            Task {
                try? await Task.sleep(for: .seconds(1))
                requestNativeReview()
            }
        case .custom:
            promptedThisSession = true
            store.set(Date(), for: ReviewStoreKeys.lastCustomPromptDate)
            Task {
                try? await Task.sleep(for: .seconds(1))
                showReviewPrompt = true
            }
        case nil:
            break
        }
    }

    /// Apple's sheet. iOS decides whether it actually appears (at most three
    /// times a year per app); the date is stamped only when we asked.
    private func requestNativeReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else {
            promptedThisSession = false   // nothing shown; the next moment tries again
            return
        }
        store.set(Date(), for: ReviewStoreKeys.lastNativePromptDate)
        AppStore.requestReview(in: scene)
    }

    // MARK: - User actions

    /// Settings' "Rate the App" and the card's Rate button: straight to the
    /// App Store review page. Someone who went there is never asked again.
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

    /// "No, thanks" on the card: it never comes back (Cairn's rule since
    /// 2026-10-31; it used to take two). Apple's sheet keeps its own cadence.
    func userDismissedReview() {
        let d = store.defaults
        d.set(Self.dismissalsAfterNoThanks(current: d.integer(forKey: ReviewStoreKeys.customDismissCount)),
              forKey: ReviewStoreKeys.customDismissCount)
    }

    /// The scheduler retires the card at `maxCustomDismissals`.
    nonisolated static func dismissalsAfterNoThanks(current: Int) -> Int {
        max(ReviewPolicy.leavingProtection.maxCustomDismissals, current)
    }
}
