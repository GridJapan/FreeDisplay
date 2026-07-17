# Services — Business Logic Layer

> The system framework interaction layer; no UI. Every Service is a `@MainActor` singleton (`static let shared`).

## Responsibilities

Interacts directly with the macOS system frameworks (IOKit, CoreGraphics, ScreenCaptureKit, ColorSync),
providing high-level APIs to Views/ViewModels.

## Key Patterns

- **Singleton + @MainActor**: every Service is marked `@MainActor final class: ObservableObject, @unchecked Sendable`
- **DDC communication**: DDCService is the low-level dependency for every external display feature; Apple Silicon uses IOAVService
- **Sole writer of the gamma table**: GammaService owns write access to CGSetDisplayTransfer*
  - BrightnessService's software brightness is written indirectly through GammaService
  - ❌ No Service/View may call CGSetDisplayTransferByFormula/Table directly
- **CGHelpers.runWithTimeout**: blocking CG calls (apply settings, enableMirror) MUST be wrapped with this

## File List

| File | Purpose |
|------|------|
| DDCService.swift | Low-level IOKit I2C / IOAVService DDC communication |
| DisplayManager.swift | Display enumeration, refresh, cross-Service coordination |
| BrightnessService.swift | Software brightness (written through GammaService) |
| GammaService.swift | Sole writer of the gamma table |
| AutoBrightnessService.swift | Syncs external displays to follow the built-in screen's brightness (CoreDisplay API) |
| ResolutionService.swift | Resolution/HiDPI mode switching |
| ArrangementService.swift | Display arrangement |
| MirrorService.swift | Mirroring mode |
| HiDPIService.swift | HiDPI detection and management |
| VirtualDisplayService.swift | CGVirtualDisplay creation/teardown |
| ColorProfileService.swift | ColorSync ICC Profile |
| NotchOverlayManager.swift | Notch mask overlay layer |
| SettingsService.swift | UserDefaults persistence |
| UpdateService.swift | App update checking |
| LaunchService.swift | Launch at login |
| CGHelpers.swift | Timeout wrapper for blocking CG calls |

## Cross-Service Rules

- **Sleep/wake reapply order**: BrightnessService → GammaService (Brightness is Gamma's data provider)
  - AppDelegate listens for `NSWorkspace.didWakeNotification` → calls reapply
- **C callbacks**: use `Unmanaged.passRetained(self)` + a paired `release()`; ❌ do not use passUnretained
- **VirtualDisplayService**: the HiDPI configuration is purely runtime (❌ do not persist autoCreate to UserDefaults),
  and `CGVirtualDisplay(descriptor:)` init MUST be on the main thread

## Testing Notes

- DDC/IOKit features MUST be tested manually on a real external display
- After VirtualDisplayService creates a display, verify that `CGVirtualDisplay` is non-nil (vendorID MUST be non-zero)
