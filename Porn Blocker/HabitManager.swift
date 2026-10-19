import Foundation
import SwiftUI
import UserNotifications

/// Wraps an element so a single undecodable entry yields `nil` instead of
/// failing the whole array — used to salvage a damaged habit store.
private struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

// MARK: - Habit Model

struct TrackedHabit: Identifiable, Codable {
    /// Canonical ID of the built-in "Porn Free" habit. Lives here (not on the
    /// @MainActor manager) so the nonisolated decoder can reference it.
    static let builtInID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    var id: UUID
    var name: String
    var emoji: String
    var colorHue: Double
    var isAutoStreak: Bool
    var streakStartDate: Date
    var checkIns: [String]       // "yyyy-MM-dd" strings
    var relapseHistory: [Date]
    /// Day keys of slips reported with "I slipped today"; each starts a new run
    /// (see `consecutiveRun`). Only slips since this field existed — older
    /// relapses deleted the check-ins around them instead.
    var relapseDays: [String]
    var isBuiltIn: Bool
    var reminderEnabled: Bool
    /// The reminder as a wall-clock time — "10 PM wherever I am". It was a
    /// stored `Date` (one moment), so after flying to Bangkok a 10 PM New York
    /// reminder read, and was re-queued, as 9 AM.
    var reminderHour: Int
    var reminderMinute: Int
    var bestStreakRecord: Int    // best streak ever seen — survives history edits and old-style relapses
    var lastCelebratedMilestone: Int   // highest milestone celebrated in the run below; reset on relapse
    var celebratedRunStart: String?    // day key that run began on — see milestoneCelebratedThisRun

    /// Name to show in the UI. The built-in habit is persisted with its
    /// English default ("Porn Free"); that stored value is translated at
    /// display time so existing users see their language without a data
    /// migration. A user-renamed built-in shows exactly what they typed.
    var displayName: String {
        isBuiltIn && name == "Porn Free" ? String(localized: "Porn Free") : name
    }

    /// The reminder time today, in the current time zone — for the time
    /// pickers, which bind a `Date`. Setting it keeps just the hour and minute
    /// the picker showed.
    var reminderTime: Date {
        get {
            Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Date()) ?? Date()
        }
        set {
            let time = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderHour = time.hour ?? 21
            reminderMinute = time.minute ?? 0
        }
    }

    // MARK: Init

    init(id: UUID = UUID(),
         name: String,
         emoji: String,
         colorHue: Double,
         isAutoStreak: Bool = false,
         streakStartDate: Date = Date(),
         checkIns: [String] = [],
         relapseHistory: [Date] = [],
         relapseDays: [String] = [],
         isBuiltIn: Bool = false,
         reminderEnabled: Bool = false,
         reminderTime: Date = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date(),
         bestStreakRecord: Int = 0,
         lastCelebratedMilestone: Int = 0,
         celebratedRunStart: String? = nil) {
        let time = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        self.id              = id
        self.name            = name
        self.emoji           = emoji
        self.colorHue        = colorHue
        self.isAutoStreak    = isAutoStreak
        self.streakStartDate = streakStartDate
        self.checkIns        = checkIns
        self.relapseHistory  = relapseHistory
        self.relapseDays     = relapseDays
        self.isBuiltIn       = isBuiltIn
        self.reminderEnabled = reminderEnabled
        self.reminderHour    = time.hour ?? 21
        self.reminderMinute  = time.minute ?? 0
        self.bestStreakRecord = bestStreakRecord
        self.lastCelebratedMilestone = lastCelebratedMilestone
        self.celebratedRunStart = celebratedRunStart
    }

    // MARK: - Custom Codable (handles missing keys in old data)

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, colorHue, isAutoStreak, streakStartDate
        case checkIns, relapseHistory, relapseDays, isBuiltIn, reminderEnabled
        case reminderHour, reminderMinute
        case bestStreakRecord, lastCelebratedMilestone, celebratedRunStart
    }

    /// Read from old data, never written.
    private enum LegacyCodingKeys: String, CodingKey {
        case reminderTime
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Every field falls back to a default so one bad field can't throw away
        // the habit (and with it the user's whole check-in history).
        // isBuiltIn decodes first: the built-in habit is identified by id
        // everywhere, so a failed id must fall back to builtInID — a random
        // UUID would orphan it and ensureBuiltInHabit() would insert a duplicate.
        isBuiltIn       = (try? c.decode(Bool.self,   forKey: .isBuiltIn)) ?? false
        id              = (try? c.decode(UUID.self,   forKey: .id)) ?? (isBuiltIn ? Self.builtInID : UUID())
        name            = (try? c.decode(String.self, forKey: .name)) ?? (isBuiltIn ? "Porn Free" : "Habit")
        emoji           = (try? c.decode(String.self, forKey: .emoji)) ?? (isBuiltIn ? "🛡️" : "⭐️")
        colorHue        = (try? c.decode(Double.self, forKey: .colorHue)) ?? 0.38
        // false is the safe direction: a decode fallback must never re-trigger
        // the auto-streak migration and resurrect a relapsed streak.
        isAutoStreak    = (try? c.decode(Bool.self,   forKey: .isAutoStreak)) ?? false
        streakStartDate = (try? c.decode(Date.self,   forKey: .streakStartDate)) ?? Date()
        checkIns        = (try? c.decode([String].self, forKey: .checkIns)) ?? []
        relapseHistory  = (try? c.decode([Date].self, forKey: .relapseHistory)) ?? []
        relapseDays     = (try? c.decode([String].self, forKey: .relapseDays)) ?? []
        reminderEnabled = (try? c.decode(Bool.self,   forKey: .reminderEnabled)) ?? false
        // Saved before reminders were wall-clock: take the old moment's hour
        // and minute where the user is now — what the time picker showed.
        let legacy = try? decoder.container(keyedBy: LegacyCodingKeys.self)
        let legacyTime = (try? legacy?.decode(Date.self, forKey: .reminderTime)).map {
            Calendar.current.dateComponents([.hour, .minute], from: $0)
        }
        let hour   = (try? c.decode(Int.self, forKey: .reminderHour)) ?? legacyTime?.hour
        let minute = (try? c.decode(Int.self, forKey: .reminderMinute)) ?? legacyTime?.minute
        reminderHour   = hour.flatMap { (0...23).contains($0) ? $0 : nil } ?? 21
        reminderMinute = minute.flatMap { (0...59).contains($0) ? $0 : nil } ?? 0
        bestStreakRecord = (try? c.decode(Int.self,  forKey: .bestStreakRecord)) ?? 0
        lastCelebratedMilestone = (try? c.decode(Int.self, forKey: .lastCelebratedMilestone)) ?? 0
        // Absent in data saved before runs were tracked: the milestone then
        // counts as celebrated in no run, so the current one can celebrate.
        celebratedRunStart = try? c.decode(String.self, forKey: .celebratedRunStart)
    }

    // MARK: Computed

    var currentStreak: Int {
        if isAutoStreak {
            let days = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: streakStartDate),
                to: Calendar.current.startOfDay(for: Date())
            ).day ?? 0
            return max(0, days)
        } else {
            return consecutiveRun(endingOn: Date()).length
        }
    }

    /// Day key the current streak began on, or `nil` at 0. Identifies the run
    /// for `milestoneCelebratedThisRun`.
    var currentRunStart: String? {
        if isAutoStreak { return Self.dayKey(for: streakStartDate) }
        return consecutiveRun(endingOn: Date()).start
    }

    /// The highest milestone already celebrated in the current run. A run ends
    /// with a missed day as well as with a recorded relapse; keyed only on the
    /// relapse, a streak rebuilt after a missed day stayed silent until it beat
    /// the old record. Keyed on the run's first day, undoing and redoing
    /// today's check-in still can't celebrate twice.
    var milestoneCelebratedThisRun: Int {
        celebratedRunStart == currentRunStart ? lastCelebratedMilestone : 0
    }

    var longestStreak: Int {
        if isAutoStreak {
            var best = currentStreak
            var prev: Date? = nil
            for relapse in relapseHistory.sorted() {
                if let start = prev {
                    let days = Calendar.current.dateComponents([.day], from: start, to: relapse).day ?? 0
                    best = max(best, days)
                }
                prev = relapse
            }
            return best
        } else {
            // bestStreakRecord preserves the best across history edits and
            // old-style relapses, which removed the keys anchoring a run.
            return max(longestCheckInStreak(), bestStreakRecord)
        }
    }

    var isCheckedInToday: Bool {
        if isAutoStreak { return currentStreak > 0 }
        return checkIns.contains(Self.dayKey(for: Date()))
    }

    /// The user reported a slip today ("I slipped today").
    var slippedToday: Bool {
        relapseDays.contains(Self.dayKey(for: Date()))
    }

    var totalDays: Int {
        if isAutoStreak {
            return relapseHistory.count > 0
                ? (Calendar.current.dateComponents([.day], from: relapseHistory.min()!, to: Date()).day ?? 0)
                : currentStreak
        }
        return checkIns.count
    }

    var swiftColor: Color { Color(hue: colorHue, saturation: 0.65, brightness: 0.55) }

    // MARK: Day keys
    //
    // A day key is the "yyyy-MM-dd" date the user is on — always Gregorian with
    // ASCII digits, regardless of the device locale. A Buddhist-calendar or
    // Arabic-numeral locale would otherwise write keys that never match again
    // and zero the streak.

    /// The date `date` falls on in the *current* time zone, read fresh on every
    /// call. A formatter created once kept the zone it started in, so after
    /// travel the streak was off by a day until the app relaunched. A new
    /// calendar takes the app's time zone as of now — the same one
    /// `Calendar.current` and the time pickers use (`TimeZone.current` can
    /// differ from it, so it isn't used here).
    static func dayKey(for date: Date) -> String {
        let day = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", day.year ?? 1970, day.month ?? 1, day.day ?? 1)
    }

    /// Maps keys to whole days and back, so stepping from one date to the next
    /// is plain arithmetic. UTC has no DST and no skipped midnight, so
    /// consecutive dates are always exactly one day apart.
    private static let utcKeyFormatter: DateFormatter = {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC")!
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = gregorian
        f.timeZone = gregorian.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Days since 1970-01-01 for a day key; `nil` if it isn't one.
    static func dayNumber(_ key: String) -> Int? {
        guard let date = utcKeyFormatter.date(from: key) else { return nil }
        return Int((date.timeIntervalSince1970 / 86_400).rounded())
    }

    static func dayKey(dayNumber: Int) -> String {
        utcKeyFormatter.string(from: Date(timeIntervalSince1970: Double(dayNumber) * 86_400))
    }

    // MARK: Helpers

    /// The streak ending on `date` (or the day before — see the grace day
    /// below): its length, and the day key it began on.
    private func consecutiveRun(endingOn date: Date) -> (length: Int, start: String?) {
        let set = Set(checkIns)
        let slips = Set(relapseDays)
        var key = Self.dayKey(for: date)
        guard var day = Self.dayNumber(key) else { return (0, nil) }

        // Grace day: if today isn't checked in yet, start counting from
        // yesterday so the streak number persists through the current day.
        // It only drops to 0 once today ends without a check-in (i.e. at
        // midnight, when "yesterday" itself becomes the missed day) — or at
        // once, on a day the user reported a slip.
        if !set.contains(key) {
            if slips.contains(key) { return (0, nil) }
            day -= 1
            key = Self.dayKey(dayNumber: day)
        }

        var streak = 0
        var start: String?
        while set.contains(key) {
            streak += 1
            start = key
            // A slip starts a new run: the slip day counts (checked in after
            // the slip, it's day 1), the day before it never does.
            if slips.contains(key) { break }
            day -= 1
            key = Self.dayKey(dayNumber: day)
        }
        return (streak, start)
    }

    private func longestCheckInStreak() -> Int {
        let days = checkIns.compactMap(Self.dayNumber).sorted()
        guard !days.isEmpty else { return 0 }
        let slips = Set(relapseDays.compactMap(Self.dayNumber))
        var longest = 1, current = 1
        for i in 1..<days.count {
            let diff = days[i] - days[i - 1]
            if diff == 1 && !slips.contains(days[i]) { current += 1; longest = max(longest, current) }
            else if diff >= 1 { current = 1 }   // a gap, or a slip starting a new run
        }
        return longest
    }
}

// MARK: - Milestone

struct Milestone {
    let days: Int
    let icon: String
    let label: String
    let colorHue: Double
}

let allMilestones: [Milestone] = [
    Milestone(days: 1,   icon: "sunrise.fill", label: String(localized: "1 Day"),    colorHue: 0.13),
    Milestone(days: 7,   icon: "star.fill",    label: String(localized: "1 Week"),   colorHue: 0.15),
    Milestone(days: 30,  icon: "crown.fill",   label: String(localized: "1 Month"),  colorHue: 0.55),
    Milestone(days: 90,  icon: "shield.fill",  label: String(localized: "3 Months"), colorHue: 0.38),
    Milestone(days: 365, icon: "trophy.fill",  label: String(localized: "1 Year"),   colorHue: 0.13),
]

// MARK: - Habit Notification Manager

/// Prefix on the scheduled notification's identifier. `NotificationDelegate`
/// parses this back out to learn which habit the tap belongs to.
private let habitNotificationPrefix = "habit-"

/// Habit reminders: one notification per upcoming day, identified
/// `habit-<UUID>-<yyyy-MM-dd>`. It used to be a single repeating trigger,
/// which can't skip a day — it told the user to "check in for today!" after
/// they already had. `HabitManager.syncReminders` rebuilds the queue whenever
/// a check-in, a slip, the settings, the day or the time zone changes.
struct HabitNotificationManager {

    /// Days of reminders kept queued per habit. iOS keeps only the soonest 64
    /// pending notifications per app, so the window is shared between habits.
    static func windowDays(remindedHabits: Int) -> Int {
        max(7, min(30, 60 / max(1, remindedHabits)))
    }

    /// The reminders `habit` should have queued as of `now`: one a day at its
    /// wall-clock time, minus today once it's checked in or a slip was
    /// reported, minus any time already past.
    static func requests(for habit: TrackedHabit, days: Int, now: Date = Date()) -> [UNNotificationRequest] {
        guard habit.reminderEnabled else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let todayDone = habit.isCheckedInToday || habit.slippedToday

        return (0..<days).compactMap { offset in
            guard !(offset == 0 && todayDone),
                  let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            var when = calendar.dateComponents([.year, .month, .day], from: day)
            when.hour = habit.reminderHour
            when.minute = habit.reminderMinute
            // No time zone: the trigger floats, firing at this wall-clock time
            // wherever the user is that day.
            guard let fireDate = calendar.date(from: when), fireDate > now else { return nil }

            let content = UNMutableNotificationContent()
            content.title  = "\(habit.emoji) \(habit.displayName)"
            content.body   = String(localized: "Don't break your streak — check in for today! 🔥")
            content.sound  = .default
            // Round-trip the habit ID in userInfo too, so the tap handler
            // doesn't have to rely solely on parsing the identifier.
            content.userInfo = ["habitID": habit.id.uuidString]
            return UNNotificationRequest(
                identifier: "\(habitNotificationPrefix)\(habit.id.uuidString)-\(TrackedHabit.dayKey(for: day))",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            )
        }
    }

    /// Replaces whatever is queued for `habits` with `requests(for:)`. Asks for
    /// notification permission only when `askPermission` — the user turning a
    /// reminder on — never on a refresh.
    static func sync(_ habits: [TrackedHabit], days: Int, askPermission: Bool) async {
        let center = UNUserNotificationCenter.current()
        // Everything queued for these habits: the per-day requests, plus the
        // repeating "habit-<UUID>" one older versions queued.
        let prefixes = habits.map { "\(habitNotificationPrefix)\($0.id.uuidString)" }
        let queued = await center.pendingNotificationRequests().map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: queued.filter { identifier in
            prefixes.contains { identifier.hasPrefix($0) }
        })

        let wanted = habits.flatMap { requests(for: $0, days: days) }
        guard !wanted.isEmpty, await isAuthorized(center, askPermission: askPermission) else { return }
        for request in wanted {
            do {
                try await center.add(request)
            } catch {
                Log.error("Failed to schedule habit reminder: \(error.localizedDescription)")
            }
        }
        let next = wanted.compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }.min()
        Log.debug("Queued \(wanted.count) habit reminders — next fires at \(next?.description ?? "never")")
    }

    /// Whether reminders may be queued. On `.notDetermined` it asks (when
    /// allowed) and the caller queues straight after a grant — an early return
    /// there once meant a user's first reminder never fired.
    private static func isAuthorized(_ center: UNUserNotificationCenter, askPermission: Bool) async -> Bool {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            guard askPermission else { return false }
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .denied:
            // User opted out — leave it; they can re-enable in Settings.
            return false
        @unknown default:
            return false
        }
    }
}

// MARK: - Habit Notification Routing

/// Shared bus that the notification delegate publishes into and the UI
/// observes. Stays set until consumed so a cold-launch tap (where views
/// aren't yet subscribed when the delegate fires) is still picked up by
/// whichever view appears next.
@MainActor
final class HabitNotificationRouter: ObservableObject {
    static let shared = HabitNotificationRouter()

    /// Set by the notification delegate when a habit reminder is tapped.
    /// `MainTabView` is the sole consumer: it switches to the Streaks tab and
    /// clears this. The tap deliberately does *not* open the habit's edit
    /// sheet — the user lands on the Streaks tab itself.
    @Published var pendingHabitID: UUID?

    private init() {}

    func received(habitID: UUID) {
        pendingHabitID = habitID
    }

    func clear() {
        pendingHabitID = nil
    }
}

/// `UNUserNotificationCenterDelegate` that routes habit-reminder taps into
/// `HabitNotificationRouter`. Installed by `AppDelegate` at launch.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    /// Keep the banner visible if the reminder fires while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        defer { completionHandler() }

        // Prefer userInfo (explicit), fall back to parsing the identifier
        // for older notifications already scheduled before this change.
        let userInfo = response.notification.request.content.userInfo
        let id: UUID? = {
            if let raw = userInfo["habitID"] as? String, let uuid = UUID(uuidString: raw) {
                return uuid
            }
            let identifier = response.notification.request.identifier
            guard identifier.hasPrefix(habitNotificationPrefix) else { return nil }
            // "habit-<UUID>", or per day "habit-<UUID>-<yyyy-MM-dd>".
            return UUID(uuidString: String(identifier.dropFirst(habitNotificationPrefix.count).prefix(36)))
        }()

        guard let habitID = id else { return }
        Task { @MainActor in
            HabitNotificationRouter.shared.received(habitID: habitID)
        }
    }
}

// MARK: - HabitManager

@MainActor
class HabitManager: ObservableObject {
    static let shared = HabitManager()

    @Published var habits: [TrackedHabit] = []

    private let defaults = UserDefaults.standard
    private let key = "trackedHabits_v2"

    static let pornFreeID = TrackedHabit.builtInID

    private var dayChangeObserver: NSObjectProtocol?
    private var timeZoneObserver: NSObjectProtocol?
    /// The reminder sync in flight. Each new one waits for it, so a quick
    /// check-in and undo can't interleave their remove and add steps.
    private var reminderSync: Task<Void, Never>?

    private init() {
        load()
        sanitizeDayKeys()
        ensureBuiltInHabit()

        // Streaks and "checked in today" are computed from the clock, so a new
        // day changes them without touching `habits` — and nothing redrew.
        // Opened the next morning, the Streaks tab still read "Checked in
        // today" from the night before, inviting the user to skip the
        // check-in that keeps the streak alive. Posted at midnight, or on wake
        // if the day changed while the app was suspended.
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.clockChanged() }
        }
        // A new time zone can change today's date too. Day keys read the zone
        // fresh on every call — reset Foundation's cached copy so it is fresh.
        timeZoneObserver = NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            NSTimeZone.resetSystemTimeZone()
            Task { @MainActor in self?.clockChanged() }
        }

        // Re-queue from the stored settings: tops up the rolling window, moves
        // installs off the old repeating reminder, and re-times any reminder an
        // older version queued at a time-zone-shifted hour.
        syncReminders()
    }

    /// A new day or time zone: redraw, and re-queue so today's reminder is
    /// right for the day it now is.
    private func clockChanged() {
        objectWillChange.send()
        syncReminders()
    }

    // MARK: - Reminders

    /// Re-queues the reminders of `targets` — by default every habit with a
    /// reminder on. Touches the notification center only when there's a habit
    /// to sync, which keeps the macOS logic harness clear of it.
    private func syncReminders(_ targets: [TrackedHabit]? = nil, askPermission: Bool = false) {
        let targets = targets ?? habits.filter(\.reminderEnabled)
        guard !targets.isEmpty else { return }
        let days = HabitNotificationManager.windowDays(remindedHabits: habits.filter(\.reminderEnabled).count)
        let previous = reminderSync
        reminderSync = Task {
            await previous?.value
            await HabitNotificationManager.sync(targets, days: days, askPermission: askPermission)
        }
    }

    /// After a check-in, undo, slip or backfill: today's reminder may now be
    /// unwanted, or wanted again.
    private func syncReminders(at idx: Int) {
        if habits[idx].reminderEnabled { syncReminders([habits[idx]]) }
    }

    /// Drops everything queued for habits being deleted.
    private func clearReminders(_ gone: [TrackedHabit]) {
        syncReminders(gone.map { habit in
            var off = habit
            off.reminderEnabled = false
            return off
        })
    }

    // MARK: - Check-in / Reset

    func checkIn(habitID: UUID) {
        guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
        let today = TrackedHabit.dayKey(for: Date())
        if !habits[idx].checkIns.contains(today) {
            habits[idx].checkIns.append(today)
            save()
            syncReminders(at: idx)
        }
    }

    func undoCheckIn(habitID: UUID) {
        guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
        let today = TrackedHabit.dayKey(for: Date())
        habits[idx].checkIns.removeAll { $0 == today }
        save()
        syncReminders(at: idx)
    }

    func recordRelapse(habitID: UUID) {
        guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
        // A slip today: today isn't a clean day, and the run ends here. The
        // recorded slip day is what stops the grace day carrying the old
        // streak on — this used to delete yesterday's check-in too, losing a
        // clean day from the history the dialog promises to keep.
        let today = TrackedHabit.dayKey(for: Date())
        habits[idx].checkIns.removeAll { $0 == today }
        if !habits[idx].relapseDays.contains(today) {
            habits[idx].relapseDays.append(today)
        }
        // The run that just ended (through yesterday) can set the record.
        habits[idx].bestStreakRecord = max(habits[idx].bestStreakRecord, habits[idx].longestStreak)
        habits[idx].relapseHistory.append(Date())
        habits[idx].streakStartDate = Date()
        // New run — milestones celebrate again as the user rebuilds.
        habits[idx].lastCelebratedMilestone = 0
        habits[idx].celebratedRunStart = nil
        save()
        // No "don't break your streak" reminder tonight.
        syncReminders(at: idx)
        Log.debug("Relapse recorded for \(habits[idx].name)")
    }

    /// Takes back today's "I slipped today" — offered on the slip day for a
    /// mis-tap. The old streak returns through the grace day; a check-in the
    /// slip removed isn't restored, the user checks in again.
    func undoRelapse(habitID: UUID) {
        guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
        let today = TrackedHabit.dayKey(for: Date())
        guard habits[idx].relapseDays.contains(today) else { return }
        habits[idx].relapseDays.removeAll { $0 == today }
        if let last = habits[idx].relapseHistory.last, TrackedHabit.dayKey(for: last) == today {
            habits[idx].relapseHistory.removeLast()
        }
        // The restored run already reached its milestones — an undo mustn't
        // celebrate them again.
        let restored = habits[idx]
        habits[idx].lastCelebratedMilestone = allMilestones.last { $0.days <= restored.currentStreak }?.days ?? 0
        habits[idx].celebratedRunStart = restored.currentRunStart
        save()
        syncReminders(at: idx)
        Log.debug("Relapse undone for \(habits[idx].name)")
    }

    func markMilestoneCelebrated(days: Int, habitID: UUID) {
        guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
        habits[idx].lastCelebratedMilestone = max(habits[idx].milestoneCelebratedThisRun, days)
        habits[idx].celebratedRunStart = habits[idx].currentRunStart
        save()
    }

    func setStartDate(_ date: Date, habitID: UUID) {
        guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
        let now = Date()
        let startKey = TrackedHabit.dayKey(for: min(date, now))
        habits[idx].streakStartDate = Calendar.current.startOfDay(for: min(date, now))
        // Backfill day keys start...today inclusive (today too, or the streak
        // would silently collapse at midnight unless the user checks in),
        // merged with whatever is already logged.
        var keys = Set(habits[idx].checkIns)
        if let first = TrackedHabit.dayNumber(startKey),
           let last = TrackedHabit.dayNumber(TrackedHabit.dayKey(for: now)), first <= last {
            for day in first...last { keys.insert(TrackedHabit.dayKey(dayNumber: day)) }
        }
        habits[idx].checkIns = keys.sorted()
        // "Clean since" that day: slips reported after it no longer stand —
        // which is also how a mistaken slip is taken back on a later day.
        habits[idx].relapseDays.removeAll { $0 > startKey }
        save()
        syncReminders(at: idx)
        Log.debug("Backfilled streak from \(startKey) — \(habits[idx].checkIns.count) days logged")
    }

    // MARK: - CRUD

    func addHabit(_ habit: TrackedHabit) {
        habits.append(habit)
        save()
        // The user just set this reminder up, so this may ask permission.
        syncReminders([habit], askPermission: true)
    }

    func removeHabits(at offsets: IndexSet) {
        let toRemove = offsets.filter { !habits[$0].isBuiltIn }
        clearReminders(toRemove.map { habits[$0] })
        habits.remove(atOffsets: IndexSet(toRemove))
        save()
    }

    func deleteHabit(id: UUID) {
        guard let idx = habits.firstIndex(where: { $0.id == id }),
              !habits[idx].isBuiltIn else { return }
        clearReminders([habits[idx]])
        habits.remove(at: idx)
        save()
    }

    func updateHabit(_ updated: TrackedHabit) {
        guard let idx = habits.firstIndex(where: { $0.id == updated.id }) else { return }
        habits[idx] = updated
        save()
        // Saved from the settings sheet or onboarding — turning the reminder
        // on there may ask permission.
        syncReminders([updated], askPermission: true)
    }

    // MARK: - Persistence

    private func save() {
        do {
            defaults.set(try JSONEncoder().encode(habits), forKey: key)
        } catch {
            Log.error("Failed to encode habits: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: key) else { return }
        do {
            habits = try JSONDecoder().decode([TrackedHabit].self, from: data)
        } catch {
            Log.error("Habit store decode failed: \(error.localizedDescription)")
            // Preserve the original blob before ensureBuiltInHabit()'s save()
            // can overwrite the main key — the user's history is irreplaceable.
            let backupKey = "trackedHabits_v2_corrupt"
            if defaults.data(forKey: backupKey) == nil {
                defaults.set(data, forKey: backupKey)
            }
            // Salvage whatever elements still decode individually.
            if let partial = try? JSONDecoder().decode([FailableDecodable<TrackedHabit>].self, from: data) {
                habits = partial.compactMap { $0.value }
                Log.error("Recovered \(habits.count)/\(partial.count) habits from damaged store")
            }
        }
    }

    /// Repairs check-in keys written by the unpinned pre-fix formatter under
    /// non-Gregorian / non-latin-numeral locales, and dedupes. Idempotent —
    /// canonical keys short-circuit through the regex, and nothing is saved
    /// unless a repair actually happened.
    private func sanitizeDayKeys() {
        let legacy = DateFormatter()   // device locale — how bad keys were written
        legacy.dateFormat = "yyyy-MM-dd"
        var changed = false
        for idx in habits.indices {
            var repaired: Set<String> = []
            for dayKey in habits[idx].checkIns {
                // [0-9] is ASCII-only; \d would also match Unicode digits.
                if dayKey.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil {
                    repaired.insert(dayKey)
                } else if let date = legacy.date(from: dayKey) {
                    repaired.insert(TrackedHabit.dayKey(for: date))
                    changed = true
                    Log.debug("Repaired non-canonical check-in key: \(dayKey)")
                } else {
                    changed = true
                    Log.error("Dropping unparseable check-in key: \(dayKey)")
                }
            }
            if repaired.count != habits[idx].checkIns.count { changed = true }
            habits[idx].checkIns = repaired.sorted()
        }
        if changed { save() }
    }

    private func ensureBuiltInHabit() {
        // Pathological double-corruption can leave several habits claiming the
        // built-in id (which would also break ForEach's Identifiable contract)
        // — keep the one with the most history.
        let claimants = habits.filter { $0.id == HabitManager.pornFreeID }
        if claimants.count > 1,
           let keep = claimants.max(by: { $0.checkIns.count < $1.checkIns.count }) {
            habits.removeAll { $0.id == HabitManager.pornFreeID }
            habits.insert(keep, at: 0)
            save()
        }

        if !habits.contains(where: { $0.id == HabitManager.pornFreeID }) {
            // First time: no pre-checked days — user starts fresh
            let builtIn = TrackedHabit(
                id: HabitManager.pornFreeID,
                name: "Porn Free",
                emoji: "🛡️",
                colorHue: 0.38,
                isAutoStreak: false,
                streakStartDate: Date(),
                checkIns: [],   // not pre-checked
                isBuiltIn: true
            )
            habits.insert(builtIn, at: 0)
            save()
        } else {
            // Migrate autoStreak to check-in model if needed
            if let idx = habits.firstIndex(where: { $0.id == HabitManager.pornFreeID }),
               habits[idx].isAutoStreak {
                var migrated = habits[idx]
                migrated.isAutoStreak = false
                let cal = Calendar.current
                var cursor = cal.startOfDay(for: migrated.streakStartDate)
                let today = cal.startOfDay(for: Date())
                var generated: Set<String> = Set(migrated.checkIns)
                while cursor <= today {
                    generated.insert(TrackedHabit.dayKey(for: cursor))
                    cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
                }
                migrated.checkIns = Array(generated).sorted()
                habits[idx] = migrated
                save()
            }
            // Always keep porn-free first
            if let idx = habits.firstIndex(where: { $0.id == HabitManager.pornFreeID }), idx != 0 {
                let h = habits.remove(at: idx)
                habits.insert(h, at: 0)
            }
        }
    }
}
