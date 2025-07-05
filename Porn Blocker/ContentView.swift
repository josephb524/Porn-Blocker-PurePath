//
//  ContentView.swift
//  Porn Blocker
//
//  Created by Jose Pimentel on 6/5/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "shield.fill")
                    Text("Protection")
                }
                .tag(0)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(1)
        }
    }
}

struct DashboardView: View {
    @StateObject private var blocklistManager = BlocklistManager.shared
    @StateObject private var subManager = SubscriptionManager.shared
    @AppStorage("lockProtection") private var lockProtection = false
    @State private var showPaywall = false
    @State private var showExtensionInstructions = false
    @State private var contentBlockerEnabled = false
    
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
                        .background(blocklistManager.isEnabled && lockProtection ? Color.gray.opacity(0.5) : (blocklistManager.isEnabled ? Color.gray : Color.red))
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

struct SafariExtensionInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Enable Safari Extension")
                        .font(.title)
                        .bold()
                    
                    Text("To start blocking websites, you need to enable the Porn Blocker extension in Safari:")
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        InstructionStep(
                            number: "1",
                            title: "Open Safari Settings",
                            description: "Go to Safari app → Settings → Extensions"
                        )
                        
                        InstructionStep(
                            number: "2",
                            title: "Find Porn Blocker",
                            description: "Look for 'Porn Blocker' in the list of extensions"
                        )
                        
                        InstructionStep(
                            number: "3",
                            title: "Enable Extension",
                            description: "Toggle ON the Porn Blocker extension"
                        )
                        
                        InstructionStep(
                            number: "4",
                            title: "Grant Permissions",
                            description: "Allow the extension to access all websites"
                        )
                    }
                    
                    Text("Once enabled, the extension will automatically block adult content websites and keywords while you browse.")
                        .foregroundColor(.secondary)
                        .padding(.top)
                    
                    Button("Open Safari Settings") {
                        if let url = URL(string: "App-prefs:SAFARI") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(.top)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Setup Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InstructionStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct StatisticCard: View {
    let title: String
    let count: Int
    let subtitle: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
            Text("\(count)")
                .font(.title)
                .bold()
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

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

struct SettingsRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.primary)
                .frame(width: 24, height: 24)
            Text(title)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct BlockerSettingsView: View {
    @StateObject private var blocklistManager = BlocklistManager.shared
    @State private var showKeywordEditor = false
    @State private var showWebsiteEditor = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Custom Keywords Section
            VStack(spacing: 16) {
                HStack {
                    Text("Custom Keywords")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                    Spacer()
                    Button("Edit") {
                        showKeywordEditor = true
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(12)
                
                HStack {
                    Text("Total: \(blocklistManager.keywordBlocklist.count)")
                        .foregroundColor(.white)
                    Spacer()
                    Toggle("", isOn: .constant(true))
                }
                .padding(.horizontal)
                
                Text("You can specify a keyword and the domains including this keyword will be blocked")
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            
            // Custom Websites Section
            VStack(spacing: 16) {
                HStack {
                    Text("Custom Websites")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                    Spacer()
                    Button("Edit") {
                        showWebsiteEditor = true
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(12)
                
                HStack {
                    Text("Total: \(blocklistManager.customBlocklist.count)")
                        .foregroundColor(.white)
                    Spacer()
                    Toggle("", isOn: .constant(true))
                }
                .padding(.horizontal)
                
                Text("You can create your own url list for blocking")
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .navigationTitle("Extension Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showKeywordEditor) {
            KeywordEditorView()
        }
        .sheet(isPresented: $showWebsiteEditor) {
            WebsiteEditorView()
        }
    }
}

struct SubmitView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Blacklist Section
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                        Text("Blacklist")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Text("Submit keywords and website that you want to Blacklist (which you feel are not blocked but should be). We will review these and once approved, you will be able to browse them online without any interference.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                // Whitelist Section
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                        Text("Whitelist")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Text("Submit the keywords and website that you want to whitelist (which you feel is blocked accidentally or unintentionally). We will review these and once approved, you will be able to browse them online without any interference.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .navigationTitle("Submit keywords & websites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct KeywordEditorView: View {
    @StateObject private var blocklistManager = BlocklistManager.shared
    @State private var newKeyword = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Enter keyword", text: $newKeyword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Add") {
                        if !newKeyword.isEmpty {
                            blocklistManager.addToKeywordBlocklist(newKeyword)
                            newKeyword = ""
                        }
                    }
                }
                .padding()
                
                List {
                    ForEach(blocklistManager.keywordBlocklist, id: \.self) { keyword in
                        Text(keyword)
                    }
                    .onDelete(perform: deleteKeywords)
                }
            }
            .navigationTitle("Custom Keywords")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func deleteKeywords(offsets: IndexSet) {
        for index in offsets {
            let keyword = blocklistManager.keywordBlocklist[index]
            blocklistManager.removeFromKeywordBlocklist(keyword)
        }
    }
}

struct WebsiteEditorView: View {
    @StateObject private var blocklistManager = BlocklistManager.shared
    @State private var newWebsite = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Enter website URL", text: $newWebsite)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Add") {
                        if !newWebsite.isEmpty {
                            blocklistManager.addToCustomBlocklist(newWebsite)
                            newWebsite = ""
                        }
                    }
                }
                .padding()
                
                List {
                    ForEach(blocklistManager.customBlocklist, id: \.self) { website in
                        Text(website)
                    }
                    .onDelete(perform: deleteWebsites)
                }
            }
            .navigationTitle("Custom Websites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func deleteWebsites(offsets: IndexSet) {
        for index in offsets {
            let website = blocklistManager.customBlocklist[index]
            blocklistManager.removeFromCustomBlocklist(website)
        }
    }
}

struct FAQView: View {
    var body: some View {
        List {
            Text("Frequently Asked Questions")
                .font(.title2)
                .bold()
            
            Text("How does the app work?")
                .font(.headline)
            Text("The app uses Safari's content blocking feature to block adult content websites.")
            
            Text("Can I customize the blocklist?")
                .font(.headline)
            Text("Yes, you can add custom keywords and websites to block, as well as whitelist trusted sites.")
        }
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ContactView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Contact Us")
                .font(.title)
                .bold()
            
            Text("If you have any questions or need support, please contact us:")
            
            Button("Email Support") {
                if let url = URL(string: "mailto:support@pornblocker.com") {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Contact")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text("Privacy Policy")
                .font(.title)
                .bold()
                .padding()
            
            Text("Your privacy is important to us. This app does not collect any personal information...")
                .padding()
            
            Spacer()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TermsView: View {
    var body: some View {
        ScrollView {
            Text("Terms of Use")
                .font(.title)
                .bold()
                .padding()
            
            Text("By using this app, you agree to the following terms...")
                .padding()
            
            Spacer()
        }
        .navigationTitle("Terms of Use")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PaywallScreen: View {
    @StateObject private var subManager = SubscriptionManager.shared
    @Binding var isPresented: Bool
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Get the unlimited access in the app")
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(icon: "globe", text: "Block millions of porn sites in safari")
                FeatureRow(icon: "shield", text: "Safe web surfing")
                FeatureRow(icon: "gear", text: "Database customization")
            }
            .padding(.vertical)
            
            Text("$69.99/year")
                .font(.title3)
            
            Button(action: {
                isPurchasing = true
                Task {
                    do {
                        try await subManager.purchase()
                        if subManager.isSubscribed {
                            isPresented = false
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    isPurchasing = false
                }
            }) {
                Text(isPurchasing ? "Processing..." : "START NOW")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
            }
            .disabled(isPurchasing)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            
            Text("Payment will be charged to iTunes Account at confirmation of purchase. Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top)
            
            HStack {
                Button("Privacy Policy") {
                    // Navigate to privacy policy
                }
                Spacer()
                Button("Terms of use") {
                    // Navigate to terms
                }
            }
            .font(.caption)
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Later") {
                    isPresented = false
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Restore") {
                    Task { 
                        await subManager.restore()
                        if subManager.isSubscribed {
                            isPresented = false
                        }
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
            Text(text)
                .font(.body)
        }
    }
}
