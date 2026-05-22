import Foundation
import SwiftUI
import SafariServices

@MainActor
class BlocklistManager: ObservableObject {
    static let shared = BlocklistManager()
    
    @Published var apiBlocklist: [String] = []
    @Published var customBlocklist: [String] = [] {
        didSet { updateSets() }
    }
    @Published var keywordBlocklist: [String] = [] {
        didSet { updateSets() }
    }
    @Published var whitelist: [String] = [] {
        didSet { updateSets() }
    }
    @Published var isLoading = false
    @Published var lastUpdated: Date?

    /// Predefined adult-content keywords. Owned by `KeywordMatcher` so the
    /// Safe Browser and the content blocker stay in sync.
    var predefinedKeywords: [String] { KeywordMatcher.predefinedKeywords }

    // Performance-optimized Sets for O(1) lookups in Safe Browser
    var apiBlocklistSet: Set<String> = []
    var customBlocklistSet: Set<String> = []
    var keywordBlocklistSet: Set<String> = []
    var whitelistSet: Set<String> = []
    
    private let searchEngineDomains: Set<String> = [
        "google.com", "bing.com", "duckduckgo.com", "yahoo.com", 
        "baidu.com", "yandex.com", "ask.com", "ecosia.org"
    ]
    
    @Published var strictImageMode: Bool {
        didSet {
            userDefaults.set(strictImageMode, forKey: "strictImageMode")
            updateContentBlocker()
        }
    }
    @Published var isEnabled: Bool {
        didSet {
            userDefaults.set(isEnabled, forKey: "isEnabled")
            updateContentBlocker()
        }
    }
    
    private let userDefaults = UserDefaults.standard
    private let stevenBlackHostsURL = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn/hosts"
    private let updateInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private let appGroupIdentifier = "group.com.jose.pimentel.PornBlocker" // Shared container for blocker rules

    /// Pending debounced content blocker rebuild — see `updateContentBlocker()`.
    private var contentBlockerUpdateTask: Task<Void, Never>?

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
        loadLocalData()

        // Save initial subscription status so the extension has fresh data.
        saveSubscriptionStatusToSharedStorage()

        // Reflect the current subscription state immediately (debounced).
        updateContentBlocker()

        // Load the cached domain list off the main actor so launch isn't
        // blocked, then download a fresh copy if it's stale.
        Task { [weak self] in
            guard let self else { return }
            await self.loadCachedAPIBlocklist()
            if self.shouldDownloadAPIBlocklist() {
                print("Need to download/update API blocklist")
                await self.fetchBlocklistFromAPI()
            } else {
                print("Using cached API blocklist with \(self.apiBlocklist.count) domains")
                self.updateContentBlocker()
            }
        }
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
    
    /// Reads and decodes the cached domain list off the main actor, then
    /// publishes it. Decoding ~300k strings is too heavy to do on the main thread.
    private func loadCachedAPIBlocklist() async {
        let url = apiBlocklistURL
        let (domains, set): ([String], Set<String>) = await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else {
                return ([], [])
            }
            let set = Set(decoded.map { $0.lowercased().trimmingCharacters(in: .whitespaces) })
            return (decoded, set)
        }.value

        apiBlocklist = domains
        apiBlocklistSet = set
        print("Loaded \(domains.count) domains from cache")
    }

    /// Encodes and writes the cached domain list off the main actor.
    private func saveCachedAPIBlocklist() {
        let snapshot = apiBlocklist
        let url = apiBlocklistURL
        Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url)
                UserDefaults.standard.set(Date(), forKey: "apiBlocklistLastUpdate")
                print("Saved \(snapshot.count) domains to cache")
            } catch {
                print("Failed to save API blocklist to cache: \(error)")
            }
        }
    }
    
    // MARK: - Subscription Status Management
    
    func saveSubscriptionStatusToSharedStorage() {
        let isSubscribed = SubscriptionManager.shared.isSubscribed
        let expiryTimestamp = SubscriptionManager.shared.expiryDate?.timeIntervalSince1970

        // Mirror the status into app-group UserDefaults — a robust secondary
        // source the content blocker falls back to if the JSON file below is
        // ever missing or corrupt.
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            sharedDefaults.set(isSubscribed, forKey: "isSubscribed")
            sharedDefaults.set(Date().timeIntervalSince1970, forKey: "subscriptionStatusUpdated")
            if let expiryTimestamp {
                sharedDefaults.set(expiryTimestamp, forKey: "subscriptionExpiry")
            } else {
                sharedDefaults.removeObject(forKey: "subscriptionExpiry")
            }
        }

        guard let containerURL = sharedContainerURL else {
            print("Failed to access shared container for subscription status")
            return
        }

        let subscriptionStatusURL = containerURL.appendingPathComponent("subscriptionStatus.json")
        let subscriptionData: [String: Any] = [
            "isSubscribed": isSubscribed,
            "expiryDate": expiryTimestamp as Any,
            "lastUpdated": Date().timeIntervalSince1970
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: subscriptionData, options: [])
            try data.write(to: subscriptionStatusURL)
            print("Saved subscription status: subscribed=\(isSubscribed) expiry=\(String(describing: expiryTimestamp))")
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
    
    // Helper to check if a host is a known search engine
    func isSearchEngine(_ host: String) -> Bool {
        let cleanHost = host.lowercased().trimmingCharacters(in: .whitespaces)
        return searchEngineDomains.contains { domain in
            cleanHost == domain || cleanHost.hasSuffix(".\(domain)")
        }
    }
    
    func updateSets() {
        customBlocklistSet = Set(customBlocklist.map { $0.lowercased().trimmingCharacters(in: .whitespaces) })
        keywordBlocklistSet = Set(keywordBlocklist.map { $0.lowercased().trimmingCharacters(in: .whitespaces) })
        whitelistSet = Set(whitelist.map { $0.lowercased().trimmingCharacters(in: .whitespaces) })
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
            let domains = await Task.detached(priority: .utility) {
                Self.parseHostsFile(hostsContent)
            }.value
            print("Parsed \(domains.count) domains")
            
            // Only update if we got a reasonable number of domains
            guard domains.count > 100000 else {
                print("Warning: Only got \(domains.count) domains, expected ~305k. Not updating cache.")
                isLoading = false
                return
            }
            
            apiBlocklist = domains
            apiBlocklistSet = Set(apiBlocklist.map { $0.lowercased().trimmingCharacters(in: .whitespaces) })
            lastUpdated = Date()

            // Save to both local cache and user defaults
            saveCachedAPIBlocklist()
            saveLocalData()

            // Rebuild the Safari content blocker so the freshly downloaded
            // domains take effect without waiting for the next launch.
            updateContentBlocker()

            isLoading = false
            print("Successfully updated blocklist with \(domains.count) domains")
            
        } catch {
            print("Error fetching blocklist: \(error)")
            isLoading = false
        }
    }
    
    nonisolated private static func parseHostsFile(_ content: String) -> [String] {
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
    
    /// Max number of downloaded domains fed into the Safari content blocker.
    /// Well under Safari's 150k-rule ceiling once core/keyword/cosmetic rules are added.
    private static let maxAPIDomainRules = 35_000
    /// Max number of user-defined custom keywords turned into content blocker rules.
    private static let maxCustomKeywordRules = 50

    func generateContentBlockerRules() -> [ContentBlockerRule] {
        // Only generate rules if the user is subscribed
        guard SubscriptionManager.shared.isSubscribed else { return [] }

        var rules: [ContentBlockerRule] = []

        // 1. Core static rules from the ContentBlocker bundle (never skipped)
        if let bundleRules = loadBundleRules() {
            rules.append(contentsOf: bundleRules)
        } else {
            print("⚠️ Bundle rules failed to load — using essential fallback rules")
            rules.append(contentsOf: createEssentialStaticRules())
        }
        let coreCount = rules.count

        let whitelisted = whitelistSet

        // 2. Custom domains added by the user
        var customDomainCount = 0
        for domain in Set(customBlocklist)
        where !whitelisted.contains(domain) && isValidDomain(domain) {
            rules.append(domainRule(for: domain))
            customDomainCount += 1
        }

        // 3. A capped, evenly-sampled slice of the downloaded domain list
        var apiDomainCount = 0
        for domain in sampledAPIDomains(cap: Self.maxAPIDomainRules)
        where !whitelisted.contains(domain) {
            rules.append(domainRule(for: domain))
            apiDomainCount += 1
        }

        // 4. Keyword rules — search engines and whitelisted sites are exempt
        let exemptDomains = Array(searchEngineDomains) + Array(whitelisted)
        for filter in KeywordMatcher.predefinedURLFilters() {
            rules.append(keywordRule(filter: filter, exemptDomains: exemptDomains))
        }
        var customKeywordCount = 0
        for keyword in keywordBlocklist.prefix(Self.maxCustomKeywordRules) {
            guard let filter = KeywordMatcher.customURLFilter(for: keyword) else { continue }
            rules.append(keywordRule(filter: filter, exemptDomains: exemptDomains))
            customKeywordCount += 1
        }

        // 5. CSS cosmetic rules — hide media on pages that partially load
        let cosmeticRules = generateCosmeticFilterRules()
        rules.append(contentsOf: cosmeticRules)

        let keywordCount = KeywordMatcher.predefinedKeywords.count + customKeywordCount
        print("📊 Generated \(rules.count) content blocker rules — core: \(coreCount), custom domains: \(customDomainCount), API domains: \(apiDomainCount), keyword: \(keywordCount), cosmetic: \(cosmeticRules.count)")
        return rules
    }

    // MARK: - Rule Builders

    /// Evenly samples up to `cap` domains across the full downloaded list so
    /// coverage is spread across the whole list rather than truncated.
    private func sampledAPIDomains(cap: Int) -> [String] {
        guard apiBlocklist.count > cap else { return apiBlocklist }
        let step = Double(apiBlocklist.count) / Double(cap)
        return (0..<cap).map { apiBlocklist[Int(Double($0) * step)] }
    }

    /// A block rule for a single domain. Domains only ever contain `.` as a
    /// regex metacharacter, so escaping is cheap.
    private func domainRule(for domain: String) -> ContentBlockerRule {
        let escaped = domain.replacingOccurrences(of: ".", with: "\\.")
        return ContentBlockerRule(
            trigger: ContentBlockerTrigger(urlFilter: ".*\(escaped).*"),
            action: ContentBlockerAction(type: "block")
        )
    }

    /// A block rule for a keyword url-filter, exempting search engines and
    /// whitelisted domains so search and trusted sites keep working.
    private func keywordRule(filter: String, exemptDomains: [String]) -> ContentBlockerRule {
        ContentBlockerRule(
            trigger: ContentBlockerTrigger(
                urlFilter: filter,
                unlessDomain: exemptDomains.isEmpty ? nil : exemptDomains
            ),
            action: ContentBlockerAction(type: "block")
        )
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
            "hentai", "porn", "xxx"
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

    /// Schedules a content blocker rebuild. Rapid callers (bulk keyword/domain
    /// edits, launch, downloads) are coalesced into a single rebuild + reload.
    func updateContentBlocker() {
        // Subscription status is cheap and read directly by the extension —
        // keep it immediate rather than debounced.
        saveSubscriptionStatusToSharedStorage()

        contentBlockerUpdateTask?.cancel()
        contentBlockerUpdateTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s debounce window
            guard !Task.isCancelled, let self else { return }
            await self.rebuildContentBlocker()
        }
    }

    /// Builds the ruleset, writes it off the main actor, then reloads Safari.
    private func rebuildContentBlocker() async {
        let subscribed = SubscriptionManager.shared.isSubscribed
        let rules = subscribed ? generateContentBlockerRules() : generateNoopContentBlockerRules()

        await Self.writeContentBlockerRules(rules, appGroupIdentifier: appGroupIdentifier)

        let success = await enableContentBlocker()
        print("Content blocker reloaded — \(rules.count) rules, subscribed: \(subscribed), success: \(success)")
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
    
    /// Encodes the ruleset and writes it to the shared container (plus a
    /// documents-directory copy). Runs entirely off the main actor — encoding a
    /// large ruleset is far too heavy to do on the main thread.
    nonisolated private static func writeContentBlockerRules(
        _ rules: [ContentBlockerRule],
        appGroupIdentifier: String
    ) async {
        await Task.detached(priority: .userInitiated) {
            do {
                let data = try JSONEncoder().encode(rules)
                // Round-trip through JSONSerialization to confirm it parses.
                _ = try JSONSerialization.jsonObject(with: data)

                let fileManager = FileManager.default
                if let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
                    try data.write(to: containerURL.appendingPathComponent("blockerList.json"))
                }
                if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                    try data.write(to: documentsURL.appendingPathComponent("blockerList.json"))
                }
                print("Saved \(rules.count) content blocker rules (\(data.count) bytes)")
            } catch {
                print("Error saving content blocker rules: \(error)")
            }
        }.value
    }
    
    // MARK: - Helper Methods
    
    /// Normalizes user-entered text down to a bare host: lowercased, scheme and
    /// `www.` removed, and path / query / fragment / port stripped so that
    /// `https://pornhub.com/videos?x=1` is stored simply as `pornhub.com`.
    private func cleanURL(_ url: String) -> String {
        var host = url.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let schemeRange = host.range(of: "://") {
            host = String(host[schemeRange.upperBound...])
        }
        if host.hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }
        if let end = host.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" || $0 == ":" }) {
            host = String(host[..<end])
        }
        return host
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
        updateSets()
    }
    
    // MARK: - Content Blocker Integration
    
    func enableContentBlocker() async -> Bool {
        // Capture subscription status on main actor before entering background context
        let isSubscribed = SubscriptionManager.shared.isSubscribed
        
        return await withCheckedContinuation { continuation in
            #if os(iOS)
            let extensionIdentifier = "com.jose.pimentel.Porn-Blocker.ContentBlocker"
            
            SFContentBlockerManager.reloadContentBlocker(withIdentifier: extensionIdentifier) { error in
                if let error = error {
                    print("Error reloading content blocker: \(error)")
                    continuation.resume(returning: false)
                } else {
                    let statusMessage = isSubscribed ? "with blocking rules" : "with empty rules (not subscribed)"
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
