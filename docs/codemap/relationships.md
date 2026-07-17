# Module Relationships — FreeDisplay

> Module relationship diagram, Services internal dependencies, data flow. See [CLAUDE.md](CLAUDE.md) for the quick reference and [file-tree.md](file-tree.md) for the file tree.

---

## Module Relationship Diagram

```
App (FreeDisplayApp)
  └── @StateObject DisplayManager
        └── @Published [DisplayInfo]
              └── MenuBarView (@EnvironmentObject DisplayManager)
                    ├── DisplayRowView
                    │     └── DisplayDetailView  ← 12 Sections (three groups)
                    │           ├── BrightnessSliderView     → BrightnessService → DDCService
                    │           ├── ResolutionSliderView     → ResolutionService
                    │           ├── DisplayModeListView      → ResolutionService
                    │           ├── ColorProfileView         → ColorProfileService
                    │           ├── ImageAdjustmentView      → GammaService
                    │           ├── MainDisplayView          → ArrangementService
                    │           ├── NotchView                → NotchOverlayManager
                    │           └── HiDPIVirtualRowView      → VirtualDisplayService
                    ├── ArrangementView          → ArrangementService
                    ├── VirtualDisplayView       → VirtualDisplayService
                    ├── AutoBrightnessView       → AutoBrightnessService → BrightnessService
                    ├── SystemColorMenuEntry     → SystemColorView → SettingsService
                    └── SettingsView             → SettingsService, LaunchService
```

---

## Services Internal Dependencies

```
BrightnessService ──────────→ DDCService (DDC brightness read/write on external displays)
AutoBrightnessService ──────→ BrightnessService (called after mapping lux→brightness)
DisplayManager ─────────────→ BrightnessService (asynchronously initializes brightness on refresh)
               ─────────────→ ArrangementService (setAsMainDisplay)
               ─────────────→ arrangeExternalAboveBuiltin() (automatically positions external displays after hot-plug)

CGHelpers (shared helper) ──→ used by the following Services (WindowServer IPC timeout protection):
  ArrangementService (setPosition/setAsMainDisplay CG transactions)
  MirrorService (enableMirror/disableMirror CG transactions)
  ResolutionService (applyModeSync CG transactions)
  VirtualDisplayService (CGVirtualDisplay apply transactions)

GammaService (gamma owner) ─→ the only Service that writes CGSetDisplayTransferByFormula/Table
  BrightnessService ────────→ GammaService (software brightness is written through GammaService, not directly to CG)
  ❌ The View layer must not call CGSetDisplayTransferByFormula/Table directly
  ❌ Do not use CGDisplayRestoreColorSyncSettings() (it is global); use GammaService.resetSingleDisplay(displayID) instead

ResolutionService ──────────→ VirtualDisplayService.virtualDisplayID(for:) (mirror detection fallback)
```

---

## Data Flow

```
Unidirectional data flow (reactive):
  CGDisplayAPI / IOKit → Services → DisplayInfo (@Published) → Views (reactive SwiftUI)
  User interaction    → Views   → Services → Hardware

Sleep/wake data flow:
  NSWorkspace.didWakeNotification → AppDelegate
    → GammaService.reapplyIfNeeded()
    → BrightnessService.reapplySoftwareBrightnessIfNeeded()

Hot-plug data flow:
  CGDisplayRegisterReconfigurationCallback → DisplayManager.displayReconfigCallback
    → refreshDisplays()
    → arrangeExternalAboveBuiltin()
    → @Published displays updated → global View re-render

Virtual display data flow (runtime, not persisted):
  VirtualDisplayView → VirtualDisplayService.enableHiDPIVirtual()
    → CGVirtualDisplay(descriptor:) [main thread, vendorID=0xEEEE]
    → MirrorService.enableMirror() [background, CGHelpers.runWithTimeout]
    → HiDPI modes available (gone after a restart)
```
