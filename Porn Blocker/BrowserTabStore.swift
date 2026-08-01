import Foundation

// MARK: - Browser Tab Models

/// One Safe Browser tab. `interactionState` is the WKWebView session blob
/// (back/forward history + page state) captured for persistence; a tab that
/// was restored from disk but never re-activated keeps its blob untouched.
struct BrowserTab: Codable, Identifiable {
    var id = UUID()
    var urlString: String = "https://www.google.com"
    var title: String?
    var interactionState: Data?
}

/// Everything needed to restore a browsing session across launches.
struct TabSessionSnapshot: Codable {
    var version = 1
    var activeTabID: UUID?
    var tabs: [BrowserTab]
}

// MARK: - Store

/// Persists the tab session to the Documents directory. An actor so encoding
/// and file I/O run off the main actor, and saves serialize — a debounced
/// save can't interleave with the resign-active save.
///
/// A lost session is low-stakes (unlike habit history), so decode failures
/// simply fall back to a fresh session — no per-element salvage.
actor BrowserTabStore {
    private var fileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("safe_browser_tabs.json")
    }

    func load() -> TabSessionSnapshot? {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(TabSessionSnapshot.self, from: data) else {
            Log.debug("BrowserTabStore: no saved session")
            return nil
        }
        Log.debug("BrowserTabStore: restored \(snapshot.tabs.count) tabs")
        return snapshot
    }

    func save(_ snapshot: TabSessionSnapshot) {
        guard let fileURL else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            Log.debug("BrowserTabStore: saved \(snapshot.tabs.count) tabs (\(data.count) bytes)")
        } catch {
            Log.error("BrowserTabStore: save failed — \(error)")
        }
    }
}
