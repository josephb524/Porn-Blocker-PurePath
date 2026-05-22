# Porn Blocker: PurePath

An iOS app that helps users block adult content and build healthier habits.

## Features

- **Safari content blocker** — a system-wide content-blocker extension that
  blocks adult domains and keyword-matching URLs across Safari.
- **Safe Browser** — an in-app WKWebView browser that blocks adult sites and
  blurs inappropriate images in real time.
- **Streak tracking** — track porn-free streaks and custom habits, with
  milestones and optional daily reminders.
- **Custom rules** — users can add their own blocked websites, blocked
  keywords, and an allow-list.

Blocking features require an auto-renewable subscription (StoreKit 2).

## Project Layout

| Target          | Purpose                                              |
|-----------------|------------------------------------------------------|
| `Porn Blocker`  | The main SwiftUI app.                                |
| `ContentBlocker`| The Safari content-blocker app extension.            |

The two targets share data through an App Group
(`group.com.jose.pimentel.PornBlocker`).

## Requirements

- Xcode 16+
- iOS 16.4+

## Building

```sh
xcodebuild build -scheme "Porn Blocker" -project "Porn Blocker.xcodeproj" \
  -destination 'generic/platform=iOS Simulator'
```

See [CLAUDE.md](CLAUDE.md) for architecture details.
