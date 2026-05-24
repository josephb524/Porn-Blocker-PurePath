//
//  Porn_BlockerApp.swift
//  Porn Blocker
//
//  Created by Jose Pimentel on 6/5/23.
//

import SwiftUI
import StoreKit
import UserNotifications

@main
struct Porn_BlockerApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    /// Set up `UIApplicationDelegate` early so the notification delegate is
    /// in place before iOS delivers any pending tap from a cold launch.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        RatingRequestManager.shared.trackLaunch()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearanceMode.preferredColorScheme)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Prompt only when appropriate
                    RatingRequestManager.shared.maybePromptForReview()
                }
        }
    }
}

// MARK: - App Delegate

/// Lightweight delegate whose sole job today is wiring up
/// `UNUserNotificationCenter` so habit-reminder taps land on
/// `NotificationDelegate` (see `HabitManager.swift`).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        return true
    }
}

// MARK: - Appearance

/// Light / Dark / System override for the whole app. Persisted under the
/// `appearanceMode` key — see `SettingsView` for the picker.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// `nil` means "no override — follow the system setting".
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
