# App Store screenshots

Two sets, both generated from `screens.html`:

- **iPhone 6.9"** — `s01.png` … `s06.png`, 1290×2796
- **iPad 13"** — `ipad01.png` … `ipad06.png`, 2064×2752

Apple auto-scales each to the smaller device classes in its family, so these
two sets cover every required size.

| Panel | iPhone | iPad |
|---|---|---|
| Blocked before you see it — Protection Center | `s01.png` | `ipad01.png` |
| Build a streak you're proud of — Insights / milestones | `s02.png` | `ipad02.png` |
| A browser that can't wander — Safe Browse tabs | `s03.png` | `ipad03.png` |
| Someone in your corner at 2am — Buddy chat | `s04.png` | `ipad04.png` |
| A blocklist that keeps up — proof + Blocklist screen | `s05.png` | `ipad05.png` |
| Protected in under a minute — setup steps + Settings | `s06.png` | `ipad06.png` |

`_contactsheet.png` and `_contactsheet-ipad.png` are review-only strips.
Don't upload them.

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
done
```

Opening `screens.html` with no `?p` shows a contact sheet (add `?d=ipad` for
the tablet one).

Both sets share every `screen*()` function — the iPad versions are the same
markup in a 1032×1376 container, which is exactly why they reproduce the
stretch faithfully. Per-mode values (card positions, device scale, type sizes)
go through the `M(phone, ipad)` helper or a `body.ipad` CSS rule; don't fork
the screen builders.

Rendering **must** happen on macOS with Chrome — the device mockups use
`system-ui` and `ui-rounded`, which resolve to SF Pro and SF Pro Rounded there.
On another platform the type will fall back and the panels will not match the
real app.

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
- **Numbers shown:** 302,723 sites / 1,200+ keywords / 18-day streak /
  1,284 attempts blocked. The two blocklist figures should stay consistent
  with what the app actually ships.
- **Content must clear the tab bar.** Each mock screen is 430×932pt with an
  84pt tab bar. Content that runs past ~848pt gets clipped and reads as a
  rendering bug — the most common thing to break when editing.
