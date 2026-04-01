import Foundation

struct ContentBlockerAction: Codable {
    let type: String
}
struct ContentBlockerTrigger: Codable {
    let urlFilter: String
    enum CodingKeys: String, CodingKey {
        case urlFilter = "url-filter"
    }
}
struct ContentBlockerRule: Codable {
    let trigger: ContentBlockerTrigger
    let action: ContentBlockerAction
}

let path = "Porn Blocker/keywordsList.json"
let data = try! Data(contentsOf: URL(fileURLWithPath: path))
let rules = try! JSONDecoder().decode([ContentBlockerRule].self, from: data)

let keywords = rules.compactMap { rule -> String? in
    let urlFilter = rule.trigger.urlFilter
    if urlFilter.hasPrefix(".*") && urlFilter.hasSuffix(".*") {
        return String(urlFilter.dropFirst(2).dropLast(2))
    }
    return nil
}

print("Loaded keywords: \(keywords)")

// Test domains
let urls = ["https://apple.com", "https://google.com"]
for u in urls {
    for k in keywords {
        if u.lowercased().contains(k.lowercased()) {
            print("URL '\(u)' is blocked by keyword: '\(k)'")
        }
    }
}
