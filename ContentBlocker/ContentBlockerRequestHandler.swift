//
//  ContentBlockerRequestHandler.swift
//  ContentBlocker
//
//  Created by Jose Pimentel on 7/9/25.
//

//import UIKit
//import MobileCoreServices
//
//class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {
//
//    func beginRequest(with context: NSExtensionContext) {
//        let attachment = NSItemProvider(contentsOf: Bundle.main.url(forResource: "blockerList", withExtension: "json"))!
//        
//        let item = NSExtensionItem()
//        item.attachments = [attachment]
//        
//        context.completeRequest(returningItems: [item], completionHandler: nil)
//    }
//    
//}

//import SafariServices
//
//class ContentBlockerRequestHandler: SFContentBlockerManager {
//    override func beginRequest(with context: NSExtensionContext) {
//        if let attachment = try? NSItemProvider(contentsOf: Bundle.main.url(forResource: "blockerList", withExtension: "json")!) {
//            let item = NSExtensionItem()
//            item.attachments = [attachment]
//            context.completeRequest(returningItems: [item], completionHandler: nil)
//        } else {
//            context.cancelRequest(withError: NSError(domain: "ContentBlocker", code: 0, userInfo: nil))
//        }
//    }
//}

import UIKit
import MobileCoreServices

class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {
    
    private let appGroupIdentifier = "group.com.jose.pimentel.PornBlocker"

    func beginRequest(with context: NSExtensionContext) {
        // Check subscription status from shared storage
        let isSubscribed = checkSubscriptionStatus()
        
        if isSubscribed {
            // User is subscribed, provide blocking rules
            guard let url = Bundle.main.url(forResource: "blockerList", withExtension: "json"),
                  let attachment = NSItemProvider(contentsOf: url) else {
                context.cancelRequest(withError: NSError(domain: "ContentBlocker", code: 1, userInfo: nil))
                return
            }
            
            let item = NSExtensionItem()
            item.attachments = [attachment]
            context.completeRequest(returningItems: [item], completionHandler: nil)
        } else {
            // User is not subscribed, provide empty rules (no blocking)
            let emptyRules: [[String: Any]] = []
            
            do {
                let emptyRulesData = try JSONSerialization.data(withJSONObject: emptyRules, options: [])
                let attachment = NSItemProvider(item: emptyRulesData as NSSecureCoding, typeIdentifier: "public.json")
                
                let item = NSExtensionItem()
                item.attachments = [attachment]
                context.completeRequest(returningItems: [item], completionHandler: nil)
            } catch {
                context.cancelRequest(withError: NSError(domain: "ContentBlocker", code: 2, userInfo: nil))
            }
        }
    }
    
    private func checkSubscriptionStatus() -> Bool {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("ContentBlocker: Failed to access shared container")
            return false // Default to not subscribed if we can't check
        }
        
        let subscriptionStatusURL = containerURL.appendingPathComponent("subscriptionStatus.json")
        
        do {
            let data = try Data(contentsOf: subscriptionStatusURL)
            let subscriptionData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            let isSubscribed = subscriptionData?["isSubscribed"] as? Bool ?? false
            let lastUpdated = subscriptionData?["lastUpdated"] as? Double ?? 0
            print("ContentBlocker: Subscription status: \(isSubscribed), last updated: \(Date(timeIntervalSince1970: lastUpdated))")
            return isSubscribed
        } catch {
            print("ContentBlocker: Error reading subscription status from \(subscriptionStatusURL.path): \(error)")
            print("ContentBlocker: File exists: \(FileManager.default.fileExists(atPath: subscriptionStatusURL.path))")
            return false // Default to not subscribed if we can't read the status
        }
    }
}
