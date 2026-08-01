import SwiftUI

struct SettingsView: View {
    @StateObject private var blocklistManager = BlocklistManager.shared
    @StateObject private var subManager = SubscriptionManager.shared
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @State private var showSubmitSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                
                Section(header: Text("Appearance")) {
                    Picker("Appearance", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Match your device's setting, or pick light or dark.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                
                Section {
                    NavigationLink(destination: BlockerSettingsView()) {
                        SettingsRow(icon: "gear", title: "Blocker Settings")
                    }
                }
                
                Section(header: Text("Feedback")) {
                    Button {
                        RatingRequestManager.shared.promptForReviewDirectly()
                    } label: {
                        SettingsRow(icon: "star.fill", title: "Rate the App")
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                
                Section {
                    //DO NOT DELETE THESE NAVIGATION LINKS
                    // Submit / FAQ / Contact stay hidden until a real support
                    // mailbox exists — ContactView routes to an unowned address.
//                    Button(action: { showSubmitSheet = true }) {
//                        SettingsRow(icon: "magnifyingglass", title: "Submit keyword & website")
//                    }
//
//                    NavigationLink(destination: FAQView()) {
//                        SettingsRow(icon: "questionmark.circle", title: "FAQ")
//                    }
//
//                    NavigationLink(destination: ContactView()) {
//                        SettingsRow(icon: "phone", title: "Contact us")
//                    }

                    Button(action: { shareApp() }) {
                        SettingsRow(icon: "square.and.arrow.up", title: "Share this app")
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: PrivacyPolicyView()) {
                        SettingsRow(icon: "lock", title: "Privacy policy")
                    }

                    NavigationLink(destination: TermsView()) {
                        SettingsRow(icon: "doc.text", title: "Terms of use")
                    }
                }

                Section(header: Text("Subscription")) {
                    if subManager.isSubscribed {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Subscription Active")
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                            if let expiryDate = subManager.expiryDate {
                                Text("Renews: \(expiryDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Visible to non-subscribers too — that's who needs it
                    // after a reinstall or a new device.
                    Button("Restore Purchases") {
                        Task { await subManager.restore() }
                    }
                    .disabled(subManager.isLoading)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showSubmitSheet) {
                SubmitView()
            }
        }
    }
    
    private func shareApp() {
        var items: [Any] = ["Check out this great app for blocking adult content!"]
        if let storeURL = URL(string: "https://apps.apple.com/app/id6749251520") {
            items.append(storeURL)
        }
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
} 

#Preview {
    SettingsView()
}
