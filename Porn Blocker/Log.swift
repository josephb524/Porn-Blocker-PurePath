import Foundation
import os

/// Lightweight logging facade over `os.Logger`.
///
/// `debug` calls are compiled out of release builds, so development tracing
/// never ships. `error` calls always log. Use this instead of `print`.
enum Log {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.jose.pimentel.Porn-Blocker",
        category: "app"
    )

    /// Development-only tracing — stripped from release builds.
    static func debug(_ message: @autoclosure () -> String) {
        #if DEBUG
        let text = message()
        logger.debug("\(text, privacy: .public)")
        #endif
    }

    /// Error-level logging — recorded in all build configurations.
    static func error(_ message: @autoclosure () -> String) {
        let text = message()
        logger.error("\(text, privacy: .public)")
    }
}
