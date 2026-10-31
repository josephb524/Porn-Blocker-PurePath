import XCTest
@testable import Porn_Blocker

/// When the app asks for a review (2026-10-31): at a streak milestone of
/// 1 Week or more, or — for someone with protection on and no streak running —
/// on leaving the Protection tab. Never on the day of a slip; a Rate tap ends
/// every ask; "No, thanks" retires the card. The cooldowns are the shared
/// `ReviewScheduler`'s, unit-tested in ChantsDEsperance / HarpaCrista.
final class ReviewPromptTests: XCTestCase {

    private let day0 = Date(timeIntervalSince1970: 1_800_000_000)
    private func day(_ n: Int) -> Date { day0.addingTimeInterval(TimeInterval(n) * 86_400) }

    /// Installed on day 0 and opened once since.
    private var newUser: ReviewState { ReviewState(launches: 1, installDate: day0) }

    private func decide(_ state: ReviewState, _ policy: ReviewPolicy, at n: Int,
                        slippedToday: Bool = false) -> ReviewPromptKind? {
        RatingRequestManager.decide(state, policy: policy, slippedToday: slippedToday, now: day(n))
    }

    func testMilestonesAskFromOneWeek() {
        XCTAssertFalse(RatingRequestManager.milestoneAsks(days: 1))
        for days in [7, 30, 90, 365] {
            XCTAssertTrue(RatingRequestManager.milestoneAsks(days: days), "\(days) days")
        }
    }

    func testMilestoneSkipsTheLaunchCountButNotTheFirstThreeDays() {
        XCTAssertEqual(decide(newUser, .milestoneMoment, at: 6), .native)
        // One launch isn't enough when leaving the Protection tab…
        XCTAssertNil(decide(newUser, .leavingProtection, at: 6))
        // …and a start date backdated on install day can't ask at once.
        XCTAssertNil(decide(newUser, .milestoneMoment, at: 2))
    }

    /// Start date set to today in onboarding, checked in every day:
    /// 1 Week on day 6, 1 Month on 29, 3 Months on 89, 1 Year on 364.
    func testDailyUserGetsAppleThenTheCardTwiceThenApple() {
        var s = newUser
        XCTAssertEqual(decide(s, .milestoneMoment, at: 6), .native)
        s.lastNativePrompt = day(6)
        XCTAssertEqual(decide(s, .milestoneMoment, at: 29), .custom)
        s.lastCustomPrompt = day(29)
        XCTAssertEqual(decide(s, .milestoneMoment, at: 89), .custom)
        s.lastCustomPrompt = day(89)
        XCTAssertEqual(decide(s, .milestoneMoment, at: 364), .native)
    }

    func testLeavingProtectionAsksOnlyWithProtectionOnAndNoStreak() {
        XCTAssertTrue(RatingRequestManager.asksWhenLeavingProtection(protectionOn: true, streak: 0))
        XCTAssertFalse(RatingRequestManager.asksWhenLeavingProtection(protectionOn: true, streak: 3))
        XCTAssertFalse(RatingRequestManager.asksWhenLeavingProtection(protectionOn: false, streak: 0))
    }

    func testLeavingProtectionNeedsThreeLaunchesAndThreeDays() {
        var s = newUser
        s.launches = 2
        XCTAssertNil(decide(s, .leavingProtection, at: 5))
        s.launches = 3
        XCTAssertNil(decide(s, .leavingProtection, at: 2))
        XCTAssertEqual(decide(s, .leavingProtection, at: 3), .native)
    }

    func testNeverOnASlipDay() {
        var s = newUser
        s.launches = 3
        XCTAssertNil(decide(s, .milestoneMoment, at: 10, slippedToday: true))
        XCTAssertNil(decide(s, .leavingProtection, at: 10, slippedToday: true))
        XCTAssertEqual(decide(s, .leavingProtection, at: 11), .native)
    }

    func testRateEndsEveryAsk() {
        var s = newUser
        s.lastNativePrompt = day(6)
        s.didLeaveReview = true
        // The shared scheduler alone would bring Apple's sheet back…
        XCTAssertEqual(ReviewScheduler.decide(s, now: day(100), policy: .milestoneMoment), .native)
        // …this app doesn't.
        XCTAssertNil(decide(s, .milestoneMoment, at: 100))
        XCTAssertNil(decide(s, .leavingProtection, at: 100))
    }

    func testNoThanksRetiresTheCardAtOnce() {
        var s = newUser
        s.lastNativePrompt = day(6)
        s.customDismissals = RatingRequestManager.dismissalsAfterNoThanks(current: 0)
        XCTAssertNil(decide(s, .milestoneMoment, at: 29))
        // Apple's sheet keeps its own cadence.
        XCTAssertEqual(decide(s, .milestoneMoment, at: 100), .native)
    }

    func testBothMomentsKeepTheSharedCooldowns() {
        let standard = ReviewPolicy.standard
        for policy in [ReviewPolicy.milestoneMoment, .leavingProtection] {
            XCTAssertEqual(policy.nativeCooldownDays, standard.nativeCooldownDays)
            XCTAssertEqual(policy.customCooldownDays, standard.customCooldownDays)
            XCTAssertEqual(policy.crossCooldownDays, standard.crossCooldownDays)
            XCTAssertEqual(policy.maxCustomDismissals, standard.maxCustomDismissals)
        }
    }
}
