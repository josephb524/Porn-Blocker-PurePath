# CLAUDE.md

Guidance for working in this repository.

## Overview

"Porn Blocker" is a SwiftUI iOS app (iOS 16.4+) that blocks adult content and
includes a subscription-gated AI buddy chat for users on a recovery journey.

The repo has two iOS targets that share an App Group
(`group.com.jose.pimentel.PornBlocker`):

- **`Porn Blocker`** — the main app.
- **`ContentBlocker`** — a Safari content-blocker extension.

Plus a Cloudflare Worker (`worker/`) that backs the buddy chat — see the
Buddy Chat section below.

## Tabs

Five tabs in `MainTabView`, in this order:

| Tag | Tab | View |
|---|---|---|
| 0 | Protection | `DashboardView` |
| 1 | Safe Browse | `SafeBrowserView` (subscription-gated) |
| 2 | Buddy | `BuddyChatView` (subscription-gated) |
| 3 | Streaks | `StatsView` |
| 4 | Settings | `SettingsView` |

The Safe Browse and Buddy tabs both show a locked marketing view for
non-subscribers that opens the paywall. The other tabs are free.

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

### Blocking (all in `Porn Blocker/`)

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
- **`HabitManager`** / `TrackedHabit` — streak and habit tracking.
- **`ContentBlockerRequestHandler`** (extension) — serves the rule JSON to
  Safari and checks subscription status.

### Two blocking engines

1. **Safari content blocker** — `ContentBlockerRuleBuilder` generates a JSON
   ruleset, writes it to the shared container, and `BlocklistManager` reloads
   the extension. `ContentBlockerRequestHandler` serves that file to Safari.
2. **In-app Safe Browser** (`SafeBrowserView`) — a `WKWebView` that checks
   each navigation against `BlocklistManager`'s domain sets and
   `KeywordMatcher`.

Both engines go through `KeywordMatcher` so they block identically.

### Subscription

- **`SubscriptionManager`** — StoreKit 2 wrapper, `@MainActor` singleton.
  Loads the monthly + yearly products, exposes `isSubscribed`,
  `signedTransactionJWS` (Apple-signed JWS sent to the chat Worker as
  `signedTransaction`), and `originalTransactionID`. Listens to
  `Transaction.updates`; hourly expiration check timer.
- **`PaywallScreen`** — solid-accent hero, features list (Safari blocking,
  buddy chat, customizable list, etc.), plan picker (monthly + yearly,
  yearly selected by default with a dynamic "SAVE X%" badge), Subscribe +
  Restore buttons. Dynamically shows free-trial copy if a product has an
  introductory offer.

`SubscriptionManager` posts a `.subscriptionStatusChanged` notification when
status changes; `BlocklistManager` observes it and re-syncs the content
blocker. `SubscriptionManager` has **no** reference back to `BlocklistManager`
— keep that dependency one-directional.

The app mirrors subscription status into the shared container as both a JSON
file and app-group `UserDefaults`; the extension reads the file and falls back
to `UserDefaults` if it is missing.

#### Subscription products

Product IDs must match in **three** places: `SubscriptionManager.swift`,
`worker/src/verify.ts` (`VALID_PRODUCT_IDS`), **and** App Store Connect.

- `pornBlocker` — yearly
- `pornBlockerMonthly` — monthly

Both declared in `SubscriptionManager` as `nonisolated static let` so the
detached transaction listener can reference them without Swift 6 isolation
warnings.

### Buddy Chat (paid feature)

| File | Role |
|---|---|
| `ChatMessage.swift` / `ChatConversation.swift` | Codable models — role, content, timestamps, feedback. |
| `ConversationStore.swift` | `@MainActor` singleton. Persists `Documents/buddy_chat_conversations.json`. Auto-saves on each turn. |
| `BuddyChatService.swift` | Networking namespace. POSTs to the Worker `/chat` with `signedTransaction + messages` and yields text deltas from the SSE stream. **The hardcoded `endpoint` URL must be updated after every Worker deploy.** |
| `BuddyChatViewModel.swift` | `@MainActor` ObservableObject. Owns the active conversation, draft, streaming state. Two inits — `init()` for the common case (resolves singletons inside the body, avoids Swift 6 actor-isolated default-arg warning) and `init(conversation:store:subManager:)` for tests. |
| `BuddyChatView.swift` | Tab entry point. If subscribed: `BuddyChatContent` (NavigationStack, toolbar [history/new chat], empty state with 4 suggested prompts that **auto-send on tap**, message bubbles with action bar [copy / read aloud / 👍 / 👎], composer). If not: `BuddyLockedView` — marketing gate styled like Safe Browser's, with the same dynamic trial caption, opening the existing paywall. |
| `ConversationListView.swift` | History sheet with swipe-to-delete and relative timestamps. |
| `ChatRichText.swift` | Lightweight markdown renderer for assistant messages — paragraphs, blockquotes, bullets, inline bold/italic via `AttributedString`. Flattens headings, tables, HTML to plain text. Includes `TypingIndicator`. |
| `SpeechController.swift` | `AVSpeechSynthesizer` wrapper. `toggle(messageID:text:)`. Strips markdown before speaking. Default voice `en-US`. |

**Keyboard dismiss — three ways** in the chat content:
- tap the chat background (`.onTapGesture` on the `Color(.systemGroupedBackground)` wrapper)
- swipe down on the message list or empty-state scroll view (`.scrollDismissesKeyboard(.interactively)`)
- tap `Done` in `ToolbarItemGroup(placement: .keyboard)`

Keep all three when refactoring — the iOS norm is "all three or none".

### Streaks, reminders, and deep-linking

`HabitManager` / `TrackedHabit` (in `HabitManager.swift`) own the streak
data and check-in history. A few non-obvious behaviors live here:

- **One-day grace on the current streak.** `consecutiveStreak(endingOn:)`
  starts from yesterday if today isn't checked in yet, so the displayed
  count persists through the day. The streak only drops to 0 once today
  ends without a check-in. `isCheckedInToday` still strictly checks
  today's key, so the check-in button correctly empties at midnight —
  giving the user a visual nudge without zeroing the count.
- **Reminder identifier convention.** `HabitNotificationManager.schedule`
  registers a repeating `UNCalendarNotificationTrigger` with identifier
  `"habit-<UUID>"` and stamps the same UUID into `userInfo["habitID"]`
  (so the tap handler doesn't have to parse the identifier).
- **Permission race — handled.** `schedule(for:)` switches on
  `authorizationStatus`: on `.notDetermined` it calls `requestAuthorization`
  and chains the actual `add(request:)` **inside that completion**.
  Previously the function early-returned after only requesting permission,
  so a user's first reminder was never queued and silently missed its
  first day. Don't reintroduce the early return.

**Tap routing** (notification → Streaks tab → edit sheet for that habit):

1. `AppDelegate` (in `Porn_BlockerApp.swift`, via
   `@UIApplicationDelegateAdaptor`) installs `NotificationDelegate.shared`
   as `UNUserNotificationCenter.current().delegate` at launch — early
   enough to catch cold-launch taps.
2. `NotificationDelegate` parses the habit UUID (from `userInfo`, falling
   back to the identifier prefix for older scheduled notifications) and
   stores it on `HabitNotificationRouter.shared.pendingHabitID` — a
   `@MainActor ObservableObject` singleton.
3. `MainTabView` observes the router and switches `selectedTab = 3`
   (Streaks) on cold-launch `.onAppear` or warm `.onChange`.
4. `StatsView` observes the same router, finds the habit by ID, sets
   `selectedEditHabit` (opening `EditHabitView` as a sheet — the same
   surface used by the gear button), and calls `router.clear()` so it
   isn't replayed.

### Logging

- **`Log`** — logging facade over `os.Logger`. Use `Log.debug(...)` and
  `Log.error(...)` instead of `print`. `Log.debug` is compiled out of
  release builds, so dev tracing never ships. `Log.swift` is in **both**
  targets so the Safari extension can use it too.

## Buddy Chat backend (`worker/`)

A Cloudflare Worker that:

1. Verifies the iOS app's StoreKit 2 signed transaction JWS locally
   (`src/verify.ts`) — bundle ID, product ID, expiry, revocation.
2. Proxies the conversation to **Fireworks AI** with streaming
   (`src/fireworks.ts`), using their OpenAI-compatible chat completions API.
3. Re-frames Fireworks' OpenAI-style SSE into a tiny `data: {"text":"…"}`
   format the iOS client consumes directly.

**Endpoint:** `POST /chat`. Body: `{ signedTransaction, messages }`. Anything
else returns 404.

| File | Role |
|---|---|
| `src/index.ts` | Entry, top-level error wrapper, routing, request validation. |
| `src/verify.ts` | Decodes the JWS payload, checks bundle/product/expiry/revocation against `APPLE_BUNDLE_ID` + `VALID_PRODUCT_IDS`. |
| `src/fireworks.ts` | Streaming proxy to `api.fireworks.ai/inference/v1/chat/completions`. `MAX_TOKENS: 1024` (bump for longer replies). |
| `src/prompt.ts` | Empathetic-buddy system prompt. **Forbids tables, headings, lists, code blocks** so the UI stays clean. |
| `src/types.ts` | Shared TypeScript interfaces. |

**Secrets** (set via `npx wrangler secret put <NAME>`):

- `FIREWORKS_API_KEY` — starts with `fw_`

**Vars** (in `wrangler.toml`, non-secret):

- `APPLE_BUNDLE_ID = "com.jose.pimentel.Porn-Blocker"` — must match the iOS bundle ID exactly.
- `FIREWORKS_MODEL` — default `accounts/fireworks/models/gpt-oss-120b`. See <https://fireworks.ai/models>.

### Worker workflow

```sh
cd worker
npx wrangler dev                  # local dev server
npx wrangler tail --format=pretty # stream live production logs
npx wrangler deploy               # redeploy after code changes
npx wrangler secret list          # see which secrets exist (not values)
```

**After every deploy:** paste the Worker URL (with `/chat` appended) into
`BuddyChatService.swift` → `endpoint`. That's the one hardcoded URL the iOS
app holds.

### Common errors and fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| 404 from Worker | Path missing `/chat` in `BuddyChatService.endpoint` | Append `/chat` |
| 401 + `bundle_mismatch` | `APPLE_BUNDLE_ID` in `wrangler.toml` doesn't match iOS bundle | Fix var, redeploy |
| 402 + `product_not_allowed` | Product ID not in `VALID_PRODUCT_IDS` (e.g. renamed in ASC but not in `verify.ts`) | Sync IDs across `SubscriptionManager.swift`, `verify.ts`, App Store Connect |
| 402 + `expired` while testing | Sandbox subscriptions expire fast | Re-purchase in the simulator or extend the test cadence |
| Fireworks `404` | Wrong model identifier | Set `FIREWORKS_MODEL` to a valid Fireworks model path |
| Fireworks `401` | API key invalid/revoked | `npx wrangler secret put FIREWORKS_API_KEY` |
| Chat reply cut off mid-word | Hitting `MAX_TOKENS: 1024` in `src/fireworks.ts` | Bump (raises per-request cost) |

### Security note

The Worker decodes the JWS payload without verifying Apple's signature.
Forging a JWS that decodes to a valid bundle + allow-listed product +
future-expiry is impractical without compromising Apple's signing
infrastructure. If abuse appears, add `crypto.subtle.verify` against
Apple's root cert.

## Conventions

- **Use `Log.debug` / `Log.error` instead of `print`.** `Log.debug` is
  compiled out of release builds.
- **Heavy I/O off the main actor.** File reads/writes, JSON encoding of
  large rulesets, and hosts parsing all run in detached tasks or actor
  methods. Don't put them back on `@MainActor` types.
- **`updateContentBlocker()` is debounced.** Call it freely; rapid calls
  coalesce into one rebuild.
- **`NavigationStack`, not `NavigationView`.** New code uses
  `NavigationStack` and `.navigationDestination`. `NavigationView` is fully
  migrated out.
- **`onChange` is the iOS 16 single-arg form** (`.onChange(of:) { newValue in ... }`)
  because the app deploys to iOS 16.4. The iOS 17 two-arg / zero-arg forms
  will fail the build with "only available in iOS 17.0".
- **Don't reintroduce hardcoded prices** in `PaywallScreen`. Both plans
  pull live `displayPrice` / period from `Product`, and the trial copy is
  derived from `Product.freeTrialText` (an extension on `Product` in
  `SubscriptionManager.swift`).
- **Don't break the one-directional dep:** `BlocklistManager` may read
  `SubscriptionManager`, but `SubscriptionManager` must not reference
  `BlocklistManager`. Subscription changes propagate via the
  `.subscriptionStatusChanged` notification.
- **When adding a Swift file to the main app target,** register it in
  `project.pbxproj` (PBXBuildFile, PBXFileReference, the group, and the
  Sources phase). The ContentBlocker target uses a synchronized folder
  group, so files dropped in `ContentBlocker/` are picked up automatically.
- **Buddy chat suggested prompts auto-send on tap.** They set
  `viewModel.draft` and call `viewModel.send()` directly — they do not
  populate the input and wait for the user to tap send.
- **Don't add fallback / retry logic for the buddy chat** without
  confirming. Fireworks failures should bubble up to the user as the
  visible error banner, not be silently retried.
- **Pulse animations: scale, don't resize.** The protection-status hero
  pulse in `DashboardView` uses a fixed-size `.frame` plus `.scaleEffect`
  driven by `TimelineView`. Animating `.frame` directly makes the parent
  `ZStack` grow and shrink the whole card with each pulse. Same applies
  anywhere else a `TimelineView` drives a decorative loop inside a
  layout-sensitive container.

## Privacy

- All blocking data is local — `customBlocklist`, `keywordBlocklist`,
  `whitelist`, the downloaded StevenBlack list, and the buddy-chat
  conversation history all live on-device (`UserDefaults` or `Documents/`).
- The Worker is stateless. The only thing leaving the device is the chat
  conversation (sent to Fireworks via the Worker) and the StoreKit JWS
  (used for entitlement verification).
- `PrivacyInfo.xcprivacy` is present in both targets; submission-ready.

## Hardcoded values worth knowing

- **App Store ID** in `RatingRequestManager.swift`: `6749251520`.
- **App group** in `BlocklistManager.swift` and `ContentBlocker*.swift`:
  `group.com.jose.pimentel.PornBlocker`.
- **Worker endpoint** in `BuddyChatService.swift` — must be updated after
  every `wrangler deploy`.
- **Anthropic-style chat history cap** (`MAX_MESSAGES` in `worker/src/index.ts`):
  40 messages.
