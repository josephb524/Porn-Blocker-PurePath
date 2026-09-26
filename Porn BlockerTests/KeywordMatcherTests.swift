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

    // MARK: - Non-English keywords

    func testSpanishPortugueseGermanKeywordsBlock() {
        for url in ["https://example.com/videos/sexo-casero",        // es/pt word
                    "https://example.com/chicas-desnudas/",          // es
                    "https://example.com/buceta-gratis",             // pt substring
                    "https://example.com/putaria/",                  // pt word
                    "https://example.com/nackte-frauen",             // de word
                    "https://example.com/grossetitten"] {            // de substring
            XCTAssertTrue(KeywordMatcher.isBlocked(url: url, customKeywords: []), url)
        }
    }

    func testNonEnglishFalsePositivesAreNotBlocked() {
        for url in ["https://www.computadora.example/ofertas",       // "puta"
                    "https://turismo.example/tren-transandino",      // "transando"
                    "https://example.com/fickle-weather",            // "fick"
                    "https://de.wikipedia.org/wiki/Nacktschnecke",   // "nackt"
                    "https://example.com/sexologia"] {               // "sexo"
            XCTAssertFalse(KeywordMatcher.isBlocked(url: url, customKeywords: []), url)
        }
    }

    func testKeywordsAreLowercaseASCII() {
        // URLs arrive percent-encoded and Safari's boundary is [^a-z], so an
        // accented or uppercase keyword could never match.
        for keyword in KeywordMatcher.predefinedKeywords {
            XCTAssertTrue(keyword.allSatisfy { ("a"..."z").contains($0) }, keyword)
        }
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
