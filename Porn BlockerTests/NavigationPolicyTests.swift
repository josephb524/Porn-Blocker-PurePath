import XCTest
import WebKit
@testable import Porn_Blocker

/// Covers the Safe Browser's universal-link containment. iOS hands a tapped
/// Google link to the Google app, which has none of this app's filtering — so
/// those taps are cancelled and re-issued programmatically. The two assertions
/// that matter most: `.other` returns false (the re-entry loop guard) and
/// non-Google hosts are untouched.
final class NavigationPolicyTests: XCTestCase {

    private func shouldLoadInPlace(_ urlString: String,
                                   from currentURLString: String? = nil,
                                   type: WKNavigationType = .linkActivated,
                                   method: String? = nil) -> Bool {
        SafeWebView.Coordinator.shouldLoadInPlace(
            url: URL(string: urlString)!,
            currentURL: currentURLString.flatMap { URL(string: $0) },
            navigationType: type,
            httpMethod: method
        )
    }

    // MARK: - The host predicate

    /// `isAppHandoffHost` also gates tab hydration — a tab on one of these
    /// hosts skips `interactionState` restore, because WebKit's replay of the
    /// session is what launched the Google app on reopen.
    func testAppHandoffHostsAreRecognized() {
        let isHandoff = SafeWebView.Coordinator.isAppHandoffHost
        XCTAssertTrue(isHandoff("google.com"))
        XCTAssertTrue(isHandoff("www.google.com"))
        XCTAssertTrue(isHandoff("news.google.com"))
        XCTAssertTrue(isHandoff("WWW.GOOGLE.COM"))
        XCTAssertTrue(isHandoff("goo.gl"))
        XCTAssertTrue(isHandoff("g.co"))

        XCTAssertFalse(isHandoff("notgoogle.com"))
        XCTAssertFalse(isHandoff("google.com.evil.net"))
        XCTAssertFalse(isHandoff("example.com"))
    }

    // MARK: - Google hosts are contained

    func testGoogleLinkTapsLoadInPlace() {
        XCTAssertTrue(shouldLoadInPlace("https://google.com/search?q=x"))
        XCTAssertTrue(shouldLoadInPlace("https://www.google.com/search?q=x&tbm=isch"))
        XCTAssertTrue(shouldLoadInPlace("https://news.google.com/"))
        XCTAssertTrue(shouldLoadInPlace("http://www.google.com/"))
    }

    func testGoogleShortenerDomainsLoadInPlace() {
        XCTAssertTrue(shouldLoadInPlace("https://goo.gl/maps/abc"))
        XCTAssertTrue(shouldLoadInPlace("https://g.co/kgs/abc"))
    }

    // MARK: - Everything else is left alone

    func testNonGoogleHostsAreAllowedNormally() {
        XCTAssertFalse(shouldLoadInPlace("https://example.com/page"))
        XCTAssertFalse(shouldLoadInPlace("https://en.wikipedia.org/wiki/Search"))
    }

    func testLookalikeHostsAreNotTreatedAsGoogle() {
        XCTAssertFalse(shouldLoadInPlace("https://notgoogle.com/search?q=x"))
        XCTAssertFalse(shouldLoadInPlace("https://google.com.evil.net/search?q=x"))
        XCTAssertFalse(shouldLoadInPlace("https://mygoo.gl/x"))
    }

    func testNonWebSchemesAreLeftToTheSystem() {
        XCTAssertFalse(shouldLoadInPlace("mailto:someone@google.com"))
        XCTAssertFalse(shouldLoadInPlace("tel:+15551234567"))
    }

    // MARK: - The loop and history guards

    func testOnlyUserActivatedNavigationsAreReissued() {
        let url = "https://www.google.com/search?q=x"
        // `.other` is what the re-issued load itself comes back as — returning
        // true here would cancel/reload forever.
        XCTAssertFalse(shouldLoadInPlace(url, type: .other))
        // Cancelling these and calling load() would corrupt the back stack.
        XCTAssertFalse(shouldLoadInPlace(url, type: .backForward))
        XCTAssertFalse(shouldLoadInPlace(url, type: .reload))
    }

    func testGetFormSubmissionsAreReissuedButPostIsNot() {
        let url = "https://www.google.com/search?q=x"
        // Submitting Google's search box carries a user gesture and hands off.
        XCTAssertTrue(shouldLoadInPlace(url, type: .formSubmitted, method: "GET"))
        XCTAssertTrue(shouldLoadInPlace(url, type: .formSubmitted, method: nil))
        // WebKit doesn't expose httpBody, so re-issuing a POST would submit an
        // empty form — worse than letting it through.
        XCTAssertFalse(shouldLoadInPlace(url, type: .formSubmitted, method: "POST"))
    }

    // MARK: - The anchor guard

    func testSamePageAnchorIsNotReloaded() {
        XCTAssertFalse(shouldLoadInPlace("https://www.google.com/search?q=x#results",
                                         from: "https://www.google.com/search?q=x"))
        XCTAssertFalse(shouldLoadInPlace("https://www.google.com/search?q=x#bottom",
                                         from: "https://www.google.com/search?q=x#top"))
    }

    func testDifferentGooglePageStillLoadsInPlace() {
        XCTAssertTrue(shouldLoadInPlace("https://www.google.com/search?q=y#results",
                                        from: "https://www.google.com/search?q=x"))
        XCTAssertTrue(shouldLoadInPlace("https://www.google.com/maps",
                                        from: "https://www.google.com/search?q=x"))
    }
}
