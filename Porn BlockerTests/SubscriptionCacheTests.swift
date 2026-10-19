import XCTest
@testable import Porn_Blocker

/// Covers the rule that decides whether a cached subscription status is safe to
/// seed `isSubscribed` from at launch. The seed is what keeps a subscriber from
/// seeing a red "Protection Inactive" flash while StoreKit's async check is in
/// flight; the expiry gate is what keeps that optimism from outliving the
/// subscription it came from.
final class SubscriptionCacheTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testActiveWithFutureExpiryIsTrusted() {
        XCTAssertTrue(
            SubscriptionManager.cachedStatusIsActive(
                flag: true,
                expiry: now.timeIntervalSince1970 + 86_400,
                now: now
            )
        )
    }

    func testActiveWithPastExpiryIsNotTrusted() {
        XCTAssertFalse(
            SubscriptionManager.cachedStatusIsActive(
                flag: true,
                expiry: now.timeIntervalSince1970 - 1,
                now: now
            )
        )
    }

    /// A missing expiry can't be aged out, so it must never seed an optimistic
    /// `true` — otherwise a lapsed user would look subscribed forever.
    func testActiveWithNilExpiryIsNotTrusted() {
        XCTAssertFalse(
            SubscriptionManager.cachedStatusIsActive(flag: true, expiry: nil, now: now)
        )
    }

    func testInactiveFlagIsNotTrustedEvenWithFutureExpiry() {
        XCTAssertFalse(
            SubscriptionManager.cachedStatusIsActive(
                flag: false,
                expiry: now.timeIntervalSince1970 + 86_400,
                now: now
            )
        )
    }

    /// Expiry exactly at `now` has elapsed — the comparison is strict.
    func testExpiryExactlyNowIsNotTrusted() {
        XCTAssertFalse(
            SubscriptionManager.cachedStatusIsActive(
                flag: true,
                expiry: now.timeIntervalSince1970,
                now: now
            )
        )
    }

    // MARK: - When the Dashboard shows "Checking Protection…"

    /// Nothing was ever resolved on this install (fresh install, reinstall).
    func testNoCachedStatusIsInconclusive() {
        XCTAssertFalse(SubscriptionManager.cacheIsConclusive(premiumFlag: nil, premiumSeeded: false))
    }

    /// The last check found no subscription: show that at once rather than a
    /// "checking" card on every launch.
    func testCachedNoIsConclusive() {
        XCTAssertTrue(SubscriptionManager.cacheIsConclusive(premiumFlag: false, premiumSeeded: false))
    }

    /// Past its cached expiry a subscription has most likely renewed, so
    /// "inactive" would be a guess.
    func testSubscriptionPastCachedExpiryIsInconclusive() {
        XCTAssertFalse(SubscriptionManager.cacheIsConclusive(premiumFlag: true, premiumSeeded: false))
    }

    func testTrustedSubscriptionIsConclusive() {
        XCTAssertTrue(SubscriptionManager.cacheIsConclusive(premiumFlag: true, premiumSeeded: true))
    }
}
