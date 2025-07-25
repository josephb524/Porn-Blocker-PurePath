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
                // Protection Status
                if !subManager.isSubscribed {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        
                        Text("Browser protection not activated")
                            .font(.title2)
                            .bold()
                        
                        Text("We recommend urgently enable browser protection")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 30)
                } else if !contentBlockerEnabled {
                    VStack(spacing: 16) {
                        Image(systemName: "gear.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Safari Extension Setup Required")
                            .font(.title2)
                            .bold()
                        
                        Text("Enable the Safari extension to start blocking")
                            .foregroundColor(.secondary)
                        
                        Button("Show Instructions") {
                            showExtensionInstructions = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 30)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("Browser protection activated")
                            .font(.title2)
                            .bold()
                        
                        Text("Your device is now protected from inappropriate content")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 30)
                }
                
                // Statistics
                HStack(spacing: 20) {
                    StatisticCard(
                        title: "Websites",
                        count: blocklistManager.apiBlocklist.count + blocklistManager.customBlocklist.count,
                        subtitle: "Selected Websites"
                    )
                    
                    StatisticCard(
                        title: "Keywords",
                        count: blocklistManager.totalKeywordCount,
                        subtitle: "Selected Keywords"
                    )
                }
                
                Text("Blocked site database is relevant")
                    .foregroundColor(.secondary)
                Text("Last update \(blocklistManager.lastUpdated?.formatted() ?? "today")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
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
//                            if blocklistManager.isEnabled {
//                                Task {
//                                    let success = await blocklistManager.enableContentBlocker()
//                                    if success {
//                                        contentBlockerEnabled = true
//                                    } else {
//                                        showExtensionInstructions = true
//                                    }
//                                }
//                            }
                        
                    //} else {
                        showPaywall = true
                    //}
                }) {
                    Text(
                        subManager.isSubscribed
                        ? (contentBlockerEnabled
                           ? "PROTECTION ACTIVATED"
                           : "SAFARI EXTENSION REQUIRED")
                        : "ACTIVATE PROTECTION"
                    )
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(subManager.isSubscribed && !contentBlockerEnabled ? Color.yellow :
                                        (subManager.isSubscribed ? Color.green : Color.red))
                        .cornerRadius(10)
                }
                .disabled(subManager.isSubscribed)
                .padding(.top, 30)
                
//                if blocklistManager.isEnabled && lockProtection {
//                    Text("Protection is locked and cannot be disabled")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Protection Status")
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

#Preview {
    DashboardView()
        .environmentObject(BlocklistManager.shared)
        .environmentObject(SubscriptionManager.shared)
}
