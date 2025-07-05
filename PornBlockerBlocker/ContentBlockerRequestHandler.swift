import Foundation
import SafariServices
import UniformTypeIdentifiers

class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {
    
    func beginRequest(with context: NSExtensionContext) {
        let attachment = NSExtensionItem()
        var itemProvider: NSItemProvider? = nil
        
        print("ContentBlockerRequestHandler: Starting request")
        
        // Try to read from the documents directory (shared with main app)
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let rulesURL = documentsPath.appendingPathComponent("blockerList.json")
            print("ContentBlockerRequestHandler: Trying to load rules from: \(rulesURL.path)")
            
            if let rulesData = try? NSData(contentsOf: rulesURL) {
                print("ContentBlockerRequestHandler: Successfully loaded rules from documents directory")
                itemProvider = NSItemProvider(item: rulesData, typeIdentifier: UTType.json.identifier)
            } else {
                print("ContentBlockerRequestHandler: Failed to load rules from documents directory")
            }
        }
        
        // Fallback to default JSON in bundle
        if itemProvider == nil,
           let defaultRulesURL = Bundle.main.url(forResource: "blockerList", withExtension: "json"),
           let defaultRulesData = try? NSData(contentsOf: defaultRulesURL) {
            print("ContentBlockerRequestHandler: Using default rules from bundle")
            itemProvider = NSItemProvider(item: defaultRulesData, typeIdentifier: UTType.json.identifier)
        }
        
        // If a valid itemProvider was found, attach and complete the request
        if let provider = itemProvider {
            print("ContentBlockerRequestHandler: Completing request with rules")
            attachment.attachments = [provider]
            context.completeRequest(returningItems: [attachment], completionHandler: nil)
        } else {
            print("ContentBlockerRequestHandler: No rules found, completing with empty response")
            // In case of failure, complete with no items (still required to prevent hanging)
            context.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
} 