import SwiftUI

struct BlockerSettingsView: View {
    @StateObject private var blocklistManager = BlocklistManager.shared
    @StateObject private var subManager = SubscriptionManager.shared
    @State private var showKeywordEditor = false
    @State private var showWebsiteEditor = false
    @State private var showWhitelistEditor = false
    @State private var keywordsEnabled = true
    @State private var websitesEnabled = true    
    var body: some View {
        List {
            // MARK: Built-in Protection
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "shield.checkered")
                            .foregroundColor(.green)
                            .font(.body)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Core Block List")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("\(blocklistManager.apiBlocklist.count + blocklistManager.customBlocklist.count) domains • Always active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "textformat.abc")
                            .foregroundColor(.purple)
                            .font(.body)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Built-in Keywords")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("\(blocklistManager.predefinedKeywords.count) keywords • Always active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Built-in Protection")
            } footer: {
                Text("Core protection is always active and cannot be disabled.")
            }
            
            // MARK: Custom Keywords
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Custom Keywords")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("\(blocklistManager.keywordBlocklist.count) keywords added")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $keywordsEnabled)
                }
                
                Button(action: { showKeywordEditor = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Manage Keywords")
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !blocklistManager.keywordBlocklist.isEmpty {
                    ForEach(blocklistManager.keywordBlocklist.prefix(3), id: \.self) { kw in
                        Label(kw, systemImage: "tag")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if blocklistManager.keywordBlocklist.count > 3 {
                        Text("+ \(blocklistManager.keywordBlocklist.count - 3) more…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Custom Keywords")
            } footer: {
                Text("URLs containing these keywords will be blocked in Safari.")
            }
            
            // MARK: Custom Websites
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Custom Websites")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("\(blocklistManager.customBlocklist.count) sites added")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $websitesEnabled)
                }
                
                Button(action: { showWebsiteEditor = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Manage Custom Sites")
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !blocklistManager.customBlocklist.isEmpty {
                    ForEach(blocklistManager.customBlocklist.prefix(3), id: \.self) { site in
                        Label(site, systemImage: "globe")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if blocklistManager.customBlocklist.count > 3 {
                        Text("+ \(blocklistManager.customBlocklist.count - 3) more…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Custom Websites")
            } footer: {
                Text("Block any website by adding its domain here.")
            }
            
            // MARK: CSS Visual Filtering
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "eye.slash.fill")
                            .foregroundColor(.blue)
                            .font(.body)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CSS Visual Filtering")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Hides images & videos on matched pages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.body)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Visual Blocking")
            } footer: {
                Text("Even if a page partially loads, all images and videos are hidden using Safari's CSS injection. This works alongside URL blocking for double protection.")
            }
            
            // MARK: Strict Image Mode
            Section {
                if subManager.isSubscribed {
                    Toggle(isOn: $blocklistManager.strictImageMode) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Strict Image Mode")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Hides ALL images on suspicious URL patterns")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Strict Image Mode")
                                .font(.body)
                                .foregroundColor(.secondary)
                            Text("Subscribe to enable aggressive image hiding")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                HStack {
                    Text("Strict Mode")
                    if !subManager.isSubscribed {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
            } footer: {
                Text("Strict mode casts a wider net — hiding images on pages with suspicious URL patterns like /cam, /babes, /fetish even if the domain isn't explicitly blocked.")
            }
            
            // MARK: Whitelist (subscribers only)
            Section {
                if subManager.isSubscribed {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Allowed Sites")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("\(blocklistManager.whitelist.count) sites allowed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    Button(action: { showWhitelistEditor = true }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Manage Allowed Sites")
                                .foregroundColor(.blue)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Allowed Sites")
                                .font(.body)
                                .foregroundColor(.secondary)
                            Text("Subscribe to whitelist specific sites")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                HStack {
                    Text("Allowed Sites (Whitelist)")
                    if !subManager.isSubscribed {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
            } footer: {
                if subManager.isSubscribed {
                    Text("Sites here are never blocked, even if they match a keyword.")
                } else {
                    Text("Premium feature — whitelist sites you want to always allow.")
                }
            }
        }
        .navigationTitle("Blocker Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showKeywordEditor) { KeywordEditorView() }
        .sheet(isPresented: $showWebsiteEditor) { WebsiteEditorView() }
        .sheet(isPresented: $showWhitelistEditor) { WhitelistEditorView() }
        .onChange(of: keywordsEnabled) { _ in blocklistManager.updateContentBlocker() }
        .onChange(of: websitesEnabled) { _ in blocklistManager.updateContentBlocker() }
    }
}

#Preview {
    NavigationView { BlockerSettingsView() }
}
