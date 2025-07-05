import Foundation
import SwiftUI
import SafariServices

@MainActor
class BlocklistManager: ObservableObject {
    static let shared = BlocklistManager()
    
    @Published var apiBlocklist: [String] = []
    @Published var customBlocklist: [String] = []
    @Published var keywordBlocklist: [String] = []
    @Published var predefinedKeywords: [String] = []
    @Published var whitelist: [String] = []
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    @Published var isEnabled: Bool {
        didSet {
            userDefaults.set(isEnabled, forKey: "isEnabled")
            if isEnabled {
                updateContentBlocker()
                updateSafariExtension()
            } else {
                clearSafariExtensionRules()
            }
        }
    }
    
    private let userDefaults = UserDefaults.standard
    private let stevenBlackHostsURL = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn/hosts"
    private let updateInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    
    // Local storage paths
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var apiBlocklistURL: URL {
        documentsDirectory.appendingPathComponent("apiBlocklist.json")
    }
    
    init() {
        self.isEnabled = userDefaults.bool(forKey: "isEnabled")
        loadPredefinedKeywords()
        loadLocalData()
        loadCachedAPIBlocklist()
        
        // Only download if we need to update
        if shouldDownloadAPIBlocklist() {
            print("Need to download/update API blocklist")
            Task {
                await fetchBlocklistFromAPI()
            }
        } else {
            print("Using cached API blocklist with \(apiBlocklist.count) domains")
            // Make sure content blocker is updated with cached data
            if SubscriptionManager.shared.isSubscribed {
                updateContentBlocker()
            }
        }
    }
    
    // MARK: - Predefined Keywords Loading
    
    private func loadPredefinedKeywords() {
        guard let path = Bundle.main.path(forResource: "keywordsList", ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let keywordRules = try? JSONDecoder().decode([ContentBlockerRule].self, from: data) else {
            print("Failed to load predefined keywords")
            return
        }
        
        // Extract keywords from the URL filters
        predefinedKeywords = keywordRules.compactMap { rule in
            let urlFilter = rule.trigger.urlFilter
            // Extract keyword from patterns like ".*porn.*" -> "porn"
            if urlFilter.hasPrefix(".*") && urlFilter.hasSuffix(".*") {
                let keyword = String(urlFilter.dropFirst(2).dropLast(2))
                return keyword
            }
            return nil
        }
        
        print("Loaded \(predefinedKeywords.count) predefined keywords: \(predefinedKeywords.prefix(10))")
    }
    
    // MARK: - Computed Properties
    
    var allKeywords: [String] {
        return predefinedKeywords + keywordBlocklist
    }
    
    var totalKeywordCount: Int {
        return allKeywords.count
    }
    
    // MARK: - Local Storage Management
    
    private func shouldDownloadAPIBlocklist() -> Bool {
        // Check if we have cached data
        if apiBlocklist.isEmpty {
            print("No cached API blocklist found")
            return true
        }
        
        // Check if it's time to update (daily)
        guard let lastUpdate = userDefaults.object(forKey: "apiBlocklistLastUpdate") as? Date else {
            print("No last update date found")
            return true
        }
        
        let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
        let needsUpdate = timeSinceLastUpdate >= updateInterval
        
        if needsUpdate {
            print("API blocklist needs update (last updated: \(lastUpdate))")
        }
        
        return needsUpdate
    }
    
    private func loadCachedAPIBlocklist() {
        do {
            let data = try Data(contentsOf: apiBlocklistURL)
            apiBlocklist = try JSONDecoder().decode([String].self, from: data)
            print("Loaded \(apiBlocklist.count) domains from cache")
        } catch {
            print("Failed to load cached API blocklist: \(error)")
            apiBlocklist = []
        }
    }
    
    private func saveCachedAPIBlocklist() {
        do {
            let data = try JSONEncoder().encode(apiBlocklist)
            try data.write(to: apiBlocklistURL)
            userDefaults.set(Date(), forKey: "apiBlocklistLastUpdate")
            print("Saved \(apiBlocklist.count) domains to cache")
        } catch {
            print("Failed to save API blocklist to cache: \(error)")
        }
    }
    
    // MARK: - API Integration
    
    func checkAndUpdateBlocklist() {
        if shouldDownloadAPIBlocklist() {
            Task {
                await fetchBlocklistFromAPI()
            }
        }
    }
    
    func fetchBlocklistFromAPI() async {
        print("Starting to fetch blocklist from API...")
        isLoading = true
        
        do {
            guard let url = URL(string: stevenBlackHostsURL) else { 
                print("Invalid URL")
                isLoading = false
                return 
            }
            
            print("Downloading from: \(stevenBlackHostsURL)")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status: \(httpResponse.statusCode)")
                guard httpResponse.statusCode == 200 else {
                    print("HTTP error: \(httpResponse.statusCode)")
                    isLoading = false
                    return
                }
            }
            
            guard let hostsContent = String(data: data, encoding: .utf8) else {
                print("Failed to decode data as UTF-8")
                isLoading = false
                return
            }
            
            print("Downloaded content length: \(hostsContent.count) characters")
            
            // Parse the hosts file
            let domains = parseHostsFile(hostsContent)
            print("Parsed \(domains.count) domains")
            
            // Only update if we got a reasonable number of domains
            guard domains.count > 100000 else {
                print("Warning: Only got \(domains.count) domains, expected ~305k. Not updating cache.")
                isLoading = false
                return
            }
            
            apiBlocklist = domains
            lastUpdated = Date()
            
            // Save to both local cache and user defaults
            saveCachedAPIBlocklist()
            saveLocalData()
            
            if SubscriptionManager.shared.isSubscribed {
                updateContentBlocker()
                // Force reload the content blocker extension
                Task {
                    let success = await enableContentBlocker()
                    print("Content blocker reloaded after API update: \(success)")
                }
            }
            
            isLoading = false
            print("Successfully updated blocklist with \(domains.count) domains")
            
        } catch {
            print("Error fetching blocklist: \(error)")
            isLoading = false
        }
    }
    
    private func parseHostsFile(_ content: String) -> [String] {
        var domains = Set<String>()
        
        // Split the content into lines
        let lines = content.components(separatedBy: .newlines)
        print("Processing \(lines.count) lines from hosts file")
        
        for line in lines {
            // Skip comments, empty lines, and localhost entries
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }
            
            // Split the line into components
            let components = trimmedLine.components(separatedBy: .whitespaces)
            if components.count >= 2 {
                let ip = components[0]
                let domain = components[1]
                
                // Skip localhost and broadcast entries
                if ip == "127.0.0.1" || ip == "::1" || ip == "255.255.255.255" || 
                   domain == "localhost" || domain == "localhost.localdomain" || 
                   domain.contains("ip6-") || domain.isEmpty {
                    continue
                }
                
                // Only process 0.0.0.0 entries (blocked domains)
                if ip == "0.0.0.0" && !domain.isEmpty {
                    domains.insert(domain)
                }
            }
        }
        
        let finalDomains = Array(domains).sorted()
        print("Final parsed domains count: \(finalDomains.count)")
        return finalDomains
    }
    
    // MARK: - Custom Blocklist Management
    
    func addToCustomBlocklist(_ url: String) {
        // Only allow if user is subscribed
        guard SubscriptionManager.shared.isSubscribed else { return }
        
        let cleanURL = cleanURL(url)
        if !customBlocklist.contains(cleanURL) {
            customBlocklist.append(cleanURL)
            saveLocalData()
            updateContentBlocker()
        }
    }
    
    func removeFromCustomBlocklist(_ url: String) {
        // Only allow if user is subscribed
        guard SubscriptionManager.shared.isSubscribed else { return }
        
        customBlocklist.removeAll { $0 == url }
        saveLocalData()
        updateContentBlocker()
    }
    
    // MARK: - Keyword Blocklist Management
    
    func addToKeywordBlocklist(_ keyword: String) {
        // Only allow if user is subscribed
        guard SubscriptionManager.shared.isSubscribed else { return }
        
        let cleanKeyword = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !keywordBlocklist.contains(cleanKeyword) {
            keywordBlocklist.append(cleanKeyword)
            saveLocalData()
            updateContentBlocker()
        }
    }
    
    func removeFromKeywordBlocklist(_ keyword: String) {
        // Only allow if user is subscribed
        guard SubscriptionManager.shared.isSubscribed else { return }
        
        keywordBlocklist.removeAll { $0 == keyword }
        saveLocalData()
        updateContentBlocker()
    }
    
    // MARK: - Whitelist Management
    
    func addToWhitelist(_ url: String) {
        // Only allow if user is subscribed
        guard SubscriptionManager.shared.isSubscribed else { return }
        
        let cleanURL = cleanURL(url)
        if !whitelist.contains(cleanURL) {
            whitelist.append(cleanURL)
            saveLocalData()
            updateContentBlocker()
        }
    }
    
    func removeFromWhitelist(_ url: String) {
        // Only allow if user is subscribed
        guard SubscriptionManager.shared.isSubscribed else { return }
        
        whitelist.removeAll { $0 == url }
        saveLocalData()
        updateContentBlocker()
    }
    
    // MARK: - Content Blocker Generation
    
    func generateContentBlockerRules() -> [ContentBlockerRule] {
        // Only generate rules if user is subscribed
        guard SubscriptionManager.shared.isSubscribed else { return [] }
        
        var rules: [ContentBlockerRule] = []
        
        // Combine API blocklist and custom blocklist (limit to prevent Safari from rejecting)
        // Use more domains from the API but still keep it reasonable for Safari
        let allDomains = Set(apiBlocklist.prefix(30000) + customBlocklist)
        
        // Add domain-based rules (excluding whitelisted sites)
        // Use more specific patterns to avoid blocking search results
        for domain in allDomains {
            if !whitelist.contains(domain) && !domain.isEmpty {
                // Create rule for exact domain blocking (avoid blocking search results)
                let escapedDomain = domain.replacingOccurrences(of: ".", with: "\\.")
                let urlFilter = "^https?://([^/]*\\.)?\\b\(escapedDomain)\\b"
                rules.append(ContentBlockerRule(
                    trigger: ContentBlockerTrigger(urlFilter: urlFilter),
                    action: ContentBlockerAction(type: "block")
                ))
            }
        }
        
        // Add predefined keyword-based rules with better patterns
        print("Adding \(predefinedKeywords.count) predefined keyword rules")
        for keyword in predefinedKeywords {
            if !keyword.isEmpty {
                // Use domain-based blocking only to avoid blocking search results
                let escapedKeyword = keyword.replacingOccurrences(of: ".", with: "\\.")
                
                // Block if keyword appears in domain name
                let domainFilter = "^https?://([^/]*\\.)?[^/]*\(escapedKeyword)[^/]*\\."
                rules.append(ContentBlockerRule(
                    trigger: ContentBlockerTrigger(urlFilter: domainFilter),
                    action: ContentBlockerAction(type: "block")
                ))
            }
        }
        
        // Add custom keyword-based rules
        print("Adding \(keywordBlocklist.count) custom keyword rules")
        for keyword in keywordBlocklist {
            if !keyword.isEmpty {
                let escapedKeyword = keyword.replacingOccurrences(of: ".", with: "\\.")
                
                // Block if keyword appears in domain name
                let domainFilter = "^https?://([^/]*\\.)?[^/]*\(escapedKeyword)[^/]*\\."
                rules.append(ContentBlockerRule(
                    trigger: ContentBlockerTrigger(urlFilter: domainFilter),
                    action: ContentBlockerAction(type: "block")
                ))
            }
        }
        
        print("Generated \(rules.count) content blocker rules:")
        print("- Domain rules: \(allDomains.count)")
        print("- Predefined keyword rules: \(predefinedKeywords.count)")
        print("- Custom keyword rules: \(keywordBlocklist.count)")
        print("- API domains available: \(apiBlocklist.count)")
        return rules
    }
    
    func updateContentBlocker() {
        // Only update if user is subscribed
        guard SubscriptionManager.shared.isSubscribed else { return }
        
        let rules = generateContentBlockerRules()
        saveContentBlockerRules(rules)
    }
    
    private func saveContentBlockerRules(_ rules: [ContentBlockerRule]) {
        do {
            let data = try JSONEncoder().encode(rules)
            if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let rulesURL = documentsPath.appendingPathComponent("blockerList.json")
                try data.write(to: rulesURL)
                print("Content blocker rules saved to: \(rulesURL)")
                print("Saved \(rules.count) rules including \(apiBlocklist.count) API domains")
            }
        } catch {
            print("Error saving content blocker rules: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func cleanURL(_ url: String) -> String {
        var cleanURL = url.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURL.hasPrefix("http://") || cleanURL.hasPrefix("https://") {
            cleanURL = String(cleanURL.dropFirst(cleanURL.hasPrefix("https://") ? 8 : 7))
        }
        if cleanURL.hasPrefix("www.") {
            cleanURL = String(cleanURL.dropFirst(4))
        }
        return cleanURL
    }
    
    // MARK: - Public API
    
    func forceRefreshBlocklist() async {
        print("Force refreshing blocklist...")
        await fetchBlocklistFromAPI()
    }
    
    func getCacheInfo() -> (domains: Int, lastUpdate: Date?) {
        let lastUpdate = userDefaults.object(forKey: "apiBlocklistLastUpdate") as? Date
        return (apiBlocklist.count, lastUpdate)
    }
    
    // MARK: - Local Storage
    
    private func saveLocalData() {
        userDefaults.set(customBlocklist, forKey: "customBlocklist")
        userDefaults.set(keywordBlocklist, forKey: "keywordBlocklist")
        userDefaults.set(whitelist, forKey: "whitelist")
        userDefaults.set(lastUpdated, forKey: "lastUpdated")
        // Note: API blocklist is saved separately to apiBlocklist.json
    }
    
    private func loadLocalData() {
        customBlocklist = userDefaults.stringArray(forKey: "customBlocklist") ?? []
        keywordBlocklist = userDefaults.stringArray(forKey: "keywordBlocklist") ?? []
        whitelist = userDefaults.stringArray(forKey: "whitelist") ?? []
        lastUpdated = userDefaults.object(forKey: "lastUpdated") as? Date
        
        print("Loaded local data: \(customBlocklist.count) custom domains, \(keywordBlocklist.count) custom keywords, \(whitelist.count) whitelisted domains")
    }
    
    // MARK: - Safari Extension Communication
    
    private func updateSafariExtension() {
        guard SubscriptionManager.shared.isSubscribed else { return }
        
        print("Updating Safari extension with blocking rules...")
        
        // Generate rules for the extension
        let rules = generateSafariExtensionRules()
        
        // Save rules to a file that the extension can access
        saveSafariExtensionRules(rules)
        
        // Notify Safari to reload the extension
        reloadSafariExtension()
    }
    
    private func clearSafariExtensionRules() {
        print("Clearing Safari extension rules...")
        saveSafariExtensionRules([])
        reloadSafariExtension()
    }
    
    private func generateSafariExtensionRules() -> [[String: Any]] {
        var rules: [[String: Any]] = []
        var ruleId = 1
        
        // Add keyword-based rules
        let allKeywords = predefinedKeywords + keywordBlocklist
        for keyword in allKeywords {
            if !keyword.isEmpty {
                rules.append([
                    "id": ruleId,
                    "priority": 1,
                    "action": ["type": "block"],
                    "condition": [
                        "urlFilter": "*\(keyword)*",
                        "resourceTypes": ["main_frame", "sub_frame"]
                    ]
                ])
                ruleId += 1
            }
        }
        
        // Add domain-based rules (sample of top domains to avoid too many rules)
        let topDomains = Array(apiBlocklist.prefix(1000)) + customBlocklist
        for domain in topDomains {
            if !whitelist.contains(domain) && !domain.isEmpty {
                rules.append([
                    "id": ruleId,
                    "priority": 1,
                    "action": ["type": "block"],
                    "condition": [
                        "urlFilter": "*\(domain)*",
                        "resourceTypes": ["main_frame", "sub_frame"]
                    ]
                ])
                ruleId += 1
                
                // Limit total rules to avoid Safari extension limits
                if ruleId > 5000 {
                    break
                }
            }
        }
        
        print("Generated \(rules.count) Safari extension rules")
        return rules
    }
    
    private func saveSafariExtensionRules(_ rules: [[String: Any]]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: rules, options: .prettyPrinted)
            let rulesURL = documentsDirectory.appendingPathComponent("safariRules.json")
            try data.write(to: rulesURL)
            
            // Also save to the extension's bundle if possible
            if let bundlePath = Bundle.main.path(forResource: "rules", ofType: "json", inDirectory: "PornBlockerBlocker.appex/Resources") {
                try data.write(to: URL(fileURLWithPath: bundlePath))
            }
            
            print("Saved \(rules.count) rules for Safari extension")
        } catch {
            print("Error saving Safari extension rules: \(error)")
        }
    }
    
    private func reloadSafariExtension() {
        #if os(iOS)
        // On iOS, content blockers are managed through SFContentBlockerManager
        Task {
            let success = await enableContentBlocker()
            if success {
                print("Safari content blocker reloaded successfully")
            } else {
                print("Failed to reload Safari content blocker")
            }
        }
        #endif
    }
    
    // MARK: - Content Blocker Integration
    
    func enableContentBlocker() async -> Bool {
        guard SubscriptionManager.shared.isSubscribed else { return false }
        
        return await withCheckedContinuation { continuation in
            #if os(iOS)
            // Use the correct bundle identifier for your content blocker extension
            let extensionIdentifier = "com.jose.pimentel.Porn-Blocker.PornBlockerBlocker"
            
            SFContentBlockerManager.reloadContentBlocker(withIdentifier: extensionIdentifier) { error in
                if let error = error {
                    print("Error enabling content blocker: \(error)")
                    continuation.resume(returning: false)
                } else {
                    print("Content blocker enabled successfully")
                    continuation.resume(returning: true)
                }
            }
            #else
            continuation.resume(returning: true)
            #endif
        }
    }
    
    func checkContentBlockerStatus() async -> Bool {
        return await withCheckedContinuation { continuation in
            #if os(iOS)
            let extensionIdentifier = "com.jose.pimentel.Porn-Blocker.PornBlockerBlocker"
            
            SFContentBlockerManager.getStateOfContentBlocker(withIdentifier: extensionIdentifier) { state, error in
                if let error = error {
                    print("Error checking content blocker status: \(error)")
                    continuation.resume(returning: false)
                } else {
                    let isEnabled = state?.isEnabled ?? false
                    print("Content blocker enabled: \(isEnabled)")
                    continuation.resume(returning: isEnabled)
                }
            }
            #else
            continuation.resume(returning: true)
            #endif
        }
    }
}

// MARK: - Content Blocker Models

struct ContentBlockerRule: Codable {
    let trigger: ContentBlockerTrigger
    let action: ContentBlockerAction
}

struct ContentBlockerTrigger: Codable {
    let urlFilter: String
    
    enum CodingKeys: String, CodingKey {
        case urlFilter = "url-filter"
    }
}

struct ContentBlockerAction: Codable {
    let type: String
}

 