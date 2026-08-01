import XCTest
@testable import Porn_Blocker

/// Covers the browser session models and the on-disk store. File tests write
/// to the test host's own Documents sandbox — nothing user-visible.
final class BrowserTabStoreTests: XCTestCase {

    private var sessionFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("safe_browser_tabs.json")
    }

    func testBrowserTabDefaults() {
        let tab = BrowserTab()
        XCTAssertEqual(tab.urlString, "https://www.google.com")
        XCTAssertNil(tab.title)
        XCTAssertNil(tab.interactionState)
    }

    func testSnapshotJSONRoundTrip() throws {
        let tabs = [
            BrowserTab(urlString: "https://a.com", title: "A", interactionState: Data([1, 2, 3])),
            BrowserTab(urlString: "https://b.com")
        ]
        let snapshot = TabSessionSnapshot(activeTabID: tabs[1].id, tabs: tabs)

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(TabSessionSnapshot.self, from: data)

        XCTAssertEqual(decoded.tabs.map(\.id), tabs.map(\.id))
        XCTAssertEqual(decoded.tabs[0].interactionState, Data([1, 2, 3]))
        XCTAssertEqual(decoded.tabs[0].title, "A")
        XCTAssertEqual(decoded.activeTabID, tabs[1].id)
    }

    func testStoreRoundTrip() async {
        let store = BrowserTabStore()
        let tab = BrowserTab(urlString: "https://roundtrip.example", title: "RT")

        await store.save(TabSessionSnapshot(activeTabID: tab.id, tabs: [tab]))
        let loaded = await store.load()

        XCTAssertEqual(loaded?.tabs.count, 1)
        XCTAssertEqual(loaded?.tabs.first?.urlString, "https://roundtrip.example")
        XCTAssertEqual(loaded?.activeTabID, tab.id)
    }

    func testCorruptFileLoadsAsNil() async throws {
        try Data("definitely not json".utf8).write(to: sessionFileURL)
        let store = BrowserTabStore()
        let loaded = await store.load()
        XCTAssertNil(loaded, "a corrupt session falls back to a fresh one, never crashes")
    }
}
