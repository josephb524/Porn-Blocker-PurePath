import Foundation

/// Single source of truth for adult-content keyword detection.
///
/// Both blocking engines use this type so they behave identically:
/// - the in-app Safe Browser calls `isBlocked(url:customKeywords:)`
/// - the Safari content blocker is built from `predefinedURLFilters()` / `customURLFilter(for:)`
///
/// Keywords are split into two tiers to avoid false positives:
/// - `substringKeywords` — strings that essentially never appear inside ordinary
///   words or domains, so a plain substring match is safe and also catches
///   concatenated forms like `pornhub` or `freeporn`.
/// - `wordKeywords` — strings that DO occur inside ordinary words (`sex` in
///   `essex`, `anal` in `canal`, `trans` in `translate`), so they only match when
///   delimited by a non-letter on both sides.
enum KeywordMatcher {

    // MARK: - Keyword data

    /// Safe to match anywhere in a URL.
    static let substringKeywords: [String] = [
        "porn", "xxx", "hentai", "creampie", "blowjob", "deepthroat", "cumshot",
        "gangbang", "bukkake", "fisting", "handjob", "shemale", "tranny", "tgirl",
        "ladyboy", "tsescort", "bdsm", "camgirl", "camsex", "sexcam", "livesex",
        "masturbat", "pegging", "milf", "nsfw", "xvideos", "xnxx", "xhamster",
        "erotica", "upskirt"
    ]

    /// Must be delimited by a non-letter on both sides.
    static let wordKeywords: [String] = [
        "sex", "anal", "cum", "nude", "naked", "escort", "fetish", "bondage",
        "spank", "hardcore", "softcore", "lesbian", "gay", "trans", "adult",
        "strip", "hooker", "orgy", "kinky", "horny"
    ]

    /// Flat list of every predefined keyword — used for UI counts.
    static var predefinedKeywords: [String] { substringKeywords + wordKeywords }

    // MARK: - Safe Browser matching

    /// Returns `true` when `url` contains a blocked keyword.
    /// Custom (user-added) keywords are always treated as word-bounded, which is
    /// the safe default for arbitrary input.
    static func isBlocked(url: String, customKeywords: [String]) -> Bool {
        let lower = url.lowercased()

        for keyword in substringKeywords where lower.contains(keyword) {
            return true
        }

        if let regex = boundedRegex,
           regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) != nil {
            return true
        }

        for raw in customKeywords {
            let keyword = raw.lowercased().trimmingCharacters(in: .whitespaces)
            guard keyword.count > 1 else { continue }
            if containsBounded(keyword, in: lower) { return true }
        }
        return false
    }

    // MARK: - Content blocker url-filters

    /// Safari `url-filter` strings for every predefined keyword.
    static func predefinedURLFilters() -> [String] {
        substringKeywords.map { ".*\(escaped($0)).*" }
            + wordKeywords.map { ".*[^a-z]\(escaped($0))[^a-z].*" }
    }

    /// Safari `url-filter` for a single user-supplied custom keyword (always
    /// word-bounded). Returns `nil` if the keyword is too short to be useful.
    static func customURLFilter(for keyword: String) -> String? {
        let clean = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > 1 else { return nil }
        return ".*[^a-z]\(escaped(clean))[^a-z].*"
    }

    // MARK: - Internals

    /// One compiled regex covering all predefined `wordKeywords`.
    private static let boundedRegex: NSRegularExpression? = {
        let alternation = wordKeywords
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
        return try? NSRegularExpression(
            pattern: "(^|[^a-z])(\(alternation))([^a-z]|$)",
            options: .caseInsensitive
        )
    }()

    /// True if `keyword`, delimited by non-letters, occurs in `url`.
    private static func containsBounded(_ keyword: String, in url: String) -> Bool {
        let pattern = "(^|[^a-z])\(NSRegularExpression.escapedPattern(for: keyword))([^a-z]|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }
        return regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) != nil
    }

    /// Escapes a keyword for use inside a Safari content-blocker `url-filter` regex.
    private static func escaped(_ keyword: String) -> String {
        NSRegularExpression.escapedPattern(for: keyword)
    }
}
