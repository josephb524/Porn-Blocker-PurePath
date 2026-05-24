import Foundation
import SwiftUI
import UserNotifications

// MARK: - Habit Model

struct TrackedHabit: Identifiable, Codable {
    var id: UUID
    var name: String
    var emoji: String
    var colorHue: Double
    var isAutoStreak: Bool
    var streakStartDate: Date
    var checkIns: [String]       // "yyyy-MM-dd" strings
    var relapseHistory: [Date]
    var isBuiltIn: Bool
    var reminderEnabled: Bool
    var reminderTime: Date       // only hour & minute are used

    // MARK: Init

    init(id: UUID = UUID(),
         name: String,
         emoji: String,
         colorHue: Double,
         isAutoStreak: Bool = false,
         streakStartDate: Date = Date(),
         checkIns: [String] = [],
         relapseHistory: [Date] = [],
         isBuiltIn: Bool = false,
         reminderEnabled: Bool = false,
         reminderTime: Date = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()) {
        self.id              = id
        self.name            = name
        self.emoji           = emoji
        self.colorHue        = colorHue
        self.isAutoStreak    = isAutoStreak
        self.streakStartDate = streakStartDate
        self.checkIns        = checkIns
        self.relapseHistory  = relapseHistory
        self.isBuiltIn       = isBuiltIn
        self.reminderEnabled = reminderEnabled
        self.reminderTime    = reminderTime
    }

    // MARK: - Custom Codable (handles missing keys in old data)

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, colorHue, isAutoStreak, streakStartDate
        case checkIns, relapseHistory, isBuiltIn, reminderEnabled, reminderTime
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(UUID.self,   forKey: .id)
        name            = try c.decode(String.self, forKey: .name)
        emoji           = try c.decode(String.self, forKey: .emoji)
        colorHue        = try c.decode(Double.self, forKey: .colorHue)
        isAutoStreak    = try c.decode(Bool.self,   forKey: .isAutoStreak)
        streakStartDate = try c.decode(Date.self,   forKey: .streakStartDate)
        checkIns        = try c.decode([String].self, forKey: .checkIns)
        relapseHistory  = (try? c.decode([Date].self, forKey: .relapseHistory)) ?? []
        isBuiltIn       = (try? c.decode(Bool.self,   forKey: .isBuiltIn)) ?? false
        reminderEnabled = (try? c.decode(Bool.self,   forKey: .reminderEnabled)) ?? false
        let defaultTime = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
        reminderTime    = (try? c.decode(Date.self,   forKey: .reminderTime)) ?? defaultTime
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
            return consecutiveStreak(endingOn: Date())
        }
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
            return longestCheckInStreak()
        }
    }

    var isCheckedInToday: Bool {
        if isAutoStreak { return currentStreak > 0 }
        return checkIns.contains(Self.dayKey(for: Date()))
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

    // MARK: Helpers

    /// Shared "yyyy-MM-dd" formatter. Building a `DateFormatter` is expensive,
    /// so it is created once and reused — it is only ever read, never mutated.
    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(for date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }

    private func consecutiveStreak(endingOn date: Date) -> Int {
        let set = Set(checkIns)
        let f = Self.dayKeyFormatter
        var cursor = Calendar.current.startOfDay(for: date)

        // Grace day: if today isn't checked in yet, start counting from
        // yesterday so the streak number persists through the current day.
        // It only drops to 0 once today ends without a check-in (i.e. at
        // midnight, when "yesterday" itself becomes the missed day).
        if !set.contains(f.string(from: cursor)) {
            cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor)!
        }

        var streak = 0
        while set.contains(f.string(from: cursor)) {
            streak += 1
            cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor)!
        }
        return streak
    }

    private func longestCheckInStreak() -> Int {
        let f = Self.dayKeyFormatter
        let sorted = checkIns.compactMap { f.date(from: $0) }.sorted()
        guard !sorted.isEmpty else { return 0 }
        var longest = 1, current = 1
        for i in 1..<sorted.count {
            let diff = Calendar.current.dateComponents([.day], from: sorted[i-1], to: sorted[i]).day ?? 0
            if diff == 1 { current += 1; longest = max(longest, current) }
            else if diff > 1 { current = 1 }
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
    Milestone(days: 1,   icon: "sunrise.fill", label: "1 Day",    colorHue: 0.13),
    Milestone(days: 7,   icon: "star.fill",    label: "1 Week",   colorHue: 0.15),
    Milestone(days: 30,  icon: "crown.fill",   label: "1 Month",  colorHue: 0.55),
    Milestone(days: 90,  icon: "shield.fill",  label: "3 Months", colorHue: 0.38),
    Milestone(days: 365, icon: "trophy.fill",  label: "1 Year",   colorHue: 0.13),
]

// MARK: - Habit Notification Manager

/// Prefix on the scheduled notification's identifier. `NotificationDelegate`
/// parses this back out to learn which habit the tap belongs to.
private let habitNotificationPrefix = "habit-"

struct HabitNotificationManager {

    static func schedule(for habit: TrackedHabit) {
        let center = UNUserNotificationCenter.current()
        let identifier = "\(habitNotificationPrefix)\(habit.id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard habit.reminderEnabled else { return }

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                // First-time enable: ask, then schedule on the same call
                // chain. Previously this branch only asked and returned,
                // so the user's first reminder was never actually queued
                // and didn't fire that day.
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    guard granted else { return }
                    addRequest(for: habit, on: center, identifier: identifier)
                }
            case .authorized, .provisional, .ephemeral:
                addRequest(for: habit, on: center, identifier: identifier)
            case .denied:
                // User opted out — leave it; they can re-enable in Settings.
                break
            @unknown default:
                break
            }
        }
    }

    static func cancel(for habitID: UUID) {
        let identifier = "\(habitNotificationPrefix)\(habitID.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Builds and submits the actual repeating request. Pulled out so both
    /// the already-authorized branch and the `.notDetermined`-then-granted
    /// branch above share the same code path.
    private static func addRequest(for habit: TrackedHabit,
                                   on center: UNUserNotificationCenter,
                                   identifier: String) {
        let content = UNMutableNotificationContent()
        content.title  = "\(habit.emoji) \(habit.name)"
        content.body   = "Don't break your streak — check in for today! 🔥"
        content.sound  = .default
        // Round-trip the habit ID in userInfo too, so the tap handler
        // doesn't have to rely solely on parsing the identifier.
        content.userInfo = ["habitID": habit.id.uuidString]

        var comps = Calendar.current.dateComponents([.hour, .minute], from: habit.reminderTime)
        comps.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error {
                Log.error("Failed to schedule habit reminder: \(error.localizedDescription)")
            } else if let next = trigger.nextTriggerDate() {
                Log.debug("Scheduled habit reminder for \(habit.name) — next fires at \(next)")
            }
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
    /// `MainTabView` reacts by switching to the Streaks tab; `StatsView`
    /// reacts by opening the edit sheet for that habit, then clears it.
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
            return UUID(uuidString: String(identifier.dropFirst(habitNotificationPrefix.count)))
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

    static let pornFreeID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private init() {
        load()
        ensureBuiltInHabit()
    }

    // MARK: - Check-in / Reset

    func checkIn(habitID: UUID) {
        guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
        let today = TrackedHabit.dayKey(for: Date())
        if !habits[idx].checkIns.contains(today) {
            habits[idx].checkIns.append(today)
            save()
        }
    }

    func undoCheckIn(habitID: UUID) {
        guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
        let today = TrackedHabit.dayKey(for: Date())
        habits[idx].checkIns.removeAll { $0 == today }
        save()
    }

    func recordRelapse(habitID: UUID) {
        guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
        habits[idx].relapseHistory.append(Date())
        habits[idx].streakStartDate = Date()
        save()
    }

    func setStartDate(_ date: Date, habitID: UUID) {
        guard let idx = habits.firstIndex(where: { $0.id == habitID }) else { return }
        habits[idx].streakStartDate = Calendar.current.startOfDay(for: min(date, Date()))
        save()
    }

    // MARK: - CRUD

    func addHabit(_ habit: TrackedHabit) {
        habits.append(habit)
        HabitNotificationManager.schedule(for: habit)
        save()
    }

    func removeHabits(at offsets: IndexSet) {
        let toRemove = offsets.filter { !habits[$0].isBuiltIn }
        for idx in toRemove { HabitNotificationManager.cancel(for: habits[idx].id) }
        habits.remove(atOffsets: IndexSet(toRemove))
        save()
    }

    func deleteHabit(id: UUID) {
        guard let idx = habits.firstIndex(where: { $0.id == id }),
              !habits[idx].isBuiltIn else { return }
        HabitNotificationManager.cancel(for: id)
        habits.remove(at: idx)
        save()
    }

    func updateHabit(_ updated: TrackedHabit) {
        guard let idx = habits.firstIndex(where: { $0.id == updated.id }) else { return }
        habits[idx] = updated
        HabitNotificationManager.schedule(for: updated)
        save()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(habits) {
            defaults.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TrackedHabit].self, from: data) else { return }
        habits = decoded
    }

    private func ensureBuiltInHabit() {
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
