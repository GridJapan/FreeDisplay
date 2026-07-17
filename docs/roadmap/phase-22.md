# Phase 22: Auto brightness rewrite — follow the built-in screen

> Status: Done | Estimate: high complexity

## Goal

Rewrite the auto brightness feature: drop the Intel-only AppleLMUController approach in favor of **watching the built-in screen's brightness and syncing it proportionally to external displays**. This is the approach BetterDisplay takes, and it is stable and reliable on Apple Silicon.

## Technical approach

macOS already adjusts the built-in screen's brightness automatically (based on ambient light). FreeDisplay only needs to:
1. Poll the built-in screen's current brightness every 2 seconds (`IODisplayGetFloatParameter` or a CoreDisplay private API)
2. If the brightness changes beyond the threshold (2%), sync it to external displays along the user's configured mapping curve
3. Set the brightness on external displays via DDC VCP 0x10 or the gamma table software fallback

**Key APIs**:
- Reading built-in screen brightness: `CoreDisplay_Display_GetUserBrightness(displayID)` — reliable on Apple Silicon
- Alternative: `IODisplayGetFloatParameter(service, kNilOptions, kIODisplayBrightnessKey, &brightness)`
- Setting external screen brightness: reuse the existing `BrightnessService.setBrightness()`

## Tasks

### Task 1: Rewrite AutoBrightnessService — follow mode
- [x] Remove the `AppleLMUController` sensor polling logic (delete `findSensorPort`, `readAmbientLux`, etc. entirely)
- [x] Add `readBuiltinBrightness() -> Double?`: read the built-in screen's current brightness (0.0-1.0)
  - Preferred: `@_silgen_name("CoreDisplay_Display_GetUserBrightness") func CoreDisplay_Display_GetUserBrightness(_ display: CGDirectDisplayID) -> Double`
  - Alternative: `IODisplayGetFloatParameter` iterating over IODisplayConnect
- [x] Add `@Published var builtinBrightness: Double = 0` to replace `lastLux`
- [x] Change the polling logic to: read built-in screen brightness → if the change is > 2% → compute the external screen's target brightness from the mapping curve → call BrightnessService
- [x] Mapping curve: `externalTarget = builtinBrightness * sensitivityMultiplier` (sensitivity ranges 0.5-1.5, default 1.0)
- [x] Keep the 30-second manual adjustment cooldown
- [x] Keep the UserDefaults keys `fd.AutoBrightnessEnabled` and `fd.AutoBrightnessSensitivity`

**Implementation notes**: `CoreDisplay_Display_GetUserBrightness` is a private API but exists stably on macOS 14+, and open source projects like MonitorControl/Lunar all use it. Declaring it with `@_silgen_name` is enough. If `CoreDisplay_Display_GetUserBrightness` returns 0 (on some OS versions), fall back to IODisplayGetFloatParameter.

### Task 2: Rewrite AutoBrightnessView — adapt to the new approach
- [x] Remove the `lastLux` display (there is no lux value any more)
- [x] Show "Built-in screen brightness: XX%" instead (`builtinBrightness` displayed live)
- [x] Change the sensor-unavailable message to "No built-in display detected" (shown only when there is no built-in screen)
- [x] Keep the sensitivity slider, but change its label to "Sync ratio"
- [x] Add explanatory text: "Automatically adjust external displays to follow the built-in screen's brightness"

**Implementation notes**: change the `sensorUnavailable` logic to check `builtinBrightness > 0 || hasBuiltinDisplay` instead of checking lux.

### Task 3: Verify reading the built-in screen brightness
- [x] Write a temporary test: on AppDelegate startup, print `CoreDisplay_Display_GetUserBrightness(builtinDisplayID)` to `~/Desktop/brightness_test.log`
- [x] Adjust the brightness slider by hand and confirm the reading changes live (in the 0.0-1.0 range)
- [x] If CoreDisplay returns 0 or something unexpected → switch to the IODisplayGetFloatParameter path
- [x] Delete the temporary test code once the test passes

**Implementation notes**: filter for the built-in display ID with `CGDisplayIsBuiltin(displayID)`. File logging is more reliable than print for debugging (a menu bar app has no stdout).

### Task 4: Build verification + integration testing
- [x] Builds successfully
- [x] Real-world test: enable auto brightness → adjust the MacBook's brightness → observe whether the external display follows
- [x] Edge case test: unplug the external display → no crash; no built-in screen → the message is shown
- [x] Update the AutoBrightnessService description in `docs/CODEMAP.md`

## Acceptance criteria

```bash
# Builds successfully
xcodebuild -scheme FreeDisplay -configuration Debug build 2>&1 | tail -3

# Manual testing
# 1. Enable auto brightness → adjust the MacBook's brightness → the external display's brightness follows
# 2. Adjust the "Sync ratio" slider → the external display responds
# 3. Manually adjust the external display's brightness → auto brightness does not override it for 30 seconds
# 4. Close the lid/unplug the display → no crash
```
