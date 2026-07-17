# Phase 11: Configuration Protection and Auto Brightness ✅

> Core value: prevent the system from resetting display settings + ambient-light-based auto brightness

## Task List

- [x] Implement configuration snapshots (`FreeDisplay/Services/ConfigProtectionService.swift`)
  - Implementation notes:
    Save a snapshot of the complete current display configuration:
    ```swift
    struct DisplayConfig: Codable {
        let displayID: UInt32
        let displayName: String
        let resolution: (width: Int, height: Int)
        let refreshRate: Double
        let rotation: Int
        let colorProfile: String
        let brightness: Double
        let contrast: Double
        let hdrEnabled: Bool
        let isMain: Bool
        let isMirrored: Bool
        let mirrorSource: UInt32?
        let origin: CGPoint
    }
    ```
    Snapshots are stored in `~/Library/Application Support/FreeDisplay/configs/` as JSON.
    Support multiple named snapshots ("Daytime config", "Nighttime config", etc.).
  - Verification: after saving a snapshot, the JSON file is generated correctly

- [x] Implement configuration protection monitoring (`ConfigProtectionService` extension)
  - Implementation notes:
    Following the "Configuration Protection" section in the BetterDisplay screenshot, the protectable items are:
    - Resolution, refresh rate, color mode, HDR color mode, rotation,
      color profile, HDR color profile, HDR state, mirroring, main display state
    Use `CGDisplayRegisterReconfigurationCallback` to observe display configuration changes.
    When a protected item is detected as changed, automatically restore it to the snapshot value.
    Shortcut buttons to enable/disable all protections.
  - Verification: with resolution protected, changing the resolution from System Settings is automatically reverted

- [x] Implement the configuration protection UI (`FreeDisplay/Views/ConfigProtectionView.swift`)
  - Implementation notes:
    An expandable "Configuration Protection" section, following the screenshot:
    A list of protected items, one Toggle per row:
    Resolution(📺) / Refresh rate(📡) / Color mode(🎨) / HDR color mode / Rotation(🔄) /
    Color profile(🎯) / HDR color profile / HDR state / Mirroring(📋) / Main display state(Ⓜ)
    Bottom:
    - Two buttons: "Enable all protections" / "Disable all protections"
    - Explanatory text: "Settings made by this application are protected."
  - Verification: the UI matches the BetterDisplay screenshot

- [x] Implement auto brightness (`FreeDisplay/Services/AutoBrightnessService.swift`)
  - Implementation notes:
    macOS built-in displays have an ambient light sensor.
    Read ambient light: `IOServiceGetMatchingService` + `AppleLMUController` to read the lux value.
    Or use `CBTrueToneClient` (private framework) to get ambient light data.
    Simplified approach: use the `IOReport` framework or read IOKit's ambient light sensor value.
    Brightness mapping curve: a logarithmic lux → brightness mapping, with a user-adjustable curve offset.
    Auto brightness for external displays: adjusted in sync with the built-in sensor's value (via DDC).
    Settings options: an "Auto Brightness" Toggle + a sensitivity slider.
  - Verification: covering the ambient light sensor automatically lowers screen brightness

- [x] Implement the auto brightness UI (`FreeDisplay/Views/AutoBrightnessView.swift`)
  - Implementation notes:
    Add an "Auto Brightness" option (blue Ⓐ icon) at the bottom of the menu or in the display details, following the screenshot.
    A Toggle switch + an optional sensitivity slider.
  - Verification: the switch works and brightness follows ambient light

## Phase Acceptance

- All configuration protection items work
- Protected configurations are automatically restored after system changes
- Auto brightness follows ambient light
- All settings persist (effective after restart)

**After completion**: recommend running project-optimize for reflection
