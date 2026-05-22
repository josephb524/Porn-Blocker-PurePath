import Foundation
import SwiftUI
import SafariServices

/// Observable facade over the app's blocking state.
///
/// It owns the published lists the UI binds to and orchestrates updates, but
/// delegates the heavy lifting:
/// - `BlocklistRepository` — the downloaded domain list (fetch / parse / cache)
/// - `ContentBlockerRuleBuilder` — Safari content-blocker rule generation
/// - `KeywordMatcher` — keyword detection
@MainActor
class BlocklistManager: ObservableObject {
    static let shared = BlocklistManager()

    // MARK: - Published State

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

    /// Predefined adult-content keywords. Owned by `KeywordMatcher` so the
    /// Safe Browser and the content blocker stay in sync.
    var predefinedKeywords: [String] { KeywordMatcher.predefinedKeywords }
    var allKeywords: [String] { predefinedKeywords + keywordBlocklist }
    var totalKeywordCount: Int { allKeywords.count }

    // Performance-optimized Sets for O(1) lookups in the Safe Browser.
    var apiBlocklistSet: Set<String> = []
    var customBlocklistSet: Set<String> = []
    var keywordBlocklistSet: Set<String> = []
    var whitelistSet: Set<String> = []

    // MARK: - Private

    private let userDefaults = UserDefaults.standard
    private let appGroupIdentifier = "group.com.jose.pimentel.PornBlocker"
    private let extensionIdentifier = "com.jose.pimentel.Porn-Blocker.ContentBlocker"

    private let repository = BlocklistRepository()

    /// Pending debounced content blocker rebuild — see `updateContentBlocker()`.
    private var contentBlockerUpdateTask: Task<Void, Never>?
    private var subscriptionObserver: NSObjectProtocol?

    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    // MARK: - Init

    init() {
        self.isEnabled = userDefaults.bool(forKey: "isEnabled")
        self.strictImageMode = userDefaults.bool(forKey: "strictImageMode")
        loadLocalData()

        // React to subscription changes without SubscriptionManager needing a
        // reference back to us (breaks the old circular dependency).
        subscriptionObserver = NotificationCenter.default.addObserver(
            forName: .subscriptionStatusChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateSubscriptionStatus() }
        }

        // Save initial subscription status so the extension has fresh data,
        // then reflect the current state in the content blocker (debounced).
        saveSubscriptionStatusToSharedStorage()
        updateContentBlocker()

        // Load the cached domain list off the main actor so launch isn't
        // blocked, then download a fresh copy if it's stale.
        Task { [weak self] in
            guard let self else { return }
            let cached = await self.repository.loadCache()
            if !cached.isEmpty {
                await self.applyAPIDomains(cached)
                print("BlocklistManager: loaded \(cached.count) cached domains")
                self.updateContentBlocker()
            }
            if await self.repository.needsRefresh(haveCachedDomains: !cached.isEmpty) {
                await self.refreshBlocklist()
            }
        }
    }

    deinit {
        if let subscriptionObserver {
            NotificationCenter.default.removeObserver(subscriptionObserver)
        }
    }

    // MARK: - Domain List

    /// Downloads a fresh domain list and rebuilds the content blocker.
    func refreshBlocklist() async {
        isLoading = true
        defer { isLoading = false }

        guard let domains = await repository.downloadDomains() else { return }
        await applyAPIDomains(domains)
        lastUpdated = Date()
        await repository.saveCache(domains)
        saveLocalData()
        updateContentBlocker()
        print("BlocklistManager: refreshed — \(domains.count) domains")
    }

    func forceRefreshBlocklist() async {
        await refreshBlocklist()
    }

    func getCacheInfo() -> (domains: Int, lastUpdate: Date?) {
        (apiBlocklist.count, userDefaults.object(forKey: "apiBlocklistLastUpdate") as? Date)
    }

    /// Publishes a new API domain list, building the lookup Set off the main actor.
    private func applyAPIDomains(_ domains: [String]) async {
        let set = await Task.detached(priority: .utility) {
            Set(domains.map { $0.lowercased().trimmingCharacters(in: .whitespaces) })
        }.value
        apiBlocklist = domains
        apiBlocklistSet = set
    }

    // MARK: - Lookup Helpers

    func updateSets() {
        customBlocklistSet = Set(customBlocklist.map { $0.lowercased().trimmingCharacters(in: .whitespaces) })
        keywordBlocklistSet = Set(keywordBlocklist.map { $0.lowercased().trimmingCharacters(in: .whitespaces) })
        whitelistSet = Set(whitelist.map { $0.lowercased().trimmingCharacters(in: .whitespaces) })
    }

    /// Whether `host` is a known search engine (never keyword-blocked).
    func isSearchEngine(_ host: String) -> Bool {
        let cleanHost = host.lowercased().trimmingCharacters(in: .whitespaces)
        return ContentBlockerRuleBuilder.searchEngineDomains.contains { domain in
            cleanHost == domain || cleanHost.hasSuffix(".\(domain)")
        }
    }

    // MARK: - Custom Blocklist

    func addToCustomBlocklist(_ url: String) {
        let cleaned = cleanURL(url)
        guard !cleaned.isEmpty, !customBlocklist.contains(cleaned) else { return }
        customBlocklist.append(cleaned)
        saveLocalData()
        updateContentBlocker()
    }

    func removeFromCustomBlocklist(_ url: String) {
        customBlocklist.removeAll { $0 == url }
        saveLocalData()
        updateContentBlocker()
    }

    // MARK: - Keyword Blocklist

    func addToKeywordBlocklist(_ keyword: String) {
        let cleaned = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !keywordBlocklist.contains(cleaned) else { return }
        keywordBlocklist.append(cleaned)
        saveLocalData()
        updateContentBlocker()
    }

    func removeFromKeywordBlocklist(_ keyword: String) {
        keywordBlocklist.removeAll { $0 == keyword }
        saveLocalData()
        updateContentBlocker()
    }

    // MARK: - Whitelist

    func addToWhitelist(_ url: String) {
        guard SubscriptionManager.shared.isSubscribed else { return }
        let cleaned = cleanURL(url)
        guard !cleaned.isEmpty, !whitelist.contains(cleaned) else { return }
        whitelist.append(cleaned)
        saveLocalData()
        updateContentBlocker()
    }

    func removeFromWhitelist(_ url: String) {
        guard SubscriptionManager.shared.isSubscribed else { return }
        whitelist.removeAll { $0 == url }
        saveLocalData()
        updateContentBlocker()
    }

    // MARK: - Content Blocker

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
        let rules: [ContentBlockerRule]
        if subscribed {
            let input = ContentBlockerRuleBuilder.Input(
                customDomains: customBlocklist,
                customKeywords: keywordBlocklist,
                whitelist: whitelistSet,
                apiDomains: apiBlocklist,
                strictImageMode: strictImageMode
            )
            rules = ContentBlockerRuleBuilder.build(input)
        } else {
            rules = ContentBlockerRuleBuilder.noopRules()
        }

        await ContentBlockerRuleBuilder.write(rules, appGroupIdentifier: appGroupIdentifier)

        let success = await enableContentBlocker()
        print("BlocklistManager: content blocker reloaded — \(rules.count) rules, subscribed: \(subscribed), success: \(success)")
    }

    /// Reloads the Safari content blocker extension.
    @discardableResult
    func enableContentBlocker() async -> Bool {
        await withCheckedContinuation { continuation in
            #if os(iOS)
            SFContentBlockerManager.reloadContentBlocker(withIdentifier: extensionIdentifier) { error in
                if let error {
                    print("BlocklistManager: error reloading content blocker — \(error)")
                    continuation.resume(returning: false)
                } else {
                    continuation.resume(returning: true)
                }
            }
            #else
            continuation.resume(returning: true)
            #endif
        }
    }

    /// Whether the user has enabled the content blocker in Settings.
    func checkContentBlockerStatus() async -> Bool {
        await withCheckedContinuation { continuation in
            #if os(iOS)
            SFContentBlockerManager.getStateOfContentBlocker(withIdentifier: extensionIdentifier) { state, error in
                if let error {
                    print("BlocklistManager: error checking content blocker status — \(error)")
                    continuation.resume(returning: false)
                } else {
                    continuation.resume(returning: state?.isEnabled ?? false)
                }
            }
            #else
            continuation.resume(returning: true)
            #endif
        }
    }

    /// Diagnostic: confirms the core bundled ruleset can be loaded.
    func verifyCoreBlockingRules() -> (isLoaded: Bool, count: Int, sampleRules: [String]) {
        guard let bundleRules = ContentBlockerRuleBuilder.loadBundleRules() else {
            print("BlocklistManager: ❌ core blocking rules could not be loaded from bundle")
            return (false, 0, [])
        }
        let sample = bundleRules.prefix(5).map { $0.trigger.urlFilter }
        return (true, bundleRules.count, Array(sample))
    }

    // MARK: - Subscription Status

    /// Mirrors the current subscription status into the shared container (JSON
    /// file + app-group UserDefaults) for the content blocker extension.
    func saveSubscriptionStatusToSharedStorage() {
        let isSubscribed = SubscriptionManager.shared.isSubscribed
        let expiryTimestamp = SubscriptionManager.shared.expiryDate?.timeIntervalSince1970

        // Robust secondary source the extension falls back to if the JSON file
        // below is ever missing or corrupt.
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
            print("BlocklistManager: failed to access shared container for subscription status")
            return
        }
        let statusURL = containerURL.appendingPathComponent("subscriptionStatus.json")
        let payload: [String: Any] = [
            "isSubscribed": isSubscribed,
            "expiryDate": expiryTimestamp as Any,
            "lastUpdated": Date().timeIntervalSince1970
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            try data.write(to: statusURL)
        } catch {
            print("BlocklistManager: error saving subscription status — \(error)")
        }
    }

    /// Called when the subscription status changes (via notification).
    func updateSubscriptionStatus() {
        saveSubscriptionStatusToSharedStorage()
        updateContentBlocker()
    }

    // MARK: - Local Storage

    private func saveLocalData() {
        userDefaults.set(customBlocklist, forKey: "customBlocklist")
        userDefaults.set(keywordBlocklist, forKey: "keywordBlocklist")
        userDefaults.set(whitelist, forKey: "whitelist")
        userDefaults.set(lastUpdated, forKey: "lastUpdated")
    }

    private func loadLocalData() {
        customBlocklist = userDefaults.stringArray(forKey: "customBlocklist") ?? []
        keywordBlocklist = userDefaults.stringArray(forKey: "keywordBlocklist") ?? []
        whitelist = userDefaults.stringArray(forKey: "whitelist") ?? []
        lastUpdated = userDefaults.object(forKey: "lastUpdated") as? Date
        updateSets()
    }

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
}
