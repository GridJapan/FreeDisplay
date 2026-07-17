# Phase 7: Advanced Display Management ✅

> Core value: main display switching, notch management, integrated control, manage display settings

## Task List

- [x] Implement the "Set as main display" UI and logic (`FreeDisplay/Views/MainDisplayView.swift`)
  - Implementation hint:
    Add a "Set as main display" option to the menu (Ⓜ icon), following the blue circular M icon in the screenshot.
    The logic is already implemented in Phase 4's ArrangementService (moving to the coordinate origin).
    This task is the UI layer: show an Ⓜ marker next to the current main display in the display list.
    Clicking another display's "Set as main display" button switches to it.
  - Verification: after clicking, the Dock and menu bar move to the target display

- [x] Implement "Show notch" management (`FreeDisplay/Views/NotchView.swift`)
  - Implementation hint:
    MacBooks have a notch, which affects resolution and layout.
    Feature: annotate a "notch" label in the resolution list (following the "notch 60Hz 10bit" in the screenshot).
    Detecting the notch: `NSScreen.safeAreaInsets.top > 0`, or check the device model.
    Provide a "Hide notch" option: implemented by covering the notch area with a black bar
    (create a borderless, always-on-top black NSWindow covering the notch area).
  - Verification: the "notch" label is correctly shown next to the built-in screen's resolutions

- [x] Implement "Integrated control" (DDC extension) (`FreeDisplay/Views/IntegratedControlView.swift`)
  - Implementation hint:
    An expandable "Integrated control" section, following the screenshot layout:
    - "Read from device and update" button: read all DDC VCP codes and refresh the UI
    - "Configure integrated control items..." button: opens a configuration window
    DDCService extension: batch-read the commonly used VCP codes:
    0x10 (brightness), 0x12 (contrast), 0x14 (color temperature selection), 0x16 (video gain R),
    0x18 (video gain G), 0x1A (video gain B), 0x60 (input source), 0x62 (volume),
    0x87 (color saturation), 0xD6 (power mode), 0xDC (display mode)
    Store the results in DisplayInfo's `ddcValues: [UInt8: UInt16]` dictionary.
  - Verification: after clicking "Read from device", the external display's DDC parameters are shown correctly

- [x] Implement the "Manage display" settings (`FreeDisplay/Views/ManageDisplayView.swift`)
  - Implementation hint:
    An expandable "Manage display" section, following the screenshot:
    - "Configure display...": opens the Displays panel of System Settings
      `NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Displays-Settings")!)`
    - "Visual identification": pops up a full-screen identification window on the target display (showing the display name + ID),
      closing automatically after 3 seconds. Use NSWindow + NSScreen to position it on the target display.
    - Hint text: "Use ⌥ Option + click on the display menu title for quick identification."
    - "Prevent sleep while connected": use `IOPMAssertionCreateWithName` to create a power assertion
      preventing system sleep (`kIOPMAssertionTypePreventSystemSleep`).
  - Verification: after clicking "Visual identification", the identification window pops up on the target display

## Phase Acceptance

- Main display switching works correctly
- The notch label is displayed correctly
- Integrated control can read DDC parameters
- All sub-features of manage display work

**After completion**: consider running project-optimize for a retrospective
