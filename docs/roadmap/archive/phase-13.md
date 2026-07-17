# Phase 13: Critical Bug Fixes

> Goal: fix three functional bugs reported by users

## Task List

- [x] Fix the residual image left behind after closing image adjustment
  - Implementation notes:
    1. `ImageAdjustmentView.swift`: add `.onDisappear` — check whether all sliders are at zero; if not, call `GammaService.shared.restoreColorSync()`
    2. In `GammaService.swift`'s `init()`, register an `NSApplication.willTerminateNotification` observer whose callback calls `CGDisplayRestoreColorSyncSettings()`
    3. Add another safeguard in `AppDelegate.swift`'s `applicationWillTerminate`: `CGDisplayRestoreColorSyncSettings()`
    4. Consider adding `saveState()` / `restoreState()` methods to GammaService, saving the current adjustment values to UserDefaults on onDisappear and restoring them on onAppear (so closing the panel does not lose settings, but everything is cleaned up when the app quits)
  - Verification: adjust gamma → collapse the image adjustment panel → the screen returns to normal; force quit the app → the screen returns to normal

- [x] Fix the 1920x1080 resolution not being clickable
  - Implementation notes:
    1. `DisplayModeListView.swift`'s `switchTo()` method: remove the silent `mode.id != display.currentDisplayMode?.id` guard; instead, if it is the current mode, show an "Already the current mode" notice (flash the highlight with `withAnimation`)
    2. Change the `ResolutionService.shared.setDisplayMode()` call to `Task { @MainActor in }`, setting `isSwitching = true` before the call and `isSwitching = false` after the await completes
    3. `ResolutionService.swift`'s `setDisplayMode` becomes an `async` method, internally wrapping `CGConfigureDisplayWithDisplayMode` + `CGCompleteDisplayConfiguration` with `withCheckedContinuation`
    4. Add failure feedback: if `setDisplayMode` returns false, show an error notice
  - Verification: click 1920x1080 → loading is shown → the switch succeeds or an error message is shown; click the mode that is already current → "Already the current mode" is shown

- [x] Fix HiDPI scaled modes not appearing / requiring a reconnect
  - Implementation notes:
    1. In `HiDPIService.swift`'s `enableHiDPI()`, after the plist write completes, call `CGDisplayForceToMirror(displayID, 0)` and then `CGDisplayForceToMirror(displayID, kCGNullDirectDisplay)` to make the display re-enumerate its modes (following BetterDisplay's approach)
    2. If the above is unavailable, fallback: use `IOServiceRequestProbe` to tell IOKit to rescan
    3. After refreshing, call `DisplayMode.availableModes(for:)` to re-fetch the mode list and update `display.availableModes`
    4. Add a "Refresh mode list" button in `DisplayModeListView` as a last resort
  - Verification: click to enable HiDPI → the mode list refreshes automatically and new HiDPI scaled resolutions appear (e.g. 1920x1080 HiDPI)

- [x] Improve the HiDPI categorization display for DisplayMode
  - Implementation notes:
    1. `DisplayModeListView.swift` grouping logic: add a "HiDPI scaled modes" group that specifically shows modes where `isHiDPI && !isNative`
    2. For 2K displays (such as the user's HKC 2560x1440), the HiDPI scaled modes should include: 1280x720 HiDPI (native 2x) and lower-resolution HiDPI modes
    3. Show "logical resolution @ actual pixel density" information on each mode row to help users understand what HiDPI means
  - Verification: the mode list clearly shows the groups "Default and native modes", "HiDPI scaled modes", and "Other modes"

**Phase Acceptance**: compiles successfully + all four verification scenarios above are satisfied
