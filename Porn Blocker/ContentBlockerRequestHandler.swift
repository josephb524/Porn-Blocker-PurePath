import Foundation
import SafariServices
import UniformTypeIdentifiers

class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {
    
    func beginRequest(with context: NSExtensionContext) {
        let attachment = NSExtensionItem()
        var itemProvider: NSItemProvider? = nil
        
        // Try to read from the documents directory
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let rulesURL = documentsPath.appendingPathComponent("blockerList.json")
            
            if let rulesData = try? NSData(contentsOf: rulesURL) {
                itemProvider = NSItemProvider(item: rulesData, typeIdentifier: UTType.json.identifier)
            }
        }
        
        // Fallback to default JSON in bundle
        if itemProvider == nil,
           let defaultRulesURL = Bundle.main.url(forResource: "blockerList", withExtension: "json"),
           let defaultRulesData = try? NSData(contentsOf: defaultRulesURL) {
            itemProvider = NSItemProvider(item: defaultRulesData, typeIdentifier: UTType.json.identifier)
        }
        
        // If a valid itemProvider was found, attach and complete the request
        if let provider = itemProvider {
            attachment.attachments = [provider]
            context.completeRequest(returningItems: [attachment], completionHandler: nil)
        } else {
            // In case of failure, complete with no items (still required to prevent hanging)
            context.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}
