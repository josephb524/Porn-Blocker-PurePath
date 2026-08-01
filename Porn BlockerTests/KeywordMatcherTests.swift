import XCTest
@testable import Porn_Blocker

/// Covers the two-tier keyword system: substring keywords match anywhere,
/// word keywords require non-letter delimiters (the "sex" in "essex" rule).
final class KeywordMatcherTests: XCTestCase {

    // MARK: - Substring tier

    func testSubstringKeywordMatchesAnywhere() {
        XCTAssertTrue(KeywordMatcher.isBlocked(url: "https://freexxxvideos.example.com", customKeywords: []))
        XCTAssertTrue(KeywordMatcher.isBlocked(url: "https://example.com/watch?v=pornclip", customKeywords: []))
    }

    func testMatchingIsCaseInsensitive() {
        XCTAssertTrue(KeywordMatcher.isBlocked(url: "https://EXAMPLE.com/PORN", customKeywords: []))
    }

    // MARK: - Word-bounded tier

    func testWordKeywordRequiresDelimiters() {
        // "sex" inside "essex" must NOT match…
        XCTAssertFalse(KeywordMatcher.isBlocked(url: "https://www.essex.ac.uk/students", customKeywords: []))
        // …but delimited it must.
        XCTAssertTrue(KeywordMatcher.isBlocked(url: "https://example.com/sex/videos", customKeywords: []))
    }

    func testCommonFalsePositivesAreNotBlocked() {
        XCTAssertFalse(KeywordMatcher.isBlocked(url: "https://translate.google.com", customKeywords: []))   // "trans"
        XCTAssertFalse(KeywordMatcher.isBlocked(url: "https://www.canalplus.com", customKeywords: []))      // "anal"
        XCTAssertFalse(KeywordMatcher.isBlocked(url: "https://gaylord-hotels.example", customKeywords: [])) // "gay"
    }

    // MARK: - Custom keywords

    func testCustomKeywordsAreWordBounded() {
        XCTAssertTrue(KeywordMatcher.isBlocked(url: "https://example.com/cats/", customKeywords: ["cats"]))
        XCTAssertFalse(KeywordMatcher.isBlocked(url: "https://concatsstring.example", customKeywords: ["cats"]))
    }

    func testTooShortCustomKeywordsAreIgnored() {
        XCTAssertFalse(KeywordMatcher.isBlocked(url: "https://a.example.com/a", customKeywords: ["a", " ", ""]))
    }

    // MARK: - Safari url-filters

    func testPredefinedURLFilterShapes() {
        let filters = KeywordMatcher.predefinedURLFilters()
        XCTAssertEqual(filters.count, KeywordMatcher.predefinedKeywords.count)
        XCTAssertTrue(filters.contains(".*porn.*"), "substring keywords use plain wildcard filters")
        XCTAssertTrue(filters.contains(".*[^a-z]sex[^a-z].*"), "word keywords use bounded filters")
    }

    func testCustomURLFilter() {
        XCTAssertNil(KeywordMatcher.customURLFilter(for: "x"))
        XCTAssertNil(KeywordMatcher.customURLFilter(for: "  "))
        XCTAssertEqual(KeywordMatcher.customURLFilter(for: "Casino"), ".*[^a-z]casino[^a-z].*")
    }

    func testCustomURLFilterEscapesRegexMetacharacters() {
        XCTAssertEqual(KeywordMatcher.customURLFilter(for: "a.b"), ".*[^a-z]a\\.b[^a-z].*")
    }
}
