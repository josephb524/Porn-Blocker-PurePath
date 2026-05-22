# CLAUDE.md

Guidance for working in this repository.

## Overview

"Porn Blocker: PurePath" is a SwiftUI iOS app (iOS 16.4+) that blocks adult
content. It has two targets that share an App Group
(`group.com.jose.pimentel.PornBlocker`):

- **`Porn Blocker`** — the main app.
- **`ContentBlocker`** — a Safari content-blocker extension.

## Build & Run

```sh
# Build (no signing needed for the simulator)
xcodebuild build -scheme "Porn Blocker" -project "Porn Blocker.xcodeproj" \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

The `ContentBlocker` target uses an Xcode synchronized folder group — files
dropped into `ContentBlocker/` are added to it automatically. The main app
target uses explicit file references, so new files there must be registered
in `project.pbxproj`.

## Architecture

The blocking logic is split into focused types (all in `Porn Blocker/`):

- **`BlocklistManager`** — `@MainActor` `ObservableObject` facade. Owns the
  `@Published` lists the UI binds to and orchestrates updates. Delegates the
  real work to the types below. Accessed as `BlocklistManager.shared`.
- **`BlocklistRepository`** — an `actor` that owns the downloaded domain
  blocklist: the StevenBlack hosts-file download, parsing, and on-disk cache.
  All its I/O runs off the main actor.
- **`ContentBlockerRuleBuilder`** — stateless logic that builds the Safari
  content-blocker ruleset (`[ContentBlockerRule]`) and writes it to the shared
  container. Also defines the `ContentBlockerRule` Codable models.
- **`KeywordMatcher`** — the single source of truth for adult-keyword
  detection. Keywords are split into `substringKeywords` (safe to match
  anywhere) and `wordKeywords` (must be delimited to avoid false positives
  like "sex" in "essex"). Used by **both** blocking engines.
- **`SubscriptionManager`** — StoreKit 2 subscription state.
- **`HabitManager`** / `TrackedHabit` — streak and habit tracking.
- **`ContentBlockerRequestHandler`** (extension) — serves the rule JSON to
  Safari and checks subscription status.
- **`Log`** — logging facade over `os.Logger`; use it instead of `print`.

### Two blocking engines

1. **Safari content blocker** — `ContentBlockerRuleBuilder` generates a JSON
   ruleset, writes it to the shared container, and `BlocklistManager` reloads
   the extension. `ContentBlockerRequestHandler` serves that file to Safari.
2. **In-app Safe Browser** (`SafeBrowserView`) — a `WKWebView` that checks
   each navigation against `BlocklistManager`'s domain sets and
   `KeywordMatcher`.

Both engines go through `KeywordMatcher` so they block identically.

### Subscription flow

`SubscriptionManager` posts a `.subscriptionStatusChanged` notification when
status changes; `BlocklistManager` observes it and re-syncs the content
blocker. `SubscriptionManager` has **no** reference back to `BlocklistManager`
— keep that dependency one-directional.

The app mirrors subscription status into the shared container as both a JSON
file and app-group `UserDefaults`; the extension reads the file and falls back
to `UserDefaults` if it is missing.

## Conventions

- Use `Log.debug` / `Log.error` instead of `print`. `debug` is compiled out
  of release builds.
- Keep heavy I/O (file reads/writes, JSON encoding of large rulesets, hosts
  parsing) off the main actor.
- `updateContentBlocker()` is debounced — call it freely; rapid calls coalesce
  into one rebuild.
- When adding a file to the main app target, register it in `project.pbxproj`
  (PBXBuildFile, PBXFileReference, the group, and the Sources phase).
