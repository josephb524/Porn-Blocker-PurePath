//
//  ContentView.swift
//  Porn Blocker
//
//  Created by Jose Pimentel on 6/5/23.
//

import SwiftUI

struct ContentView: View {
    /// Flipped by `OnboardingView.completeOnboarding()`. Both views read the
    /// same key via @AppStorage, so the swap happens the moment it changes.
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if hasSeenOnboarding {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: hasSeenOnboarding)
    }
}

#Preview {
    ContentView()
}
