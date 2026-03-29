import SwiftUI

// MARK: - Main Insights / Habit Tracker View

struct StatsView: View {
    @StateObject private var habitManager = HabitManager.shared
    @State private var showAddHabit = false
    @State private var selectedEditHabit: TrackedHabit? = nil
    @State private var appear = false

    private var pornFreeHabit: TrackedHabit? {
        habitManager.habits.first(where: { $0.id == HabitManager.pornFreeID })
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let habit = pornFreeHabit {
                        pornFreeHeroCard(habit)
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 24)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appear)

                        milestonesRow(streak: habit.currentStreak)
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 20)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appear)
                    }

                    customHabitsSection
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: appear)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddHabit = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color(hue: 0.38, saturation: 0.65, brightness: 0.5))
                            .font(.title3)
                    }
                }
            }
            .onAppear { withAnimation { appear = true } }
            .sheet(isPresented: $showAddHabit) { AddHabitView() }
            .sheet(item: $selectedEditHabit) { habit in
                EditHabitView(habit: habit)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Porn Free Hero Card

    private func pornFreeHeroCard(_ habit: TrackedHabit) -> some View {
        VStack(spacing: 0) {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(hue: 0.38, saturation: 0.7, brightness: 0.38),
                        Color(hue: 0.55, saturation: 0.6, brightness: 0.28)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )

                // Decorative circles
                Circle().fill(Color.white.opacity(0.06)).frame(width: 200).offset(x: 100, y: -60)
                Circle().fill(Color.white.opacity(0.04)).frame(width: 140).offset(x: -100, y: 80)

                VStack(spacing: 16) {
                    // Streak ring + number
                    ZStack {
                        // Outer ring
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 10)
                            .frame(width: 140, height: 140)

                        // Progress ring
                        Circle()
                            .trim(from: 0, to: ringProgress(streak: habit.currentStreak))
                            .stroke(
                                LinearGradient(colors: [.white, Color.white.opacity(0.5)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .frame(width: 140, height: 140)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 1.0, dampingFraction: 0.7), value: habit.currentStreak)

                        VStack(spacing: 2) {
                            Text("\(habit.currentStreak)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(habit.currentStreak == 1 ? "DAY" : "DAYS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .tracking(2)
                        }
                    }

                    // Label
                    VStack(spacing: 4) {
                        Text("🛡️ Porn Free")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("\(habit.checkIns.count) days logged")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.65))
                    }

                    // Stats row
                    HStack(spacing: 0) {
                        pornFreeStat(value: "\(habit.longestStreak)", label: "Best Streak")
                        Divider().frame(height: 30).background(Color.white.opacity(0.2))
                        pornFreeStat(value: "\(habit.totalDays)", label: "Total Days")
                        Divider().frame(height: 30).background(Color.white.opacity(0.2))
                        pornFreeStat(value: nextMilestoneLabel(habit.currentStreak), label: "Next Goal")
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 28)
                .padding(.horizontal, 20)

                // Gear button — top right of card, opens edit sheet
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            if let h = pornFreeHabit { selectedEditHabit = h }
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(10)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .padding(12)
                    }
                    Spacer()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .shadow(color: Color(hue: 0.38, saturation: 0.5, brightness: 0.3).opacity(0.3), radius: 16, x: 0, y: 8)
    }

    private func pornFreeStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Milestones Row

    private func milestonesRow(streak: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(allMilestones, id: \.days) { milestone in
                        MilestoneBadge(milestone: milestone, currentStreak: streak)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Custom Habits Section

    private var customHabitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Habits")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: { showAddHabit = true }) {
                    Label("Add", systemImage: "plus")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(hue: 0.38, saturation: 0.65, brightness: 0.5))
                }
            }
            .padding(.horizontal, 4)

            let customHabits = habitManager.habits.filter { !$0.isBuiltIn }

            if customHabits.isEmpty {
                emptyHabitsPrompt
            } else {
                ForEach(customHabits) { habit in
                    HabitCard(habit: habit, onTap: { selectedEditHabit = habit })
                }
            }
        }
    }

    private var emptyHabitsPrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            VStack(spacing: 6) {
                Text("Track a healthy habit")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("Add habits like Exercise, Reading, or Meditation and track your daily streaks.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            Button(action: { showAddHabit = true }) {
                Label("Add First Habit", systemImage: "plus")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(hue: 0.38, saturation: 0.65, brightness: 0.5))
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - Helpers

    private func ringProgress(streak: Int) -> Double {
        // Cycles through milestones: progress toward next milestone
        let next = allMilestones.first(where: { $0.days > streak })?.days ?? 365
        let prev = allMilestones.last(where:  { $0.days <= streak })?.days ?? 0
        guard next != prev else { return 1.0 }
        return min(1.0, Double(streak - prev) / Double(next - prev))
    }

    private func streakStartLabel(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "since \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    private func nextMilestoneLabel(_ streak: Int) -> String {
        guard let next = allMilestones.first(where: { $0.days > streak }) else { return "🏆 All!" }
        let diff = next.days - streak
        return "\(diff)d"
    }
}

// MARK: - Milestone Badge

struct MilestoneBadge: View {
    let milestone: Milestone
    let currentStreak: Int

    private var achieved: Bool { currentStreak >= milestone.days }
    private var color: Color { Color(hue: milestone.colorHue, saturation: 0.7, brightness: achieved ? 0.7 : 0.4) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achieved ? color.opacity(0.18) : Color(.systemGray6))
                    .frame(width: 58, height: 58)
                if achieved {
                    Circle()
                        .stroke(color.opacity(0.4), lineWidth: 2)
                        .frame(width: 58, height: 58)
                }
                Image(systemName: milestone.icon)
                    .font(.system(size: 22))
                    .foregroundColor(achieved ? color : Color(.systemGray4))
            }

            Text(milestone.label)
                .font(.caption2)
                .fontWeight(achieved ? .semibold : .regular)
                .foregroundColor(achieved ? .primary : .secondary)
        }
        .frame(width: 68)
        .scaleEffect(achieved ? 1.0 : 0.93)
        .animation(.spring(response: 0.4), value: achieved)
    }
}

// MARK: - Habit Card (Custom Habits)

struct HabitCard: View {
    @StateObject private var habitManager = HabitManager.shared
    let habit: TrackedHabit
    var onTap: (() -> Void)? = nil

    private var color: Color {
        Color(hue: habit.colorHue, saturation: 0.65, brightness: 0.55)
    }

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 14) {
                // Emoji + color bg
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.12))
                        .frame(width: 50, height: 50)
                    Text(habit.emoji)
                        .font(.title2)
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(habit.name)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(habit.currentStreak > 0 ? .orange : .secondary)
                        Text("\(habit.currentStreak) day streak")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("·")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("Best: \(habit.longestStreak)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Check-in + chevron
                HStack(spacing: 10) {
                    Button(action: {
                        if habit.isCheckedInToday {
                            habitManager.undoCheckIn(habitID: habit.id)
                        } else {
                            habitManager.checkIn(habitID: habit.id)
                        }
                    }) {
                        Image(systemName: habit.isCheckedInToday ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 28))
                            .foregroundColor(habit.isCheckedInToday ? color : Color(.systemGray4))
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: habit.isCheckedInToday)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Habit Sheet

struct AddHabitView: View {
    @StateObject private var habitManager = HabitManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedEmoji = "⭐️"
    @State private var selectedHue: Double = 0.38
    @State private var reminderEnabled: Bool = false
    @State private var reminderTime: Date = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()

    private let quickEmojis = ["⭐️","💪","📚","🧘","🏃","🎨","✍️","🎵","🌿","💧","🥗","😴","🙏","🏋️","🚴"]
    private let quickHues: [Double] = [0.38, 0.6, 0.08, 0.75, 0.0, 0.15, 0.55, 0.9]

    var body: some View {
        NavigationView {
            Form {
                Section("Habit Details") {
                    TextField("Habit name (e.g. Exercise, Reading)", text: $name)
                        .autocapitalization(.words)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Emoji").font(.caption).foregroundColor(.secondary)
                        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 5), spacing: 10) {
                            ForEach(quickEmojis, id: \.self) { emoji in
                                Button(action: { selectedEmoji = emoji }) {
                                    Text(emoji)
                                        .font(.title2)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedEmoji == emoji
                                                      ? Color(hue: selectedHue, saturation: 0.5, brightness: 0.9).opacity(0.2)
                                                      : Color(.systemGray6))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Color").font(.caption).foregroundColor(.secondary)
                        HStack(spacing: 10) {
                            ForEach(quickHues, id: \.self) { hue in
                                Button(action: { selectedHue = hue }) {
                                    Circle()
                                        .fill(Color(hue: hue, saturation: 0.65, brightness: 0.6))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle().stroke(Color.primary.opacity(0.7), lineWidth: selectedHue == hue ? 2.5 : 0)
                                                .padding(2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Daily Reminder") {
                    Toggle("Remind me daily", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section {
                    Button("Add Habit") {
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        let habit = TrackedHabit(
                            name: name.trimmingCharacters(in: .whitespaces),
                            emoji: selectedEmoji,
                            colorHue: selectedHue,
                            isAutoStreak: false,
                            streakStartDate: Date(),
                            checkIns: [],
                            reminderEnabled: reminderEnabled,
                            reminderTime: reminderTime
                        )
                        habitManager.addHabit(habit)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : Color(hue: 0.38, saturation: 0.65, brightness: 0.5))
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Porn Free Start Date Sheet

struct PornFreeStartDateSheet: View {
    @StateObject private var habitManager = HabitManager.shared
    @Environment(\.dismiss) private var dismiss
    let habit: TrackedHabit

    @State private var selectedDate: Date

    init(habit: TrackedHabit) {
        self.habit = habit
        _selectedDate = State(initialValue: habit.streakStartDate)
    }

    private var dayCount: Int {
        max(0, Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: selectedDate),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Preview banner
                VStack(spacing: 6) {
                    Text("\(dayCount)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hue: 0.38, saturation: 0.65, brightness: 0.55),
                                         Color(hue: 0.55, saturation: 0.6, brightness: 0.45)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    Text(dayCount == 1 ? "day porn free" : "days porn free")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Color(.systemGroupedBackground))

                Form {
                    Section {
                        DatePicker(
                            "I've been clean since",
                            selection: $selectedDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .tint(Color(hue: 0.38, saturation: 0.65, brightness: 0.5))
                    } footer: {
                        Text("Set to the date you last watched porn. The app will count your streak from that day.")
                    }
                }
            }
            .navigationTitle("Set Start Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        habitManager.setStartDate(selectedDate, habitID: habit.id)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hue: 0.38, saturation: 0.65, brightness: 0.5))
                }
            }
        }
    }
}

// MARK: - Edit Habit Sheet

struct EditHabitView: View {
    @StateObject private var habitManager = HabitManager.shared
    @Environment(\.dismiss) private var dismiss

    let habit: TrackedHabit

    @State private var name: String
    @State private var selectedEmoji: String
    @State private var selectedHue: Double
    @State private var localCheckIns: [String]
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    @State private var showDeleteConfirm = false

    private let quickEmojis = ["⭐️","💪","📚","🧘","🏃","🎨","✍️","🎵","🌿","💧","🥗","😴","🙏","🏋️","🚴"]
    private let quickHues: [Double] = [0.38, 0.6, 0.08, 0.75, 0.0, 0.15, 0.55, 0.9]

    init(habit: TrackedHabit) {
        self.habit = habit
        _name          = State(initialValue: habit.name)
        _selectedEmoji = State(initialValue: habit.emoji)
        _selectedHue   = State(initialValue: habit.colorHue)
        _localCheckIns  = State(initialValue: habit.checkIns)
        _reminderEnabled = State(initialValue: habit.reminderEnabled)
        _reminderTime    = State(initialValue: habit.reminderTime)
    }

    private var previewColor: Color {
        Color(hue: selectedHue, saturation: 0.65, brightness: 0.55)
    }

    var body: some View {
        NavigationView {
            Form {
                // Preview header
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(previewColor.opacity(0.15))
                                .frame(width: 52, height: 52)
                            Text(selectedEmoji)
                                .font(.title2)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name.isEmpty ? "Habit Name" : name)
                                .font(.headline)
                                .foregroundColor(name.isEmpty ? .secondary : .primary)
                            Text("\(habit.currentStreak) day streak · Best: \(habit.longestStreak)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Name
                Section("Name") {
                    TextField("Habit name", text: $name)
                        .autocapitalization(.words)
                }

                // Emoji
                Section("Emoji") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 5), spacing: 10) {
                        ForEach(quickEmojis, id: \.self) { emoji in
                            Button(action: { selectedEmoji = emoji }) {
                                Text(emoji)
                                    .font(.title2)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedEmoji == emoji
                                                  ? previewColor.opacity(0.2)
                                                  : Color(.systemGray6))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Color
                Section("Color") {
                    HStack(spacing: 12) {
                        ForEach(quickHues, id: \.self) { hue in
                            Button(action: { selectedHue = hue }) {
                                Circle()
                                    .fill(Color(hue: hue, saturation: 0.65, brightness: 0.6))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary.opacity(0.7), lineWidth: selectedHue == hue ? 2.5 : 0)
                                            .padding(2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Reminder
                Section("Daily Reminder") {
                    Toggle("Remind me daily", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .tint(previewColor)
                    }
                }

                // History grid — tap any past day to check in or undo
                Section {
                    HabitHistoryGrid(checkIns: $localCheckIns, color: previewColor)
                } header: {
                    Text("Check-in History")
                } footer: {
                    Text("Tap any past day to mark or unmark it. Use this to log days you forgot, or correct accidental check-ins.")
                }

                // Delete (hidden for built-in habits)
                if !habit.isBuiltIn {
                    Section {
                        Button(role: .destructive, action: { showDeleteConfirm = true }) {
                            HStack {
                                Spacer()
                                Label("Delete Habit", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(habit.isBuiltIn ? "Porn Free Settings" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        var updated = habit
                        updated.name            = name.trimmingCharacters(in: .whitespaces)
                        updated.emoji           = selectedEmoji
                        updated.colorHue        = selectedHue
                        updated.checkIns        = localCheckIns
                        updated.reminderEnabled = reminderEnabled
                        updated.reminderTime    = reminderTime
                        habitManager.updateHabit(updated)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(previewColor)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Delete \"\(habit.name)\"?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    habitManager.deleteHabit(id: habit.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the habit and all its check-in history.")
            }
        }
    }
}

// MARK: - Habit History Grid

struct HabitHistoryGrid: View {
    @Binding var checkIns: [String]
    let color: Color

    private let weeksToShow = 8
    private let calendar = Calendar.current
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    /// All dates laid out as [week][dayOfWeek], oldest first
    private var grid: [[Date]] {
        let today = calendar.startOfDay(for: Date())
        // Start of the oldest displayed week (Sunday)
        let weekday = calendar.component(.weekday, from: today) // 1=Sun
        let startOfCurrentWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today)!
        let gridStart = calendar.date(byAdding: .weekOfYear, value: -(weeksToShow - 1), to: startOfCurrentWeek)!

        return (0..<weeksToShow).map { week in
            (0..<7).compactMap { day in
                calendar.date(byAdding: .day, value: week * 7 + day, to: gridStart)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Day-of-week header
            HStack(spacing: 4) {
                ForEach(dayLabels.indices, id: \.self) { i in
                    Text(dayLabels[i])
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Week rows
            ForEach(grid.indices, id: \.self) { weekIdx in
                HStack(spacing: 4) {
                    ForEach(grid[weekIdx].indices, id: \.self) { dayIdx in
                        let date    = grid[weekIdx][dayIdx]
                        let key     = TrackedHabit.dayKey(for: date)
                        let todayKey = TrackedHabit.dayKey(for: Date())
                        let isFuture = key > todayKey
                        let isToday  = key == todayKey
                        let isChecked = checkIns.contains(key)

                        Button(action: {
                            guard !isFuture else { return }
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                if isChecked {
                                    checkIns.removeAll { $0 == key }
                                } else {
                                    checkIns.append(key)
                                    checkIns.sort()
                                }
                            }
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        isFuture  ? Color.clear :
                                        isChecked ? color :
                                                    Color(.systemGray5)
                                    )
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)

                                // Today indicator ring
                                if isToday {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isChecked ? Color.white.opacity(0.5) : color, lineWidth: 2)
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fit)
                                }

                                // Check icon when checked
                                if isChecked {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isFuture)
                    }
                }
            }

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(.systemGray5)).frame(width: 12, height: 12)
                    Text("Missed").font(.caption2).foregroundColor(.secondary)
                }
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
                    Text("Completed").font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                Text("\(checkIns.count) total days")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    StatsView()
}

