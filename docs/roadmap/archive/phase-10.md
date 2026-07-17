# Phase 10: Virtual Displays ✅

> Core value: create dummy displays / virtual screens, extend HiDPI support

## Task List

- [x] Implement virtual display creation (`FreeDisplay/Services/VirtualDisplayService.swift`)
  - Implementation notes:
    Use the `CGVirtualDisplay` API from macOS 14+:
    ```swift
    import CoreGraphics

    let descriptor = CGVirtualDisplayDescriptor()
    descriptor.queue = DispatchQueue.global()
    descriptor.name = "FreeDisplay Virtual"
    descriptor.maxPixelsWide = 3840
    descriptor.maxPixelsHigh = 2160
    descriptor.sizeInMillimeters = CGSize(width: 600, height: 340) // 27 inch
    descriptor.productID = 0x1234
    descriptor.vendorID = 0x5678
    descriptor.serialNum = 0

    let display = CGVirtualDisplay(descriptor: descriptor)

    // Add display modes
    let settings = CGVirtualDisplaySettings()
    settings.hiDPI = 1  // Enable HiDPI
    let mode = CGVirtualDisplayMode(width: 1920, height: 1080, refreshRate: 60)
    settings.modes = [mode, ...]
    display?.applySettings(settings)
    ```
    Features:
    - Create a virtual display (specify name, resolution, DPI)
    - Destroy a virtual display
    - List currently active virtual displays
    - Persist configuration (UserDefaults/JSON), auto-create on launch
    Note: once created, the system treats a virtual display as a real display; it can be used for HiDPI and Sidecar scenarios.
  - Verification: after creating a virtual display, a new display appears in System Settings

- [x] Implement HiDPI enhancement (virtual-display based) (`HiDPIService` extension)
  - Implementation notes:
    Phase 3 implemented HiDPI via plist override; here it is enhanced with the virtual display approach:
    1. Create a virtual display matching the external display's resolution (with HiDPI enabled)
    2. Mirror the external display to the virtual display
    3. The external display inherits the virtual display's HiDPI mode
    This is how BetterDisplay implements HiDPI — no system file modification, no SIP changes required.
    Add a "High Resolution (HiDPI)" switch in ResolutionService that automatically creates a paired virtual display when turned on.
  - Verification: after enabling HiDPI on an external display, scaled modes appear in the resolution list

- [x] Implement virtual display management UI (`FreeDisplay/Views/VirtualDisplayView.swift`)
  - Implementation notes:
    Add a "Displays and Virtual Screens" entry in the "Tools" area (following the screenshot).
    Clicking opens the management panel/window:
    - List of current virtual displays (name, resolution, status)
    - "+" button to add a new virtual display (opens a config form: name, resolution, DPI)
    - Each row has a delete button
    - Configuration persistence option (auto-create on next launch)
  - Verification: the full create/delete virtual display flow works

- [x] Implement the "High Resolution (HiDPI)" one-click switch UI
  - Implementation notes:
    Add a "High Resolution (HiDPI)" row (blue ⊕ icon) in each display's menu area, following the screenshot.
    Toggle behavior: when on, automatically create a paired virtual display and mirror to it;
    when off, destroy the virtual display and stop mirroring.
    Persist state to UserDefaults.
  - Verification: after enabling HiDPI, the external display's resolution list changes

## Phase Acceptance

- Virtual display creation/destruction works
- HiDPI takes effect via the virtual display approach
- Virtual display management UI is complete
- Configuration persistence works (restored after restart)

**After completion**: recommend running project-optimize for reflection
