# Pitfalls — Cross-Service Coordination / Concurrency / Resource Management

> Updated: 2026-03-05

## Feature Interaction / Cross-Service Coordination (Round 3-4 optimization)

### L-008: two Services writing the same CoreGraphics resource overwrite each other
- **Symptom**: after setting a gamma adjustment, dragging the brightness slider makes the gamma effect disappear (or vice versa)
- **Cause**: GammaService and BrightnessService both call CGSetDisplayTransfer*, and whichever is called later completely overwrites the earlier one
- **Fix**: designate GammaService as the sole writer; BrightnessService stores the brightness factor in softwareBrightnessFactors, and GammaService reads it in applyFormula and multiplies it into rHi/gHi/bHi
- **Lesson**: when two Services share an underlying resource, a single owner must be designated; the others influence it through an interface instead of writing directly
- **Date**: 2026-03-04

### L-009: macOS sleep/wake resets all CGSetDisplayTransfer* effects
- **Symptom**: gamma adjustments and software brightness are all lost after the Mac sleeps
- **Cause**: macOS resets the display transfer function to the system default on sleep; CGSetDisplayTransfer* effects are not persistent
- **Fix**: register for NSWorkspace.didWakeNotification and re-apply to all displays 500ms after waking
- **Lesson**: any feature that writes display hardware state must account for the reset after sleep/wake, and testing must cover this scenario
- **Date**: 2026-03-04

### L-010: CGDisplayRegisterReconfigurationCallback must use passRetained
- **Symptom**: theoretical crash risk: the C callback accesses a dangling pointer
- **Cause**: passUnretained does not increment the reference count, so once self is released the callback accesses a dangling pointer
- **Fix**: passRetained + a paired release (in stopMonitoring/deinit)
- **Lesson**: always use passRetained for a self pointer handed to a C callback; this has already come up twice in the project (DisplayManager + ConfigProtectionService)
- **Date**: 2026-03-04

### L-011: AutoBrightness and manual adjustment need a cooldown mechanism
- **Symptom**: brightness adjusted by hand is overwritten by AutoBrightness 2 seconds later
- **Cause**: applyBrightness only checks the delta; there is no protection for "the user adjusted it manually just now"
- **Fix**: add an isAutoAdjust parameter to setBrightness, record lastManualAdjustDate on manual calls, and have AutoBrightness check a 30s cooldown
- **Lesson**: an automatic adjustment feature must have a pause mechanism after manual intervention
- **Date**: 2026-03-04

## Concurrency / Resource Management (Round 5 optimization)

### L-012: the GammaService activeAdjustments dictionary must be locked
- **Symptom**: data race risk — BrightnessService reads hasActiveAdjustment from a background queue while GammaService writes activeAdjustments from the MainActor
- **Cause**: the dictionary has no synchronization; concurrent multi-threaded read/write is undefined behavior in Swift (it may crash or corrupt data)
- **Fix**: add an NSLock and lock around all activeAdjustments reads and writes (hasActiveAdjustment/apply/reapply/reset, etc.)
- **Lesson**: any mutable state accessed by multiple Actors must be locked, whether or not a race has actually been triggered yet
- **Date**: 2026-03-04

### L-013: the GammaService quantization path must sync the brightness factor
- **Symptom**: software brightness silently stops working in quantized mode (quantizationLevels < 256)
- **Cause**: applyFormula reads the softwareBrightness factor but applyQuantizedTable does not, so the two paths are inconsistent
- **Fix**: have applyQuantizedTable read brightnessFactor as well and scale rHi/gHi/bHi
- **Lesson**: when a single Service has multiple execution paths, every path must apply the same modification logic
- **Date**: 2026-03-04

### L-014: on sleep/wake, BrightnessService must reapply before GammaService
- **Symptom**: the screen briefly flashes white (full brightness) on wake before recovering
- **Cause**: when GammaService.reapply is called first, softwareBrightnessFactors has not been restored yet, so applyFormula reads 1.0 and writes it to the hardware
- **Fix**: on wake, call BrightnessService.reapply first, then GammaService.reapply (making sure the factor is ready)
- **Lesson**: reapply calls with a dependency relationship must be made in dependency order; BrightnessService is the data provider for GammaService
- **Date**: 2026-03-04

### L-015: closing an NSWindow must stop the associated SCStream
- **Symptom**: when the user clicks the red close button of the PiP/Stream window, the stream keeps running in the background and consuming resources
- **Cause**: NSWindowController does not implement NSWindowDelegate.windowWillClose, so the close event does not trigger stopCapture
- **Fix**: have PiPWindowController/StreamWindowController implement windowWillClose → viewModel.stopCapture(), and set window.delegate = self
- **Lesson**: both the system-provided close entry point (the red button) and the in-app close button must clean up resources; handling only one of them is not enough
- **Date**: 2026-03-04

### L-016: never call removeValue while iterating a Dictionary
- **Symptom**: NotchOverlayManager.screenParametersChanged() calls removeValue while iterating overlayWindows — a potential crash
- **Cause**: a Swift Dictionary does not support modifying itself during for-in iteration; the behavior is undefined
- **Fix**: collect the keys to delete into a temporary array and delete them all outside the loop
- **Lesson**: while iterating any collection with for-in, you must not add to or remove from that collection (the equivalent of ConcurrentModificationException in other languages)
- **Date**: 2026-03-04

### L-017: UserDefaults keys must have an app namespace prefix
- **Symptom**: SettingsService/AutoBrightnessService/ConfigProtectionService use bare keys (e.g. "launchAtLogin")
- **Cause**: a bare key may collide with macOS system defaults or with a future third-party library, causing unexpected values to be read or system settings to be overwritten
- **Fix**: consistently add an `fd.` prefix (fd.launchAtLogin, fd.AutoBrightnessEnabled, etc.)
- **Lesson**: UserDefaults key naming convention: `<app_prefix>.<key>`
- **Date**: 2026-03-04

### L-018: the query direction of the mirror source/target API
- **Symptom**: refreshMirrorState queries with CGDisplayMirrorsDisplay(source) and always gets nil back (the source does not clone anyone)
- **Cause**: CGDisplayMirrorsDisplay(X) returns "the target that X clones", and the SOURCE itself is not the cloner
- **Fix**: query in reverse — iterate over all displays and find the one where CGDisplayMirrorsDisplay(candidate) == source (i.e. the target)
- **Lesson**: mirror API semantics: the SOURCE is what gets cloned, the TARGET is the cloner; queries should be made from the TARGET's perspective ("who is cloning me")
- **Date**: 2026-03-04

### L-019: IOPMAssertion must release before creating a new assertion
- **Symptom**: ManageDisplayView leaks an IOPMAssertion every time the prevent-sleep switch is turned on; the old ID is overwritten and can no longer be released
- **Cause**: createSleepAssertion() does not check sleepAssertionID != 0 and overwrites it directly
- **Fix**: release the old assertion before creating one; onDisappear only releases when !preventSleep (so it stays in effect while the switch is ON)
- **Lesson**: system resources (IOPMAssertion, IO iterators, etc.) must be strictly paired create/release; release the old one before overwriting an ID
- **Date**: 2026-03-04
