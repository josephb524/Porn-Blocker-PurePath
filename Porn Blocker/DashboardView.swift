import SwiftUI

struct DashboardView: View {
    @StateObject private var blocklistManager = BlocklistManager.shared
    @StateObject private var subManager = SubscriptionManager.shared
    @StateObject private var habitManager = HabitManager.shared
    @AppStorage("lockProtection") private var lockProtection = false
    /// Legacy anchor (Unix timestamp of the first moment full protection became
    /// active). Kept only for one-time migration into the accumulator below; set
    /// to `0` once migrated. See `reconcileProtectionAccrual()`.
    @AppStorage("protectionEnabledStart") private var protectionEnabledStart: Double = 0
    /// Banked protected time (seconds) from past active stretches. Full protection
    /// means subscribed **and** the Safari content blocker enabled — the same pair
    /// that turns the status card green.
    @AppStorage("protectedSecondsBanked") private var protectedSecondsBanked: Double = 0
    /// Unix timestamp the current active stretch began, or `0` while protection is
    /// off. The count pauses (no live stretch) when off and resumes from the bank
    /// when protection comes back.
    @AppStorage("protectionStretchStart") private var protectionStretchStart: Double = 0
    @State private var showPaywall = false
    @State private var showExtensionInstructions = false
    @State private var contentBlockerEnabled = true
    @State private var statusCheckTimer: Timer?

    /// Cumulative whole days protection has actually been active — banked time plus
    /// any live stretch in progress. Pauses while protection is off.
    private var daysProtected: Int {
        var total = protectedSecondsBanked
        if protectionStretchStart > 0 {
            total += Date().timeIntervalSince1970 - protectionStretchStart
        }
        return max(0, Int(total / 86_400))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    protectionStatusCard
                    quickStatsRow
                    databaseStatusCard
                    actionButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Protection Center")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                startStatusMonitoring()
            }
            .onDisappear {
                stopStatusMonitoring()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                Task { await checkContentBlockerStatus() }
            }
            .onChange(of: subManager.isSubscribed) { _ in
                // Subscription lapsing/renewing flips protection on or off just like
                // toggling the extension — bank or resume the accumulator accordingly.
                reconcileProtectionAccrual()
            }
            .sheet(isPresented: $showExtensionInstructions) {
                SafariExtensionInstructionsView()
            }
        }
    }
    
    // MARK: - Protection Status Hero Card
    
    private var protectionStatusCard: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: subManager.isSubscribed && contentBlockerEnabled
                            ? [Color(hue: 0.38, saturation: 0.65, brightness: 0.45), Color(hue: 0.42, saturation: 0.7, brightness: 0.35)]
                            : [Color.red, Color(white: 0.25)], // Reverting to previous red logic
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: statusColor.opacity(0.4), radius: 20, x: 0, y: 8)
            
            VStack(spacing: 18) {
                // Animated Shield
                ZStack {
                    // Outer pulse ring — only mounted (and only ticking) when fully protected.
                    // TimelineView drives it from wall-clock time so it can't get "stuck" on tab
                    // switches the way a state-driven .repeatForever animation can.
                    if subManager.isSubscribed && contentBlockerEnabled {
                        TimelineView(.animation) { context in
                            let phase = pulsePhase(at: context.date)
                            // Keep the layout footprint fixed at the pulse's max
                            // diameter and drive the growth via `.scaleEffect`,
                            // which is visual-only — otherwise the parent card
                            // would expand and contract along with the ring.
                            Circle()
                                .stroke(Color.white.opacity(0.6 * (1 - phase)), lineWidth: 2)
                                .frame(width: 140, height: 140)
                                .scaleEffect((110 + 30 * phase) / 140)
                        }
                    }

                    // Inner circle
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: statusIcon)
                        .font(.system(size: 44, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 6) {
                    Text(statusTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(statusSubtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 12)
                }
                
                // Quick Action (if needed)
                if !subManager.isSubscribed || !contentBlockerEnabled {
                    quickActionButton
                }
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Quick Stats Row
    
    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            // Porn Free Streak (from HabitManager)
            let pornFreeStreak = habitManager.habits
                .first(where: { $0.id == HabitManager.pornFreeID })?.currentStreak ?? 0
            QuickStatCard(
                value: "\(pornFreeStreak)",
                label: "Porn Free\nStreak",
                icon: "heart.fill",
                color: Color(hue: 0.38, saturation: 0.65, brightness: 0.5)
            )

            // Days Protected — counted from the first moment subscription + Safari
            // blocker were both active. Stays at 0 until that's true at least once.
            QuickStatCard(
                value: "\(daysProtected)",
                label: "Days\nProtected",
                icon: "calendar.badge.checkmark",
                color: Color(hue: 0.6, saturation: 0.7, brightness: 0.75)
            )

            // Total sites in the protection database (StevenBlack list + user additions),
            // scaled ×10 for display.
            QuickStatCard(
                value: formatCount((blocklistManager.apiBlocklist.count + blocklistManager.customBlocklist.count) * 10),
                label: "Sites\nBlocked",
                icon: "globe.badge.chevron.backward",
                color: Color(hue: 0.08, saturation: 0.8, brightness: 0.85)
            )
        }
    }
    
    // MARK: - Database Status Card
    
    private var databaseStatusCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Protection Database")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("Up to date • \(blocklistManager.totalKeywordCount) keywords active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let last = blocklistManager.lastUpdated {
                        Text("Updated \(last.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if blocklistManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.85)
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }
    
    // MARK: - Action Button
    
    private var actionButton: some View {
        VStack(spacing: 0) {
            Button(action: { showPaywall = true }) {
                HStack(spacing: 12) {
                    Image(systemName: buttonIcon)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(buttonText)
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(buttonGradient)
                        .shadow(color: buttonColor.opacity(0.35), radius: 14, x: 0, y: 6)
                )
            }
            .disabled(subManager.isSubscribed)
        }
        .navigationDestination(isPresented: $showPaywall) {
            PaywallScreen(isPresented: $showPaywall)
        }
    }
    
    // MARK: - Quick Action Button
    
    private var quickActionButton: some View {
        Button(action: {
            if !subManager.isSubscribed {
                showPaywall = true
            } else {
                showExtensionInstructions = true
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: !subManager.isSubscribed ? "plus.circle.fill" : "gear.circle.fill")
                    .font(.body)
                Text(!subManager.isSubscribed ? "Get Protection" : "Setup Extension")
                    .font(.body)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        if !subManager.isSubscribed { return .red }
        if !contentBlockerEnabled    { return .orange }
        return Color(hue: 0.38, saturation: 0.65, brightness: 0.5)
    }
    
    private var statusIcon: String {
        if !subManager.isSubscribed  { return "exclamationmark.shield.fill" }
        if !contentBlockerEnabled    { return "gear.badge" }
        return "checkmark.shield.fill"
    }
    
    private var statusTitle: String {
        if !subManager.isSubscribed  { return "Protection Inactive" }
        if !contentBlockerEnabled    { return "Setup Required" }
        return "Fully Protected"
    }
    
    private var statusSubtitle: String {
        if !subManager.isSubscribed  { return "Subscribe to activate comprehensive browser protection" }
        if !contentBlockerEnabled    { return "Enable Safari extension to complete setup" }
        return "Your browser is shielded from inappropriate content"
    }
    
    private var buttonColor: Color {
        if subManager.isSubscribed && contentBlockerEnabled { return Color(hue: 0.38, saturation: 0.65, brightness: 0.5) }
        if subManager.isSubscribed                          { return .orange }
        return .red
    }
    
    private var buttonGradient: LinearGradient {
        LinearGradient(
            colors: [buttonColor, buttonColor.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var buttonIcon: String {
        if subManager.isSubscribed && contentBlockerEnabled { return "checkmark.circle.fill" }
        if subManager.isSubscribed                          { return "gear.circle.fill" }
        return "shield.fill"
    }
    
    private var buttonText: String {
        if subManager.isSubscribed && contentBlockerEnabled { return "PROTECTION ACTIVE" }
        if subManager.isSubscribed                          { return "COMPLETE SETUP" }
        return "ACTIVATE PROTECTION"
    }
    
    // MARK: - Status Monitoring
    
    private func startStatusMonitoring() {
        Task { await checkContentBlockerStatus() }
        statusCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { await checkContentBlockerStatus() }
        }
    }
    
    private func stopStatusMonitoring() {
        statusCheckTimer?.invalidate()
        statusCheckTimer = nil
    }
    
    private func checkContentBlockerStatus() async {
        let isEnabled = await blocklistManager.checkContentBlockerStatus()
        await MainActor.run {
            if contentBlockerEnabled != isEnabled {
                contentBlockerEnabled = isEnabled
            }
            reconcileProtectionAccrual()
        }
    }

    /// Keeps the "Days Protected" accumulator in sync with the live protection
    /// state. Starts a stretch when protection becomes fully active (subscribed +
    /// blocker enabled), and banks the elapsed time when it stops — so the count
    /// pauses while off and resumes from where it left off.
    private func reconcileProtectionAccrual() {
        let now = Date().timeIntervalSince1970
        let active = subManager.isSubscribed && contentBlockerEnabled
        migrateLegacyAnchorIfNeeded(active: active, now: now)
        if active {
            if protectionStretchStart == 0 {
                protectionStretchStart = now
            }
        } else if protectionStretchStart > 0 {
            protectedSecondsBanked += max(0, now - protectionStretchStart)
            protectionStretchStart = 0
        }
    }

    /// One-time migration from the old single `protectionEnabledStart` anchor to the
    /// banked/stretch model, preserving whatever count the user already saw. Runs at
    /// most once — the legacy key is zeroed after.
    private func migrateLegacyAnchorIfNeeded(active: Bool, now: Double) {
        guard protectionEnabledStart > 0 else { return }
        let legacy = protectionEnabledStart
        protectionEnabledStart = 0
        if active {
            // Still protected — keep counting live from the original anchor.
            if protectionStretchStart == 0 { protectionStretchStart = legacy }
        } else {
            // Not protected now — bank the time the old code would have shown.
            protectedSecondsBanked += max(0, now - legacy)
        }
    }

    // MARK: - Helpers

    private func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
    }

    // MARK: - Pulse Animation

    /// 0…1 phase that loops every 2 seconds, driven by wall-clock time so the
    /// pulse can't desync or stall on tab switches.
    private func pulsePhase(at date: Date) -> CGFloat {
        let duration: TimeInterval = 2.0
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration)
        return CGFloat(t / duration)
    }
}

// MARK: - Quick Stat Card

struct QuickStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }
}

#Preview {
    DashboardView()
        .environmentObject(BlocklistManager.shared)
        .environmentObject(SubscriptionManager.shared)
}
