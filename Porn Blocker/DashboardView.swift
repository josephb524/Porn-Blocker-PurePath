import SwiftUI

struct DashboardView: View {
    @StateObject private var blocklistManager = BlocklistManager.shared
    @StateObject private var subManager = SubscriptionManager.shared
    @AppStorage("lockProtection") private var lockProtection = false
    @State private var showPaywall = false
    @State private var showExtensionInstructions = false
    @State private var contentBlockerEnabled = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Protection Status
                if !blocklistManager.isEnabled {
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
                    if subManager.isSubscribed {
                        if !lockProtection || !blocklistManager.isEnabled {
                            blocklistManager.isEnabled.toggle()
                            
                            // Enable content blocker when protection is activated
                            if blocklistManager.isEnabled {
                                Task {
                                    let success = await blocklistManager.enableContentBlocker()
                                    if success {
                                        contentBlockerEnabled = true
                                    } else {
                                        showExtensionInstructions = true
                                    }
                                }
                            }
                        }
                    } else {
                        showPaywall = true
                    }
                }) {
                    Text(blocklistManager.isEnabled ? "DEACTIVATE PROTECTION" : "ACTIVATE PROTECTION")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(blocklistManager.isEnabled && lockProtection ? Color.gray.opacity(0.5) : 
(blocklistManager.isEnabled ? Color.gray : Color.red))
                        .cornerRadius(10)
                }
                .disabled(blocklistManager.isEnabled && lockProtection)
                .padding(.top, 30)
                
                if blocklistManager.isEnabled && lockProtection {
                    Text("Protection is locked and cannot be disabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Protection Status")
            .task {
                // Check content blocker status on appear
                contentBlockerEnabled = await blocklistManager.checkContentBlockerStatus()
            }
            .sheet(isPresented: $showExtensionInstructions) {
                SafariExtensionInstructionsView()
            }
        }
    }
} 