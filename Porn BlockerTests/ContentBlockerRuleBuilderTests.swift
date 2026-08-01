import XCTest
@testable import Porn_Blocker

/// Covers the Safari ruleset builder. These tests run app-hosted on purpose:
/// `loadBundleRules()` reads `Bundle.main`, so the 264 core rules load exactly
/// as they do in production. If the core count changes, update the constants.
final class ContentBlockerRuleBuilderTests: XCTestCase {

    private let coreRuleCount = 264
    private let predefinedKeywordRuleCount = 50
    private let baseCosmeticRuleCount = 22

    private func input(
        customDomains: [String] = [],
        customKeywords: [String] = [],
        whitelist: Set<String> = [],
        apiDomains: [String] = [],
        strictImageMode: Bool = false
    ) -> ContentBlockerRuleBuilder.Input {
        ContentBlockerRuleBuilder.Input(
            customDomains: customDomains,
            customKeywords: customKeywords,
            whitelist: whitelist,
            apiDomains: apiDomains,
            strictImageMode: strictImageMode
        )
    }

    func testNoopRulesIsASingleIgnoreRule() {
        let rules = ContentBlockerRuleBuilder.noopRules()
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules[0].action.type, "ignore-previous-rules")
        XCTAssertEqual(rules[0].trigger.urlFilter, ".*")
    }

    func testBaselineBuildComposition() {
        let rules = ContentBlockerRuleBuilder.build(input())
        let blocks = rules.filter { $0.action.type == "block" }
        let cosmetic = rules.filter { $0.action.type == "css-display-none" }
        XCTAssertEqual(blocks.count, coreRuleCount + predefinedKeywordRuleCount)
        XCTAssertEqual(cosmetic.count, baseCosmeticRuleCount)
        XCTAssertFalse(rules.contains { $0.action.type == "ignore-previous-rules" },
                       "no exemption rule without a whitelist")
    }

    /// The single most load-bearing invariant of the ruleset: the whitelist
    /// exemption is one `ignore-previous-rules` rule and it comes LAST —
    /// it only cancels rules that precede it.
    func testWhitelistExemptionRuleIsLast() throws {
        let rules = ContentBlockerRuleBuilder.build(input(whitelist: ["example.com", "allowed.org"]))
        let last = try XCTUnwrap(rules.last)
        XCTAssertEqual(last.action.type, "ignore-previous-rules")
        XCTAssertEqual(last.trigger.urlFilter, ".*")
        XCTAssertEqual(last.trigger.ifDomain, ["*allowed.org", "*example.com"],
                       "sorted hosts with the * subdomain prefix")
        XCTAssertEqual(rules.filter { $0.action.type == "ignore-previous-rules" }.count, 1)
    }

    func testWhitelistedCustomDomainProducesNoBlockRule() {
        let rules = ContentBlockerRuleBuilder.build(
            input(customDomains: ["blocked.com", "allowed.com"], whitelist: ["allowed.com"])
        )
        XCTAssertTrue(rules.contains { $0.trigger.urlFilter == ".*blocked\\.com.*" })
        XCTAssertFalse(rules.contains { $0.trigger.urlFilter == ".*allowed\\.com.*" && $0.action.type == "block" })
    }

    func testInvalidCustomDomainsAreFiltered() {
        let baseline = ContentBlockerRuleBuilder.build(input()).count
        let rules = ContentBlockerRuleBuilder.build(input(customDomains: ["not a domain", "-bad-", "ok.com"]))
        XCTAssertEqual(rules.count, baseline + 1, "only ok.com should produce a rule")
    }

    func testKeywordRulesExemptSearchEnginesAndWhitelist() throws {
        let rules = ContentBlockerRuleBuilder.build(input(whitelist: ["safe.com"]))
        // The core bundle also contains a bare .*porn.* rule; the keyword rule
        // is the one carrying unless-domain.
        let keywordRule = try XCTUnwrap(
            rules.first { $0.trigger.urlFilter == ".*porn.*" && $0.trigger.unlessDomain != nil }
        )
        let exempt = Set(keywordRule.trigger.unlessDomain ?? [])
        XCTAssertTrue(exempt.isSuperset(of: ContentBlockerRuleBuilder.searchEngineDomains))
        XCTAssertTrue(exempt.contains("safe.com"))
    }

    func testAPIDomainsAreCappedAt100k() {
        let domains = (0..<120_000).map { "d\($0).com" }
        let baseline = ContentBlockerRuleBuilder.build(input()).count
        let rules = ContentBlockerRuleBuilder.build(input(apiDomains: domains))
        XCTAssertEqual(rules.count, baseline + 100_000)
    }

    func testCustomKeywordsAreCappedAt50() {
        let keywords = (0..<60).map { "keyword\($0)" }
        let baseline = ContentBlockerRuleBuilder.build(input()).count
        let rules = ContentBlockerRuleBuilder.build(input(customKeywords: keywords))
        XCTAssertEqual(rules.count, baseline + 50)
    }

    func testStrictImageModeAddsCosmeticRules() {
        let normal = ContentBlockerRuleBuilder.build(input())
            .filter { $0.action.type == "css-display-none" }.count
        let strict = ContentBlockerRuleBuilder.build(input(strictImageMode: true))
            .filter { $0.action.type == "css-display-none" }.count
        XCTAssertEqual(strict, normal + 8)
    }

    func testTriggerEncodingUsesSafariKeysAndOmitsNils() throws {
        let rule = ContentBlockerRule(
            trigger: ContentBlockerTrigger(urlFilter: ".*", ifDomain: ["*a.com"]),
            action: ContentBlockerAction(type: "ignore-previous-rules")
        )
        let data = try JSONEncoder().encode(rule)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let trigger = try XCTUnwrap(json["trigger"] as? [String: Any])
        XCTAssertEqual(trigger["url-filter"] as? String, ".*")
        XCTAssertEqual(trigger["if-domain"] as? [String], ["*a.com"])
        XCTAssertNil(trigger["unless-domain"], "nil optionals must be omitted, not null")
        XCTAssertNil(trigger["resource-type"])
    }
}
