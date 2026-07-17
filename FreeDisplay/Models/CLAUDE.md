# Models — Data Model Layer

> Pure data structures, ObservableObject.

## Files

| File | Purpose |
|------|------|
| DisplayInfo.swift | State model for a single display (high risk) |
| DisplayMode.swift | Display mode value type (resolution + refresh rate + HiDPI) |

---

## DisplayInfo.swift — High Risk

The core display model, with multiple `@Published` properties. **Every View and Service depends on this class.**

### Change Protocol

1. Adding/removing a `@Published` property → `grep -r "DisplayInfo" FreeDisplay/ --include="*.swift"` to find every reference
2. Update every reference in sync (a successful build ≠ correct logic)
3. `loadDetails()` is an async method, called on new displays from `DisplayManager.refreshDisplays()`

### Notes on Key Properties

- `displayID: CGDirectDisplayID` — hardware identifier; may change after hot-plugging (cannot be used as a persistent key)
- `isBuiltin` — determined with `CGDisplayIsBuiltin()`
- `bounds` — comes from `CGDisplayBounds()`; needs refreshing after hot-plugging or an arrangement change
- `name` — comes from `NSScreen.localizedName` (more reliable than the IOKit vendorID)
- The `rotation` property was removed in Phase 21 (deleted along with RotationService/RotationView)

---

## DisplayMode.swift

The value type for a single display mode (resolution + refresh rate + HiDPI flag).

- The `currentMode(for:)` static method gets the current mode
- `availableModes(for:)` gets the list of available modes (including HiDPI variants)
- Changes affect ResolutionService and DisplayModeListView

### HiDPI Notes

- HiDPI modes are distinguished by the `kIOScalingModeKey` flag, not by simply being 2× the resolution
- HiDPI modes for virtual displays are injected dynamically by VirtualDisplayService; they do not come from DisplayMode
