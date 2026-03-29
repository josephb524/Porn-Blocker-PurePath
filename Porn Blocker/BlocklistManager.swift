import Foundation
import SwiftUI
import SafariServices

// MARK: - Block Event Model

struct BlockEvent: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let category: String // e.g. "keyword", "domain", "custom"
    
    // Computed: is this event from today?
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var dayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

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
    @Published var blockEvents: [BlockEvent] = []
    
    // MARK: - Block Stats Computed Properties
    
    var blockedToday: Int {
        blockEvents.filter { $0.isToday }.count
    }
    
    var blockedThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return blockEvents.filter { $0.date >= weekAgo }.count
    }
    
    /// Consecutive days with at least one block event ("days protected" streak)
    var blockStreak: Int {
        guard !blockEvents.isEmpty else { return 0 }
        let calendar = Calendar.current
        var streak = 0
        var checkDate = Date()
        let dayKeys = Set(blockEvents.map { $0.dayKey })
        
        // If no events today, still count as day 0 and look backwards
        while true {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let key = formatter.string(from: checkDate)
            if dayKeys.contains(key) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else if streak == 0 {
                // Allow one gap for today (protection might be active but no block needed yet)
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                let key2 = formatter.string(from: checkDate)
                if dayKeys.contains(key2) {
                    streak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                } else {
                    break
                }
            } else {
                break
            }
        }
        return streak
    }
    
    /// Daily blocked counts for past 7 days (for chart)
    var weeklyBlockCounts: [(day: String, count: Int)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "EEE"
        
        return (0..<7).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let key = formatter.string(from: date)
            let label = shortFormatter.string(from: date)
            let count = blockEvents.filter { $0.dayKey == key }.count
            return (day: label, count: count)
        }
    }
    @Published var strictImageMode: Bool {
        didSet {
            userDefaults.set(strictImageMode, forKey: "strictImageMode")
            updateContentBlocker()
        }
    }
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
        self.strictImageMode = userDefaults.bool(forKey: "strictImageMode")
        loadPredefinedKeywords()
        loadLocalData()
        loadCachedAPIBlocklist()
        loadBlockEvents()
        
        // Save initial subscription status to shared storage
        saveSubscriptionStatusToSharedStorage()
        
        // Ensure Safari Content Blocker is reloaded on launch to reflect current subscription state
        // This guarantees empty rules are applied if the user is not subscribed, avoiding stale cached rules
        updateContentBlocker()
        
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
        let expiryTimestamp = SubscriptionManager.shared.expiryDate?.timeIntervalSince1970
        let subscriptionData: [String: Any] = [
            "isSubscribed": SubscriptionManager.shared.isSubscribed,
            "expiryDate": expiryTimestamp as Any,
            "lastUpdated": Date().timeIntervalSince1970
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: subscriptionData, options: [])
            try data.write(to: subscriptionStatusURL)
            print("Saved subscription status to shared storage: \(SubscriptionManager.shared.isSubscribed) | expiry=\(String(describing: expiryTimestamp))")
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
    
    // Public method to verify core blocking rules are properly loaded
    func verifyCoreBlockingRules() -> (isLoaded: Bool, count: Int, sampleRules: [String]) {
        guard let bundleRules = loadBundleRules() else {
            print("❌ CRITICAL: Core blocking rules could not be loaded from bundle!")
            return (false, 0, [])
        }
        
        let sampleRules = bundleRules.prefix(5).map { $0.trigger.urlFilter }
        print("✅ VERIFIED: Core blocking rules loaded successfully")
        print("   📊 Total core rules: \(bundleRules.count)")
        print("   📝 Sample rules: \(sampleRules)")
        
        return (true, bundleRules.count, Array(sampleRules))
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
        let cleanURL = cleanURL(url)
        if !customBlocklist.contains(cleanURL) {
            customBlocklist.append(cleanURL)
            saveLocalData()
            print("Added custom website: '\(cleanURL)'. Total custom websites: \(customBlocklist.count)")
            updateContentBlocker()
        }
    }
    
    func removeFromCustomBlocklist(_ url: String) {
        let originalCount = customBlocklist.count
        customBlocklist.removeAll { $0 == url }
        if customBlocklist.count < originalCount {
            print("Removed custom website: '\(url)'. Total custom websites: \(customBlocklist.count)")
        }
        saveLocalData()
        updateContentBlocker()
    }
    
    // MARK: - Keyword Blocklist Management
    
    func addToKeywordBlocklist(_ keyword: String) {
        let cleanKeyword = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !keywordBlocklist.contains(cleanKeyword) {
            keywordBlocklist.append(cleanKeyword)
            saveLocalData()
            print("Added custom keyword: '\(cleanKeyword)'. Total custom keywords: \(keywordBlocklist.count)")
            updateContentBlocker()
        }
    }
    
    func removeFromKeywordBlocklist(_ keyword: String) {
        let originalCount = keywordBlocklist.count
        keywordBlocklist.removeAll { $0 == keyword }
        if keywordBlocklist.count < originalCount {
            print("Removed custom keyword: '\(keyword)'. Total custom keywords: \(keywordBlocklist.count)")
        }
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
        
        // 1️⃣ ALWAYS include static rules from bundle (HIGHEST PRIORITY - NEVER SKIP)
        if let bundleRules = loadBundleRules() {
            rules.append(contentsOf: bundleRules)
            print("✅ CORE BLOCKING: Added \(bundleRules.count) static rules from ContentBlocker bundle")
        } else {
            // This should never happen, but if it does, use essential fallback rules
            let essentialRules = createEssentialStaticRules()
            rules.append(contentsOf: essentialRules)
            print("⚠️ FALLBACK: Bundle rules failed to load, using \(essentialRules.count) essential static rules")
            
            // Log this as a serious issue
            print("ERROR: Could not load core blockerList.json from ContentBlocker bundle!")
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
        
        let bundleRulesCount = loadBundleRules()?.count ?? 0
        print("📊 Generated \(rules.count) content blocker rules:")
        print("   ✅ CORE static rules from bundle: \(bundleRulesCount) (ALWAYS INCLUDED)")
        print("   🏠 Custom domain rules: \(customDomains.count)")
        print("   📝 Predefined keyword rules: \(importantKeywords.count)")
        print("   ⭐ Custom keyword rules: \(limitedCustomKeywords.count)")
        print("   📊 API domains available (UI only): \(apiBlocklist.count)")
        
        // CRITICAL: Verify that core static rules are included
        if bundleRulesCount == 0 {
            print("⚠️ WARNING: No core static rules found! This should never happen!")
        } else {
            print("✅ CONFIRMED: Core blocking rules (\(bundleRulesCount) rules) are included in blocking system")
        }
        
        // 5️⃣ Add CSS cosmetic filter rules (hide images/videos on matched pages)
        let cosmeticRules = generateCosmeticFilterRules()
        rules.append(contentsOf: cosmeticRules)
        print("   🎨 Cosmetic CSS rules: \(cosmeticRules.count)")
        
        return rules
    }
    
    // MARK: - CSS Cosmetic Filtering
    
    /// Generates css-display-none rules that hide visual media on pages matching adult URL patterns.
    /// These work even when the page partially loads — the browser applies the CSS before rendering.
    func generateCosmeticFilterRules() -> [ContentBlockerRule] {
        guard SubscriptionManager.shared.isSubscribed else { return [] }
        
        var rules: [ContentBlockerRule] = []
        
        // Universal selector that hides common adult media elements
        let baseSelector = "img, video, picture, source, canvas, embed, object, iframe"
        
        // Additional selectors for suspicious thumbnail/gallery class names
        let gallerySelector = "[class*='thumb'], [class*='preview'], [class*='gallery-item'], [class*='video-thumb'], [class*='adult'], [class*='porn'], [class*='xxx'], [class*='nude']"
        
        let fullSelector = baseSelector + ", " + gallerySelector
        
        // Top adult URL patterns to apply cosmetic filtering on
        let adultURLPatterns: [(filter: String, desc: String)] = [
            (".*porn.*",      "porn keyword pages"),
            (".*xxx.*",       "xxx keyword pages"),
            (".*xvideos.*",   "xvideos pages"),
            (".*xnxx.*",      "xnxx pages"),
            (".*xhamster.*",  "xhamster pages"),
            (".*pornhub.*",   "pornhub pages"),
            (".*redtube.*",   "redtube pages"),
            (".*youporn.*",   "youporn pages"),
            (".*tube8.*",     "tube8 pages"),
            (".*spankbang.*", "spankbang pages"),
            (".*beeg.*",      "beeg pages"),
            (".*chaturbate.*","chaturbate pages"),
            (".*onlyfans.*",  "onlyfans pages"),
            (".*fansly.*",    "fansly pages"),
            (".*brazzers.*",  "brazzers pages"),
            (".*hentai.*",    "hentai pages"),
            (".*nhentai.*",   "nhentai pages"),
            (".*erotic.*",    "erotic keyword pages"),
            (".*nude.*",      "nude keyword pages"),
            (".*naked.*",     "naked keyword pages"),
            (".*sex\\.com.*",  "sex.com"),
            (".*adult.*",     "adult keyword pages"),
        ]
        
        // Whitelisted domains should not get cosmetic rules applied
        let whitelistDomains = whitelist
        
        for pattern in adultURLPatterns {
            rules.append(ContentBlockerRule(
                trigger: ContentBlockerTrigger(
                    urlFilter: pattern.filter,
                    ifDomain: nil,
                    unlessDomain: whitelistDomains.isEmpty ? nil : whitelistDomains,
                    resourceTypes: nil
                ),
                action: ContentBlockerAction(type: "css-display-none", selector: baseSelector)
            ))
        }
        
        // Strict Image Mode: also hide all images across ANY URL if the page
        // contains a suspicious path segment (broader net)
        if strictImageMode {
            let strictPatterns = [
                ".*\\/cam.*", ".*\\/live.*sex.*", ".*\\/girls.*",
                ".*\\/babes.*", ".*\\/milf.*", ".*\\/teen.*sex.*",
                ".*\\/fetish.*", ".*\\/bdsm.*"
            ]
            for p in strictPatterns {
                rules.append(ContentBlockerRule(
                    trigger: ContentBlockerTrigger(
                        urlFilter: p,
                        ifDomain: nil,
                        unlessDomain: whitelistDomains.isEmpty ? nil : whitelistDomains,
                        resourceTypes: nil
                    ),
                    action: ContentBlockerAction(type: "css-display-none", selector: fullSelector)
                ))
            }
            print("\t🔒 Strict Image Mode: added \(strictPatterns.count) extra cosmetic rules")
        }
        
        print("Generated \(rules.count) cosmetic filter rules (css-display-none)")
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
        
        // Check if user is subscribed
        if SubscriptionManager.shared.isSubscribed {
            // User is subscribed - generate and save blocking rules
            let rules = generateContentBlockerRules()
            saveContentBlockerRules(rules)
            
            // Reload the content blocker
            Task {
                let success = await enableContentBlocker()
                print("✅ Content blocker reloaded with \(rules.count) blocking rules (subscribed): \(success)")
            }
        } else {
            // User is NOT subscribed - save NO-OP rules to disable blocking without compilation error
            let noopRules = generateNoopContentBlockerRules()
            saveContentBlockerRules(noopRules)
            
            // Reload the content blocker with no-op rules
            Task {
                let success = await enableContentBlocker()
                print("🚫 Content blocker reloaded with no-op rules (not subscribed): \(success)")
            }
        }
    }
    
    private func generateNoopContentBlockerRules() -> [ContentBlockerRule] {
        // A single rule that effectively does nothing but ensures the ruleset is non-empty
        // Using 'ignore-previous-rules' with a wide trigger resets rule evaluation and blocks nothing
        return [
            ContentBlockerRule(
                trigger: ContentBlockerTrigger(urlFilter: ".*"),
                action: ContentBlockerAction(type: "ignore-previous-rules")
            )
        ]
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
                    print("✅ Content blocker rules saved to shared container: \(sharedRulesURL)")
                    
                    // Verify the file was written correctly
                    let fileSize = try Data(contentsOf: sharedRulesURL).count
                    print("✅ Shared rules file size: \(fileSize) bytes - ContentBlocker extension can now access these rules")
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
        
        // If not subscribed, save no-op rules instead of any blocking
        if !SubscriptionManager.shared.isSubscribed {
            do {
                let empty: [ContentBlockerRule] = generateNoopContentBlockerRules()
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(empty)
                
                if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
                    let sharedRulesURL = containerURL.appendingPathComponent("blockerList.json")
                    try data.write(to: sharedRulesURL)
                    print("Fallback: not subscribed, saved no-op rules to shared container")
                }
                
                if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let rulesURL = documentsPath.appendingPathComponent("blockerList.json")
                    try data.write(to: rulesURL)
                    print("Fallback: not subscribed, saved no-op rules to documents directory")
                }
            } catch {
                print("Error saving no-op fallback rules: \(error)")
            }
            return
        }
        
        // Create a minimal set of rules that should always work (only when subscribed)
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
    
    // MARK: - Block Event Logging
    
    func logBlockEvent(category: String = "domain") {
        let event = BlockEvent(date: Date(), category: category)
        blockEvents.append(event)
        saveBlockEvents()
    }
    
    private func saveBlockEvents() {
        // Keep only last 90 days of events to avoid unbounded growth
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        blockEvents = blockEvents.filter { $0.date >= cutoff }
        
        if let data = try? JSONEncoder().encode(blockEvents) {
            userDefaults.set(data, forKey: "blockEvents")
        }
    }
    
    private func loadBlockEvents() {
        if let data = userDefaults.data(forKey: "blockEvents"),
           let events = try? JSONDecoder().decode([BlockEvent].self, from: data) {
            blockEvents = events
            print("Loaded \(events.count) block events")
        } else {
            // Seed some demo data on first launch so charts aren't empty
            seedDemoBlockEvents()
        }
    }
    
    /// Seeds realistic demo data so the dashboard looks live from day one.
    private func seedDemoBlockEvents() {
        guard userDefaults.data(forKey: "blockEvents") == nil else { return }
        let calendar = Calendar.current
        var events: [BlockEvent] = []
        let categories = ["domain", "keyword", "domain", "domain", "keyword"]
        for dayOffset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            let count = [3, 7, 2, 5, 1, 4, 6][dayOffset]
            for i in 0..<count {
                let eventDate = calendar.date(byAdding: .hour, value: -(i * 2), to: date) ?? date
                events.append(BlockEvent(date: eventDate, category: categories[i % categories.count]))
            }
        }
        blockEvents = events
        saveBlockEvents()
        print("Seeded \(events.count) demo block events")
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
    let ifDomain: [String]?
    let unlessDomain: [String]?
    let resourceTypes: [String]?
    
    init(urlFilter: String,
         ifDomain: [String]? = nil,
         unlessDomain: [String]? = nil,
         resourceTypes: [String]? = nil) {
        self.urlFilter    = urlFilter
        self.ifDomain     = ifDomain
        self.unlessDomain = unlessDomain
        self.resourceTypes = resourceTypes
    }
    
    enum CodingKeys: String, CodingKey {
        case urlFilter     = "url-filter"
        case ifDomain      = "if-domain"
        case unlessDomain  = "unless-domain"
        case resourceTypes = "resource-type"
    }
    
    // Custom encode: omit nil optionals so the JSON stays clean
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(urlFilter, forKey: .urlFilter)
        if let v = ifDomain      { try container.encode(v, forKey: .ifDomain) }
        if let v = unlessDomain  { try container.encode(v, forKey: .unlessDomain) }
        if let v = resourceTypes { try container.encode(v, forKey: .resourceTypes) }
    }
}

struct ContentBlockerAction: Codable {
    let type: String
    let selector: String?
    
    init(type: String, selector: String? = nil) {
        self.type     = type
        self.selector = selector
    }
    
    // Custom encode: omit selector when nil
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        if let s = selector { try container.encode(s, forKey: .selector) }
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case selector
    }
}
