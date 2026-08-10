# ScreenBlock

An iOS app blocker with **no limit on how many apps you block** and a break budget you set
yourself: **1–5 breaks per day, 1–30 minutes each, with a 5-minute to 1-hour enforced wait
between them** (defaults: 3 breaks of 5 minutes, 15 minutes apart).
Built on Apple's Screen Time APIs
(FamilyControls / ManagedSettings / DeviceActivity), so the blocking is enforced by iOS
itself rather than by a VPN profile or a DNS trick.

## Why this exists

The App Store blockers tend to fail in one of two ways: they gate a basic block list
behind a subscription, or they cap how many apps you can add. Neither limit is technical.
Apple hands you a `Set<ApplicationToken>` with no size cap, and blocking one app costs
exactly what blocking forty does. ScreenBlock just doesn't add the artificial ceiling.

## How it works

Four processes share one App Group container:

| Target | Role |
|---|---|
| `ScreenBlock` | The app. Pick apps, toggle blocking, set the budget, spend a break. |
| `Monitor` | `DeviceActivityMonitor` extension. Re-applies the block when a break ends — **even if the app is force-quit**. |
| `ShieldConfig` | Draws the block screen. |
| `ShieldAction` | Handles taps on that screen, so you can start a break without opening ScreenBlock. |

### The break mechanism

This is the one genuinely tricky part. iOS **rejects any `DeviceActivitySchedule` shorter
than 15 minutes**, so a 1-minute break cannot be expressed as a schedule. ScreenBlock uses
two triggers instead:

1. **`DeviceActivityEvent` threshold (primary).** Thresholds go down to 1 minute and fire
   on *accumulated usage* of the blocked apps. A "5-minute break" is therefore 5 minutes
   of actually using those apps — idle time in your pocket doesn't burn it.
2. **Padded schedule interval (backstop).** The monitoring window is padded up to the
   15-minute floor. `intervalDidEnd` closes any break whose threshold never tripped —
   e.g. you started a break and then never opened the app.
3. **Foreground reconcile (repair).** `BreakEngine.reconcile()` runs on every app launch
   and foreground, closing a break whose wall clock expired while nothing was watching.

Ending a break early does **not** refund it. That's the point of a budget.

### The cooldown

When a break ends, a wait starts before another can begin — otherwise the whole day's
allowance could be spent in one continuous sitting, which is the failure mode the budget
exists to prevent.

Unlike breaks, the cooldown is **wall clock**, deliberately. A usage-based cooldown could
be run down from inside a blocked app, which would defeat it entirely.

The cooldown is anchored to when the break *actually* ended, not to when ScreenBlock
noticed. Ending early makes that the moment you tapped; a break that expired while the app
was closed is anchored to its scheduled end (`min(scheduledEnd, now)`). Anchoring to "now"
unconditionally would silently stretch the cooldown by however long the app stayed shut.

### Daily reset

Breaks reset at your local midnight. There's no scheduled job — state carries a
`yyyy-MM-dd` stamp and whichever process reads it first on a new day performs the reset.

## Requirements

- **A physical iPhone.** The Screen Time APIs do nothing in the Simulator: the picker is
  empty and every write to `ManagedSettingsStore` is silently dropped. The project
  compiles for the Simulator, but you cannot test behavior there.
- Xcode 16+ and iOS 16.0+ on device.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`.
- An Apple Developer account. A **free** Apple ID is enough for personal on-device use.

## Setup

```bash
git clone https://github.com/sleepyowlll/screenblock.git
cd screenblock
```

1. Open `Config/Signing.xcconfig` and set your `DEVELOPMENT_TEAM` (10-character Team ID
   from Xcode › Settings › Accounts). If the default `BUNDLE_ID_PREFIX` collides with
   something already registered, change it — the App Group follows automatically.

   This is the **only** file you need to edit. All four bundle IDs, all four entitlements
   files, and the App Group identifier in every Info.plist derive from those two values.

2. Generate and open the project:

   ```bash
   ./generate.sh
   open ScreenBlock.xcodeproj
   ```

3. Select your iPhone and run. On first launch, tap **Grant access** and approve the
   Screen Time prompt.

`ScreenBlock.xcodeproj` is generated and gitignored — edit `project.yml`, not the project.

### The entitlement caveat

`com.apple.developer.family-controls` works for **development builds signed to your own
device** out of the box. Shipping to TestFlight or the App Store requires
[requesting the distribution entitlement from Apple](https://developer.apple.com/contact/request/family-controls-distribution),
which is a manual review. Personal use needs nothing beyond a free Apple ID; you'll just
need to re-sign every 7 days on a free account.

## Using it

1. **Choose apps** — Apple's own picker. Pick as many apps, whole categories, and websites
   as you want.
2. **Toggle blocking on.** Blocked apps now show the ScreenBlock shield.
3. **Set your budget** — the gear in the top right, or tap the "Each break lasts" row on
   the home screen. Breaks per day is a 1–5 segmented control; break length is a 1–30
   minute slider; the wait between breaks is a 5–60 minute slider. Changes save immediately
   and the block screen picks them up at once.
4. **Need in?** Either open ScreenBlock and hit **Start break**, or tap **Take a break**
   directly on the block screen — that spends one break and drops you straight into the
   app without ever leaving it.

Lowering breaks-per-day below what you've already spent today doesn't claw anything back;
it takes effect from tomorrow, and the settings screen says so when that applies.

## Privacy

ScreenBlock never learns which apps you blocked. `FamilyControls` returns opaque,
device-bound tokens — no bundle IDs, no names, nothing inspectable or loggable. All state
lives in a local App Group container. There is no network code in this project.

## Project layout

```
Config/Signing.xcconfig   Team ID + bundle prefix — the only file to edit
project.yml               XcodeGen spec (4 targets)
Shared/                   Compiled into all four targets
  AppIdentifiers.swift    App Group plumbing
  BreakState.swift        Hard limits + state model + daily rollover
  BreakSettings.swift     User-chosen breaks/day and break length
  BreakStore.swift        App Group persistence
  ShieldController.swift  The only writer of shield tokens
  BreakEngine.swift       start / end / reconcile a break
ScreenBlock/              SwiftUI app
Monitor/                  DeviceActivityMonitor extension
ShieldConfig/             Block screen appearance
ShieldAction/             Block screen buttons
```

## Known limits

- Determined users can disable the block by deleting the app or revoking Screen Time
  access in Settings. There is no lock-down mode; this is a speed bump against impulse,
  not a security control.
- Usage-based break timing means a break can outlive its wall clock if you never open the
  blocked apps — the reconcile pass cleans that up next time you open ScreenBlock.
- Only the standard icon is supplied. iOS 18+ derives its dark and tinted home-screen
  variants automatically; hand-tuned ones aren't included.

## The app icon

The icon is generated, not drawn — `Tools/make-icon.swift` renders it with CoreGraphics:

```bash
swift Tools/make-icon.swift
```

That writes `ScreenBlock/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1024×1024) plus a
throwaway 120px preview for checking that the mark still reads at home-screen size. Colours
track `Theme.accent`, so the icon and the in-app UI can't drift apart.

Two constraints are baked into the renderer and worth keeping if you edit it: the bitmap
uses `noneSkipLast` so the PNG carries **no alpha channel** (App Store Connect rejects app
icons with transparency), and no corner rounding is baked in (iOS applies its own mask —
a pre-rounded icon shows a dark fringe).
