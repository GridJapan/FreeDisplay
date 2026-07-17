# Phase 3: Resolution Management and HiDPI ✅

> Core value: resolution switching and HiDPI support, BetterDisplay's core selling point

## Task List

- [x] Implement the resolution mode enumeration (`FreeDisplay/Models/DisplayMode.swift`)
  - Implementation hint:
    Model properties: `width: Int`, `height: Int`, `refreshRate: Double`, `bitDepth: Int`,
    `isHiDPI: Bool`, `isNative: Bool`, `ioDisplayModeID: Int32`.
    Use `CGDisplayCopyAllDisplayModes(displayID, options)` to get all modes.
    Add `kCGDisplayShowDuplicateLowResolutionModes: true` to the options dictionary to reveal HiDPI modes.
    Get the current mode with `CGDisplayCopyDisplayMode(displayID)`.
    Determining HiDPI: it is HiDPI when `CGDisplayModeGetPixelWidth > CGDisplayModeGetWidth`.
    Display format follows BetterDisplay: `1470x956` + labels (notch/60Hz/10bit).
  - Verification: can list all modes of the built-in screen, including 1470x956 (HiDPI), 2560x1664 (native), etc.

- [x] Implement resolution switching (`FreeDisplay/Services/ResolutionService.swift`)
  - Implementation hint:
    ```swift
    func setDisplayMode(_ mode: CGDisplayMode, for displayID: CGDirectDisplayID) -> Bool
    ```
    Switch in three steps: `CGBeginDisplayConfiguration` → `CGConfigureDisplayWithDisplayMode` →
    `CGCompleteDisplayConfiguration(.permanently)`.
    Save the current mode before switching and roll back on failure.
    Note: switching HiDPI modes may require the private API `CGSConfigureDisplayMode`,
    or injecting HiDPI modes by creating custom timings (covered in depth in the Phase 10 virtual display work).
  - Verification: the display's actual resolution changes after switching

- [x] Implement the resolution slider UI (`FreeDisplay/Views/ResolutionSliderView.swift`)
  - Implementation hint:
    Follow the resolution area of the BetterDisplay screenshot: a horizontal Slider + the current resolution text on the right.
    The Slider's step corresponds to the index in the list of available modes.
    A small display icon on the left, `1470x956` text on the right.
    Preview the resolution text live while dragging; switch on release.
  - Verification: dragging the slider changes the displayed resolution text

- [x] Implement the display mode list UI (`FreeDisplay/Views/DisplayModeListView.swift`)
  - Implementation hint:
    An expandable "Display modes" section (following the BetterDisplay screenshot layout).
    Split into two groups:
    1. "Default and native modes": the native resolution + the system default HiDPI modes
    2. "Modes matching the default filter": the other available modes
    One row per mode: icon (●/◉/⊙) + resolution text + labels on the right (notch/60Hz/10bit).
    The currently selected mode is highlighted (blue circular icon).
    Clicking switches to it.
    Add a "favorites" feature and a "Filter..." button (following the ☆ manage and ⊙ filter in the screenshot).
  - Verification: the display mode list layout matches the BetterDisplay screenshot

- [x] HiDPI mode injection (`FreeDisplay/Services/HiDPIService.swift`)
  - Implementation hint:
    External displays do not offer HiDPI modes by default. They must be enabled in one of these ways:
    1. Use `CGVirtualDisplay` to create a virtual display matching the external resolution (recommended, refined in Phase 10)
    2. Or modify the IOKit display override plist to inject custom resolutions
       Path: `/System/Library/Displays/Contents/Resources/Overrides/`
       Format: `DisplayVendorID-XXXX/DisplayProductID-XXXX`
    Phase 3 implements approach 2 (plist override) first; Phase 10 enhances it with the virtual display approach.
    Note: macOS SIP protects system directories, so the user must be guided to disable SIP or a user-level override must be used.
  - Verification: HiDPI scaling modes that were not previously available appear for the external display

## Phase Acceptance

- The resolution mode lists for the built-in and external displays are shown in full
- Clicking an item in the mode list successfully switches resolution
- The resolution slider works correctly
- The display mode list UI matches BetterDisplay's style

**After completion**: consider running project-optimize for a retrospective
