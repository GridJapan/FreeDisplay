# Phase 2: Brightness Control (DDC + Built-in) ✅

> Core value: the most frequently used feature — brightness sliders controlling external and built-in displays

## Task List

- [x] Implement low-level DDC/CI I2C communication (`FreeDisplay/Services/DDCService.swift`)
  - Implementation hint:
    1. Find the I2C port via `IOServiceGetMatchingServices` + `IOFramebufferI2CInterface`
    2. Map `CGDirectDisplayID` → `IOServicePortFromCGDisplayID` to the I2C service
       (requires walking the IOKit registry matching the display vendorID/productID)
    3. Open the I2C connection: `IOI2CInterfaceOpen`
    4. Build the DDC/CI read/write requests:
       - Write: address 0x37, prefix 0x51 0x80+len, VCP opcode 0x03 (set) + VCP code + value
       - Read: first write the request (opcode 0x01 get + VCP code), then read the response and parse the current/max value
    5. Close the connection: `IOI2CInterfaceClose`
    6. Key function signatures:
       `func read(displayID: CGDirectDisplayID, command: UInt8) -> (current: UInt16, max: UInt16)?`
       `func write(displayID: CGDirectDisplayID, command: UInt8, value: UInt16) -> Bool`
    7. Add error handling and a retry mechanism (DDC communication is unreliable; retry 3 times with a 50ms interval)
    Note: DDC communication must run on a background thread to avoid blocking the UI.
    Refer to the DDC implementation approach of the MonitorControl open-source project.
  - Verification: `DDCService.shared.read(displayID: externalID, command: 0x10)` returns the current brightness value

- [x] Implement built-in display brightness control (`FreeDisplay/Services/BrightnessService.swift`)
  - Implementation hint:
    The built-in display does not go through DDC. Use `IODisplaySetFloatParameter` + `kIODisplayBrightnessKey`.
    Get: `IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey, &brightness)`
    Set: `IODisplaySetFloatParameter(service, 0, kIODisplayBrightnessKey, brightness)`
    Obtain the service via `IOServiceGetMatchingService` + `IODisplayConnect`.
    The value range is 0.0-1.0 and must be converted to a percentage for display.
  - Verification: the built-in screen's brightness actually changes after the code modifies the brightness value

- [x] Implement the brightness slider UI (`FreeDisplay/Views/BrightnessSliderView.swift`)
  - Implementation hint:
    A horizontal Slider, sun icon (☀) on the left, percentage value shown on the right.
    Follow the layout of the "Brightness (combined)" area in the BetterDisplay screenshot.
    `@Binding var brightness: Double` (0-100).
    Call DDCService/BrightnessService in the Slider's `onEditingChanged` callback.
    Add debouncing (200ms) to avoid frequent DDC communication.
    Support "combined brightness" mode: one slider controls the brightness of all displays at once (mapped proportionally).
  - Verification: dragging the slider actually changes the external display's brightness

- [x] Integrate brightness control into the menu (`FreeDisplay/Views/MenuBarView.swift`)
  - Implementation hint:
    Add a "Brightness (combined)" area below the display list, containing a combined brightness slider.
    Each display also gets its own brightness slider when expanded.
    Add a `brightness: Double` property to `DisplayInfo`, initialized via a DDC read at startup.
  - Verification: the menu shows the brightness slider, and dragging it changes display brightness

## Phase Acceptance

- DDC brightness read and set work correctly on external displays
- Brightness read and set work correctly on the built-in display
- The UI slider drags smoothly with no noticeable lag
- Combined brightness mode can control multiple screens at once

**After completion**: consider running project-optimize for a retrospective
