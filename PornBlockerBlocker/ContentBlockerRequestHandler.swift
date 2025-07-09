import Foundation
import SafariServices
import UniformTypeIdentifiers

class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {
    
    func beginRequest(with context: NSExtensionContext) {
        let rules = loadBlockingRules()
        
        let item = NSExtensionItem()
        item.attachments = [NSItemProvider(item: rules as NSSecureCoding, typeIdentifier: UTType.json.identifier)]
        
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }
    
    private func loadBlockingRules() -> Data {
        // Try to load from shared container first
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.jose.pimentel.PornBlocker") {
            let rulesURL = containerURL.appendingPathComponent("blockerList.json")
            if let rulesData = try? Data(contentsOf: rulesURL) {
                print("Extension: Loaded rules from shared container")
                return rulesData
            }
        }
        
        // Try to load from extension bundle
        if let bundleURL = Bundle.main.url(forResource: "blockerList", withExtension: "json") {
            do {
                let rawString = try String(contentsOf: bundleURL, encoding: .utf8)
                let cleanedString = rawString
                    .components(separatedBy: .newlines)
                    .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                    .joined(separator: "\n")
                
                if let cleanedData = cleanedString.data(using: .utf8) {
                    print("Extension: Loaded rules from extension bundle")
                    return cleanedData
                }
            } catch {
                print("Extension: Error loading from bundle: \(error)")
            }
        }
        
        // Comprehensive fallback rules including youjizz and brazzers
        print("Extension: Using comprehensive fallback rules")
        let fallbackRules = """
        [
            { "trigger": { "url-filter": ".*youjizz.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*brazzers.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*pornhub.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*xvideos.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*xnxx.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*xhamster.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*redtube.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*youporn.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*tube8.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*spankbang.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*beeg.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*tnaflix.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*empflix.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*drtuber.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*gotporn.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*4tube.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*vporn.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*porn.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*xxx.*" }, "action": { "type": "block" } },
            { "trigger": { "url-filter": ".*sex.*" }, "action": { "type": "block" } }
        ]
        """
        return fallbackRules.data(using: .utf8) ?? Data()
    }
} 