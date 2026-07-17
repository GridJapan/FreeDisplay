# Phase 14: Performance Optimization (Eliminating Stutter)

> Goal: move all blocking IOKit/CG calls off the main thread and reduce unnecessary SwiftUI redraws

## Task List

- [x] Move BrightnessService's IOKit calls to a background thread
  - Implementation notes:
    1. `BrightnessService.swift`: make `getInternalBrightness()` and `setInternalBrightness()` execute on a dedicated `DispatchQueue(label: "brightness")`
    2. Make the public methods `setBrightness()` and `refreshBrightness()` `async`, wrapping them internally with `withCheckedContinuation`
    3. Call sites (`BrightnessSliderView`) call them via `Task { await ... }`; the slider's `onEditingChanged` triggers the async set
    4. Add debounce: do not send while the slider is being dragged; only send the final value on release (onEditingChanged false)
  - Verification: drag the brightness slider → the UI does not stutter, and brightness changes smoothly after release

- [x] Move DisplayInfo.init's IOKit queries to the background
  - Implementation notes:
    1. `DisplayInfo.swift`: the initializer only sets displayID and basic CG properties (name temporarily uses "Display \(id)")
    2. Add a `func loadDetails() async` method that runs `lookupDisplayName()` and `DisplayMode.availableModes()` in the background
    3. `DisplayManager.refreshDisplays()` first creates the DisplayInfo objects (fast, non-blocking), then loads details asynchronously via `Task { await display.loadDetails() }`
    4. Once loaded, update the `@Published` properties on `@MainActor` to trigger a UI refresh
  - Verification: plug/unplug a display → the new display appears in the list immediately (name briefly shown as an ID), and the name and mode list update after details load asynchronously

- [x] Make ColorProfileService.enumerateProfiles asynchronous
  - Implementation notes:
    1. `ColorProfileService.swift`: make `enumerateProfiles()` an `async` method that scans the filesystem in the background via `Task.detached`
    2. `ColorProfileView.swift`: `loadProfiles()` uses `Task { profiles = await svc.enumerateProfiles() }`
    3. Show a ProgressView animation while loading; when profiles is empty, show the loading animation rather than "No profiles"
  - Verification: open the color management panel → see the loading animation → the profile list fills in asynchronously

- [x] Split DisplayInfo's @Published properties to reduce cascading redraws
  - Implementation notes:
    1. Split `DisplayInfo`: put the basic information (name, displayID, isBuiltin, and other immutable properties) in a struct
    2. Keep the dynamic properties (brightness, currentDisplayMode, etc.) @Published, but group them into a dedicated ObservableObject sub-object
    3. Or, more simply: in `DisplayDetailView`, use `EquatableView` or `.id()` on each Section to limit the redraw scope
    4. Simplest approach (recommended): extract each Section (brightness, resolution, color, etc.) into its own View struct, each `@ObservedObject` observing only the properties it needs. Using SwiftUI's view identity mechanism, collapsed sections do not observe
  - Verification: while dragging the brightness slider, confirm with Instruments' SwiftUI profiler that other Sections do not redraw; or add `let _ = print("xxx re-render")` in the other Sections' bodies to confirm they are not triggered

- [x] Remove synchronous CG calls from View bodies
  - Implementation notes:
    1. `DisplayDetailView.swift` line 99 `Text(ColorProfileService.shared.currentColorSpaceName(...))` → fetch asynchronously in `onAppear` and store in `@State var colorSpaceName: String`
    2. Line 125 `Text(ColorProfileService.shared.colorModeDescription(...))` → same as above
    3. Any similar synchronous service calls in other Section headers should all be converted to the `@State` + `onAppear`/`task {}` pattern
  - Verification: compiles successfully + opening DisplayDetailView has no stutter

- [x] Optimize DDCService batch read performance
  - Implementation notes:
    1. In `DDCService.swift`'s `readBatchVCPCodes()`, `Thread.sleep(forTimeInterval: 0.05)` → change to `try await Task.sleep(nanoseconds: 30_000_000)` (30ms, down from 50ms)
    2. Convert the method to an `async` version, using a `TaskGroup` to read non-adjacent VCP codes in parallel (the same device on an I2C bus cannot truly parallelize, but a smaller interval can be used)
    3. Or a caching strategy: do a full read the first time, then only read the VCP code the user is currently operating on and use cached values for the rest
  - Verification: open the integrated control panel → time to read 11 VCP codes drops from ~550ms to ~330ms

**Phase Acceptance**: compiles successfully + no noticeable stutter when opening/operating any panel (subjectively smooth)
