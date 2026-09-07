//
//  ReviewScheduler.swift
//
//  Shared review-prompt policy. This file is byte-identical in every app that
//  uses it (hymnal family, Interlinear Bible Plus, La Fe de Jesús y
//  Doctrinas, Porn Blocker); change it in one place and copy it to the
//  others. It is a pure function over a state snapshot so the scheduling
//  rules are unit-tested once and behave the same everywhere.
//
//  Two prompts exist:
//  - native: Apple's rating sheet (`AppStore.requestReview`). Apple itself
//    caps it at three displays per year; we ask at most every 90 days.
//  - custom: the in-app "Do you like the app?" card, every 30 days.
//  They never fire in the same session, and whichever fired last blocks the
//  other for `crossCooldownDays`. Native wins when both are eligible.
//

import Foundation

enum ReviewPromptKind: Equatable {
    case native
    case custom
}

/// Per-app thresholds. Counters mean whatever the app counts (hymns viewed,
/// chapters read, lessons finished…); a zero threshold disables that gate.
struct ReviewPolicy {
    var minimumLaunches = 3
    var minimumPrimaryActions = 5
    var minimumSecondaryActions = 2
    var minimumDaysSinceInstall = 0
    var nativeCooldownDays = 90
    var customCooldownDays = 30
    var crossCooldownDays = 14
    var maxCustomDismissals = 2

    static let standard = ReviewPolicy()
}

/// Snapshot of everything the decision depends on.
struct ReviewState {
    var launches = 0
    var primaryActions = 0
    var secondaryActions = 0
    var installDate: Date? = nil
    var lastNativePrompt: Date? = nil
    var lastCustomPrompt: Date? = nil
    var customDismissals = 0
    var didLeaveReview = false
    /// In-memory: set when either prompt fired since launch.
    var promptedThisSession = false
}

enum ReviewScheduler {
    /// Which prompt, if any, to show right now.
    static func decide(_ s: ReviewState, now: Date = Date(), policy: ReviewPolicy = .standard,
                       calendar: Calendar = .current) -> ReviewPromptKind? {
        if s.promptedThisSession { return nil }
        guard s.launches >= policy.minimumLaunches,
              s.primaryActions >= policy.minimumPrimaryActions,
              s.secondaryActions >= policy.minimumSecondaryActions else { return nil }
        if policy.minimumDaysSinceInstall > 0 {
            guard let installed = s.installDate,
                  days(from: installed, to: now, calendar) >= policy.minimumDaysSinceInstall else { return nil }
        }

        let sinceNative = s.lastNativePrompt.map { days(from: $0, to: now, calendar) }
        let sinceCustom = s.lastCustomPrompt.map { days(from: $0, to: now, calendar) }
        func elapsed(_ d: Int?, atLeast n: Int) -> Bool { d.map { $0 >= n } ?? true }

        let nativeEligible = elapsed(sinceNative, atLeast: policy.nativeCooldownDays)
            && elapsed(sinceCustom, atLeast: policy.crossCooldownDays)
        if nativeEligible { return .native }

        let customEligible = !s.didLeaveReview
            && s.customDismissals < policy.maxCustomDismissals
            && elapsed(sinceCustom, atLeast: policy.customCooldownDays)
            && elapsed(sinceNative, atLeast: policy.crossCooldownDays)
        if customEligible { return .custom }

        return nil
    }

    /// Whole days between two dates (negative if `to` precedes `from`).
    static func days(from: Date, to: Date, _ calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }
}

/// UserDefaults keys shared by every app's ReviewManager. Engagement
/// counters keep each app's historical key names; only the prompt bookkeeping
/// is namespaced here.
enum ReviewStoreKeys {
    static let lastNativePromptDate = "review.lastNativePromptDate"
    static let lastCustomPromptDate = "review.lastCustomPromptDate"
    static let customDismissCount = "review.customDismissCount"
    static let didLeaveReview = "review.didLeaveReview"
    static let installDate = "review.installDate"
    static let migrated = "review.migratedV2"

    /// Legacy keys written by the previous engine (one date for both prompts).
    static let legacyLastRequestDate = "lastReviewRequestDate"
    static let legacyDismissCount = "userDismissedReviewCount"
    static let legacyHasRequested = "hasRequestedReview"
}

/// Thin persistence over UserDefaults so ReviewManager stays small.
struct ReviewStore {
    var defaults: UserDefaults = .standard

    func date(_ key: String) -> Date? {
        if let t = defaults.object(forKey: key) as? TimeInterval { return Date(timeIntervalSince1970: t) }
        if let d = defaults.object(forKey: key) as? Date { return d }
        return nil
    }

    func set(_ date: Date?, for key: String) {
        if let date { defaults.set(date.timeIntervalSince1970, forKey: key) } else { defaults.removeObject(forKey: key) }
    }

    /// One-time carry-over from the previous engine's keys. The single legacy
    /// date is copied to both prompts, which keeps whatever cooldown a live
    /// user was already inside. Extra legacy mappings (e.g. Porn Blocker's
    /// permanent-dismiss flag) are passed by the caller.
    func migrateIfNeeded(extra: (ReviewStore) -> Void = { _ in }) {
        guard !defaults.bool(forKey: ReviewStoreKeys.migrated) else { return }
        if let legacy = date(ReviewStoreKeys.legacyLastRequestDate) {
            if date(ReviewStoreKeys.lastNativePromptDate) == nil { set(legacy, for: ReviewStoreKeys.lastNativePromptDate) }
            if date(ReviewStoreKeys.lastCustomPromptDate) == nil { set(legacy, for: ReviewStoreKeys.lastCustomPromptDate) }
        }
        if defaults.object(forKey: ReviewStoreKeys.customDismissCount) == nil {
            defaults.set(defaults.integer(forKey: ReviewStoreKeys.legacyDismissCount), forKey: ReviewStoreKeys.customDismissCount)
        }
        if defaults.object(forKey: ReviewStoreKeys.didLeaveReview) == nil {
            defaults.set(defaults.bool(forKey: ReviewStoreKeys.legacyHasRequested), forKey: ReviewStoreKeys.didLeaveReview)
        }
        extra(self)
        if date(ReviewStoreKeys.installDate) == nil { set(Date(), for: ReviewStoreKeys.installDate) }
        defaults.set(true, forKey: ReviewStoreKeys.migrated)
    }
}
