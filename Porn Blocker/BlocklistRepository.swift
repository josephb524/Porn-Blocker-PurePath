import Foundation

/// Owns the downloaded domain blocklist: the remote fetch, hosts-file parsing,
/// and the on-disk JSON cache.
///
/// An `actor` so all of its file and network work runs off the main actor by
/// construction — callers just `await` its methods.
actor BlocklistRepository {

    private let remoteURL = URL(string: "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn/hosts")
    private let refreshInterval: TimeInterval = 24 * 60 * 60
    private let lastUpdateKey = "apiBlocklistLastUpdate"
    /// The StevenBlack porn list has ~300k entries; a much smaller result means
    /// a truncated or broken download we should not trust.
    private let minimumTrustedCount = 100_000

    private var cacheURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("apiBlocklist.json")
    }

    // MARK: - Cache

    /// Loads the cached domain list, or an empty array if there is no cache.
    func loadCache() -> [String] {
        guard let data = try? Data(contentsOf: cacheURL),
              let domains = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return domains
    }

    /// Persists the domain list and records the refresh time.
    func saveCache(_ domains: [String]) {
        do {
            let data = try JSONEncoder().encode(domains)
            try data.write(to: cacheURL)
            UserDefaults.standard.set(Date(), forKey: lastUpdateKey)
            Log.debug("BlocklistRepository: cached \(domains.count) domains")
        } catch {
            Log.debug("BlocklistRepository: failed to save cache — \(error)")
        }
    }

    /// True when there is no cache or it is older than `refreshInterval`.
    func needsRefresh(haveCachedDomains: Bool) -> Bool {
        guard haveCachedDomains else { return true }
        guard let last = UserDefaults.standard.object(forKey: lastUpdateKey) as? Date else { return true }
        return Date().timeIntervalSince(last) >= refreshInterval
    }

    // MARK: - Remote

    /// Downloads and parses the remote hosts file. Returns `nil` on any failure
    /// or if the result is too small to be trustworthy.
    func downloadDomains() async -> [String]? {
        guard let remoteURL else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: remoteURL)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                Log.debug("BlocklistRepository: HTTP \(http.statusCode)")
                return nil
            }
            guard let content = String(data: data, encoding: .utf8) else {
                Log.debug("BlocklistRepository: response was not UTF-8")
                return nil
            }
            let domains = Self.parseHostsFile(content)
            guard domains.count > minimumTrustedCount else {
                Log.debug("BlocklistRepository: only \(domains.count) domains parsed — ignoring")
                return nil
            }
            Log.debug("BlocklistRepository: downloaded \(domains.count) domains")
            return domains
        } catch {
            Log.debug("BlocklistRepository: download failed — \(error)")
            return nil
        }
    }

    // MARK: - Parsing

    /// Parses a `0.0.0.0`-style hosts file into a sorted, lowercased,
    /// de-duplicated list of domains.
    nonisolated static func parseHostsFile(_ content: String) -> [String] {
        var domains = Set<String>()
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let components = trimmed.components(separatedBy: .whitespaces)
            guard components.count >= 2 else { continue }
            let ip = components[0]
            let domain = components[1].lowercased()

            // Skip localhost / broadcast entries.
            if domain == "localhost" || domain == "localhost.localdomain"
                || domain.contains("ip6-") || domain.isEmpty {
                continue
            }
            // Only `0.0.0.0` entries are blocked domains.
            if ip == "0.0.0.0" {
                domains.insert(domain)
            }
        }
        return domains.sorted()
    }
}
