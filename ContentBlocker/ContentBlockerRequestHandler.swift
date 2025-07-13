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

    func beginRequest(with context: NSExtensionContext) {
        guard let url = Bundle.main.url(forResource: "blockerList", withExtension: "json"),
              let attachment = NSItemProvider(contentsOf: url) else {
            context.cancelRequest(withError: NSError(domain: "ContentBlocker", code: 1, userInfo: nil))
            return
        }
        
        let item = NSExtensionItem()
        item.attachments = [attachment]
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }
}
