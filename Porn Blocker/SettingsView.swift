import SwiftUI

struct SettingsView: View {
    @StateObject private var blocklistManager = BlocklistManager.shared
    @StateObject private var subManager = SubscriptionManager.shared
    @AppStorage("lockProtection") private var lockProtection = false
    @State private var showSubmitSheet = false
    
    var body: some View {
        NavigationView {
            List {
                if subManager.isSubscribed {
                    Section(header: Text("Protection Settings")) {
                        Toggle("Lock Protection When Active", isOn: $lockProtection)
                        
                        if lockProtection {
                            Text("When enabled, protection cannot be turned off until subscription expires")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    NavigationLink(destination: BlockerSettingsView()) {
                        SettingsRow(icon: "gear", title: "Blocker Settings")
                    }
                    
                    Button(action: { showSubmitSheet = true }) {
                        SettingsRow(icon: "magnifyingglass", title: "Submit keyword & website")
                    }
                    
                    NavigationLink(destination: FAQView()) {
                        SettingsRow(icon: "questionmark.circle", title: "FAQ")
                    }
                    
                    NavigationLink(destination: ContactView()) {
                        SettingsRow(icon: "phone", title: "Contact us")
                    }
                    
                    Button(action: { shareApp() }) {
                        SettingsRow(icon: "square.and.arrow.up", title: "Share this app")
                    }
                    
                    NavigationLink(destination: PrivacyPolicyView()) {
                        SettingsRow(icon: "lock", title: "Privacy policy")
                    }
                    
                    NavigationLink(destination: TermsView()) {
                        SettingsRow(icon: "doc.text", title: "Terms of use")
                    }
                }
                
                
                
                if subManager.isSubscribed {
                    Section(header: Text("Subscription")) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Subscription Active")
                                .foregroundColor(.green)
                            if let expiryDate = subManager.expiryDate {
                                Text("Renews: \(expiryDate.formatted())")
                                    .font(.caption)
                            } else {
                                Text("Renewal date unknown")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showSubmitSheet) {
                SubmitView()
            }
        }
    }
    
    private func shareApp() {
        let activityVC = UIActivityViewController(
            activityItems: ["Check out this great app for blocking adult content!"],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
} 