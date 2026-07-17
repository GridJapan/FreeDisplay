# Phase 8: Screen Mirroring ✅

> Core value: mirror the content of one display onto another

## Task List

- [x] Implement hardware mirroring (`FreeDisplay/Services/MirrorService.swift`)
  - Implementation hint:
    macOS natively supports hardware-level screen mirroring through the CoreGraphics API:
    ```swift
    func enableMirror(source: CGDirectDisplayID, target: CGDirectDisplayID) -> Bool {
        var config: CGDisplayConfigRef?
        CGBeginDisplayConfiguration(&config)
        CGConfigureDisplayMirrorOfDisplay(config, target, source)
        return CGCompleteDisplayConfiguration(config, .permanently) == .success
    }

    func disableMirror(displayID: CGDirectDisplayID) -> Bool {
        var config: CGDisplayConfigRef?
        CGBeginDisplayConfiguration(&config)
        CGConfigureDisplayMirrorOfDisplay(config, displayID, kCGNullDirectDisplay)
        return CGCompleteDisplayConfiguration(config, .permanently) == .success
    }
    ```
    Check whether mirroring is active: `CGDisplayMirrorsDisplay(displayID)` returns the source display ID;
    if it returns `kCGNullDirectDisplay` then it is not mirroring.
    Note: hardware mirroring requires the two displays to have compatible resolutions.
  - Verification: both displays show the same content once mirroring is enabled

- [x] Implement the screen mirroring UI (`FreeDisplay/Views/MirrorView.swift`)
  - Implementation hint:
    An expandable "Screen mirroring" section, following the BetterDisplay screenshot:
    Text below the title: "Mirror this display's content to:"
    The list shows the available target displays (e.g. "H2435Q"), each row with a display icon on the left.
    A "Stop mirroring" button at the bottom (toggling between grayed-out and enabled states).
    Mirroring starts immediately once a target is selected.
  - Verification: mirroring takes effect after selecting a target display, and clicking stop restores it

## Phase Acceptance

- Built-in → external mirroring works
- External → built-in mirroring works
- Stopping mirroring restores normal operation
- The UI matches the BetterDisplay screenshot

**After completion**: consider running project-optimize for a retrospective
