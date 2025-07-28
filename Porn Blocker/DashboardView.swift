import SwiftUI

struct DashboardView: View {
    @StateObject private var blocklistManager = BlocklistManager.shared
    @StateObject private var subManager = SubscriptionManager.shared
    @AppStorage("lockProtection") private var lockProtection = false
    @State private var showPaywall = false
    @State private var showExtensionInstructions = false
    @State private var contentBlockerEnabled = true
    @State private var statusCheckTimer: Timer?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Hero Protection Status Card
                protectionStatusCard
                
                // Statistics Cards Grid
                statisticsSection
                
                // Database Status Card
                databaseStatusCard
                
                // Action Button
                actionButton
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Protection Center")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                startStatusMonitoring()
            }
            .onDisappear {
                stopStatusMonitoring()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Check status when app becomes active (user might have changed settings)
                Task {
                    await checkContentBlockerStatus()
                }
            }
            .sheet(isPresented: $showExtensionInstructions) {
                SafariExtensionInstructionsView()
            }
        }
    }
    
    // MARK: - UI Components
    
    private var protectionStatusCard: some View {
        VStack(spacing: 20) {
            // Status Icon and Text
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusGradient)
                        .frame(width: 100, height: 100)
                        .shadow(color: statusColor.opacity(0.3), radius: 20, x: 0, y: 8)
                    
                    Image(systemName: statusIcon)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 8) {
                    Text(statusTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(statusSubtitle)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 20)
                }
            }
            
            // Quick Action (if needed)
            if !subManager.isSubscribed || !contentBlockerEnabled {
                quickActionButton
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    private var statisticsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Protection Statistics")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack(spacing: 12) {
                EnhancedStatisticCard(
                    icon: "globe",
                    title: "Websites",
                    count: blocklistManager.apiBlocklist.count + blocklistManager.customBlocklist.count,
                    subtitle: "Protected Sites",
                    color: .blue
                )
                
                EnhancedStatisticCard(
                    icon: "textformat.abc",
                    title: "Keywords", 
                    count: blocklistManager.totalKeywordCount,
                    subtitle: "Filtered Terms",
                    color: .purple
                )
            }
        }
    }
    
    private var databaseStatusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Database Status")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Protection database is up to date")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Last updated \(blocklistManager.lastUpdated?.formatted(date: .abbreviated, time: .omitted) ?? "today")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }
    
    private var actionButton: some View {
        VStack(spacing: 0) {
            NavigationLink(isActive: $showPaywall) {
                PaywallScreen(isPresented: $showPaywall)
            } label: {
                EmptyView()
            }
            
            Button(action: {
                //if !subManager.isSubscribed {
                        //BUT I THINK THIS SHOULD BE IN THE SHOWPAYWALL VIEW
                        //THIS IS TO ENABLE THE CONTENT BLOCKER ONCE THE USER PAYS
                        //blocklistManager.isEnabled.toggle()
                        
                        // Enable content blocker when protection is activated
//                        if blocklistManager.isEnabled {
//                            Task {
//                                let success = await blocklistManager.enableContentBlocker()
//                                if success {
//                                    contentBlockerEnabled = true
//                                } else {
//                                    showExtensionInstructions = true
//                                }
//                            }
//                        }
                    
                //} else {
                    showPaywall = true
                //}
            }) {
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
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(buttonGradient)
                        .shadow(color: buttonColor.opacity(0.3), radius: 12, x: 0, y: 6)
                )
            }
            .disabled(subManager.isSubscribed)
//            .scaleEffect(subManager.isSubscribed && contentBlockerEnabled ? 0.98 : 1.0)
//            .opacity(subManager.isSubscribed && contentBlockerEnabled ? 0.8 : 1.0)
        }
    }
    
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
                Text(!subManager.isSubscribed ? "Get Protection" : "Click Here To Setup Extension")
                    .font(.body)
                    .fontWeight(.medium)
            }
            .foregroundColor(statusColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(statusColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        if !subManager.isSubscribed {
            return .red
        } else if !contentBlockerEnabled {
            return .orange
        } else {
            return .green
        }
    }
    
    private var statusGradient: LinearGradient {
        LinearGradient(
            colors: [statusColor, statusColor.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var statusIcon: String {
        if !subManager.isSubscribed {
            return "exclamationmark.shield"
        } else if !contentBlockerEnabled {
            return "gear.badge"
        } else {
            return "checkmark.shield.fill"
        }
    }
    
    private var statusTitle: String {
        if !subManager.isSubscribed {
            return "Protection Inactive"
        } else if !contentBlockerEnabled {
            return "Setup Required"
        } else {
            return "Fully Protected"
        }
    }
    
    private var statusSubtitle: String {
        if !subManager.isSubscribed {
            return "Subscribe to activate comprehensive browser protection"
        } else if !contentBlockerEnabled {
            return "Enable Safari extension to complete setup"
        } else {
            return "Your device is protected from inappropriate content"
        }
    }
    
    private var buttonColor: Color {
        if subManager.isSubscribed && !contentBlockerEnabled {
            return .orange
        } else if subManager.isSubscribed {
            return .green
        } else {
            return .red
        }
    }
    
    private var buttonGradient: LinearGradient {
        LinearGradient(
            colors: [buttonColor, buttonColor.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var buttonIcon: String {
        if subManager.isSubscribed && contentBlockerEnabled {
            return "checkmark.circle.fill"
        } else if subManager.isSubscribed && !contentBlockerEnabled {
            return "gear.circle.fill"
        } else {
            return "shield.fill"
        }
    }
    
    private var buttonText: String {
        if subManager.isSubscribed && contentBlockerEnabled {
            return "PROTECTION ACTIVE"
        } else if subManager.isSubscribed && !contentBlockerEnabled {
            return "COMPLETE SETUP"
        } else {
            return "ACTIVATE PROTECTION"
        }
    }
    
    // MARK: - Status Monitoring
    
    private func startStatusMonitoring() {
        // Initial check
        Task {
            await checkContentBlockerStatus()
        }
        
        // Set up timer to check every 5 seconds
        statusCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await checkContentBlockerStatus()
            }
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
                print("Content blocker status changed: \(isEnabled)")
                contentBlockerEnabled = isEnabled
            }
        }
    }
}

// MARK: - Enhanced Statistic Card

struct EnhancedStatisticCard: View {
    let icon: String
    let title: String
    let count: Int
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("\(count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }
}

#Preview {
    DashboardView()
        .environmentObject(BlocklistManager.shared)
        .environmentObject(SubscriptionManager.shared)
}
