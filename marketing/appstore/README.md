# App Store screenshots

Three sets, all generated from `screens.html`:

- **iPhone 6.9"** — `s01.png` … `s06.png`, 1290×2796
- **iPad 13"** — `ipad01.png` … `ipad06.png`, 2064×2752
- **iPhone Duo** — `duo01.png` … `duo06.png`, 1398×2034 (the outer display)

Apple auto-scales the first two to the smaller device classes in their
family, so they cover every required size. The Duo set is its own display
type — see "iPhone Duo set" below.

| Panel | iPhone | iPad | iPhone Duo |
|---|---|---|---|
| Blocked before you see it — Protection Center | `s01.png` | `ipad01.png` | `duo01.png` |
| Build a streak you're proud of — Insights / milestones | `s02.png` | `ipad02.png` | `duo02.png` |
| A browser that can't wander — Safe Browse tabs | `s03.png` | `ipad03.png` | `duo03.png` |
| Someone in your corner at 2am — Buddy chat | `s04.png` | `ipad04.png` | `duo04.png` |
| A blocklist that keeps up — proof + Blocklist screen | `s05.png` | `ipad05.png` | `duo05.png` |
| Protected in under a minute — setup steps + Settings | `s06.png` | `ipad06.png` | `duo06.png` |

`_contactsheet.png`, `_contactsheet-ipad.png` and `_contactsheet-duo.png`
are review-only strips. Don't upload them.

## iPhone Duo set

`?d=duo` renders the panels at 1398×2034, the Duo's outer display, folded.
App Store Connect takes one Duo set, display type `APP_IPHONE_DUO`, at
either the outer screen's size or the inner screen's (2007×2853). It's
optional until April 2027, required after that for apps built with the
iOS 27.1 SDK, and it earns the "optimized for iPhone Duo" badge. **Upload it
only to a version whose build was archived with Xcode 27.1 or later.** An
iOS 27.0-SDK build runs windowed on the outer display beside a black strip,
so it wouldn't match these images.

The mock screen mirrors what the app really does there, as captured in the
simulator on 2026-10-19 (`CLAUDE.md` → "iPhone Duo"):

- The app keeps its iPhone layout in a 466×678pt window. The system puts the
  status bar (time and wifi only), the tab bar (icons only, the selected
  one blue on a grey disc, as in the app) and toolbar buttons (Streaks' `+`,
  the Blocklist back button) in a rail on the trailing edge. That leaves a
  382pt content column: `.screen` gets `padding-right:84px`, and
  `statusbar()`, `tabbar()` and `railBtn()` branch on `DUO`.
- The screens are the same markup, so a screen taller than 678pt is cut at
  the bottom, as the real one scrolls. The chat composer drops to the bottom
  inset, since there's no bottom tab bar.
- The device's leading corners are nearly square and its trailing corners
  rounded: the hinge is the leading edge (the simulator's display mask).
- Keep the floating cards off the rail. It's what makes the set read as the
  Duo, so the right-hand cards sit at the device's bottom corner.

Only the outer screen is drawn. The simulator boots folded, and only Xcode
27.1's DeviceHub can open it, so the inner screen's layout hasn't been seen.

**Uploaded 2026-10-20** to the 1.6.2 draft as `APP_IPHONE_DUO` in all six
locales: English files for en-US and en-GB, `es/` for es-MX and es-ES,
`pt-BR/`, and `de/`. Each set was read back with six screenshots in order,
checksums matching these files, processed at 1398×2034. The upload went
through the API one set at a time; `deliver --overwrite_screenshots` would
have replaced the iPhone and iPad sets too.

## ⚠️ The iPad set shows an unadapted layout

The app has **no iPad adaptation at all** — no `horizontalSizeClass` checks, no
`userInterfaceIdiom` branches, no `frame(maxWidth:)` caps on any content
column, and a plain `TabView`. Every content stack is
`.frame(maxWidth: .infinity)`, so on a 1032×1376pt canvas the iPhone layout
simply stretches: cards span the full width, and the content runs out around
40% of the way down the screen, leaving a large empty region.

The iPad panels render that honestly — they are what the shipping app actually
looks like on a 13" iPad. The floating cards are positioned over the empty
lower region deliberately, to make that space read as composition rather than
as a void. **No screenshot framing can fix this**; at any scale where the iPad
fits the panel width, the content cannot fill the panel height.

Two real options, both a product decision:

1. **Drop iPad support** — set `TARGETED_DEVICE_FAMILY = 1` in
   `project.pbxproj` (currently `"1,2"`). No iPad screenshots required, and it
   removes the Guideline 4.0 exposure that comes with shipping a visibly
   unoptimized iPad build. Check App Analytics for iPad install share first.
2. **Actually adapt the layout** — this is real design work, not a one-liner.
   A `maxWidth` cap centers the column but does not solve the vertical
   emptiness; filling a 1376pt canvas means a genuine iPad layout (multi-column
   dashboard, sidebar navigation, or similar). Regenerate this set afterward.

## Regenerating

Panels come from one HTML file, selected with `?p=N`, plus `&d=ipad` for the
tablet set.

```sh
cd marketing/appstore
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for i in 1 2 3 4 5 6; do
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --window-size=1290,2796 \
    --screenshot="s0$i.png" "file://$PWD/screens.html?p=$i"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --window-size=2064,2752 \
    --screenshot="ipad0$i.png" "file://$PWD/screens.html?d=ipad&p=$i"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --window-size=1398,2034 \
    --screenshot="duo0$i.png" "file://$PWD/screens.html?d=duo&p=$i"
done
```

Opening `screens.html` with no `?p` shows a contact sheet (add `?d=ipad` or
`?d=duo` for the other sets; the Duo strip is rendered at 2142×526).

All sets share every `screen*()` function — the iPad versions are the same
markup in a 1032×1376 container, which is exactly why they reproduce the
stretch faithfully. Per-mode values (card positions, device scale, type sizes)
go through the `M(phone, ipad, duo)` helper (the Duo falls back to the phone
value) or a `body.ipad` / `body.duo` CSS rule; don't fork the screen
builders.

Rendering **must** happen on macOS with Chrome — the device mockups use
`system-ui` and `ui-rounded`, which resolve to SF Pro and SF Pro Rounded there.
On another platform the type will fall back and the panels will not match the
real app.

## Localized sets

`?l=es`, `?l=pt-BR` or `?l=de` renders a panel in that language; output
lives in `es/`, `pt-BR/`, `de/` with the same file names. Upload each folder
to the matching App Store Connect locale (Spanish covers es-MX and es-ES).

```sh
for L in es pt-BR de; do mkdir -p $L; for i in 1 2 3 4 5 6; do
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --window-size=1290,2796 \
    --screenshot="$L/s0$i.png" "file://$PWD/screens.html?p=$i&l=$L"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --window-size=2064,2752 \
    --screenshot="$L/ipad0$i.png" "file://$PWD/screens.html?d=ipad&p=$i&l=$L"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --window-size=1398,2034 \
    --screenshot="$L/duo0$i.png" "file://$PWD/screens.html?d=duo&p=$i&l=$L"
done; done
```

- Every visible string goes through `t('English')`, looked up in the `I18N`
  table near the bottom of `screens.html`; a missing key falls back to
  English. Use a `ctx:` key prefix when one English string needs two
  translations (`eyebrow:Safe Browse` vs the tab label).
- Device-UI strings mirror the app's `Localizable.xcstrings` translations —
  keep them in sync so the store images match what users see.
- Numbers, dates and times go through `nf`/`cf`/`df`/`tf` (locale-aware).
  The figures themselves are the `SITES`/`ATTEMPTS`/`KEYWORDS` constants.
- Translated sets get `text-wrap: balance` on subtitles (`body.l10n`) —
  English deliberately doesn't, so its PNGs stay byte-identical.
- Adding a language: add a column to `I18N`, render, and review the
  headline wraps and floating-card widths — German runs ~30% longer.

## Constraints baked into these panels

- **No fabricated social proof.** The previous set carried a "Popular Pick —
  Trusted by Millions" laurel badge. That is a false popularity claim under
  App Store Review Guideline 2.3 and was removed deliberately. Do not
  reintroduce awards, rankings, or review-count claims that aren't true.
- **No explicit sample content.** An earlier draft of `s05` rendered a literal
  blocked-keyword list. It was replaced with the Blocklist status screen —
  counts and update state only. Keep example content non-explicit; these
  images are public metadata.
- **The device UI mirrors the real app.** Colors, copy, and layout are taken
  from `DashboardView`, `StatsView`, `SafeBrowserView`, `BuddyChatView`, and
  `HabitManager.allMilestones`. If those screens change materially, update the
  corresponding `screen*()` function so the store images don't misrepresent
  the app.
- **Numbers shown:** 172,912 sites / 100 keywords / 18-day streak /
  1,284 attempts blocked (`SITES`/`KEYWORDS`/`ATTEMPTS` in `screens.html`).
  The keyword figure is `KeywordMatcher.predefinedKeywords.count` — it was
  previously a false "1,200+" (Guideline 2.3.1). Update it whenever the
  built-in keyword lists change.
- **Content must clear the tab bar.** Each mock screen is 430×932pt with an
  84pt tab bar. Content that runs past ~848pt gets clipped and reads as a
  rendering bug — the most common thing to break when editing.
