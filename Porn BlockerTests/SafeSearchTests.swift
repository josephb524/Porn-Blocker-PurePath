import XCTest
@testable import Porn_Blocker

/// Covers the Safe Browser's safe-search URL rewriting. The nil-on-compliant
/// contract is the reload-loop guard — the single most important assertion
/// here is idempotency.
final class SafeSearchTests: XCTestCase {

    private func enforced(_ urlString: String) -> URL? {
        SafeWebView.Coordinator.safeSearchEnforcedURL(for: URL(string: urlString)!)
    }

    // MARK: - Per-engine enforcement

    func testGoogleSearchGetsSafeActive() throws {
        let result = try XCTUnwrap(enforced("https://www.google.com/search?q=flowers"))
        XCTAssertTrue(result.absoluteString.contains("safe=active"))
    }

    func testWrongParameterValueIsReplaced() throws {
        let result = try XCTUnwrap(enforced("https://www.google.com/search?q=flowers&safe=off"))
        XCTAssertTrue(result.absoluteString.contains("safe=active"))
        XCTAssertFalse(result.absoluteString.contains("safe=off"))
    }

    func testBingVariantsGetAdltStrict() throws {
        let web = try XCTUnwrap(enforced("https://www.bing.com/search?q=x"))
        XCTAssertTrue(web.absoluteString.contains("adlt=strict"))
        let images = try XCTUnwrap(enforced("https://www.bing.com/images/search?q=x"))
        XCTAssertTrue(images.absoluteString.contains("adlt=strict"))
    }

    func testDuckDuckGoGetsKP1() throws {
        let result = try XCTUnwrap(enforced("https://duckduckgo.com/?q=x"))
        XCTAssertTrue(result.absoluteString.contains("kp=1"))
    }

    func testYahooGetsVMR() throws {
        let result = try XCTUnwrap(enforced("https://es.search.yahoo.com/search?p=x"))
        XCTAssertTrue(result.absoluteString.contains("vm=r"))
    }

    func testEcosiaGetsSafesearch2() throws {
        let result = try XCTUnwrap(enforced("https://www.ecosia.org/search?q=x"))
        XCTAssertTrue(result.absoluteString.contains("safesearch=2"))
    }

    // MARK: - The loop guard

    func testEnforcedURLIsIdempotent() throws {
        let once = try XCTUnwrap(enforced("https://www.google.com/search?q=flowers"))
        XCTAssertNil(SafeWebView.Coordinator.safeSearchEnforcedURL(for: once),
                     "re-enforcing must return nil — this prevents an infinite reload loop")
    }

    // MARK: - Out of scope URLs

    func testHomepagesAndNonSearchPathsAreIgnored() {
        XCTAssertNil(enforced("https://www.google.com/"))
        XCTAssertNil(enforced("https://www.google.com/maps?q=pizza"))
        XCTAssertNil(enforced("https://duckduckgo.com/about"))
    }

    func testQueryTermIsRequired() {
        XCTAssertNil(enforced("https://www.google.com/search"))
        XCTAssertNil(enforced("https://www.bing.com/search"))
    }

    func testUnrelatedAndLookalikeHostsAreIgnored() {
        XCTAssertNil(enforced("https://example.com/search?q=x"))
        XCTAssertNil(enforced("https://notgoogle.com/search?q=x"))
    }
}
