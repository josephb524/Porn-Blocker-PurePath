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
    private let appGroupIdentifier = "group.com.jose.pimentel.PornBlocker" // Shared container for blocker rules
    
    // Local storage paths
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var apiBlocklistURL: URL {
        documentsDirectory.appendingPathComponent("apiBlocklist.json")
    }
    
    // Shared container URL for subscription status
    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    init() {
        self.isEnabled = userDefaults.bool(forKey: "isEnabled")
        loadPredefinedKeywords()
        loadLocalData()
        loadCachedAPIBlocklist()
        
        // Save initial subscription status to shared storage
        saveSubscriptionStatusToSharedStorage()
        
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
    
    // MARK: - Subscription Status Management
    
    func saveSubscriptionStatusToSharedStorage() {
        guard let containerURL = sharedContainerURL else {
            print("Failed to access shared container for subscription status")
            return
        }
        
        let subscriptionStatusURL = containerURL.appendingPathComponent("subscriptionStatus.json")
        let subscriptionData: [String: Any] = [
            "isSubscribed": SubscriptionManager.shared.isSubscribed,
            "lastUpdated": Date().timeIntervalSince1970
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: subscriptionData, options: [])
            try data.write(to: subscriptionStatusURL)
            print("Saved subscription status to shared storage: \(SubscriptionManager.shared.isSubscribed)")
            print("Subscription status file path: \(subscriptionStatusURL.path)")
            print("File exists after save: \(FileManager.default.fileExists(atPath: subscriptionStatusURL.path))")
        } catch {
            print("Error saving subscription status to \(subscriptionStatusURL.path): \(error)")
        }
    }
    
    // Call this method whenever subscription status changes
    func updateSubscriptionStatus() {
        saveSubscriptionStatusToSharedStorage()
        updateContentBlocker()
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
            
            // Note: API domains are now only used for UI display, not for blocking rules
            // Content blocker uses static rules from bundle instead
            
            isLoading = false
            print("Successfully updated blocklist with \(domains.count) domains (for UI display only)")
            
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
        
        // 1️⃣ First, load static rules from bundle (highest priority)
        if let bundleRules = loadBundleRules() {
            rules.append(contentsOf: bundleRules)
            print("Added \(bundleRules.count) static rules from bundle")
        } else {
            // Fallback to essential static rules if bundle loading fails
            let essentialRules = createEssentialStaticRules()
            rules.append(contentsOf: essentialRules)
            print("Added \(essentialRules.count) essential static rules as fallback")
        }
        
        // Limit total rules to stay well under Safari's limits (keep under 15,000)
        let maxKeywordRules = 200
        
        // 2️⃣ Only use custom blocklist (no API domains to avoid massive file size)
        let customDomains = Set(customBlocklist)
        
        // Add custom domain-based rules (excluding whitelisted sites)
        for domain in customDomains {
            if !whitelist.contains(domain) && !domain.isEmpty && isValidDomain(domain) {
                // Create simpler, more reliable domain blocking pattern
                let escapedDomain = escapeRegexCharacters(domain)
                let urlFilter = ".*\(escapedDomain).*"
                rules.append(ContentBlockerRule(
                    trigger: ContentBlockerTrigger(urlFilter: urlFilter),
                    action: ContentBlockerAction(type: "block")
                ))
            }
        }
        
        // 3️⃣ Add predefined keyword-based rules with better patterns (limit to most important)
        let importantKeywords = Array(predefinedKeywords.prefix(maxKeywordRules))
        print("Adding \(importantKeywords.count) predefined keyword rules")
        for keyword in importantKeywords {
            if !keyword.isEmpty && isValidKeyword(keyword) {
                let escapedKeyword = escapeRegexCharacters(keyword)
                let urlFilter = ".*\(escapedKeyword).*"
                rules.append(ContentBlockerRule(
                    trigger: ContentBlockerTrigger(urlFilter: urlFilter),
                    action: ContentBlockerAction(type: "block")
                ))
            }
        }
        
        // 4️⃣ Add custom keyword-based rules (limit to reasonable number)
        let limitedCustomKeywords = Array(keywordBlocklist.prefix(50))
        print("Adding \(limitedCustomKeywords.count) custom keyword rules")
        for keyword in limitedCustomKeywords {
            if !keyword.isEmpty && isValidKeyword(keyword) {
                let escapedKeyword = escapeRegexCharacters(keyword)
                let urlFilter = ".*\(escapedKeyword).*"
                rules.append(ContentBlockerRule(
                    trigger: ContentBlockerTrigger(urlFilter: urlFilter),
                    action: ContentBlockerAction(type: "block")
                ))
            }
        }
        
        print("Generated \(rules.count) content blocker rules:")
        print("- Static rules from bundle: \(loadBundleRules()?.count ?? 0)")
        print("- Custom domain rules: \(customDomains.count)")
        print("- Predefined keyword rules: \(importantKeywords.count)")
        print("- Custom keyword rules: \(limitedCustomKeywords.count)")
        print("- API domains available (UI only): \(apiBlocklist.count)")
        return rules
    }
    
    // Helper function to load static rules from bundle
    private func loadBundleRules() -> [ContentBlockerRule]? {
        guard let resourceURL = Bundle.main.url(forResource: "blockerList", withExtension: "json") else {
            print("Could not find blockerList.json in main bundle")
            return nil
        }
        
        do {
            // Read file as text so we can strip line comments (// ...)
            let rawString = try String(contentsOf: resourceURL, encoding: .utf8)
            let cleanedString = rawString
                .components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            
            guard let cleanedData = cleanedString.data(using: .utf8) else {
                print("Failed converting cleaned JSON string to Data")
                return nil
            }
            
            let bundleRules = try JSONDecoder().decode([ContentBlockerRule].self, from: cleanedData)
            print("Successfully loaded \(bundleRules.count) static rules from bundle")
            return bundleRules
        } catch {
            print("Error loading bundle rules: \(error)")
            return nil
        }
    }
    
    // Helper function to create essential static rules manually
    private func createEssentialStaticRules() -> [ContentBlockerRule] {
        let essentialSites = [
            "brazzers", "youjizz", "pornhub", "xvideos", "xnxx", "xhamster", "redtube", "youporn",
            "tube8", "spankbang", "beeg", "rule34", "motherless", "efukt", "sex.com", "cam4",
            "livejasmin", "bongacams", "chaturbate", "onlyfans", "fansly", "stripchat", "camsoda",
            "adultfriendfinder", "ashley.madison", "imagefap", "gelbooru", "nhentai", "hanime",
            "hentai", "porn", "xxx", "sex", "adult", "nude"
        ]
        
        var rules: [ContentBlockerRule] = []
        for site in essentialSites {
            rules.append(ContentBlockerRule(
                trigger: ContentBlockerTrigger(urlFilter: ".*\(site).*"),
                action: ContentBlockerAction(type: "block")
            ))
        }
        
        print("Created \(rules.count) essential static rules manually")
        return rules
    }
    
    // Helper function to validate domains
    private func isValidDomain(_ domain: String) -> Bool {
        // Basic domain validation
        let domainPattern = "^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]*\\.[a-zA-Z]{2,}$"
        let regex = try? NSRegularExpression(pattern: domainPattern)
        let range = NSRange(location: 0, length: domain.utf16.count)
        return regex?.firstMatch(in: domain, options: [], range: range) != nil
    }
    
    // Helper function to validate keywords
    private func isValidKeyword(_ keyword: String) -> Bool {
        // Ensure keyword doesn't contain problematic characters
        let invalidChars = CharacterSet(charactersIn: "[]{}()+*?^$|\\")
        return keyword.rangeOfCharacter(from: invalidChars) == nil && keyword.count > 1
    }
    
    // Helper function to properly escape regex characters
    private func escapeRegexCharacters(_ string: String) -> String {
        let charactersToEscape = ["\\", ".", "*", "+", "?", "^", "$", "(", ")", "[", "]", "{", "}", "|"]
        var escaped = string
        for char in charactersToEscape {
            escaped = escaped.replacingOccurrences(of: char, with: "\\\(char)")
        }
        return escaped
    }
    
    func updateContentBlocker() {
        // Always update subscription status in shared storage
        saveSubscriptionStatusToSharedStorage()
        
        // Only update if user is subscribed
        guard SubscriptionManager.shared.isSubscribed else { 
            // Still reload the content blocker to apply empty rules if not subscribed
            Task {
                let success = await enableContentBlocker()
                print("Content blocker reloaded with empty rules (not subscribed): \(success)")
            }
            return 
        }
        
        let rules = generateContentBlockerRules()
        saveContentBlockerRules(rules)
        
        // Reload the content blocker
        Task {
            let success = await enableContentBlocker()
            print("Content blocker reloaded after rules update: \(success)")
        }
    }
    
    private func saveContentBlockerRules(_ rules: [ContentBlockerRule]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(rules)
            
            // Validate JSON before saving
            if let jsonString = String(data: data, encoding: .utf8) {
                // Try to parse it back to ensure it's valid JSON
                _ = try JSONSerialization.jsonObject(with: data, options: [])
                
                // Save to shared container first (for Safari extension)
                if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
                    let sharedRulesURL = containerURL.appendingPathComponent("blockerList.json")
                    try data.write(to: sharedRulesURL)
                    print("Content blocker rules saved to shared container: \(sharedRulesURL)")
                }
                
                // Also save to documents directory (fallback)
                if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let rulesURL = documentsPath.appendingPathComponent("blockerList.json")
                    try data.write(to: rulesURL)
                    print("Content blocker rules also saved to documents: \(rulesURL)")
                }
                
                print("Saved \(rules.count) rules (JSON size: \(data.count) bytes)")
            }
        } catch {
            print("Error saving content blocker rules: \(error)")
            // If there's an error, try to save a minimal fallback ruleset
            saveFallbackRules()
        }
    }
    
    private func saveFallbackRules() {
        print("Saving fallback rules due to JSON error...")
        // Create a minimal set of rules that should always work
        let fallbackRules = [
            ContentBlockerRule(
                trigger: ContentBlockerTrigger(urlFilter: ".*pornhub.*"),
                action: ContentBlockerAction(type: "block")
            ),
            ContentBlockerRule(
                trigger: ContentBlockerTrigger(urlFilter: ".*xvideos.*"),
                action: ContentBlockerAction(type: "block")
            ),
            ContentBlockerRule(
                trigger: ContentBlockerTrigger(urlFilter: ".*xnxx.*"),
                action: ContentBlockerAction(type: "block")
            ),
            ContentBlockerRule(
                trigger: ContentBlockerTrigger(urlFilter: ".*porn.*"),
                action: ContentBlockerAction(type: "block")
            ),
            ContentBlockerRule(
                trigger: ContentBlockerTrigger(urlFilter: ".*xxx.*"),
                action: ContentBlockerAction(type: "block")
            )
        ]
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(fallbackRules)
            
            // Save to shared container
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
                let sharedRulesURL = containerURL.appendingPathComponent("blockerList.json")
                try data.write(to: sharedRulesURL)
                print("Fallback rules saved to shared container")
            }
            
            // Also save to documents directory
            if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let rulesURL = documentsPath.appendingPathComponent("blockerList.json")
                try data.write(to: rulesURL)
                print("Fallback rules saved to documents directory")
            }
        } catch {
            print("Error saving fallback rules: \(error)")
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
        // Always reload the content blocker to pick up subscription status changes
        return await withCheckedContinuation { continuation in
            #if os(iOS)
            // Use the correct bundle identifier for your content blocker extension
            let extensionIdentifier = "com.jose.pimentel.Porn-Blocker.ContentBlocker"
            
            SFContentBlockerManager.reloadContentBlocker(withIdentifier: extensionIdentifier) { error in
                if let error = error {
                    print("Error reloading content blocker: \(error)")
                    continuation.resume(returning: false)
                } else {
                    let statusMessage = SubscriptionManager.shared.isSubscribed ? "with blocking rules" : "with empty rules (not subscribed)"
                    print("Content blocker reloaded successfully \(statusMessage)")
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
            let extensionIdentifier = "com.jose.pimentel.Porn-Blocker.ContentBlocker"
            
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

 
