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
        let (isSubscribed, isExpired) = checkSubscriptionStatus()
        
        if isSubscribed && !isExpired {
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
                            Log.debug("ContentBlocker: Failed to create attachment from dynamic rules")
                            fallbackToStaticRules(context: context)
                            return
                        }
                        
                        let item = NSExtensionItem()
                        item.attachments = [attachment]
                        Log.debug("ContentBlocker: ✅ Using dynamic rules (\(rulesArray.count) rules) with CORE static rules + custom content")
                        context.completeRequest(returningItems: [item], completionHandler: nil)
                    } else {
                        Log.debug("ContentBlocker: Dynamic rules are empty or invalid, falling back to static rules")
                        fallbackToStaticRules(context: context)
                    }
                } catch {
                    Log.debug("ContentBlocker: Error parsing dynamic rules: \(error). Falling back to static rules")
                    fallbackToStaticRules(context: context)
                }
            } else {
                // Fallback to static rules from bundle
                Log.debug("ContentBlocker: Dynamic rules not found, using CORE static bundle rules")
                fallbackToStaticRules(context: context)
            }
        } else {
            // User is not subscribed or expired: provide a minimal no-op ruleset to avoid empty extension error
            let noopRules: [[String: Any]] = [[
                "trigger": ["url-filter": ".*"],
                "action": ["type": "ignore-previous-rules"]
            ]]
            do {
                let data = try JSONSerialization.data(withJSONObject: noopRules, options: [])
                let attachment = NSItemProvider(item: data as NSSecureCoding, typeIdentifier: "public.json")
                let item = NSExtensionItem()
                item.attachments = [attachment]
                if isExpired {
                    Log.debug("ContentBlocker: Subscription expired, providing no-op rules")
                } else {
                    Log.debug("ContentBlocker: User not subscribed, providing no-op rules")
                }
                context.completeRequest(returningItems: [item], completionHandler: nil)
            } catch {
                context.cancelRequest(withError: NSError(domain: "ContentBlocker", code: 2, userInfo: nil))
            }
        }
    }
    
    private func checkSubscriptionStatus() -> (Bool, Bool) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            Log.debug("ContentBlocker: Failed to access shared container")
            return subscriptionStatusFromDefaults() ?? (false, true)
        }

        let subscriptionStatusURL = containerURL.appendingPathComponent("subscriptionStatus.json")

        do {
            let data = try Data(contentsOf: subscriptionStatusURL)
            let subscriptionData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            let isSubscribed = subscriptionData?["isSubscribed"] as? Bool ?? false
            let expiryTimestamp = subscriptionData?["expiryDate"] as? Double
            let now = Date().timeIntervalSince1970
            let isExpired = expiryTimestamp.map { now >= $0 } ?? !isSubscribed
            Log.debug("ContentBlocker: Subscription status from file: subscribed=\(isSubscribed) expired=\(isExpired)")
            return (isSubscribed, isExpired)
        } catch {
            // The JSON file is missing or corrupt — fall back to the app-group
            // UserDefaults mirror rather than instantly stripping a paying
            // user's protection over a transient file glitch.
            Log.debug("ContentBlocker: Could not read subscription file (\(error)); using UserDefaults fallback")
            return subscriptionStatusFromDefaults() ?? (false, true)
        }
    }

    /// Reads the subscription status mirrored into app-group UserDefaults by the
    /// main app. Returns `nil` if the app has never written it.
    private func subscriptionStatusFromDefaults() -> (Bool, Bool)? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              defaults.object(forKey: "subscriptionStatusUpdated") != nil else {
            return nil
        }
        let isSubscribed = defaults.bool(forKey: "isSubscribed")
        let expiry = defaults.object(forKey: "subscriptionExpiry") as? Double
        let now = Date().timeIntervalSince1970
        let isExpired = expiry.map { now >= $0 } ?? !isSubscribed
        Log.debug("ContentBlocker: Subscription status from UserDefaults: subscribed=\(isSubscribed) expired=\(isExpired)")
        return (isSubscribed, isExpired)
    }
    
    private func getDynamicRulesURL() -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            Log.debug("ContentBlocker: Failed to access shared container for dynamic rules")
            return nil
        }
        return containerURL.appendingPathComponent("blockerList.json")
    }
    
    private func fallbackToStaticRules(context: NSExtensionContext) {
        guard let staticRulesURL = Bundle.main.url(forResource: "blockerList", withExtension: "json") else {
            Log.debug("ContentBlocker: ❌ CRITICAL ERROR: Cannot find blockerList.json in ContentBlocker bundle!")
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
                    Log.debug("ContentBlocker: Failed to create attachment from static rules")
                    context.cancelRequest(withError: NSError(domain: "ContentBlocker", code: 2, userInfo: nil))
                    return
                }
                
                let item = NSExtensionItem()
                item.attachments = [attachment]
                Log.debug("ContentBlocker: ✅ Using CORE static rules from bundle (\(rulesArray.count) rules) - ALL CORE WEBSITES WILL BE BLOCKED")
                context.completeRequest(returningItems: [item], completionHandler: nil)
            } else {
                Log.debug("ContentBlocker: ❌ Static rules file is empty or invalid!")
                context.cancelRequest(withError: NSError(domain: "ContentBlocker", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "Static rules file is empty or corrupted"
                ]))
            }
        } catch {
            Log.debug("ContentBlocker: ❌ Error reading static rules: \(error)")
            context.cancelRequest(withError: NSError(domain: "ContentBlocker", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Failed to read core blocking rules: \(error.localizedDescription)"
            ]))
        }
    }
}
