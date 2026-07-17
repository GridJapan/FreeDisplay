# Phase 18: Stability hardening

> Status: Done | Estimate: medium complexity

## Goal

Roll out the timeout protection pattern for blocking CG calls across the whole project, make sure HiDPI state is restored automatically after sleep/wake, and re-apply the arrangement automatically after a display configuration change.

## Tasks

### Task 1: Unified timeout protection for blocking CG calls
- [x] Extract VirtualDisplayService's `runWithTimeout` into a shared utility function (put it in `Utilities/` or `Services/CGHelpers.swift`)
- [x] MirrorService: wrap the `CGCompleteDisplayConfiguration` calls in `enableMirror`/`disableMirror` with `runWithTimeout`
- [x] ArrangementService: wrap the `CGCompleteDisplayConfiguration` call in `setPosition` with `runWithTimeout`
- [x] ResolutionService: add a 10-second timeout to `applyModeSync` (currently waits on `CGCompleteDisplayConfiguration` indefinitely)

**Implementation notes**: `runWithTimeout` is already proven in VirtualDisplayService; reuse the same pattern directly. Watch out for the `@Sendable` constraint.

### Task 2: Auto re-arrange on display configuration change
- [x] Register `CGDisplayRegisterReconfigurationCallback` in AppDelegate or DisplayManager
- [x] Detect completion of the configuration change in the callback (after `flags` contains `beginConfigurationFlag`, wait for a callback without it)
- [x] Call `displayManager.arrangeExternalAboveBuiltin()` 500ms after the configuration change completes
- [x] Avoid repeated triggering: use a debounce mechanism so that multiple callbacks within 500ms only run the last one

**Implementation notes**: pass `Unmanaged.passRetained(self)` for the context parameter of `CGDisplayRegisterReconfigurationCallback` to prevent a dangling pointer (already a rule in CLAUDE.md). The callback runs on a system thread, so `DispatchQueue.main.async` back to the main thread.

### Task 3: Auto-restore HiDPI after sleep/wake
- [x] In AppDelegate's `didWakeNotification` handler, check whether `VirtualDisplayService.hiDPIActiveDisplayIDs` has any active sessions
- [x] If so, check whether the virtual display is still online (`CGDisplayIsOnline`); if it is gone, re-create it + mirror + apply the resolution
- [x] Restore sequence: create → apply settings → sleep 500ms → mirror → sleep 500ms → setDisplayMode → arrangeExternalAboveBuiltin
- [x] Persist HiDPI state to UserDefaults (`fd.hiDPI.activePhysicalIDs`) so it can also be restored after an app restart

**Implementation notes**: WindowServer needs time to settle after wake; add a 2-second initial delay to the whole restore sequence. Refer to the existing `enableHiDPIVirtual` flow in VirtualDisplayService.

### Task 4: Error recovery and user feedback
- [x] Show a menu bar status message when a CG call times out (not a dialog; use the `statusMessage` pattern)
- [x] Prompt the user to re-enable manually when HiDPI restore fails
- [x] Automatically disable HiDPI and notify the user after 3 consecutive failures

**Implementation notes**: reuse the existing `statusMessage` pattern from HiDPIVirtualRowView.

## Acceptance criteria

```bash
# Builds successfully
xcodebuild -scheme FreeDisplay -configuration Debug build 2>&1 | tail -3

# Manual testing
# 1. Enable HiDPI → close the lid to sleep → wake → HiDPI restores automatically + arrangement is correct
# 2. Enable HiDPI → unplug the external display → plug it back in → no crash
# 3. Switch resolution → arrangement stays directly above
```
