# Pitfalls — SwiftUI / UI

> Updated: 2026-03-05

## SwiftUI / MenuBarExtra

- MenuBarExtra needs `.menuBarExtraStyle(.window)` to display a custom SwiftUI view (the default menu style only supports Button/Toggle)
- Hiding the Dock icon: set `INFOPLIST_KEY_LSUIElement: true` in project.yml; there is no need to set it manually in AppDelegate

## UI Animation / SwiftUI (Phase 12)

- `withAnimation(.easeInOut(duration: 0.2)) { state.toggle() }` is the simplest way to trigger an expand/collapse animation; there is no need to apply `.animation(_, value:)` to the whole container
- `.transition(.opacity.combined(with: .move(edge: .top)))` is used for the enter/exit effect of the expanded content; visually it looks like it slides out from under the button
- The shared icon helper `MenuItemIcon` (defined in MenuBarView.swift) can be used directly by every View in the same Module without an extra declaration
- Semantic colors in SwiftUI (green = protection/safety, red = streaming, orange = brightness, gray = settings, purple = color management) convey feature semantics effectively, with no extra text needed

## DDC Performance Caching (Phase 12)

- DDC I2C reads have 50ms+ latency, and repeated reads triggered by the UI noticeably hurt the experience → solved with `NSLock` + a dictionary cache + a 5-second TTL; the corresponding cache entry is invalidated immediately after a write
- The cache key is a two-level dictionary `[CGDirectDisplayID: [UInt8: VCPCacheEntry]]`, which allows precise invalidation per display and per VCP code
- `NSLock.lock()` / `unlock()` must be paired; `defer { lock.unlock() }` is recommended, but note that defer executes correctly on an early return

## SwiftUI Performance

- A change to an `@Published` property triggers a redraw of every View observing that ObservableObject → split the state into several small ObservableObjects, or localize it with `@State`
- Do not put synchronous IOKit/CG calls (such as `CGDisplayCopyColorSpace`) in a View `body` → fetch asynchronously with `@State` + `onAppear`/`task {}`
- The `isSwitching = true; syncCall(); isSwitching = false` pattern does not work: SwiftUI does not render in the middle of synchronous code → you must use async/await to give SwiftUI a chance to redraw
- Wrapping a shared singleton (`XXX.shared`) in `@StateObject` is an anti-pattern: every View rebuild may create a new subscription → use `@ObservedObject` for shared singletons
- The gamma table set by `CGSetDisplayTransferByFormula` persists at the kernel level and is not restored automatically when the View is destroyed → reset through `GammaService.resetSingleDisplay(_:)`, which writes an identity ramp (256 entries) for that display alone. The app never calls `CGDisplayRestoreColorSyncSettings()` (it is a global reset), and a View must not call it either; app exit is already covered by GammaService's `willTerminateNotification` observer
