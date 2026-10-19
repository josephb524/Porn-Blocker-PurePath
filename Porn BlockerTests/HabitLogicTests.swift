import Combine
import UserNotifications
import XCTest
@testable import Porn_Blocker

/// Covers the streak math (grace-day semantics), the tolerant decoder, and
/// the manager-level relapse/backdate behaviors.
///
/// Manager tests run against `HabitManager.shared` in the test host's own
/// sandbox, always on throwaway custom habits deleted afterwards — never on
/// the built-in Porn Free habit.
final class HabitLogicTests: XCTestCase {

    private func key(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return TrackedHabit.dayKey(for: date)
    }

    private func makeHabit(checkIns: [String] = [], bestStreakRecord: Int = 0) -> TrackedHabit {
        TrackedHabit(name: "Test Habit", emoji: "⭐️", colorHue: 0.5,
                     checkIns: checkIns, bestStreakRecord: bestStreakRecord)
    }

    // MARK: - dayKey

    func testDayKeyFormatIsStable() {
        let date = DateComponents(calendar: Calendar(identifier: .gregorian),
                                  timeZone: .current,
                                  year: 2026, month: 8, day: 1).date!
        XCTAssertEqual(TrackedHabit.dayKey(for: date), "2026-08-01")
    }

    // MARK: - Streak math (grace-day semantics)

    func testEmptyCheckInsIsZeroStreak() {
        XCTAssertEqual(makeHabit().currentStreak, 0)
    }

    func testTodayOnlyIsOne() {
        XCTAssertEqual(makeHabit(checkIns: [key(daysAgo: 0)]).currentStreak, 1)
    }

    func testYesterdayOnlyStillCountsViaGraceDay() {
        // Today not checked in yet → the streak persists through the day.
        XCTAssertEqual(makeHabit(checkIns: [key(daysAgo: 1)]).currentStreak, 1)
    }

    func testGraceDoesNotReachTwoDaysBack() {
        XCTAssertEqual(makeHabit(checkIns: [key(daysAgo: 2)]).currentStreak, 0)
    }

    func testConsecutiveRunCounts() {
        let h = makeHabit(checkIns: [key(daysAgo: 0), key(daysAgo: 1), key(daysAgo: 2)])
        XCTAssertEqual(h.currentStreak, 3)
    }

    func testGapBreaksStreak() {
        let h = makeHabit(checkIns: [key(daysAgo: 0), key(daysAgo: 2), key(daysAgo: 3)])
        XCTAssertEqual(h.currentStreak, 1)
        XCTAssertEqual(h.longestStreak, 2)
    }

    func testIsCheckedInTodayIsStrict() {
        // Unlike the streak, the check-in flag has no grace day — the button
        // must empty at midnight.
        XCTAssertTrue(makeHabit(checkIns: [key(daysAgo: 0)]).isCheckedInToday)
        XCTAssertFalse(makeHabit(checkIns: [key(daysAgo: 1)]).isCheckedInToday)
    }

    func testLongestStreakHonorsBestStreakRecord() {
        let h = makeHabit(checkIns: [key(daysAgo: 0)], bestStreakRecord: 9)
        XCTAssertEqual(h.longestStreak, 9)
    }

    // MARK: - Milestones per run

    func testRunStartIsTheStreaksFirstDay() {
        let h = makeHabit(checkIns: [key(daysAgo: 0), key(daysAgo: 1), key(daysAgo: 2), key(daysAgo: 5)])
        XCTAssertEqual(h.currentRunStart, key(daysAgo: 2))
        XCTAssertNil(makeHabit(checkIns: [key(daysAgo: 3)]).currentRunStart)
    }

    func testMilestonesCelebrateAgainAfterAMissedDay() {
        // "1 Week" was celebrated in a run that ended without a recorded
        // relapse — the user just stopped checking in. The rebuilt streak is
        // a new run, so its milestones celebrate again.
        var h = makeHabit(checkIns: [key(daysAgo: 0), key(daysAgo: 1)] + (10...16).map { key(daysAgo: $0) })
        h.lastCelebratedMilestone = 7
        h.celebratedRunStart = key(daysAgo: 16)
        XCTAssertEqual(h.milestoneCelebratedThisRun, 0)
    }

    // MARK: - Tolerant decoding

    private func decodeHabit(_ json: String) throws -> TrackedHabit {
        try JSONDecoder().decode(TrackedHabit.self, from: Data(json.utf8))
    }

    func testEmptyObjectDecodesWithDefaults() throws {
        let h = try decodeHabit("{}")
        XCTAssertFalse(h.isBuiltIn)
        XCTAssertFalse(h.isAutoStreak)
        XCTAssertEqual(h.checkIns, [])
        XCTAssertEqual(h.name, "Habit")
    }

    func testBuiltInFallbackRestoresCanonicalID() throws {
        // The built-in habit is identified by id everywhere; a random UUID
        // fallback would spawn a duplicate.
        let h = try decodeHabit(#"{"isBuiltIn": true}"#)
        XCTAssertEqual(h.id, TrackedHabit.builtInID)
        XCTAssertEqual(h.name, "Porn Free")
    }

    func testWrongFieldTypesAreTolerated() throws {
        let h = try decodeHabit(#"{"name": 42, "checkIns": "nope", "isAutoStreak": "yes", "id": 7}"#)
        XCTAssertEqual(h.name, "Habit")
        XCTAssertEqual(h.checkIns, [])
        XCTAssertFalse(h.isAutoStreak,
                       "a decode fallback must never re-trigger the auto-streak migration")
    }

    func testDataFromBeforeRunTrackingCanCelebrateTheCurrentRun() throws {
        let h = try decodeHabit(#"{"checkIns": ["\#(key(daysAgo: 0))"], "lastCelebratedMilestone": 30}"#)
        XCTAssertNil(h.celebratedRunStart)
        XCTAssertEqual(h.milestoneCelebratedThisRun, 0)
    }

    // MARK: - Manager behaviors

    @MainActor
    func testSetStartDateBackfillsThroughToday() {
        let manager = HabitManager.shared
        let h = makeHabit()
        manager.habits.append(h)
        defer { manager.deleteHabit(id: h.id) }

        let start = Calendar.current.date(byAdding: .day, value: -9, to: Date())!
        manager.setStartDate(start, habitID: h.id)

        let updated = manager.habits.first { $0.id == h.id }!
        XCTAssertEqual(updated.checkIns.count, 10, "start through today inclusive")
        XCTAssertEqual(updated.currentStreak, 10)
    }

    @MainActor
    func testSetStartDateUnionsWithExistingCheckIns() {
        let manager = HabitManager.shared
        let old = key(daysAgo: 30)
        let h = makeHabit(checkIns: [old])
        manager.habits.append(h)
        defer { manager.deleteHabit(id: h.id) }

        manager.setStartDate(Calendar.current.date(byAdding: .day, value: -2, to: Date())!, habitID: h.id)

        let updated = manager.habits.first { $0.id == h.id }!
        XCTAssertTrue(updated.checkIns.contains(old), "backfill must not clobber older history")
        XCTAssertEqual(updated.currentStreak, 3)
    }

    @MainActor
    func testSetStartDateClampsFutureDates() {
        let manager = HabitManager.shared
        let h = makeHabit()
        manager.habits.append(h)
        defer { manager.deleteHabit(id: h.id) }

        manager.setStartDate(Calendar.current.date(byAdding: .day, value: 5, to: Date())!, habitID: h.id)

        let updated = manager.habits.first { $0.id == h.id }!
        XCTAssertEqual(updated.checkIns, [key(daysAgo: 0)])
    }

    // MARK: - "I slipped today"

    @MainActor
    func testSlipClearsOnlyTodayAndKeepsTheHistory() {
        let manager = HabitManager.shared
        let h = makeHabit(checkIns: (0...4).map { key(daysAgo: $0) })  // 5-day streak, today checked
        manager.habits.append(h)
        defer { manager.deleteHabit(id: h.id) }

        manager.recordRelapse(habitID: h.id)

        let updated = manager.habits.first { $0.id == h.id }!
        XCTAssertEqual(updated.currentStreak, 0, "a slip day gets no grace day")
        XCTAssertEqual(Set(updated.checkIns), Set((1...4).map { key(daysAgo: $0) }),
                       "yesterday and earlier stay — the dialog promises the history stays")
        XCTAssertEqual(updated.relapseDays, [key(daysAgo: 0)])
        XCTAssertTrue(updated.slippedToday)
        XCTAssertEqual(updated.bestStreakRecord, 4, "the run that ended — today wasn't clean")
        XCTAssertEqual(updated.longestStreak, 4)
        XCTAssertEqual(updated.lastCelebratedMilestone, 0, "rebuilt streaks celebrate again")
        XCTAssertEqual(updated.relapseHistory.count, 1)
    }

    @MainActor
    func testCheckInAfterASlipStartsANewRun() {
        let manager = HabitManager.shared
        let h = makeHabit(checkIns: (1...4).map { key(daysAgo: $0) })
        manager.habits.append(h)
        defer { manager.deleteHabit(id: h.id) }

        manager.recordRelapse(habitID: h.id)
        manager.checkIn(habitID: h.id)

        let updated = manager.habits.first { $0.id == h.id }!
        XCTAssertEqual(updated.currentStreak, 1, "day 1 of a new run, not joined to yesterday")
        XCTAssertEqual(updated.longestStreak, 4)
    }

    func testCheckedInSlipDayIsDayOneTheNextDay() {
        // Slipped yesterday and checked in after it; today not checked in yet.
        var h = makeHabit(checkIns: [key(daysAgo: 1), key(daysAgo: 2), key(daysAgo: 3)])
        h.relapseDays = [key(daysAgo: 1)]
        XCTAssertEqual(h.currentStreak, 1)
        XCTAssertEqual(h.currentRunStart, key(daysAgo: 1))
    }

    func testLongestStreakDoesNotJoinRunsAcrossASlip() {
        var h = makeHabit(checkIns: (0...9).map { key(daysAgo: $0) })
        h.relapseDays = [key(daysAgo: 5)]   // runs: days 9…6 (4) and 5…0 (6)
        XCTAssertEqual(h.longestStreak, 6)
        XCTAssertEqual(h.currentStreak, 6)
    }

    @MainActor
    func testStartDateTakesBackLaterSlips() {
        let manager = HabitManager.shared
        let h = makeHabit(checkIns: (1...9).map { key(daysAgo: $0) })
        manager.habits.append(h)
        defer { manager.deleteHabit(id: h.id) }

        manager.recordRelapse(habitID: h.id)
        manager.setStartDate(Calendar.current.date(byAdding: .day, value: -9, to: Date())!, habitID: h.id)

        let updated = manager.habits.first { $0.id == h.id }!
        XCTAssertEqual(updated.relapseDays, [])
        XCTAssertEqual(updated.currentStreak, 10)
    }

    @MainActor
    func testUndoSlipRestoresTheStreakWithoutCelebrating() {
        let manager = HabitManager.shared
        let h = makeHabit(checkIns: (1...6).map { key(daysAgo: $0) })   // 6 days, today open
        manager.habits.append(h)
        defer { manager.deleteHabit(id: h.id) }

        manager.recordRelapse(habitID: h.id)
        manager.undoRelapse(habitID: h.id)

        let updated = manager.habits.first { $0.id == h.id }!
        XCTAssertFalse(updated.slippedToday)
        XCTAssertEqual(updated.currentStreak, 6)
        XCTAssertEqual(updated.relapseHistory.count, 0)
        XCTAssertEqual(updated.milestoneCelebratedThisRun, 1,
                       "milestones the restored run already reached don't celebrate again")
    }

    @MainActor
    func testUndoThenRecheckCannotCelebrateTwice() {
        let manager = HabitManager.shared
        let h = makeHabit(checkIns: (1...6).map { key(daysAgo: $0) })   // 6 days, today open
        manager.habits.append(h)
        defer { manager.deleteHabit(id: h.id) }

        manager.checkIn(habitID: h.id)                                  // 7 → "1 Week"
        manager.markMilestoneCelebrated(days: 7, habitID: h.id)
        manager.undoCheckIn(habitID: h.id)
        manager.checkIn(habitID: h.id)

        let updated = manager.habits.first { $0.id == h.id }!
        XCTAssertEqual(updated.currentStreak, 7)
        XCTAssertEqual(updated.milestoneCelebratedThisRun, 7, "same run — no second celebration")
    }

    /// Streaks are computed from the clock, so a new day must redraw the
    /// Streaks tab — or "Checked in today" lingers into the next morning.
    @MainActor
    func testDayChangeRepublishesSoStreakViewsRedraw() {
        let published = expectation(description: "objectWillChange")
        published.assertForOverFulfill = false
        let subscription = HabitManager.shared.objectWillChange.sink { published.fulfill() }
        defer { subscription.cancel() }

        NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil)

        wait(for: [published], timeout: 2)
    }

    // MARK: - Time zones

    /// Runs `body` as if the user had flown to `identifier` with the app open:
    /// the app's default zone is what `Calendar.current` and day keys follow.
    private func inTimeZone(_ identifier: String, _ body: () throws -> Void) rethrows {
        let original = NSTimeZone.default
        NSTimeZone.default = TimeZone(identifier: identifier)!
        defer { NSTimeZone.default = original }
        try body()
    }

    func testDayKeyFollowsTheTimeZoneWithoutARelaunch() {
        // 2026-08-01 20:00 UTC: still August 1 in New York, already August 2 in Bangkok.
        let instant = Date(timeIntervalSince1970: 1_785_614_400)
        inTimeZone("America/New_York") { XCTAssertEqual(TrackedHabit.dayKey(for: instant), "2026-08-01") }
        inTimeZone("Asia/Bangkok") { XCTAssertEqual(TrackedHabit.dayKey(for: instant), "2026-08-02") }
    }

    func testReminderTimeStaysWallClockAcrossTimeZones() {
        var h = makeHabit()
        inTimeZone("America/New_York") {
            h.reminderTime = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date())!
        }
        inTimeZone("Asia/Bangkok") {
            let shown = Calendar.current.dateComponents([.hour, .minute], from: h.reminderTime)
            XCTAssertEqual(shown.hour, 22, "10 PM stays 10 PM in Bangkok — it used to read 9 AM")
            XCTAssertEqual(shown.minute, 0)
        }
    }

    func testOldMomentReminderDecodesToTheTimeItShowed() throws {
        try inTimeZone("America/New_York") {
            let tenThirtyPM = Calendar.current.date(bySettingHour: 22, minute: 30, second: 0, of: Date())!
            // JSONEncoder's default: seconds since 2001-01-01.
            let h = try decodeHabit(#"{"reminderTime": \#(tenThirtyPM.timeIntervalSinceReferenceDate)}"#)
            XCTAssertEqual(h.reminderHour, 22)
            XCTAssertEqual(h.reminderMinute, 30)
        }
    }

    // MARK: - Reminders

    private func remindedHabit(checkIns: [String] = []) -> TrackedHabit {
        var h = makeHabit(checkIns: checkIns)
        h.reminderEnabled = true
        h.reminderHour = 22
        h.reminderMinute = 0
        return h
    }

    private func today(at hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
    }

    func testRemindersIncludeTodayUntilCheckedIn() {
        let requests = HabitNotificationManager.requests(for: remindedHabit(), days: 7, now: today(at: 8))
        XCTAssertEqual(requests.count, 7)
        let first = requests[0].trigger as! UNCalendarNotificationTrigger
        XCTAssertEqual(first.dateComponents.day, Calendar.current.component(.day, from: Date()))
        XCTAssertEqual(first.dateComponents.hour, 22)
        XCTAssertEqual(first.dateComponents.minute, 0)
        XCTAssertNil(first.dateComponents.timeZone, "no zone, so it fires at 10 PM wherever the user is")
        XCTAssertFalse(first.repeats)
    }

    func testNoReminderTodayOnceCheckedIn() {
        let checkedIn = remindedHabit(checkIns: [key(daysAgo: 0)])
        let requests = HabitNotificationManager.requests(for: checkedIn, days: 7, now: today(at: 8))
        XCTAssertEqual(requests.count, 6)
        XCTAssertFalse(requests.contains { $0.identifier.hasSuffix(key(daysAgo: 0)) })
    }

    func testNoReminderOnASlipDay() {
        var h = remindedHabit()
        h.relapseDays = [key(daysAgo: 0)]
        XCTAssertEqual(HabitNotificationManager.requests(for: h, days: 7, now: today(at: 8)).count, 6)
    }

    func testNoReminderForATimeAlreadyPast() {
        XCTAssertEqual(HabitNotificationManager.requests(for: remindedHabit(), days: 7, now: today(at: 23)).count, 6)
    }

    func testNoRemindersWhenTurnedOff() {
        XCTAssertTrue(HabitNotificationManager.requests(for: makeHabit(), days: 7).isEmpty)
    }

    func testReminderWindowSharesTheSixtyFourSlots() {
        XCTAssertEqual(HabitNotificationManager.windowDays(remindedHabits: 1), 30)
        XCTAssertEqual(HabitNotificationManager.windowDays(remindedHabits: 4), 15)
        XCTAssertEqual(HabitNotificationManager.windowDays(remindedHabits: 20), 7)
    }
}
