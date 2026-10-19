import XCTest
@testable import Porn_Blocker

/// Covers who gets what. Lifetime unlocks protection but never Buddy chat —
/// the one feature with a per-message cost; the chat-only add-on unlocks chat
/// but not protection; and a Lifetime owner's protection never inherits a
/// subscription's expiry, which the Safari extension would otherwise act on.
final class EntitlementsTests: XCTestCase {

    private let expiry = Date(timeIntervalSince1970: 1_700_000_000)

    func testNothingOwnedUnlocksNothing() {
        let owned = Entitlements()
        XCTAssertFalse(owned.protectionUnlocked)
        XCTAssertFalse(owned.buddyUnlocked)
        XCTAssertNil(owned.protectionExpiry)
    }

    func testPremiumUnlocksEverythingUntilItsExpiry() {
        let owned = Entitlements(hasPremiumSubscription: true, premiumExpiry: expiry)
        XCTAssertTrue(owned.protectionUnlocked)
        XCTAssertTrue(owned.buddyUnlocked)
        XCTAssertEqual(owned.protectionExpiry, expiry)
    }

    func testLifetimeUnlocksProtectionButNotChat() {
        let owned = Entitlements(ownsLifetime: true)
        XCTAssertTrue(owned.protectionUnlocked)
        XCTAssertFalse(owned.buddyUnlocked)
        XCTAssertNil(owned.protectionExpiry)
    }

    /// A Lifetime owner who also subscribes must not hand the extension the
    /// subscription's expiry — if it lapsed while the app was closed, Safari
    /// would stop blocking for someone who owns protection outright.
    func testLifetimeWithPremiumNeverExpiresProtection() {
        let owned = Entitlements(hasPremiumSubscription: true, premiumExpiry: expiry, ownsLifetime: true)
        XCTAssertTrue(owned.protectionUnlocked)
        XCTAssertTrue(owned.buddyUnlocked)
        XCTAssertNil(owned.protectionExpiry)
    }

    func testLifetimeWithBuddyAddOnUnlocksBoth() {
        let owned = Entitlements(ownsLifetime: true, hasBuddySubscription: true, buddyExpiry: expiry)
        XCTAssertTrue(owned.protectionUnlocked)
        XCTAssertTrue(owned.buddyUnlocked)
        XCTAssertNil(owned.protectionExpiry)
    }

    /// The add-on is chat only — on its own (say, after a Lifetime refund) it
    /// must not unlock protection.
    func testBuddyAddOnAloneUnlocksChatOnly() {
        let owned = Entitlements(hasBuddySubscription: true, buddyExpiry: expiry)
        XCTAssertFalse(owned.protectionUnlocked)
        XCTAssertTrue(owned.buddyUnlocked)
        XCTAssertNil(owned.protectionExpiry)
    }
}
