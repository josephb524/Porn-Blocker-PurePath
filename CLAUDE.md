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

Both engines go through `KeywordMatcher` so they block identically. The
user's custom keyword / custom website toggles
(`BlocklistManager.customKeywordsEnabled` / `customWebsitesEnabled`,
persisted) are honored by **both** engines — keep that parity when touching
either.

Safari ruleset invariants (`ContentBlockerRuleBuilder.build`):

- The whitelist is applied as a single trailing `ignore-previous-rules`
  rule (`if-domain: ["*host"]`) appended **last** — it must stay last or it
  stops exempting the rules above it, including the 264 core bundle rules
  that carry no `unless-domain`.
- `maxAPIDomainRules = 100_000` (of ~173k downloaded; evenly sampled).
  Verified compiling in the simulator; re-verify on the oldest physical
  device before raising further.
- `ContentBlocker/blockerList.json` is bundled in **both** targets — the
  main app needs it so the dynamic ruleset gets all 264 core rules instead
  of the 33-rule `essentialStaticRules()` fallback.
- `ContentBlockerRequestHandler` validates the dynamic file with a cheap
  existence + size check only. The full `JSONSerialization` parse was
  removed deliberately — at 100k rules it blew the extension's memory
  budget, and `ContentBlockerRuleBuilder.write` already round-trip
  validates before writing. Don't reintroduce the parse.

Safe Browser specifics:

- **Safe-search enforcement** (`Coordinator.safeSearchEnforcedURL`):
  main-frame GET navigations to google/bing/duckduckgo/yahoo/ecosia search
  pages are cancelled and reloaded with the strict parameter
  (`safe=active`, `adlt=strict`, `kp=1`, `vm=r`, `safesearch=2`). The
  rewrite is idempotent — nil on a compliant URL is the loop guard. The
  Safari declarative engine cannot rewrite URLs, so this exists only here.
- **Blocked-attempt counter**: main-frame blocks call
  `BlocklistManager.recordBlockedAttempt()` → app-group key
  `blockedAttemptCount`, surfaced live by the Dashboard's "Attempts
  Blocked" card via `@AppStorage`. Subframe blocks are deliberately not
  counted (one page would inflate the count by dozens). Safari's
  declarative blocker can't report matches, so this is Safe Browser only.
- Domain lookups use `BlocklistManager.hostMatches(_:anyDomainIn:)` — an
  O(labels) parent-suffix walk. Never reintroduce
  `Set.contains(where: hasSuffix)` scans; the API set has ~173k entries.

#### Safe Browser tabs & session restore

`BrowserTabStore.swift` holds `BrowserTab` (id, urlString, title,
`interactionState` blob) and `actor BrowserTabStore`, which persists a
`TabSessionSnapshot` to `Documents/safe_browser_tabs.json` (atomic write,
I/O on the actor). `SafeBrowserViewModel` is the tab manager:

- **One live `WKWebView` per activated tab**, created lazily on first
  activation; restored-but-untouched tabs hold only their serialized blob.
  LRU cap of 4 live webviews (`maxLiveWebViews`); eviction banks
  `interactionState` back into the model and invalidates that tab's KVO.
- **Hydration**: if a tab has `interactionState`, it is assigned **instead
  of** calling `load()` — the restore is async and issues its own
  navigation, so a simultaneous load races it. A next-runloop
  `url == nil` check falls back to loading `urlString` (corrupt blob).
- **Saves** fire on `UIApplication.willResignActiveNotification` (observed
  in the view model — scenePhase on the view is unreliable when Safe
  Browse isn't the visible tab) plus a 2s debounce after tab
  create/close/switch. `hasRestored` guards all saves so a fast background
  at launch can't clobber the file with an empty session.
- The shared `Coordinator` is delegate for **all** webviews; every push of
  visible state (`isLoading`, `currentURL`, progress, canGo*, overlays) is
  identity-guarded with `webView === viewModel.activeWebView`. Per-tab
  data (title/urlString KVO into the tab model) is deliberately unguarded.
  `recordBlockedAttempt()` is also unguarded — background-tab blocks are
  real blocks.
- `webViewWebContentProcessDidTerminate` reloads — iOS reclaims background
  WebContent processes and the tab would otherwise stay blank.
- The `webView(for:coordinator:)` factory is called from `updateUIView`
  (a render pass) and must not mutate `@Published` state synchronously.

Browser chrome: address pill (green badge + bold-host/gray-path styled URL,
in-pill spinner while loading, tap to edit), **horizontal swipe on the pill
switches tabs** (`activateAdjacentTab`, clamped), boxed tab-count button →
`TabSwitcherView` (list/grid layouts, grid default via
`tabSwitcherGridLayout`, tab search, monogram favicons with a hand-rolled
stable hash — Swift's `hashValue` is per-run seeded), blue `+` = new tab,
second row = back/forward + ellipsis menu (Reload/Stop, Close Tab).

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

#### Launch-time status resolution

StoreKit's answer is async, so `isSubscribed` used to be a hardcoded `false`
for the first second of every launch. That flashed a red "Protection Inactive"
dashboard at paying users **and** — because `BlocklistManager.init()` runs in
that window — wrote `isSubscribed: false` to the shared container and rebuilt
the Safari ruleset as `noopRules()`, genuinely disarming the blocker. Three
pieces prevent that; keep all three:

- **Seed from cache.** `SubscriptionManager` persists the last *resolved*
  status to `UserDefaults.standard` (`cachedSubscriptionActive` /
  `cachedSubscriptionExpiry`, written only by `markStatusResolved()`) and
  `seedFromCache()` restores it synchronously in `init()`. The seed is gated by
  `cachedStatusIsActive(flag:expiry:now:)` — a `nonisolated static` pure
  function requiring a **present, future** expiry, so an optimistic `true`
  can't outlive the subscription it came from. These keys are deliberately
  **not** the app-group keys `BlocklistManager` mirrors; those get written
  before StoreKit resolves and would seed a stale value. `signedTransactionJWS`
  is never seeded — it must stay a real Apple-signed value.
- **`hasResolvedStatus`.** `false` until StoreKit has actually been asked.
  `markStatusResolved()` sets it and writes the cache together (called from
  both `updateSubscriptionStatus(from:)` and `setSubscriptionExpired()`,
  always *before* they post `.subscriptionStatusChanged`, so observers see a
  resolved status). `DashboardView.statusUnknown` uses it to show a neutral
  "Checking Protection…" card instead of the red alarm on a cache miss
  (fresh install / reinstall), and `BlocklistManager` guards **both** downgrade
  paths on it — `saveSubscriptionStatusToSharedStorage()` and
  `rebuildContentBlocker()` return early rather than writing `false` / the
  no-op ruleset. Safe because the check posts `.subscriptionStatusChanged` on
  *both* branches, so the real write always follows.
- **`init()` runs the two startup tasks separately.** `checkSubscriptionStatus()`
  reads on-device entitlements; `loadProducts()` is a network round-trip only
  the paywall needs. They used to be `await`ed in sequence, which queued the
  status check behind the App Store. Don't re-serialize them.

#### Subscription products

Product IDs must match in **four** places: `SubscriptionManager.swift`,
`worker/src/verify.ts` (`VALID_PRODUCT_IDS`), App Store Connect, **and**
`Porn Blocker.storekit` (the local StoreKit test config — see below).

- `pornBlocker` — yearly
- `monthlyPornBlocker` — monthly

Both declared in `SubscriptionManager` as `nonisolated static let` so the
detached transaction listener can reference them without Swift 6 isolation
warnings.

#### Simulator subscription testing (`Porn Blocker.storekit`)

`Porn Blocker.storekit` defines both products locally so subscription-gated
features (Safe Browser, Buddy chat, whitelist, the full Safari ruleset) can
be exercised in the simulator without sandbox accounts.

It is deliberately **not** referenced by the shared scheme, so normal runs
use real StoreKit. To enable it: Product → Scheme → Edit Scheme → Run →
Options → StoreKit Configuration → `Porn Blocker.storekit`.

The config only applies when Xcode launches the app through the scheme's
`LaunchAction`. `xcrun simctl launch` ignores it entirely and the app will
report no products — build/install/launch from Xcode when testing purchases.

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
- **The layout is deliberately compact** (170pt header, tight feature
  rows) so both plan prices, the CTA, and the full disclosure sit above
  the fold with no scrolling — which *helps* 3.1.2(c). Don't re-inflate.
- **`.toolbarColorScheme(.dark, for: .navigationBar)` is load-bearing** —
  iOS 26's glass toolbar buttons ignore `.foregroundColor(.white)` and
  render dark labels over the header gradient without it.
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

**Keyboard dismiss — two ways** in the chat content:
- tap the chat background (`.onTapGesture` on the `Color(.systemGroupedBackground)` wrapper)
- swipe down on the message list or empty-state scroll view (`.scrollDismissesKeyboard(.interactively)`)

Deliberately **no** `Done` button in `ToolbarItemGroup(placement: .keyboard)` — on iOS 26 it renders as a floating capsule that overlaps the send button; don't re-add it.

### Onboarding

`OnboardingView.swift`, mounted by `ContentView`'s conditional swap on
`@AppStorage("hasSeenOnboarding")` (no fullScreenCover — avoids a tab-bar
flash and delays singleton init until the flow completes). Five
button-driven steps: Welcome → How It Works → streak start date → daily
reminder → paywall. Non-obvious rules:

- **Side effects fire only on explicit CTA taps** — Skip and Back are true
  no-ops, protecting updaters' existing streaks (`setStartDate` unions day
  keys; the reminder path goes through `updateHabit` →
  `HabitNotificationManager.schedule`, which itself requests notification
  permission — don't add a separate auth call).
- The paywall page is the untouched `PaywallScreen` in a `NavigationStack`
  wrapper with **zero onboarding chrome** over it (3.1.2(c)). Completion is
  detected via its `isPresented` binding: every flip on the
  purchase/restore paths happens after `isSubscribed` is already true, so
  branching on `isSubscribed` in the `onChange` is race-free. Subscribed →
  `SafariExtensionInstructionsView` sheet whose `onDismiss` completes the
  flow; "Later" completes directly. Already-subscribed users skip the
  paywall page entirely.
- `hasSeenOnboarding` flips **only** in `completeOnboarding()` — never in
  `onDisappear` (would fire on the swap) and never before the extension
  sheet dismisses (would unmount the sheet). Kill mid-flow → flow restarts
  next launch; that's intentional and safe because the side effects are
  idempotent.
- Cold-launch notification taps survive onboarding:
  `HabitNotificationRouter.pendingHabitID` persists until `MainTabView`
  finally mounts and consumes it in `.onAppear`.

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
- **Relapse removes today + yesterday, nothing else.** `recordRelapse`
  (triggered by the hero card's "I slipped today" link → confirmation
  dialog) deletes exactly those two day keys — the minimum that defeats
  the grace day so the streak reads 0 immediately. All older check-ins
  stay (history grid, "days logged"). Removing only today would NOT
  reset anything: the grace day would keep counting from yesterday.
- **`bestStreakRecord` preserves Longest Streak across relapses.**
  `longestStreak` for check-in habits is
  `max(longestCheckInStreak(), bestStreakRecord)`; `recordRelapse`
  freezes the current best into `bestStreakRecord` *before* removing
  keys, because the removal can shorten the final run and would
  otherwise shrink the displayed record by up to 2 days.
- **Backdating backfills real check-ins.** `setStartDate` (reached via
  `PornFreeStartDateSheet` — from the hero card's "Set your start date"
  link at streak 0, or the "I've been clean since…" row in Porn Free
  Settings) writes day keys from the chosen date **through today
  inclusive** (stopping at yesterday would let the streak silently
  collapse at midnight), unioned with existing keys. The sheet's
  `dayCount` preview counts the chosen day as day 1 to match.
  `EditHabitView` re-syncs its `localCheckIns` snapshot when this sheet
  closes (`.onChange(of: showStartDateSheet)`) — without that, the edit
  sheet's own Save would clobber the backfill with stale data. The hero
  card also has a one-tap check-in capsule (toggles
  `checkIn`/`undoCheckIn`, mirroring `HabitCard`).
- **Milestone celebrations fire on crossings, not thresholds.**
  `celebrateIfMilestoneCrossed` in `StatsView` compares the previous
  streak (`lastSeenStreak`, seeded in `.onAppear`) to the new one and
  celebrates the *highest* milestone with `old < days <= new` — so an
  existing 19-day streak never retro-celebrates "1 Week" on tab open or
  its next check-in, and a backdate jump celebrates once, not once per
  badge. `TrackedHabit.lastCelebratedMilestone` makes each milestone
  fire once per run (blocks undo-then-recheck repeats) and is
  deliberately reset by `recordRelapse` so rebuilt streaks celebrate
  again. The overlay (`MilestoneCelebrationView` + `ConfettiBurst`)
  mounts on the `NavigationStack` in `StatsView.body`.
- **Persistence is deliberately paranoid.** `dayKeyFormatter` is pinned
  to `en_US_POSIX` + Gregorian (an unpinned formatter under a
  Buddhist-calendar or Arabic-numeral locale writes keys that never
  match again, silently zeroing streaks); `sanitizeDayKeys()` runs every
  launch between `load()` and `ensureBuiltInHabit()` to repair/drop
  legacy non-canonical keys and dedupe. `TrackedHabit.init(from:)` is
  fully tolerant — every field has a fallback, `isBuiltIn` decodes
  first so a failed `id` falls back to `TrackedHabit.builtInID` (the
  built-in is identified by id everywhere; a random UUID would spawn a
  duplicate), and `isAutoStreak` defaults to `false` so a decode
  fallback can never re-trigger the auto-streak migration and resurrect
  a relapsed streak. On a store-level decode failure, `load()` copies
  the raw blob to `trackedHabits_v2_corrupt` **before** anything can
  overwrite the main key, then salvages per-element via
  `FailableDecodable`. Don't weaken any of this — the failure mode it
  prevents is a user's year-long history silently vanishing.
- **Logic test harness.** `HabitManager.swift` + `Log.swift` compile
  standalone for macOS, so streak/relapse/backfill/decode logic can be
  tested without the simulator:
  `swiftc -parse-as-library -o harness "Porn Blocker/HabitManager.swift" "Porn Blocker/Log.swift" harness.swift`
  with a scenario-per-process main (the singleton's init runs
  load/sanitize/ensure once, so seed `UserDefaults` first, one scenario
  per run).
- **The hero ring is absolute progress, not segment progress.**
  `ringProgress(streak:)` in `StatsView.swift` is
  `min(1.0, streak / nextMilestone)` — it counts from **zero** to the next
  milestone in `allMilestones`, so a 19-day streak fills 19/30 ≈ 63%. It
  originally measured progress *within* the current milestone band
  (`(streak - prev) / (next - prev)`, i.e. 12/23 ≈ 52% at 19 days), which
  contradicted the "Next Goal 11d" label sitting right under it —
  `nextMilestoneLabel` and the `MilestoneBadge` fill state
  (`currentStreak >= milestone.days`) both count from zero. Keep all three
  on the absolute framing. At 365+ days `next` falls back to 365 and the
  `min(1.0, …)` clamp keeps the ring full.
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

**Tap routing** (notification → Streaks tab, and nothing more):

1. `AppDelegate` (in `Porn_BlockerApp.swift`, via
   `@UIApplicationDelegateAdaptor`) installs `NotificationDelegate.shared`
   as `UNUserNotificationCenter.current().delegate` at launch — early
   enough to catch cold-launch taps.
2. `NotificationDelegate` parses the habit UUID (from `userInfo`, falling
   back to the identifier prefix for older scheduled notifications) and
   stores it on `HabitNotificationRouter.shared.pendingHabitID` — a
   `@MainActor ObservableObject` singleton.
3. `MainTabView` is the **sole** consumer: `showStreaksForPendingHabit()`
   switches `selectedTab = 3` (Streaks) and calls `router.clear()`, driven
   by cold-launch `.onAppear` or warm `.onChange`.

The tap deliberately lands on the Streaks tab itself — it does **not**
open `EditHabitView` for that habit. `StatsView` used to consume the
router and present that sheet; it no longer references the router at all.
Clearing in `MainTabView` (rather than `StatsView`) also means a reminder
for a since-deleted habit still routes and still gets consumed — the old
lookup-guarded clear left a stale ID that suppressed the next tap on that
same habit.

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

## Tests

`Porn BlockerTests` is an **app-hosted** XCTest unit-test target (~50 tests)
covering the pure-logic invariants: keyword word-boundaries, ruleset
composition (whitelist-rule-last, 100k cap, keyword exemptions), safe-search
enforcement + its idempotency loop guard, streak/relapse/backdate semantics
and the tolerant habit decoder, tab-session persistence, host matching, and the
subscription-cache seed rule.

```sh
xcodebuild test -project "Porn Blocker.xcodeproj" -scheme "Porn Blocker" \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

CI runs the same command per push (`.github/workflows/tests.yml`).

Non-obvious constraints:

- Tests **must stay app-hosted** (`TEST_HOST`): `loadBundleRules()` reads
  `Bundle.main`, so the builder tests depend on `blockerList.json` being in
  the app bundle. Unhosted, `build()` silently falls back to 33 rules and
  the composition tests break.
- `HabitManager` tests run on the shared singleton in the test host's
  sandbox — always on **throwaway custom habits deleted in a defer/tearDown**,
  never the built-in Porn Free habit.
- `BlocklistManager.cleanURL` is internal (not private) specifically so the
  normalization tests can call it.
- The baseline rule counts (264 core / 50 keyword / 22 cosmetic) are
  asserted as constants in `ContentBlockerRuleBuilderTests` — update them
  when the core bundle or keyword lists change.

## Buddy Chat backend (`worker/`)

A Cloudflare Worker that:

1. Verifies the iOS app's StoreKit 2 signed transaction JWS locally
   (`src/verify.ts`) — bundle ID, product ID, expiry, revocation.
2. Validates `messages` at runtime — roles restricted to user/assistant,
   16 KB/message + 200 KB total caps (blocks system-role injection and
   oversized payloads).
3. Rate-limits per `originalTransactionId`: burst limiter 20/60s (the
   ratelimit binding only supports 10s/60s periods) + KV daily quota of
   200/UTC-day (`quota:` keys in `SUB_CACHE`). Both bindings are optional
   in code (`if (env.…)` guards), so the worker runs without them.
4. Proxies the conversation to **Fireworks AI** with streaming
   (`src/fireworks.ts`), using their OpenAI-compatible chat completions API.
   Upstream errors map to a generic 502 `{error:"upstream_error"}` — don't
   pass Fireworks bodies/statuses through.
5. Re-frames Fireworks' OpenAI-style SSE into a tiny `data: {"text":"…"}`
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
**This does not stop deliberate forgery** — bundleId/productIds are public
(extractable from the shipped binary) and expiry just needs to be in the
future, so anyone inspecting the app's traffic can mint a passing JWS and
rotate `originalTransactionId` to dodge per-user rate keys. The claim
checks only keep honest clients honest; abuse mitigation is the burst
limiter + KV daily quota. If abuse appears, add real signature
verification against Apple's root cert (x5c chain via
`crypto.subtle.verify`) — backward compatible, since real app versions
send genuine Apple-signed JWS.

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
  `group.com.jose.pimentel.PornBlocker`. Also holds the
  `blockedAttemptCount` counter the Dashboard stat card observes.
- **Browser session file**: `Documents/safe_browser_tabs.json`
  (`BrowserTabStore`). Corrupt/missing → fresh single-tab session.
- **Worker endpoint** in `BuddyChatService.swift` — must be updated after
  every `wrangler deploy`.
- **Paywall legal URLs** in `PaywallScreen.swift`:
  - Privacy Policy: <https://josephb524.github.io/Porn-Blocker-Pure-Path-Privacy/>
  - Terms of Use: Apple Standard EULA — <https://www.apple.com/legal/internet-services/itunes/dev/stdeula/>
- **Anthropic-style chat history cap** (`MAX_MESSAGES` in `worker/src/index.ts`):
  40 messages.
