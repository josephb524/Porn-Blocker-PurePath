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

    @MainActor
    func testRelapseRemovesExactlyTodayAndYesterdayAndFreezesRecord() {
        let manager = HabitManager.shared
        let h = makeHabit(checkIns: (0...4).map { key(daysAgo: $0) })  // 5-day streak
        manager.habits.append(h)
        defer { manager.deleteHabit(id: h.id) }

        XCTAssertEqual(manager.habits.first { $0.id == h.id }!.currentStreak, 5)

        manager.recordRelapse(habitID: h.id)

        let updated = manager.habits.first { $0.id == h.id }!
        XCTAssertEqual(updated.currentStreak, 0,
                       "removing today AND yesterday defeats the grace day")
        XCTAssertEqual(Set(updated.checkIns), Set((2...4).map { key(daysAgo: $0) }),
                       "older history is preserved")
        XCTAssertEqual(updated.bestStreakRecord, 5, "record frozen before key removal")
        XCTAssertEqual(updated.longestStreak, 5)
        XCTAssertEqual(updated.lastCelebratedMilestone, 0, "rebuilt streaks celebrate again")
        XCTAssertEqual(updated.relapseHistory.count, 1)
    }
}
