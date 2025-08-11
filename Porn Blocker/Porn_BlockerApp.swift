//
//  Porn_BlockerApp.swift
//  Porn Blocker
//
//  Created by Jose Pimentel on 6/5/23.
//

import SwiftUI
import StoreKit

@main
struct Porn_BlockerApp: App {
    @AppStorage("darkMode") private var darkMode = false
    
    init() {
        RatingRequestManager.shared.trackLaunch()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(darkMode ? .dark : .light)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Prompt only when appropriate
                    RatingRequestManager.shared.maybePromptForReview()
                }
        }
    }
}
