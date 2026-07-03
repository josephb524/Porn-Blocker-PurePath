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
  introductory offer. The layout is tuned for App Store guideline
  **3.1.2(c)** compliance — see "Paywall layout (App Store 3.1.2(c))" below
  before changing fonts, button copy, or pricing prominence.

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
- `monthlyPornBlocker` — monthly

Both declared in `SubscriptionManager` as `nonisolated static let` so the
detached transaction listener can reference them without Swift 6 isolation
warnings.

#### Paywall layout (App Store 3.1.2(c))

The first submission was rejected under guideline **3.1.2(c)** for not
making the auto-renewing subscription terms clear in the purchase flow.
The current `PaywallScreen` layout is the fix — don't undo these without
re-reading the rejection notice:

- **Billed price is the most prominent pricing element.** In `planCard`,
  `product.displayPrice` is `.title2.bold()` (larger than the plan name
  `.subheadline` and the trial caption `.caption2`). The disclosure block
  under the CTA repeats the price as `.title3.bold()`. Any new pricing
  element you add (intro pricing, calculated per-month price, savings
  badge) must render *smaller and subordinate* to `displayPrice`.
- **CTA button must state that a subscription follows the trial.** When a
  trial is available, the button shows two lines: primary "Start Free
  Trial & Subscribe" (`.headline`) and secondary "Then $X.XX per year,
  auto-renews" (`.subheadline.semibold`, same white color). The secondary
  line is **on the button itself** — Apple specifically called out that
  the trial CTA must indicate "no less prominently" that a subscription
  follows. Don't move that line off the button.
- **Disclosure paragraph below the CTA** must mention that the
  subscription begins automatically at trial end, that it auto-renews,
  and that cancellation happens in Settings ≥24 hours before renewal.
  See `billingDisclosure(for:)`.
- **Free-trial copy on plan cards is intentionally muted** ("Includes
  3-day free trial", `.caption2`, secondary color). Don't restyle it in
  accent color or larger fonts — that's what got the original layout
  rejected.

### Buddy Chat (paid feature)

| File | Role |
|---|---|
| `ChatMessage.swift` / `ChatConversation.swift` | Codable models — role, content, timestamps, feedback. |
| `ConversationStore.swift` | `@MainActor` singleton. Persists `Documents/buddy_chat_conversations.json`. Auto-saves on each turn. |
| `BuddyChatService.swift` | Networking namespace. POSTs to the Worker `/chat` with `signedTransaction + messages` and yields text deltas from the SSE stream. **The hardcoded `endpoint` URL must be updated after every Worker deploy.** |
| `BuddyChatViewModel.swift` | `@MainActor` ObservableObject. Owns the active conversation, draft, streaming state. Two inits — `init()` for the common case (resolves singletons inside the body, avoids Swift 6 actor-isolated default-arg warning) and `init(conversation:store:subManager:)` for tests. Batches SSE deltas and flushes to the UI at ~10Hz — per-token `@Published` updates froze the UI on longer replies. A `streamGeneration` counter guards the stream task's completion so a stale (cancelled) stream can't clobber a newer one (stop-then-immediately-resend race that stuck `isStreaming`). A still-empty assistant placeholder is dropped on completion/cancel; history sent to the worker is capped at the last 20 messages (worker rejects >`MAX_MESSAGES` = 40). |
| `BuddyChatView.swift` | Tab entry point. If subscribed: `BuddyChatContent` (NavigationStack, toolbar [history/new chat], empty state with 4 suggested prompts that **auto-send on tap**, message bubbles with action bar [copy / read aloud / 👍 / 👎], composer). If not: `BuddyLockedView` — marketing gate styled like Safe Browser's, with the same dynamic trial caption, opening the existing paywall. |
| `ConversationListView.swift` | History sheet with swipe-to-delete and relative timestamps. |
| `ChatRichText.swift` | Lightweight markdown renderer for assistant messages — paragraphs, blockquotes, bullets, inline bold/italic via `AttributedString`. Flattens headings, tables, HTML to plain text. Includes `TypingIndicator`. |
| `SpeechController.swift` | `AVSpeechSynthesizer` wrapper. `toggle(messageID:text:)`. Strips markdown before speaking. Default voice `en-US`. |

**Keyboard dismiss — three ways** in the chat content:
- tap the chat background (`.onTapGesture` on the `Color(.systemGroupedBackground)` wrapper)
- swipe down on the message list or empty-state scroll view (`.scrollDismissesKeyboard(.interactively)`)
- tap `Done` in `ToolbarItemGroup(placement: .keyboard)`

Keep all three when refactoring — the iOS norm is "all three or none".

### Dashboard "Days Protected"

The `DashboardView` "Days Protected" quick-stat counts **cumulative days
protection has actually been active**, where active means **subscribed AND
the Safari content blocker enabled** — the same pair that turns the status
hero card green. It pauses while protection is off and resumes from where it
left off; it does **not** reset to 0, and it does **not** keep climbing while
protection is off.

Two `@AppStorage` values back it (don't go back to a single anchor):

- `protectedSecondsBanked` — banked time from completed active stretches.
- `protectionStretchStart` — Unix timestamp the current stretch began, `0`
  while protection is off.

`daysProtected = floor((banked + current live stretch) / 86_400)`.
`reconcileProtectionAccrual()` is the single source of truth: it opens a
stretch when protection becomes active and banks the elapsed time when it
stops. It must be driven by **both** signals — `checkContentBlockerStatus()`
(extension enabled flag) and `.onChange(of: subManager.isSubscribed)` — so a
subscription lapse mid-session banks correctly, not just an extension toggle.

Non-obvious bits:

- **Legacy migration.** `migrateLegacyAnchorIfNeeded()` carries existing
  users over from the old single `protectionEnabledStart` anchor exactly
  once (preserving the number they saw), then zeroes that key. Don't remove
  it until you're sure no installs still hold the old key.
- **Whole-day (24h) granularity.** A stretch under 24h banks 0 days, so day
  one reads `0` until 24h elapse. This is intentional parity with the
  original card — if you change it to count day-one as `1`, do it
  deliberately.
- **Background lapses are approximate.** Reconciliation only happens while
  the app observes the state change, so time between a background
  lapse/toggle and the next app open is counted as protected. Exact
  lapse-time banking would need `SubscriptionManager`'s expiration date.

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

### Rating prompts

`RatingRequestManager` (a `@MainActor` singleton) exposes two entry
points that are intentionally non-overlapping — don't merge them:

- **`maybePromptForReview()`** — called from `Porn_BlockerApp` on
  `didBecomeActive`. Gated by `shouldPrompt()` (≥5 launches, ≥3 days
  since first install, ≥90 days since the last prompt, not permanently
  dismissed). Fires Apple's native
  `SKStoreReviewController.requestReview(in: scene)` sheet and
  **nothing else**. If no foreground scene is available it returns
  silently — iOS will fire `didBecomeActive` again later.
- **`promptForReviewDirectly()`** — called only from Settings → "Rate
  the App". Shows the custom `ReviewPromptView` overlay defined in
  `MainTabView`.

The previous behavior chained the custom overlay 2 seconds after the
native sheet on the auto path, which visually stacked both popups.
Don't reintroduce that — the two paths are mutually exclusive by design.

**Native sheet caveats** (not a code issue, frequently misdiagnosed):
`SKStoreReviewController` only fully works on App Store-installed
builds. In Xcode-run / simulator / TestFlight builds the sheet may
appear with **Submit permanently disabled** — that's Apple's design.
iOS also rate-limits the prompt to ≤3 displays per Apple ID per app
per year, after which `requestReview(in:)` silently no-ops.

The `appStoreID` (`6749251520`) is **not** passed to the native sheet —
that API looks the app up by bundle ID. The ID is only used by the
custom prompt's `?action=write-review` deep link.

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
  `SubscriptionManager.swift`). When touching paywall typography or CTA
  copy, re-read "Paywall layout (App Store 3.1.2(c))" — the visual
  hierarchy (billed price dominant, trial copy subordinate, CTA states
  that a subscription follows the trial) is load-bearing for
  resubmission.
- **Paywall legal links are external `Link`s, not in-app sheets.** The
  Privacy Policy and Terms of Use rows in `PaywallScreen.legalSection`
  open the hosted URLs directly in Safari (see "Hardcoded values worth
  knowing" for the exact URLs). The in-app `PrivacyPolicyView` /
  `TermsView` are still used by Settings, but the paywall intentionally
  surfaces the canonical hosted documents — App Store reviewers expect
  to land on a real URL, not an in-app sheet.
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

- **App Store ID** in `RatingRequestManager.swift`: `6749251520`. Used
  only by the custom prompt's write-review deep link — the native
  `SKStoreReviewController` resolves the app by bundle ID instead.
- **App group** in `BlocklistManager.swift` and `ContentBlocker*.swift`:
  `group.com.jose.pimentel.PornBlocker`.
- **Worker endpoint** in `BuddyChatService.swift` — must be updated after
  every `wrangler deploy`.
- **Paywall legal URLs** in `PaywallScreen.swift`:
  - Privacy Policy: <https://josephb524.github.io/Porn-Blocker-Pure-Path-Privacy/>
  - Terms of Use: Apple Standard EULA — <https://www.apple.com/legal/internet-services/itunes/dev/stdeula/>
- **Anthropic-style chat history cap** (`MAX_MESSAGES` in `worker/src/index.ts`):
  40 messages.
