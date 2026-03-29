import SwiftUI

struct DashboardView: View {
    @StateObject private var blocklistManager = BlocklistManager.shared
    @StateObject private var subManager = SubscriptionManager.shared
    @StateObject private var habitManager = HabitManager.shared
    @AppStorage("lockProtection") private var lockProtection = false
    @AppStorage("daysInstalledStart") private var daysInstalledStart: Double = Date().timeIntervalSince1970
    @State private var showPaywall = false
    @State private var showExtensionInstructions = false
    @State private var contentBlockerEnabled = true
    @State private var statusCheckTimer: Timer?
    @State private var pulseAnimation = false
    @State private var cardAppear = false
    
    private var daysProtected: Int {
        let start = Date(timeIntervalSince1970: daysInstalledStart)
        return max(1, Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 1)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero Protection Status Card
                    protectionStatusCard
                        .opacity(cardAppear ? 1 : 0)
                        .offset(y: cardAppear ? 0 : 20)
                        .animation(.easeOut(duration: 0.5), value: cardAppear)
                    
                    // Quick Stats Row
                    quickStatsRow
                        .opacity(cardAppear ? 1 : 0)
                        .offset(y: cardAppear ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.1), value: cardAppear)
                    
                    // Database Status Card
                    databaseStatusCard
                        .opacity(cardAppear ? 1 : 0)
                        .offset(y: cardAppear ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: cardAppear)
                    
                    // Action Button
                    actionButton
                        .opacity(cardAppear ? 1 : 0)
                        .offset(y: cardAppear ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.3), value: cardAppear)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Protection Center")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                startStatusMonitoring()
                withAnimation { cardAppear = true }
                // Seed daysInstalledStart only the first time
                if daysInstalledStart == 0 {
                    daysInstalledStart = Date().timeIntervalSince1970
                }
            }
            .onDisappear {
                stopStatusMonitoring()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                Task { await checkContentBlockerStatus() }
            }
            .sheet(isPresented: $showExtensionInstructions) {
                SafariExtensionInstructionsView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
                    // Outer pulse ring
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 2)
                        .frame(width: pulseAnimation ? 130 : 110, height: pulseAnimation ? 130 : 110)
                        .opacity(pulseAnimation ? 0 : 0.6)
                        .animation(
                            subManager.isSubscribed && contentBlockerEnabled
                                ? .easeOut(duration: 2.0).repeatForever(autoreverses: false)
                                : .default,
                            value: pulseAnimation
                        )
                    
                    // Inner circle
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: statusIcon)
                        .font(.system(size: 44, weight: .medium))
                        .foregroundColor(.white)
                }
                .onAppear {
                    if subManager.isSubscribed && contentBlockerEnabled {
                        pulseAnimation = true
                    }
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
            
            // Days Protected
            QuickStatCard(
                value: "\(daysProtected)",
                label: "Days\nProtected",
                icon: "calendar.badge.checkmark",
                color: Color(hue: 0.6, saturation: 0.7, brightness: 0.75)
            )
            
            // Total Sites
            QuickStatCard(
                value: formatCount(blocklistManager.apiBlocklist.count + blocklistManager.customBlocklist.count),
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
            NavigationLink(isActive: $showPaywall) {
                PaywallScreen(isPresented: $showPaywall)
            } label: {
                EmptyView()
            }
            
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
    
    // MARK: - Helpers
    
    private func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
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
                // Trigger pulse when status becomes active
                if isEnabled && subManager.isSubscribed {
                    pulseAnimation = true
                }
            }
        }
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
