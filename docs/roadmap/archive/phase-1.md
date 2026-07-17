# Phase 1: Display Detection and Menu UI ✅

> Core value: list all connected displays, show basic information, establish the UI framework

## Task List

- [x] Implement the `DisplayInfo` model (`FreeDisplay/Models/DisplayInfo.swift`)
  - Implementation hint: properties include `displayID: CGDirectDisplayID`, `name: String`,
    `isBuiltin: Bool`, `isMain: Bool`, `isOnline: Bool`, `vendorNumber: UInt32`,
    `modelNumber: UInt32`, `serialNumber: UInt32`, `bounds: CGRect`,
    `pixelWidth: Int`, `pixelHeight: Int`, `rotation: Double`.
    Obtain them with CG functions such as `CGDisplayIsBuiltin()` / `CGDisplayIsMain()`.
    The display name comes from `kDisplayProductName` in `IODisplayCreateInfoDictionary`.
  - Verification: correctly identifies the built-in display and the name of the H2435Q external display

- [x] Implement the `DisplayManager` detection logic (`FreeDisplay/Services/DisplayManager.swift`)
  - Implementation hint: `@Published var displays: [DisplayInfo]`.
    Use `CGGetOnlineDisplayList(16, &displayIDs, &count)` to get all online displays.
    Register `CGDisplayRegisterReconfigurationCallback` to refresh automatically when displays are hot-plugged.
    Run a scan once at startup.
  - Verification: the list updates automatically when displays are plugged in or unplugged

- [x] Implement the main menu bar view (`FreeDisplay/Views/MenuBarView.swift`)
  - Implementation hint: a vertical ScrollView with the display list at the top (one row per display, with name + a Toggle switch),
    following the layout in the BetterDisplay screenshot: display name on the left, Toggle on the right.
    Append an Ⓜ marker after the built-in display's name to indicate the main display.
    Use `@EnvironmentObject var displayManager: DisplayManager`.
    Put a "Tools" section and a "Quit FreeDisplay" button at the bottom.
  - Verification: the menu shows two rows, H2435Q and the built-in display

- [x] Implement the display detail expansion area (`FreeDisplay/Views/DisplayDetailView.swift`)
  - Implementation hint: clicking a display row expands its details, using `DisclosureGroup` or a custom expansion animation.
    Once expanded, show the feature list (brightness, resolution, etc.), with one section header per feature.
    Phase 1 uses placeholder text for now; later phases implement these step by step.
    Follow the section list style in the BetterDisplay screenshot (blue icon + text + right chevron).
  - Verification: clicking a display row expands it and shows the feature section list

- [x] Display power toggle (`FreeDisplay/Services/DisplayManager.swift`)
  - Implementation hint: the Toggle controls display power. For external displays use DDC VCP code 0xD6 (Power Mode)
    to send the standby command. For the built-in display use `IORegistryEntrySetCFProperty` to set brightness to 0.
    Note: full DDC communication is implemented in Phase 2; here it can be simulated with `CGDisplayCapture` / `CGDisplayRelease` for now.
  - Verification: turning the Toggle off for an external display blanks the screen

## Phase Acceptance

- After building and running, clicking the menu bar icon pops up the panel
- The panel lists all connected displays (with correct names)
- Display rows can be expanded, showing the placeholder feature section list
- There is a working "Quit FreeDisplay" button at the bottom

**After completion**: consider running project-optimize for a retrospective
