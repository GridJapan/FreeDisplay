# FreeDisplay — Claude Context Entry Point

> Version: 2026-03-05 | Status: Phase 22 complete

## What This Project Is

A free and open-source alternative to BetterDisplay. A macOS menu bar app for managing displays: DDC brightness/contrast control, resolution/HiDPI management, display arrangement, color management, virtual displays.
Tech stack: Swift 6 + SwiftUI (MenuBarExtra) + IOKit + CoreGraphics, zero third-party dependencies.

## Quick Navigation (load on demand)

| What you need to do | Which file to read |
|-----------|-----------|
| **Check for blocking issues before starting work** | `docs/BLOCKING.md` |
| Understand the code structure, find files | `docs/codemap/CLAUDE.md` (index) → `docs/codemap/file-tree.md` (file tree) → `docs/codemap/relationships.md` (relationship diagram) |
| Review the project plan and current progress | `docs/roadmap/CLAUDE.md` (overview) → `docs/roadmap/phase-N.md` (details) |
| Review working habits/preferences | `docs/habits.md` |
| Review pitfalls encountered and lessons learned | `docs/lessons/CLAUDE.md` (index) → `docs/lessons/{topic}.md` (details) |

## Current Focus

- **Current phase**: Phase 22 is complete. Feature trimming (removed rotation/streaming/PiP/mirroring/config protection, etc.) + auto-brightness rewrite + HiDPI plist override implementation.
- **Off-limits areas**: do not change the structure of `docs/roadmap/` (planner output); only update the `[x]` progress markers
- **Recent changes**: Phase 21 feature trimming (removed 15+ files), Phase 22 auto-brightness rewrite (CoreDisplay dlsym), HiDPI switched from the mirroring approach to plist override, arrangement center-alignment fix, HiDPI presets

## Autonomous Decision Rules

> **Blocking issues come first (the first thing you do when starting work):**
- Every time you start → read `docs/BLOCKING.md` first → if there are P0/P1 items, resolve them first → only work on the ROADMAP once everything is clear
- Run into a problem you can't crack → add it to `docs/BLOCKING.md`

> **Ripple-effect rules:**
- Changed a `DisplayInfo` property → grep every reference and update them in sync
- Changed `project.yml` → you MUST run `xcodegen generate` to regenerate the xcodeproj
- Added a Service/View file → update `docs/codemap/file-tree.md`

> **Fixes/development:**
- Build failure → fix it until it passes; do not skip it
- Swift 6 concurrency error → use `@MainActor` or `@unchecked Sendable` (the project already sets `SWIFT_STRICT_CONCURRENCY: minimal`)
- New files do not require changing project.yml (xcodegen automatically includes every source file under FreeDisplay/)

> **SwiftUI component rules:**
- Row components that need local state (isHovered, isLoading) → MUST be a standalone `struct`; ❌ they cannot be a `@ViewBuilder` function (@ViewBuilder functions do not support @State)
- Reusable row components follow one naming scheme: `XxxRow` (e.g. DetailRow, ExpandableRow, ProtectionRowView)

> **UserDefaults key naming convention:**
- Every UserDefaults key MUST carry the `fd.` prefix (e.g. `fd.launchAtLogin`, `fd.AutoBrightnessEnabled`)
- ❌ Bare keys (e.g. `"launchAtLogin"`) may collide with system or third-party keys

> **Coordination principle for writing shared resources across Services:**
- Two Services must not each independently write the same CoreGraphics resource (e.g. the gamma table) → designate one Service as the owner responsible for the final write
- BrightnessService (software brightness) writes the transfer function through GammaService; it does not write CGSetDisplayTransferByTable directly
- ❌ The View layer calling `CGSetDisplayTransferByFormula/Table` directly (bypassing GammaService) → ✅ operate indirectly through `GammaService.apply()` or `GammaService.resetSingleDisplay()`
- ❌ `CGDisplayRestoreColorSyncSettings()` (global) → ✅ `GammaService.resetSingleDisplay(displayID)` resets only a single display

> **Sleep/wake handling (MUST):**
- Services that write display hardware state (gamma, software brightness) MUST respond to `NSWorkspace.didWakeNotification` and reapply
- Already registered: AppDelegate listens for wake → GammaService.reapplyIfNeeded + BrightnessService.reapplySoftwareBrightnessIfNeeded

> **C callback Unmanaged rules:**
- Long-lived C callbacks (CGDisplayRegisterReconfigurationCallback, etc.) → MUST use `Unmanaged.passRetained(self)`, and `release()` when unregistering
- ❌ `passUnretained` (dangling pointer risk)

> **IOKit display matching:**
- Do not use CGDisplayVendorNumber/ModelNumber to match IOKit services (unreliable for some displays)
- Use `NSScreen.localizedName` for display names
- Look up IOKit services by enumerating IODisplayConnect with IOServiceGetMatchingServices (❌ CGDisplayIOServicePort is deprecated)
- DDC external brightness control is not guaranteed to be available → the UI needs to degrade gracefully (notify the user when detection fails)

> **Async principles:**
- Only make genuinely slow operations async (filesystem scans, network requests)
- Microsecond-scale IOKit calls (name lookups, property reads) stay synchronous; they are not worth making async

> **CGVirtualDisplay private API (MUST follow):**
- `vendorID` MUST be non-zero (e.g. `0xEEEE`); when it is 0, `CGVirtualDisplay(descriptor:)` returns nil
- `CGVirtualDisplay(descriptor:)` MUST be called on the main thread (returns nil on a background thread); `apply(settings)` may run in the background
- Bridging-header property names follow Chromium's `virtual_display_mac_util.mm` (`maxPixelsWide`/`maxPixelsHigh`, not `maxPixelSize`)

> **HiDPI implementation approach (MUST follow):**
- ❌ `CGConfigureDisplayMirrorOfDisplay` for HiDPI — on Apple Silicon it triggers hardware mirroring mode + mouse stutter
- ✅ Plist override written to `/Library/Displays/Contents/Resources/Overrides/` — the same approach BetterDisplay uses
- Writing the plist requires administrator privileges → use `NSAppleScript("do shell script ... with administrator privileges")`
- ❌ Setting `DisplayProductName` in the plist — it overrides the system display name
- After enabling it, the display must be reconnected for it to take effect (IOServiceRequestProbe is not always reliable)

> **Private framework dynamic loading:**
- ❌ `@_silgen_name` to reference private framework symbols (undefined symbol at link time)
- ✅ `dlopen` + `dlsym` runtime loading (e.g. CoreDisplay_Display_GetUserBrightness)

> **Stop and ask the user:**
- When a private API (CoreDisplay, etc.) needs to be used
- When SIP must be disabled or special system permissions are required
- When the architectural direction changes (MVVM → something else)

> **Self-maintenance rules:**
- Added/removed/changed files → update `docs/codemap/file-tree.md`
- Phase task complete → mark `[x]` in `docs/roadmap/phase-N.md` **and mark `[x]` in `docs/ROADMAP.md` in sync** (autopilot tracks progress via the latter)
- Hit a pitfall → write it up in `docs/lessons/{topic}.md` (also update the `docs/lessons/CLAUDE.md` index)
- Discovered a preference/pattern → write it to `docs/habits.md`
- Got stuck → add it to `docs/BLOCKING.md`
- Resolved a BLOCKING item → move it to the resolved section

## Verification Chain (run after every change)

```bash
# 1. Build check
cd ~/Desktop/FreeDisplay && xcodebuild -scheme FreeDisplay -configuration Debug build 2>&1 | tail -5

# 2. Ripple-effect check (when interfaces/models have changed)
grep -r "DisplayInfo\|DisplayManager\|DDCService" FreeDisplay/ --include="*.swift" | grep -v "^Binary"
```

## Common Operations Playbook

### Adding a Feature Section (the most common operation in Phases 2-12)
1. Create a new Service under `Services/` (e.g. `BrightnessService.swift`)
2. Create the corresponding View under `Views/` (e.g. `BrightnessSliderView.swift`)
3. If state management is needed, create a ViewModel under `ViewModels/`
4. Embed the new View in `MenuBarView.swift`
5. Update `DisplayInfo.swift` to add the properties you need
6. Run the verification chain

### Implementing a DDC Feature
1. Implement IOKit I2C communication in `DDCService.swift`
2. Look up the new feature's VCP code in the DDC/CI standard (e.g. 0x10 = brightness)
3. Call `DDCService.shared.read/write` from the Service
4. Run the verification chain + test manually on a real external display

### Fixing a Bug
1. Determine whether it is a build error or a runtime error
2. Build error → locate it from the xcodebuild output
3. Runtime error → check the logs in Console.app or use the Xcode debugger
4. Fix it → run the verification chain

## Design Resources

- **App icon design**: use [Nano Banana](https://nano-banana.ai/) (an AI image generator powered by Google Gemini) to generate high-quality icons
  - Supports generating icons, logos, and UI elements from text descriptions
  - After generating, use Python PIL to crop/scale them into the multiple PNG sizes macOS requires (16/32/64/128/256/512/1024)
  - Icon files live in `FreeDisplay/Assets.xcassets/AppIcon.appiconset/`

## Key Conventions

- **Language**: Swift 6.0 (concurrency checking: minimal)
- **Minimum OS**: macOS 14.0
- **Architecture**: MVVM (View → ViewModel → Service)
- **Build**: `xcodegen generate && xcodebuild -scheme FreeDisplay -configuration Debug build`
- **No Sandbox**: the entitlements have App Sandbox turned off (DDC/IOKit require it)
- **No third-party dependencies**: system frameworks only

## Core Frameworks

| Framework | Purpose | Phase |
|------|------|-------|
| CoreGraphics | Display enumeration, resolution, arrangement | 1-4 |
| IOKit | DDC/CI I2C communication, brightness/contrast | 2 |
| ColorSync | ICC Profile management | 5 |
| CoreGraphics (CGVirtualDisplay) | Virtual displays | 10 |
| CoreDisplay (dlsym) | Reading built-in screen brightness | 22 |
