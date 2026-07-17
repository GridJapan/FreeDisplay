> **GridJapan fork.** Fixes four upstream bugs, all still present in `huberdf/FreeDisplay` as of
> `07ba072`. Everything below the horizontal rule is the upstream README, unchanged.
> Upstream: [huberdf/FreeDisplay](https://github.com/huberdf/FreeDisplay).

# Bugs this fork fixes

| # | Symptom | Cause in one line |
|---|---------|-------------------|
| 1 | **The app dies** the first time it changes an external display's brightness over DDC | A `@MainActor` closure runs on the DDC queue and Swift's isolation check traps |
| 2 | **The menu shows only its Quit button** — no displays, no tools, nothing | A `ScrollView` has no ideal height, and a `.window` MenuBarExtra sizes to the ideal |
| 3 | **Choosing an external display as your main one reverts** half a second later | Auto-arrange fires on that very change and drags the display off the origin |
| 4 | **A third virtual display is never created** if two already share its resolution | The duplicate guard matches on width and height instead of identity |

Details below, in that order.

# 1. The crash

FreeDisplay dies with `EXC_BREAKPOINT (SIGTRAP)` the first time it successfully writes brightness
over DDC to an external display. Not a race — if you reach the path, you crash.

**How to reproduce.** Put the cursor on an external display that answers DDC, then press a
brightness key (or drag FreeDisplay's own brightness slider). The app is gone before the monitor
finishes dimming.

**Why it took us 17 hours to hit it.** `BrightnessKeyService` only intercepts brightness keys while
the cursor sits on an *external* display — on the built-in display the keys pass through to macOS
and nothing of ours runs. So an install can look perfectly healthy until the first time you happen
to adjust brightness with the pointer parked on the external monitor.

## Root cause

`DDCService.writeAsync` invokes its completion on `ddcQueue`, never hopping to main:

```swift
ddcQueue.async {
    ...
    completion?(true)   // ← on ddcQueue
}
```

Both callers write that completion inside a `@MainActor` method (`BrightnessService.setBrightness`
and `.setBrightnessSmooth`), and a closure literal **inherits the enclosing isolation**. The
completion is therefore `@MainActor`-isolated, and so is every closure nested in it — including the
one handed to `NSLocking.withLock`:

```swift
) { [weak self] success in
    guard let self else { return }
    if success {
        self.ddcAvailableLock.withLock { self.ddcAvailable[displayID] = true }   // ← trap
```

Passing that isolated closure where a non-isolated `@Sendable` function is expected makes the
compiler emit an isolation-asserting thunk. On `ddcQueue` the assert fails, and Swift's concurrency
runtime traps exactly as designed:

```
_dispatch_assert_queue_fail
dispatch_assert_queue
_swift_task_checkIsolatedSwift
swift_task_isCurrentExecutorWithFlagsImpl
closure #1 in closure #1 in closure #6 in BrightnessService.setBrightnessSmooth(_:for:isAutoAdjust:)
specialized NSLocking.withLock<A>(_:)
closure #1 in closure #6 in BrightnessService.setBrightnessSmooth(_:for:isAutoAdjust:)
closure #1 in DDCService.writeAsync(displayID:command:value:completion:)
```

`refreshBrightness` survives the same callback only by accident: it calls `lock()` / `unlock()`
directly, so no closure — and no thunk — is ever created.

## The fix

Mark both completion parameters `@Sendable`. A `@Sendable` closure literal does not inherit actor
isolation, so no assert is emitted and the compiler starts checking these callbacks for real. The
three existing call sites need no changes: they only touch lock-protected state, a `nonisolated`
software-brightness fallback, and an explicit `Task { @MainActor in … }` hop.

```diff
-        completion: ((Bool) -> Void)? = nil
+        completion: (@Sendable (Bool) -> Void)? = nil
```

This also defuses a latent trap in `readAsync`, whose completion runs on `ddcQueue` on a cache miss
but synchronously on the *caller's* queue on a cache hit. The queue depended on cache state; now the
type system says so.

## How we found it

We hit this while running [gjPiP](https://github.com/GridJapan/gjPiPWindow), a GridJapan in-house
picture-in-picture app that mirrors any display — including FreeDisplay's virtual ones — into an
always-on-top window. FreeDisplay crashed, its virtual display vanished, and the PiP window closed
with it, so gjPiP was the obvious suspect.

**It was not the cause, and neither is any other capture tool.** gjPiP never touches DDC,
brightness, or display reconfiguration; it only calls ScreenCaptureKit and a CoreGraphics event tap.
The crash was triggered by a brightness key, and the only reason the two coincided is that the PiP
window put the cursor on the external monitor — which is precisely the condition
`BrightnessKeyService` requires before it does anything at all.

Reported on macOS 26.5.2 (25F84), Apple silicon, against upstream `07ba072`.

# 2. The menu shows only its Quit button

Open the menu bar icon and you get a 53pt strip: the version line, a ✕, and nothing else. No
display rows, no tools, no settings. Not conditionally hidden — the section headings render
unconditionally and were missing too. Every feature in the app was unreachable, which is easy to
mistake for the app simply not having any.

**Cause.** `MenuBarView` puts its content in a `ScrollView`. A scroll view has no ideal height of
its own — it takes whatever height it is offered — and a `.window` MenuBarExtra sizes its popover
to the content's *ideal* size. The scroll view asked for nothing and got it. The existing
`.frame(maxHeight: 700)` cannot help: it caps a height that was never requested.

**Fix.** Give the stack a minimum height, so there is an ideal size to open at.

```diff
-        .frame(maxHeight: 700)
+        .frame(minHeight: 480, maxHeight: 700)
```

The popover now opens at 496pt with its contents. Anything taller than 700pt scrolls, as intended.

# 3. Making an external display the main one reverts

Pick an external display as your main display and it reverts to the built-in about half a second
later — long enough to see it work before it undoes itself.

**Cause.** macOS makes whichever display holds origin (0, 0) the main one, so choosing an external
display moves it to the origin. That raises `.setMainFlag`, which `displayReconfigCallback`
forwards to `scheduleAutoArrange`. 500ms later `arrangeExternalAboveBuiltin` repositions every
external display relative to the built-in, dragging the just-chosen display off the origin and
handing main back. The feature is on by default (`fd.arrangement.externalAbove`) and has no UI to
turn off, so the revert is both unavoidable and unexplainable from the app's own surface.

**Fix.** Skip the rearrange while an external display is main. An explicit choice outranks a saved
layout preference, and "externals above the built-in" only describes a setup where the built-in is
main anyway.

# 4. Same-sized virtual displays are silently skipped

Configure three virtual displays at the same resolution and you get two — unpredictably, since
whether the previous one finished registering decides the outcome.

**Cause.** The autoCreate loop guards against duplicating a display left over from a crash by
asking whether one with matching **width and height** is already online. A second config of the
same size looks exactly like the first.

**Fix.** Match on the panel's name, which this fork makes unique per ordinal
(`FreeDisplay GridJapan`, `… 2`, `… 3`). The crash-recovery intent survives; same-sized configs
stop colliding.

## Also worth knowing

Not bugs, but two things that cost real time to learn:

- **Two declared display modes close in pixel count cannot coexist.** The window server keeps one
  and drops the other, `apply()` still reports success, and the loser simply never appears in
  `CGDisplayCopyAllDisplayModes`. Measured: 2.4% apart loses, 4.6% and 10% survive. Deterministic.
  See the comment on `standardModes` for the measurements.
- **`INFOPLIST_KEY_NSScreenCaptureUsageDescription` does nothing.** Xcode does not recognise that
  key, so it never reaches the built `Info.plist`. The usage string in `project.yml` has never been
  shown to anyone.

---

# FreeDisplay

> **Free & open-source alternative to [BetterDisplay](https://github.com/waydabber/BetterDisplay)** — all the core display management features, zero cost.

BetterDisplay is a great app, but its best features are locked behind a paid Pro license. FreeDisplay implements the most essential BetterDisplay features as a completely free, open-source macOS menu bar app.

[Download Latest Release](https://github.com/huberdf/FreeDisplay/releases/latest) | [Report an Issue](https://github.com/huberdf/FreeDisplay/issues)

---

## What BetterDisplay Features Does This Replace?

| BetterDisplay Feature | FreeDisplay | Notes |
|----------------------|:-----------:|-------|
| DDC Brightness & Contrast | ✅ | Hardware control via IOKit I2C (Intel) / IOAVService (Apple Silicon) |
| Software Brightness (Gamma) | ✅ | Per-display gamma table control with smooth transitions |
| Keyboard Brightness Keys for External Displays | ✅ | Intercepts brightness keys when cursor is on external display, shows native macOS OSD |
| Auto Brightness Sync | ✅ | Syncs external display brightness with built-in display changes |
| HiDPI Virtual Displays | ✅ | Creates HiDPI dummy displays via CGVirtualDisplay private API |
| Display Arrangement | ✅ | Position displays (external above built-in, etc.) |
| Resolution & HiDPI Switching | ✅ | Browse and switch all available display modes including HiDPI |
| ICC Color Profile Management | ✅ | Switch color profiles per display via ColorSync |
| Image Adjustment (Gamma/Temperature) | ✅ | Software contrast, color temperature, RGB channels, invert |
| Display Presets | ✅ | Save & restore full display configurations with one click |
| Virtual Display (Dummy) | ✅ | Create headless virtual displays |
| Notch Management | ✅ | Hide the MacBook notch with a black overlay |
| Launch at Login | ✅ | Via SMAppService |

### Not Included (intentionally)

- Screen streaming / PiP — rarely used, adds complexity
- EDID override — requires SIP disabled
- XDR/HDR extra brightness — requires specific hardware

---

## Screenshots

*Coming soon*

---

## Installation

### Option 1: Download DMG

1. Download `FreeDisplay.dmg` from [Releases](https://github.com/huberdf/FreeDisplay/releases/latest)
2. Open the DMG and drag **FreeDisplay.app** to **Applications**
3. First launch: right-click → **Open** (unsigned app, one-time approval)

### Option 2: Build from Source

```bash
brew install xcodegen
git clone https://github.com/huberdf/FreeDisplay.git
cd FreeDisplay
xcodegen generate
xcodebuild -scheme FreeDisplay -configuration Release build
```

---

## Permissions

| Permission | Why |
|------------|-----|
| **Accessibility** | Required for brightness key interception on external displays |

No internet connection required (except optional update checks via GitHub Releases API).

---

## Tech Stack

- **Swift 6** + **SwiftUI** (MenuBarExtra)
- **IOKit** — DDC/CI I2C for hardware brightness/contrast
- **CoreGraphics** — Display enumeration, resolution, arrangement
- **ColorSync** — ICC color profile management
- **CGVirtualDisplay** — Virtual display creation (private API, macOS 14+)
- **CoreDisplay** — Built-in display brightness reading (private API, via dlopen)
- Zero third-party dependencies

---

## Project Structure

```
FreeDisplay/
├── App/              # AppDelegate, app entry point
├── Models/           # DisplayInfo, DisplayMode, DisplayPreset
├── Services/         # System-level services (DDC, brightness, resolution, gamma, etc.)
└── Views/            # SwiftUI views for each feature section
```

---

## How It Works

FreeDisplay sits in your menu bar and talks directly to your displays:

- **External monitors**: Uses DDC/CI protocol over I2C (Intel) or IOAVService (Apple Silicon) to control hardware brightness, contrast, and other settings
- **Built-in display**: Uses CoreGraphics gamma tables for software brightness adjustment
- **Brightness keys**: Installs a CGEventTap to intercept keyboard brightness keys and route them to the display under your mouse cursor
- **Auto brightness**: Polls the built-in display brightness via CoreDisplay private API and proportionally adjusts external displays
- **HiDPI**: Creates virtual displays via CGVirtualDisplay private API, or writes display override plists for persistent HiDPI

---

## Contributing

Issues and PRs welcome. This project uses:
- `xcodegen` for project generation (edit `project.yml`, not `.xcodeproj`)
- Swift 6 with `SWIFT_STRICT_CONCURRENCY: minimal`
- MVVM architecture (View → ViewModel → Service)

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Acknowledgments

- Inspired by [BetterDisplay](https://github.com/waydabber/BetterDisplay), [MonitorControl](https://github.com/MonitorControl/MonitorControl), and [Lunar](https://lunar.fyi/)
- CGVirtualDisplay bridging header based on [Chromium's virtual_display_mac_util.mm](https://chromium.googlesource.com/chromium/src/+/main/ui/display/mac/test/virtual_display_mac_util.mm)
