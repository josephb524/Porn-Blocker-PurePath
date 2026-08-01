import SwiftUI

// MARK: - Onboarding Flow

/// First-launch onboarding, mounted by `ContentView` while
/// `hasSeenOnboarding` is false. Five button-driven steps; the paywall is the
/// terminal step and its "Later" button is the universal exit. Side effects
/// (seeding the streak start date, enabling the reminder) fire only on
/// explicit CTA taps so Skip and Back are true no-ops.
struct OnboardingView: View {
    private enum OnboardingStep: Int {
        case welcome, howItWorks, startDate, reminder, paywall
    }

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: OnboardingStep = .welcome
    @State private var paywallActive = true
    @State private var showExtensionSetup = false
    @State private var selectedDate = Date()
    @State private var reminderTime =
        Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()

    private let accent = Color(hue: 0.38, saturation: 0.65, brightness: 0.5)

    private var pornFreeHabit: TrackedHabit? {
        HabitManager.shared.habits.first { $0.id == HabitManager.pornFreeID }
    }

    var body: some View {
        ZStack {
            if step == .paywall {
                // The paywall renders full-page and pixel-untouched — its
                // Later/Restore buttons live in a toolbar, so it needs the
                // NavigationStack wrapper (same as the Safe Browser sheet).
                NavigationStack {
                    PaywallScreen(isPresented: $paywallActive)
                }
                .transition(reduceMotion ? .identity : .opacity)
            } else {
                ZStack {
                    OnboardingBackground()
                    pages
                    chrome
                }
                .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .onAppear {
            // Pre-fill from the built-in habit so updaters keep their
            // existing start date / reminder time. Read-only — nothing is
            // written until a CTA is tapped.
            if let habit = pornFreeHabit {
                selectedDate = habit.streakStartDate
                reminderTime = habit.reminderTime
            }
        }
        .onChange(of: paywallActive) { active in
            guard !active else { return }
            // PaywallScreen only flips the binding after `isSubscribed` is
            // already updated on the purchase/restore paths, so branching on
            // it here is race-free. "Later" leaves it false.
            if SubscriptionManager.shared.isSubscribed {
                Log.debug("Onboarding: subscribed on paywall — showing extension setup")
                showExtensionSetup = true
            } else {
                completeOnboarding()
            }
        }
        .sheet(isPresented: $showExtensionSetup, onDismiss: { completeOnboarding() }) {
            SafariExtensionInstructionsView()
        }
    }

    // MARK: - Pages

    @ViewBuilder
    private var pages: some View {
        switch step {
        case .welcome:
            welcomePage.transition(reduceMotion ? .identity : .opacity)
        case .howItWorks:
            howItWorksPage.transition(reduceMotion ? .identity : .opacity)
        case .startDate:
            startDatePage.transition(reduceMotion ? .identity : .opacity)
        case .reminder:
            reminderPage.transition(reduceMotion ? .identity : .opacity)
        case .paywall:
            EmptyView()
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 28) {
            Spacer()

            OnboardingIconBadge(systemName: "checkmark.shield.fill")

            VStack(spacing: 10) {
                Text("Welcome to Porn Blocker")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Take back control. Block adult content in Safari, browse safely, and build a porn-free streak — one day at a time.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            OnboardingCTAButton(title: "Get Started", icon: "arrow.right") {
                advance()
            }
            .padding(.bottom, 40)
        }
    }

    private var howItWorksPage: some View {
        VStack(spacing: 28) {
            Spacer()

            OnboardingIconBadge(systemName: "sparkles")

            VStack(spacing: 10) {
                Text("How It Works")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Four layers of protection and support, working together.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 10) {
                LockedFeaturePill(icon: "globe.badge.chevron.backward", text: "Blocks porn sites in Safari")
                LockedFeaturePill(icon: "safari.fill",                  text: "Built-in Safe Browser")
                LockedFeaturePill(icon: "bubble.left.and.bubble.right.fill", text: "Buddy chat for tough moments")
                LockedFeaturePill(icon: "flame.fill",                   text: "Streak tracking & milestones")
            }
            .padding(.horizontal, 24)

            Spacer()

            OnboardingCTAButton(title: "Continue", icon: "arrow.right") {
                advance()
            }
            .padding(.bottom, 40)
        }
    }

    /// Same semantics as `PornFreeStartDateSheet`: the chosen day counts as
    /// day 1, matching the streak the backfill produces.
    private var dayCount: Int {
        let diff = max(0, Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: selectedDate),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0)
        return diff + 1
    }

    private var startDatePage: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Text("Already on a streak?")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Count the clean days you've already earned. Pick the date you last watched porn.")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 64)

                VStack(spacing: 2) {
                    Text("\(dayCount)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(hue: 0.38, saturation: 0.5, brightness: 0.85)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    Text(dayCount == 1 ? "day porn free" : "days porn free")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.7))
                }

                DatePicker(
                    "I've been clean since",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(accent)
                .colorScheme(.dark)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.07))
                )
                .padding(.horizontal, 24)

                OnboardingCTAButton(title: "Set My Start Date", icon: "calendar.badge.checkmark") {
                    HabitManager.shared.setStartDate(selectedDate, habitID: HabitManager.pornFreeID)
                    Log.debug("Onboarding: seeded start date \(selectedDate)")
                    advance()
                }

                skipButton
                    .padding(.bottom, 32)
            }
        }
    }

    private var reminderPage: some View {
        ScrollView {
            VStack(spacing: 20) {
                OnboardingIconBadge(systemName: "bell.badge.fill")
                    .padding(.top, 64)

                VStack(spacing: 10) {
                    Text("Daily check-in reminder")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Text("A small nudge each day keeps the streak alive. Pick a time that works for you.")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .frame(maxHeight: 180)
                    .clipped()
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.07))
                    )
                    .padding(.horizontal, 24)
                    .accessibilityLabel("Daily reminder time")

                OnboardingCTAButton(title: "Remind Me Daily", icon: "bell.fill") {
                    if var habit = pornFreeHabit {
                        habit.reminderEnabled = true
                        habit.reminderTime = reminderTime
                        // updateHabit saves and schedules; scheduling requests
                        // notification permission itself when undetermined.
                        HabitManager.shared.updateHabit(habit)
                        Log.debug("Onboarding: enabled daily reminder")
                    }
                    advanceToPaywallOrFinish()
                }

                Button("Not Now") {
                    advanceToPaywallOrFinish()
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .padding(.bottom, 32)
            }
        }
    }

    private var skipButton: some View {
        Button("Skip for now") {
            advance()
        }
        .font(.subheadline)
        .foregroundColor(.white.opacity(0.6))
    }

    // MARK: - Chrome (dots + back button, pages 1–4 only)

    private var chrome: some View {
        VStack {
            ZStack {
                OnboardingDots(current: step.rawValue, total: 4, accent: accent)

                HStack {
                    if step != .welcome {
                        Button(action: goBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(10)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Back")
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Flow control

    private func setStep(_ new: OnboardingStep) {
        Log.debug("Onboarding: step -> \(new.rawValue)")
        if reduceMotion {
            step = new
        } else {
            withAnimation(.easeInOut(duration: 0.3)) { step = new }
        }
    }

    private func advance() {
        if let next = OnboardingStep(rawValue: step.rawValue + 1) {
            setStep(next)
        }
    }

    private func goBack() {
        if let previous = OnboardingStep(rawValue: step.rawValue - 1) {
            setStep(previous)
        }
    }

    /// Subscribers never see the paywall page — finish directly.
    private func advanceToPaywallOrFinish() {
        if SubscriptionManager.shared.isSubscribed {
            completeOnboarding()
        } else {
            setStep(.paywall)
        }
    }

    private func completeOnboarding() {
        Log.debug("Onboarding: complete")
        hasSeenOnboarding = true
    }
}

// MARK: - Shared Components
// Visual values copied from the Safe Browser / Buddy locked views so
// onboarding reads as the same design system.

private struct OnboardingBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hue: 0.6, saturation: 0.5, brightness: 0.15),
                    Color(hue: 0.6, saturation: 0.6, brightness: 0.08)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(hue: 0.6, saturation: 0.6, brightness: 0.4).opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -80, y: -120)

            Circle()
                .fill(Color(hue: 0.38, saturation: 0.6, brightness: 0.4).opacity(0.12))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: 100, y: 200)
        }
    }
}

private struct OnboardingIconBadge: View {
    let systemName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 110, height: 110)
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 80, height: 80)
            Image(systemName: systemName)
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(hue: 0.6, saturation: 0.3, brightness: 0.9)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        }
    }
}

private struct OnboardingCTAButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .fontWeight(.bold)
                Image(systemName: icon)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [
                        Color(hue: 0.6, saturation: 0.7, brightness: 0.75),
                        Color(hue: 0.38, saturation: 0.65, brightness: 0.5)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .cornerRadius(18)
            .shadow(
                color: Color(hue: 0.6, saturation: 0.5, brightness: 0.5).opacity(0.4),
                radius: 14, x: 0, y: 6
            )
        }
        .padding(.horizontal, 24)
    }
}

private struct OnboardingDots: View {
    let current: Int
    let total: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index == current
                          ? Color(hue: 0.38, saturation: 0.65, brightness: 0.6)
                          : Color.white.opacity(0.25))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(total)")
    }
}

#Preview {
    OnboardingView()
}
