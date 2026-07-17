# Phase 4: Screen Rotation and Display Arrangement ✅

> Core value: screen rotation and spatial arrangement of multiple displays

## Task List

- [x] Implement screen rotation (`FreeDisplay/Services/RotationService.swift`)
  - Implementation hint:
    Use `CGBeginDisplayConfiguration` → `CGConfigureDisplayOrigin` together with rotation.
    macOS rotation is set through IOKit:
    ```swift
    IOServiceRequestProbe(service, kIOFBSetTransform)  // trigger rotation
    ```
    Or use `CGDisplayRotation()` to get the current rotation angle,
    and set rotation via the private API `CGSConfigureDisplayMode`.
    Alternative: follow the approach of the `displayplacer` CLI tool, operating IOKit directly.
    Supported angles: 0°, 90°, 180°, 270°.
  - Verification: after selecting 90° rotation the display's image actually rotates

- [x] Implement the screen rotation UI (`FreeDisplay/Views/RotationView.swift`)
  - Implementation hint:
    An expandable "Screen rotation" section.
    Four options: rotate the screen 90°/180°/270° + turn rotation off.
    One row per option, with a rotation direction arrow icon on the left (↻/↓/←) and text on the right.
    The current rotation state is highlighted.
    Follow the layout of the screen rotation area in the BetterDisplay screenshot.
  - Verification: the UI shows four rotation options, and clicking one actually rotates the display

- [x] Implement display arrangement (`FreeDisplay/Services/ArrangementService.swift`)
  - Implementation hint:
    Use `CGBeginDisplayConfiguration` → `CGConfigureDisplayOrigin(config, displayID, x, y)`
    → `CGCompleteDisplayConfiguration` to set a display's position in the virtual desktop.
    Get the current position: the origin returned by `CGDisplayBounds(displayID)`.
    Coordinate system for multiple displays: the main display's top-left corner is (0,0), other displays are offset relative to it.
  - Verification: after the code adjusts a display's position, the arrangement in System Settings does change

- [x] Implement the display arrangement UI (`FreeDisplay/Views/ArrangementView.swift`)
  - Implementation hint:
    An expandable "Arrange displays" section.
    The content is a grid view following the BetterDisplay screenshot:
    display thumbnails (blue rectangle + name) on a gray background, draggable.
    Implement dragging with SwiftUI's `.gesture(DragGesture())`.
    The size of each display rectangle is scaled proportionally to its actual resolution.
    Call ArrangementService to update the position when the drag ends.
    The grid background uses light gray squares to represent the extent of the virtual desktop.
  - Verification: the display arrangement view layout matches the BetterDisplay screenshot, and positions update after dragging

- [x] Set as main display feature (`FreeDisplay/Services/DisplayManager.swift` extension)
  - Implementation hint:
    Add `func setAsMainDisplay(_ displayID: CGDirectDisplayID)` to DisplayManager.
    Use `CGBeginDisplayConfiguration` → `CGConfigureDisplayOrigin(config, displayID, 0, 0)`
    to move the target display to the origin (in macOS the main display = the display at the coordinate origin).
    The coordinates of the other displays are adjusted accordingly.
  - Verification: after setting a display as the main display, the Dock and menu bar move to the target display

## Phase Acceptance

- All four screen rotation directions work correctly
- Visual drag-and-drop display arrangement works correctly
- The set as main display feature works correctly
- The UI layout matches the BetterDisplay screenshot

**After completion**: consider running project-optimize for a retrospective
