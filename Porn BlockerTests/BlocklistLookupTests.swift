import XCTest
@testable import Porn_Blocker

/// Covers the host-matching lookups and URL normalization on
/// `BlocklistManager`. Uses the shared instance (its init has launch side
/// effects; the app host has already paid them) — the methods under test
/// only read their parameters.
@MainActor
final class BlocklistLookupTests: XCTestCase {

    private var manager: BlocklistManager { BlocklistManager.shared }

    // MARK: - hostMatches (O(labels) suffix walk)

    func testHostMatchesExactAndSubdomains() {
        let set: Set<String> = ["example.com", "b.tracker.net"]
        XCTAssertTrue(manager.hostMatches("example.com", anyDomainIn: set))
        XCTAssertTrue(manager.hostMatches("a.example.com", anyDomainIn: set))
        XCTAssertTrue(manager.hostMatches("deep.a.example.com", anyDomainIn: set))
        XCTAssertTrue(manager.hostMatches("x.b.tracker.net", anyDomainIn: set),
                      "multi-label entries must match their subdomains")
    }

    func testHostMatchesRejectsLookalikes() {
        let set: Set<String> = ["example.com"]
        XCTAssertFalse(manager.hostMatches("notexample.com", anyDomainIn: set))
        XCTAssertFalse(manager.hostMatches("example.com.evil.net", anyDomainIn: set),
                       "a blocked domain used as a subdomain of another host must not match")
        XCTAssertFalse(manager.hostMatches("example.org", anyDomainIn: set))
        XCTAssertFalse(manager.hostMatches("example.com", anyDomainIn: []))
    }

    // MARK: - isSearchEngine

    func testIsSearchEngine() {
        XCTAssertTrue(manager.isSearchEngine("google.com"))
        XCTAssertTrue(manager.isSearchEngine("www.google.com"))
        XCTAssertTrue(manager.isSearchEngine("duckduckgo.com"))
        XCTAssertFalse(manager.isSearchEngine("notgoogle.com"))
        XCTAssertFalse(manager.isSearchEngine("example.com"))
    }

    // MARK: - cleanURL normalization

    func testCleanURLNormalization() {
        XCTAssertEqual(manager.cleanURL("https://www.Example.com/videos?x=1#top"), "example.com")
        XCTAssertEqual(manager.cleanURL("HTTP://example.com:8080/path"), "example.com")
        XCTAssertEqual(manager.cleanURL("  example.com  "), "example.com")
        XCTAssertEqual(manager.cleanURL("www.example.com"), "example.com")
    }
}
