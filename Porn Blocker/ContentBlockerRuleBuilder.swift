import Foundation

// MARK: - Content Blocker Models

/// One Safari content-blocker rule (`trigger` + `action`).
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
        self.urlFilter     = urlFilter
        self.ifDomain      = ifDomain
        self.unlessDomain  = unlessDomain
        self.resourceTypes = resourceTypes
    }

    enum CodingKeys: String, CodingKey {
        case urlFilter     = "url-filter"
        case ifDomain      = "if-domain"
        case unlessDomain  = "unless-domain"
        case resourceTypes = "resource-type"
    }

    /// Omit nil optionals so the emitted JSON stays clean.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(urlFilter, forKey: .urlFilter)
        if let ifDomain      { try container.encode(ifDomain, forKey: .ifDomain) }
        if let unlessDomain  { try container.encode(unlessDomain, forKey: .unlessDomain) }
        if let resourceTypes { try container.encode(resourceTypes, forKey: .resourceTypes) }
    }
}

struct ContentBlockerAction: Codable {
    let type: String
    let selector: String?

    init(type: String, selector: String? = nil) {
        self.type     = type
        self.selector = selector
    }

    enum CodingKeys: String, CodingKey {
        case type, selector
    }

    /// Omit `selector` when nil.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        if let selector { try container.encode(selector, forKey: .selector) }
    }
}

// MARK: - Rule Builder

/// Builds the Safari content-blocker ruleset. Pure, stateless logic — no
/// observable state and no main-actor requirement — so it can be reasoned about
/// and unit-tested in isolation.
enum ContentBlockerRuleBuilder {

    /// Search engines exempt from keyword rules so search itself keeps working.
    /// Single source of truth, also used by the Safe Browser.
    static let searchEngineDomains: Set<String> = [
        "google.com", "bing.com", "duckduckgo.com", "yahoo.com",
        "baidu.com", "yandex.com", "ask.com", "ecosia.org"
    ]

    /// Max downloaded domains fed into the content blocker — well under Safari's
    /// 150k-rule ceiling once core / keyword / cosmetic rules are added.
    private static let maxAPIDomainRules = 35_000
    /// Max user-defined custom keywords turned into rules.
    private static let maxCustomKeywordRules = 50

    /// Everything the builder needs to produce a ruleset.
    struct Input {
        var customDomains: [String]
        var customKeywords: [String]
        var whitelist: Set<String>
        var apiDomains: [String]
        var strictImageMode: Bool
    }

    // MARK: Building

    /// The full blocking ruleset for a subscribed user.
    static func build(_ input: Input) -> [ContentBlockerRule] {
        var rules: [ContentBlockerRule] = []

        // 1. Core static rules from the bundle (never skipped).
        if let bundleRules = loadBundleRules() {
            rules.append(contentsOf: bundleRules)
        } else {
            Log.debug("ContentBlockerRuleBuilder: bundle rules missing — using essential fallback")
            rules.append(contentsOf: essentialStaticRules())
        }
        let coreCount = rules.count

        // 2. Custom domains added by the user.
        var customDomainCount = 0
        for domain in Set(input.customDomains)
        where !input.whitelist.contains(domain) && isValidDomain(domain) {
            rules.append(domainRule(for: domain))
            customDomainCount += 1
        }

        // 3. A capped, evenly-sampled slice of the downloaded domain list.
        var apiDomainCount = 0
        for domain in sampledDomains(input.apiDomains, cap: maxAPIDomainRules)
        where !input.whitelist.contains(domain) {
            rules.append(domainRule(for: domain))
            apiDomainCount += 1
        }

        // 4. Keyword rules — search engines and whitelisted sites are exempt.
        let exemptDomains = Array(searchEngineDomains) + Array(input.whitelist)
        for filter in KeywordMatcher.predefinedURLFilters() {
            rules.append(keywordRule(filter: filter, exemptDomains: exemptDomains))
        }
        var customKeywordCount = 0
        for keyword in input.customKeywords.prefix(maxCustomKeywordRules) {
            guard let filter = KeywordMatcher.customURLFilter(for: keyword) else { continue }
            rules.append(keywordRule(filter: filter, exemptDomains: exemptDomains))
            customKeywordCount += 1
        }

        // 5. CSS cosmetic rules — hide media on pages that partially load.
        let cosmetic = cosmeticRules(strictImageMode: input.strictImageMode, whitelist: input.whitelist)
        rules.append(contentsOf: cosmetic)

        let keywordCount = KeywordMatcher.predefinedKeywords.count + customKeywordCount
        Log.debug("ContentBlockerRuleBuilder: \(rules.count) rules — core \(coreCount), custom domains \(customDomainCount), API domains \(apiDomainCount), keyword \(keywordCount), cosmetic \(cosmetic.count)")
        return rules
    }

    /// A single no-op rule. Safari rejects an empty ruleset, so non-subscribers
    /// get one wide `ignore-previous-rules` rule that blocks nothing.
    static func noopRules() -> [ContentBlockerRule] {
        [ContentBlockerRule(
            trigger: ContentBlockerTrigger(urlFilter: ".*"),
            action: ContentBlockerAction(type: "ignore-previous-rules")
        )]
    }

    // MARK: Persistence

    /// Encodes the ruleset and writes it to the shared container (plus a
    /// documents-directory copy). Runs off the main actor — encoding a large
    /// ruleset is far too heavy for the main thread.
    nonisolated static func write(_ rules: [ContentBlockerRule], appGroupIdentifier: String) async {
        await Task.detached(priority: .userInitiated) {
            do {
                let data = try JSONEncoder().encode(rules)
                _ = try JSONSerialization.jsonObject(with: data) // confirm it parses
                let fileManager = FileManager.default
                if let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
                    try data.write(to: containerURL.appendingPathComponent("blockerList.json"))
                }
                if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                    try data.write(to: documentsURL.appendingPathComponent("blockerList.json"))
                }
                Log.debug("ContentBlockerRuleBuilder: saved \(rules.count) rules (\(data.count) bytes)")
            } catch {
                Log.debug("ContentBlockerRuleBuilder: error saving rules — \(error)")
            }
        }.value
    }

    // MARK: Bundle Rules

    /// Loads the core static ruleset bundled with the app.
    static func loadBundleRules() -> [ContentBlockerRule]? {
        guard let resourceURL = Bundle.main.url(forResource: "blockerList", withExtension: "json") else {
            Log.debug("ContentBlockerRuleBuilder: blockerList.json not found in bundle")
            return nil
        }
        do {
            // Read as text so `// ...` line comments can be stripped first.
            let rawString = try String(contentsOf: resourceURL, encoding: .utf8)
            let cleaned = rawString
                .components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            guard let data = cleaned.data(using: .utf8) else { return nil }
            return try JSONDecoder().decode([ContentBlockerRule].self, from: data)
        } catch {
            Log.debug("ContentBlockerRuleBuilder: error loading bundle rules — \(error)")
            return nil
        }
    }

    // MARK: - Private helpers

    /// Minimal hardcoded ruleset used only if the bundled file fails to load.
    private static func essentialStaticRules() -> [ContentBlockerRule] {
        let sites = [
            "brazzers", "youjizz", "pornhub", "xvideos", "xnxx", "xhamster", "redtube", "youporn",
            "tube8", "spankbang", "beeg", "rule34", "motherless", "efukt", "sex.com", "cam4",
            "livejasmin", "bongacams", "chaturbate", "onlyfans", "fansly", "stripchat", "camsoda",
            "adultfriendfinder", "ashley.madison", "imagefap", "gelbooru", "nhentai", "hanime",
            "hentai", "porn", "xxx"
        ]
        return sites.map {
            ContentBlockerRule(
                trigger: ContentBlockerTrigger(urlFilter: ".*\($0).*"),
                action: ContentBlockerAction(type: "block")
            )
        }
    }

    /// `css-display-none` rules that hide visual media on pages matching adult
    /// URL patterns — these apply even when a page only partially loads.
    private static func cosmeticRules(strictImageMode: Bool, whitelist: Set<String>) -> [ContentBlockerRule] {
        let baseSelector = "img, video, picture, source, canvas, embed, object, iframe"
        let gallerySelector = "[class*='thumb'], [class*='preview'], [class*='gallery-item'], [class*='video-thumb'], [class*='adult'], [class*='porn'], [class*='xxx'], [class*='nude']"
        let fullSelector = baseSelector + ", " + gallerySelector
        let exempt: [String]? = whitelist.isEmpty ? nil : Array(whitelist)

        let adultURLPatterns = [
            ".*porn.*", ".*xxx.*", ".*xvideos.*", ".*xnxx.*", ".*xhamster.*",
            ".*pornhub.*", ".*redtube.*", ".*youporn.*", ".*tube8.*", ".*spankbang.*",
            ".*beeg.*", ".*chaturbate.*", ".*onlyfans.*", ".*fansly.*", ".*brazzers.*",
            ".*hentai.*", ".*nhentai.*", ".*erotic.*", ".*nude.*", ".*naked.*",
            ".*sex\\.com.*", ".*adult.*"
        ]

        var rules: [ContentBlockerRule] = adultURLPatterns.map { pattern in
            ContentBlockerRule(
                trigger: ContentBlockerTrigger(urlFilter: pattern, unlessDomain: exempt),
                action: ContentBlockerAction(type: "css-display-none", selector: baseSelector)
            )
        }

        // Strict Image Mode casts a broader net over suspicious path segments.
        if strictImageMode {
            let strictPatterns = [
                ".*\\/cam.*", ".*\\/live.*sex.*", ".*\\/girls.*",
                ".*\\/babes.*", ".*\\/milf.*", ".*\\/teen.*sex.*",
                ".*\\/fetish.*", ".*\\/bdsm.*"
            ]
            rules += strictPatterns.map { pattern in
                ContentBlockerRule(
                    trigger: ContentBlockerTrigger(urlFilter: pattern, unlessDomain: exempt),
                    action: ContentBlockerAction(type: "css-display-none", selector: fullSelector)
                )
            }
        }
        return rules
    }

    /// Evenly samples up to `cap` domains across `domains` so coverage is spread
    /// across the whole list rather than truncated.
    private static func sampledDomains(_ domains: [String], cap: Int) -> [String] {
        guard domains.count > cap else { return domains }
        let step = Double(domains.count) / Double(cap)
        return (0..<cap).map { domains[Int(Double($0) * step)] }
    }

    /// A block rule for a single domain. Domains only ever contain `.` as a
    /// regex metacharacter, so escaping is cheap.
    private static func domainRule(for domain: String) -> ContentBlockerRule {
        let escaped = domain.replacingOccurrences(of: ".", with: "\\.")
        return ContentBlockerRule(
            trigger: ContentBlockerTrigger(urlFilter: ".*\(escaped).*"),
            action: ContentBlockerAction(type: "block")
        )
    }

    /// A block rule for a keyword url-filter, exempting the given domains.
    private static func keywordRule(filter: String, exemptDomains: [String]) -> ContentBlockerRule {
        ContentBlockerRule(
            trigger: ContentBlockerTrigger(
                urlFilter: filter,
                unlessDomain: exemptDomains.isEmpty ? nil : exemptDomains
            ),
            action: ContentBlockerAction(type: "block")
        )
    }

    private static func isValidDomain(_ domain: String) -> Bool {
        let pattern = "^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]*\\.[a-zA-Z]{2,}$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(in: domain, range: NSRange(location: 0, length: domain.utf16.count)) != nil
    }
}
