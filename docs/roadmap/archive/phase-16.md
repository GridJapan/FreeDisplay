# Phase 16: Comprehensive Bug Fixes

> Goal: fix the 37 issues found by the audit, executed in three batches by priority

## Batch A: P0 — Crashes / Data Loss (5 issues)

- [x] A1: Fix the race condition when AutoBrightnessService iterates displays
  - **File**: `AutoBrightnessService.swift`, applyBrightness method
  - **Problem**: accessing `DisplayManagerAccessor.shared.displays` and mutating `display.brightness` without synchronization; may crash on hot-plug
  - **Fix**: take an array snapshot before iterating with `let snapshot = displays`, or add `@MainActor` to ensure main-thread access
  - **Verification**: hot-plugging a display with auto brightness enabled does not crash

- [x] A2: Fix the memory leak in BrightnessService refreshBrightness
  - **File**: `BrightnessService.swift`, refreshBrightness method
  - **Problem**: DDCService.shared.readAsync()'s completion handler implicitly captures self; the callback dangles after the display is released
  - **Fix**: capture with `[weak self]` in the completion and `guard let self else { return }` inside the callback
  - **Verification**: no memory leak in Instruments after refreshing brightness repeatedly

- [x] A3: Fix the boundary condition in BrightnessSliderView onChange
  - **File**: `BrightnessSliderView.swift`, onChange(of: display.brightness)
  - **Problem**: `abs(newValue - localBrightness) > 1` uses `>`, so an exactly 1% change does not sync
  - **Fix**: change to `abs(newValue - localBrightness) >= 1`
  - **Verification**: an external 1% brightness change → the UI updates in sync

- [x] A4: Fix the sparse-cache problem in DDCService readBatchVCPCodes
  - **File**: `DDCService.swift`, readBatchVCPCodes method
  - **Problem**: when building the dictionary from the cache, compactMap skips missing codes, so the result has fewer entries than requested with no indication
  - **Fix**: perform an actual read for codes that miss the cache; explicitly mark which reads failed in the final result (return `[UInt8: UInt16?]`)
  - **Verification**: batch-read 11 VCP codes → all return (either successfully or as an explicit failure)

- [x] A5: Fix the missing error handling for resolution switching in DisplayModeListView
  - **File**: `DisplayModeListView.swift`, switchTo method
  - **Problem**: no retry and no user notice after `ResolutionService.shared.setDisplayMode()` fails
  - **Fix**: show an error toast on failure (using `@State var errorMessage`) and add one automatic retry
  - **Verification**: simulate a failed switch → the user sees an error notice

## Batch B: P1 — Functional Defects (11 issues)

- [x] B1: Fix the hardcoded initial brightness value in DisplayInfo
  - **File**: `DisplayInfo.swift`, init
  - **Problem**: built-in display brightness is initialized to 50.0 instead of reading the actual value
  - **Fix**: call `BrightnessService.shared.refreshBrightness(for: self)` immediately after init completes to read the real value
  - **Verification**: open the app → the brightness slider shows the real system brightness

- [x] B2: Fix GammaService's single-display state key
  - **File**: `GammaService.swift`, saveState/loadSavedState
  - **Problem**: the UserDefaults key is fixed at `"GammaService.savedAdjustment"`, so with multiple displays only the last one is saved
  - **Fix**: change the key to `"GammaService.savedAdjustment.\(displayID)"`
  - **Verification**: adjust gamma separately on two displays → restart the app → each restores the correct value

- [x] B3: Fix MirrorView's async defer executing early
  - **File**: `MirrorView.swift`, toggleMirror method
  - **Problem**: `defer { isSwitching = false }` runs before the await in an async function, so the loading state disappears instantly
  - **Fix**: remove the defer and set `isSwitching = false` separately after the await completes and in the catch block
  - **Verification**: click the mirror button → the loading animation persists until the operation completes

- [x] B4: Fix the race condition in ColorProfileView loadProfiles
  - **File**: `ColorProfileView.swift`, loadProfiles
  - **Problem**: the async task still updates @State after the View disappears, triggering a SwiftUI warning
  - **Fix**: use `.task { }` instead of a manual Task (SwiftUI cancels it automatically), or add `@State var loadTask: Task<Void, Never>?` and cancel it in onDisappear
  - **Verification**: expand/collapse the color panel rapidly → no console warnings

- [x] B5: Fix the non-MainActor state update in IntegratedControlView
  - **File**: `IntegratedControlView.swift`, readFromDevice
  - **Problem**: a non-@MainActor method updates @State variables directly
  - **Fix**: mark the method `@MainActor`, or use `await MainActor.run { isReading = false }`
  - **Verification**: compiles with no concurrency warnings

- [x] B6: Fix the concurrency issue in ColorProfileView applyProfile
  - **File**: `ColorProfileView.swift`, applyProfile
  - **Problem**: the function is not marked @MainActor but updates UI state internally
  - **Fix**: mark it `@MainActor`
  - **Verification**: apply an ICC profile → no concurrency warnings

- [x] B7: Verify HiDPIService's plist path construction (confirmed correct, no change needed)
  - **File**: `HiDPIService.swift`, overridePlistURL
  - **Problem**: the audit noted the vendor/product path may be incorrect
  - **Fix**: check whether the actually generated plist path matches the path macOS expects (`/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-XXXX/DisplayProductID-YYYY`) and correct any mismatch
  - **Verification**: write the plist → `ls` to confirm the path is correct → re-enumerate the mode list and HiDPI appears

- [x] B8: Fix the missing cancellation for DisplayDetailView's task
  - **File**: `DisplayDetailView.swift`, .task(id:)
  - **Problem**: after a display is disconnected and reconnected, the old task may update stale data
  - **Fix**: use `Task.checkCancellation()` after the await to check the cancellation state
  - **Verification**: hot-plug a display → the details panel data is correct

- [x] B9: Fix RotationService's inaccurate return value
  - **File**: `RotationService.swift`, setRotation
  - **Problem**: it returns the result of `IOServiceRequestProbe`, but that only indicates the probe request succeeded, not that the rotation took effect
  - **Fix**: sleep 100ms after the probe, then verify the actual angle with `CGDisplayRotation(displayID)`
  - **Verification**: rotate a display → the return value accurately reflects whether it took effect

- [x] B10: Clean up the dead code in DisplayInfo.lookupDisplayName
  - **File**: `DisplayInfo.swift`, lookupDisplayName
  - **Problem**: the method is never called (it was replaced by NSScreen.localizedName)
  - **Fix**: delete the entire method
  - **Verification**: compiles successfully

- [x] B11: Fix the .permanently vs .forSession inconsistency in ResolutionService
  - **File**: `ResolutionService.swift` vs `ArrangementService.swift`
  - **Problem**: resolution uses .permanently while arrangement uses .forSession — inconsistent behavior
  - **Fix**: standardize on `.forSession` (safer, since macOS restores the system settings after a restart), or use `.permanently` for both and document it
  - **Verification**: switch resolution/arrangement → behavior after restart matches expectations

## Batch C: P2 — Minor Issues / Code Quality (21 issues)

- [x] C1: AutoBrightnessService readAmbientLux may block the main thread
  - **Fix**: ensure it is called from a background thread, or dispatch to a background queue inside the method

- [x] C2: AutoBrightnessService lux scaling constants are undocumented
  - **Fix**: add a comment explaining the derivation of `rawAvg / 1_000_000.0 * 1_000.0`

- [x] C3: BrightnessSliderView DispatchAfter has no cancellation
  - **Fix**: use `DispatchWorkItem` instead, or SwiftUI `.task` + `Task.sleep`

- [x] C4: ColorProfileService assumes the ICC header is ASCII
  - **Fix**: add encoding validation with a fallback for non-ASCII

- [x] C5: DDCService buffer count capture is fragile
  - **Fix**: inline the count or extract a helper method

- [x] C6: DisplayModeListView has redundant filter logic
  - **Fix**: simplify `.filter { $0.isNative || (!$0.isHiDPI && $0.isNative) || ($0.isNative) }` to `.filter { $0.isNative }`

- [x] C7: ImageAdjustmentView quantization boundary condition
  - **Fix**: change `quantLevels >= 256` to `quantLevels >= 255` or `== 256`

- [x] C8: ImageAdjustmentView resetAll lacks a MainActor guarantee
  - **Fix**: confirm GammaService.restoreColorSync() is called on the MainActor

- [x] C9: MenuBarView update check may block the UI
  - **Fix**: add a timeout and move it to the background

- [x] C10: HiDPIService refreshModes is not awaited
  - **Fix**: store the Task reference and cancel it at the appropriate time

- [x] C11: DDCService lock release and callback ordering are inconsistent
  - **Fix**: standardize on the "unlock first, then callback" pattern

- [x] C12: VirtualDisplayService addAndCreate does not roll back on creation failure
  - **Fix**: remove it from configs when `create()` fails

- [x] C13: ArrangementService .forSession may not be what the user expects
  - **Fix**: handle together with B11

- [x] C14: UpdateService JSON parsing fails silently
  - **Fix**: add a `print("[UpdateService] JSON parse error:")` log

- [x] C15: BrightnessService overuses withCheckedContinuation
  - **Fix**: dispatch async and return directly, or simplify to a synchronous call

- [x] C16: DisplayDetailView @EnvironmentObject MainActor is not explicitly annotated
  - **Fix**: add an explanatory comment

- [x] C17: BrightnessSliderView @ObservedObject concurrency safety
  - **Fix**: ensure all DisplayInfo updates happen on the main thread

- [x] C18: DDCService theoretical memory pointer safety issue
  - **Fix**: confirm withUnsafeMutableBytes is used correctly (already correct, marked as reviewed)

- [x] C19: BrightnessService IOObjectRelease iterator cleanup
  - **Fix**: confirm the iterator is released after being fully exhausted (already correct, marked as reviewed)

- [x] C20: DisplayDetailView ResolutionSliderView reference
  - **Fix**: confirm the component exists; otherwise delete the reference

- [x] C21: Global code cleanup — remove unused imports and commented-out code
  - **Fix**: global scan and cleanup

## Acceptance Criteria

```bash
# 1. Compiles with no warnings
xcodebuild -scheme FreeDisplay -configuration Debug build 2>&1 | grep -E "warning:|error:" | head -20

# 2. Manual test checklist
# - Open the app → brightness shows the real value (not 50%)
# - Hot-plug a display → no crash
# - Adjust gamma → close the panel → the screen recovers
# - Mirror operation → the loading animation shows throughout
# - Color profile switch → no console warnings
# - HiDPI switch → the plist is written to the correct path
```
