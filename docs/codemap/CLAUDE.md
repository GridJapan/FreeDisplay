# Code Map — FreeDisplay (Quick Reference)

> **Purpose**: quick reference for Claude's code navigation. See `file-tree.md` for the detailed file tree and `relationships.md` for the module relationship diagram.
> **Maintenance**: update the descriptions and the module relationship diagram after major structural changes.

---

## Key Entry Points

- `CLAUDE.md`
- `docs/codemap/CLAUDE.md` (this file)
- `docs/roadmap/CLAUDE.md`

Details: [file-tree.md](file-tree.md) | [relationships.md](relationships.md)

---

## Module Summary

| Module | Responsibility | Key Files | Notes |
|------|------|---------|---------|
| **App** | App lifecycle, MenuBarExtra scene declaration | `FreeDisplayApp.swift` | DisplayManager is created here and injected as an environmentObject |
| **Models** | Pure data structures, ObservableObject | `DisplayInfo.swift`, `DisplayMode.swift` | Changing a DisplayInfo property requires a global grep to keep everything in sync |
| **Services** | System framework interaction, no UI | `DDCService.swift`, `DisplayManager.swift`, `BrightnessService.swift`, etc. | Most Services are @MainActor singletons |
| **Views** | SwiftUI views, purely presentation and interaction | `MenuBarView.swift`, `DisplayDetailView.swift` | Do not write business logic in a View; call a Service |
| **Utilities** | System type extensions | `NSScreenExtension.swift` | Depended on in many places; do not change lightly |

---

## High-Risk Files ⚠️

| File | Why it is risky | Required when changing it |
|------|---------|---------|
| `Models/DisplayInfo.swift` | 12+ @Published properties; every View and Service depends on it | grep every reference and update them in sync |
| `Services/DisplayManager.swift` | @Published displays is injected globally; hot-plug callback | verify hot-plug and multi-display enumeration after changes |
| `Services/DDCService.swift` | Low-level IOKit I2C communication; the basis of every external display feature | must be tested by hand on a real external display |
| `Views/MenuBarView.swift` | The entry container for every feature; nests every Section entry point | check the layout and scroll height after adding a Section |
| `Views/DisplayDetailView.swift` | The expansion container for 12 Sections; many state variables | when adding a Section, watch out for @State name collisions |

---

## Common Tasks → Which Files to Change / Task Reference Table

| Task | Files to change |
|------|--------------|
| Add a display property (e.g. HDR status) | `Models/DisplayInfo.swift` → grep every reference → the relevant View/Service |
| Add a DDC VCP feature (e.g. volume control) | `Services/DDCService.swift` (add the VCP constant) → new Service → new View → `Views/DisplayDetailView.swift` (add the Section) → `docs/codemap/CLAUDE.md` |
| Add a menu bar tool entry (not display-related) | `Views/MenuBarView.swift` (add the entry to the tools area) → new View/Service → `docs/codemap/CLAUDE.md` |
| Change resolution switching logic | `Services/ResolutionService.swift`, `Models/DisplayMode.swift`; test the impact on `Views/ResolutionSliderView.swift` and `Views/DisplayModeListView.swift` |
| Change brightness read/write | `Services/BrightnessService.swift`; for external displays also check `Services/DDCService.swift` |
| Change image adjustment effects | `Services/GammaService.swift` (formula/table computation), `Views/ImageAdjustmentView.swift` (UI slider mapping) |
| Add a new persisted setting | `Services/SettingsService.swift` (Keys + @Published property + loadAll/persist) → the relevant View |
| Change notification/hot-plug handling | `Services/DisplayManager.swift` (displayReconfigCallback + refreshDisplays) |
| Change HiDPI Override generation | `Services/HiDPIService.swift` (generateScaledModes + plist path) |
| Change the color picker / color history | `Views/SystemColorView.swift` (SystemColorViewModel), `Services/SettingsService.swift` (colorPickerHistory) |
| Change virtual display logic | `Services/VirtualDisplayService.swift`, `FreeDisplay-Bridging-Header.h` (private API declarations) |

---

## Pitfalls

- **DisplayInfo property coupling**: after changing `DisplayInfo`, grep every reference and update them in sync, otherwise it may compile but be logically wrong
- **project.yml**: after changing it you must run `xcodegen generate` to regenerate the xcodeproj
- **Adding source files**: xcodegen includes every `.swift` file under `FreeDisplay/` automatically; there is no need to change `project.yml`
- **Swift 6 concurrency**: the project sets `SWIFT_STRICT_CONCURRENCY: minimal`; handle concurrency errors with `@MainActor` or `@unchecked Sendable`
- **No Sandbox**: the entitlements disable App Sandbox, so direct access to IOKit, /Library/Displays, etc. is available
- **Bridging header private APIs**: the CGVirtualDisplay / IOAVService declarations in `FreeDisplay-Bridging-Header.h` are verified against the Chromium source; re-check the property names before changing them
- **HiDPIService privileges**: writing to `/Library/Displays/` requires administrator privileges; without them it returns an error string for the UI to display
- **CGHelpers.runWithTimeout**: WindowServer IPC may block the main thread, so every CG configuration transaction must be run through this helper on a background thread with timeout protection
