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
            if let dynamicRulesURL = getDynamicRulesURL(),
               FileManager.default.fileExists(atPath: dynamicRulesURL.path) {
                // Try to use dynamic rules (includes core static rules + custom keywords and websites)
                do {
                    let dynamicRulesData = try Data(contentsOf: dynamicRulesURL)
                    let parsedRules = try JSONSerialization.jsonObject(with: dynamicRulesData, options: [])
                    
                    // Validate that we have valid rules
                    if let rulesArray = parsedRules as? [[String: Any]], !rulesArray.isEmpty {
                        guard let attachment = NSItemProvider(contentsOf: dynamicRulesURL) else {
                            print("ContentBlocker: Failed to create attachment from dynamic rules")
                            fallbackToStaticRules(context: context)
                            return
                        }
                        
                        let item = NSExtensionItem()
                        item.attachments = [attachment]
                        print("ContentBlocker: ✅ Using dynamic rules (\(rulesArray.count) rules) with CORE static rules + custom content")
                        context.completeRequest(returningItems: [item], completionHandler: nil)
                    } else {
                        print("ContentBlocker: Dynamic rules are empty or invalid, falling back to static rules")
                        fallbackToStaticRules(context: context)
                    }
                } catch {
                    print("ContentBlocker: Error parsing dynamic rules: \(error). Falling back to static rules")
                    fallbackToStaticRules(context: context)
                }
            } else {
                // Fallback to static rules from bundle
                print("ContentBlocker: Dynamic rules not found, using CORE static bundle rules")
                fallbackToStaticRules(context: context)
            }
        } else {
            // User is not subscribed, provide empty rules (no blocking)
            let emptyRules: [[String: Any]] = []
            
            do {
                let emptyRulesData = try JSONSerialization.data(withJSONObject: emptyRules, options: [])
                let attachment = NSItemProvider(item: emptyRulesData as NSSecureCoding, typeIdentifier: "public.json")
                
                let item = NSExtensionItem()
                item.attachments = [attachment]
                print("ContentBlocker: User not subscribed, providing empty rules")
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
    
    private func getDynamicRulesURL() -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            print("ContentBlocker: Failed to access shared container for dynamic rules")
            return nil
        }
        return containerURL.appendingPathComponent("blockerList.json")
    }
    
    private func fallbackToStaticRules(context: NSExtensionContext) {
        guard let staticRulesURL = Bundle.main.url(forResource: "blockerList", withExtension: "json") else {
            print("ContentBlocker: ❌ CRITICAL ERROR: Cannot find blockerList.json in ContentBlocker bundle!")
            context.cancelRequest(withError: NSError(domain: "ContentBlocker", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Core blocking rules not found in bundle"
            ]))
            return
        }
        
        // Validate that the static rules file is readable and contains data
        do {
            let staticRulesData = try Data(contentsOf: staticRulesURL)
            let parsedRules = try JSONSerialization.jsonObject(with: staticRulesData, options: [])
            
            if let rulesArray = parsedRules as? [[String: Any]], !rulesArray.isEmpty {
                guard let attachment = NSItemProvider(contentsOf: staticRulesURL) else {
                    print("ContentBlocker: Failed to create attachment from static rules")
                    context.cancelRequest(withError: NSError(domain: "ContentBlocker", code: 2, userInfo: nil))
                    return
                }
                
                let item = NSExtensionItem()
                item.attachments = [attachment]
                print("ContentBlocker: ✅ Using CORE static rules from bundle (\(rulesArray.count) rules) - ALL CORE WEBSITES WILL BE BLOCKED")
                context.completeRequest(returningItems: [item], completionHandler: nil)
            } else {
                print("ContentBlocker: ❌ Static rules file is empty or invalid!")
                context.cancelRequest(withError: NSError(domain: "ContentBlocker", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "Static rules file is empty or corrupted"
                ]))
            }
        } catch {
            print("ContentBlocker: ❌ Error reading static rules: \(error)")
            context.cancelRequest(withError: NSError(domain: "ContentBlocker", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Failed to read core blocking rules: \(error.localizedDescription)"
            ]))
        }
    }
}
