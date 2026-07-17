# Pitfalls — CoreGraphics

> Updated: 2026-03-05

## CoreGraphics / Displays

- In a Swift 6 class init, if any `@Published` property is not yet initialized, you cannot use `self.anyProperty` before initialization completes (even if that property has already been assigned) → fix: hold the value in a local variable and reference that
- `CGDisplayRegisterReconfigurationCallback` requires the callback to be a C function pointer (a global func), not a closure → pass `Unmanaged.passRetained(self).toOpaque()` via `userInfo` (`passUnretained` leaves a dangling pointer once the owner is released); balance the retain in `deinit` — call `CGDisplayRemoveReconfigurationCallback` first, then `Unmanaged<T>.fromOpaque(ctx).release()`
- `deinit` is nonisolated under Swift 6 and cannot access `@MainActor`-isolated properties → fix: mark the properties that need to be accessed in deinit as `nonisolated(unsafe)`
- If compilation reports "symbol not found" after adding a Swift source file, rerun `xcodegen generate` to regenerate the xcodeproj (even if project.yml uses a glob, the old xcodeproj may not include the new file)
- The macOS 26.2 SDK replaces the C functions `CGDisplayModeGetWidth/Height/PixelWidth/PixelHeight/RefreshRate/IODisplayModeID` and others entirely with Swift properties (`mode.width`, `mode.pixelWidth`, `mode.ioDisplayModeID`, etc.) and methods (`mode.isUsableForDesktopGUI()`) → with the new SDK, use property syntax directly and avoid the deprecated functions
- `kCGDisplayShowDuplicateLowResolutionModes: true` is the correct key name; passing it in the options dictionary of `CGDisplayCopyAllDisplayModes` makes HiDPI scaled modes show up
- `CGDisplayCopyColorSpace` returns a non-Optional `CGColorSpace` in the macOS 26 SDK (older SDKs returned an Optional) → replace guard let with a direct call, and use `colorSpace.name` to get the name (`CGColorSpaceCopyName` has been replaced by a property)
- `CGDisplayMode.pixelEncoding` is `CFString?` (not `String`) and must be bridged manually: `if let cfEnc = mode.pixelEncoding { encoding = cfEnc as String }`
- The ColorSync global constants (`kColorSyncDisplayDeviceClass`, `kColorSyncDeviceDefaultProfileID`) have type `Unmanaged<CFString>?` in Swift 6, and accessing global vars produces concurrency-safety warnings → use `@preconcurrency import ColorSync` to suppress the concurrency errors; access them with `.takeUnretainedValue()` to borrow the reference (do not use `takeRetainedValue`, to avoid a double release)
- `kColorSyncProfileUseSystemSequence` does not exist in the public ColorSync headers → an API to reset to the system default profile cannot be implemented through public interfaces; resetProfile is skipped
- After adding a Swift source file you must rerun `xcodegen generate` to regenerate the xcodeproj, otherwise the compiler will not know about the new file ("cannot find in scope" error)

## HiDPI / Resolution

- After `HiDPIService` writes the display override plist, macOS does not load the new modes immediately → display re-enumeration must be triggered (`CGDisplayForceToMirror` or `IOServiceRequestProbe`)
- `isUsableForDesktopGUI()` filters out some resolution modes, which makes certain resolutions "invisible" → this filter may need to be bypassed

### L-006: plist injection cannot enable HiDPI dynamically on macOS 14+
- **Symptom**: after writing the display override plist + IOServiceRequestProbe, no HiDPI modes appear on the 2K external display
- **Cause**: macOS Ventura/Sonoma does not dynamically re-enumerate plist-injected modes for an already-connected display. The plist approach only works when the display is first connected
- **Fix**: use the CGVirtualDisplay private API to create a 3840x2160 virtual display (hiDPI=1), then mirror the physical display to the virtual display; macOS then automatically offers HiDPI modes such as 1920x1080@2x
- **Lesson**: the core of BetterDisplay's HiDPI approach is "virtual display + mirroring", not plist injection
- **Date**: 2026-03-03

### L-007: NSWindow.isReleasedWhenClosed defaults to true
- **Symptom**: the app crashes/hangs when the notch overlay is closed
- **Cause**: NSWindow defaults to `isReleasedWhenClosed = true`; after close() the window is released by ARC immediately, and the reference held in the dictionary becomes a dangling pointer
- **Fix**: set `isReleasedWhenClosed = false` immediately after creating the NSWindow
- **Lesson**: the other windows in the project (PiPWindow, StreamWindow, VideoFilterWindow) all set this property correctly; only NotchOverlayManager missed it
- **Date**: 2026-03-03

## CGVirtualDisplay / Virtual Displays

- `CGVirtualDisplay`, `CGVirtualDisplayDescriptor`, `CGVirtualDisplaySettings`, and `CGVirtualDisplayMode` are private CoreGraphics SPI; although the symbols are exported in the TBD file (`grep CGVirtualDisplay CoreGraphics.tbd`), they are declared in neither the public C/ObjC headers nor the Swift interface files of the macOS 26 SDK → referencing them directly from Swift raises a "cannot find type in scope" error
- BetterDisplay/BetterDummy use these classes by declaring the private interfaces themselves in a bridging header → this counts as private API usage, and the project needs an explicit decision on whether to accept the risk
- If asked to resolve this before continuing, read BLOCKING.md B-002 first

### L-020: CGVirtualDisplay vendorID must be non-zero
- **Symptom**: `CGVirtualDisplay(descriptor:)` always returns nil, with no error
- **Cause**: `vendorID = 0` is rejected by WindowServer; the node-mac-virtual-display project uses `0xEEEE` for reference
- **Fix**: set `vendorID = 0xEEEE`, `productID = 0x0001`, `serialNum = 0x0001`
- **Lesson**: the implicit constraints of private APIs are undocumented; you must refer to a known-working open source implementation
- **Date**: 2026-03-04

### L-021: CGVirtualDisplay(descriptor:) must run on the main thread
- **Symptom**: calls from a background DispatchQueue return nil; calls from the main thread succeed
- **Cause**: WindowServer IPC requires CGVirtualDisplay initialization to happen on the main thread
- **Fix**: build the descriptor + init on @MainActor; run `apply(settings)` and `enableMirror` in the background via `runWithTimeout`
- **Lesson**: different methods of the same API may have different threading requirements
- **Date**: 2026-03-04

### L-022: bridging header property names must match the runtime API exactly
- **Symptom**: `-[CGVirtualDisplayDescriptor setMaxPixelSize:]: unrecognized selector` causes a crash
- **Cause**: the bridging header declared `maxPixelSize` (CGSize), but the actual property names are `maxPixelsWide`/`maxPixelsHigh` (uint32_t)
- **Fix**: use Chromium's `virtual_display_mac_util.mm` as the authoritative reference and verify each property name one by one
- **Lesson**: property names in a private API bridging header must never be guessed; refer to reverse engineering or a known-working implementation
- **Date**: 2026-03-04

### L-023: HiDPI virtual display configs must not use autoCreate
- **Symptom**: on every app restart, stale virtual displays pile up (displayID=7,8,9,10...) and creation eventually fails
- **Cause**: the HiDPI config was stored in the configs array with `autoCreate: true`, but autoCreate only creates the virtual display without setting up mirroring, so useless virtual displays accumulate
- **Fix**: keep the HiDPI config purely at runtime (`autoCreate: false`, not stored in configs) and clean up leftovers at startup
- **Lesson**: a config that depends on runtime state (such as a mirroring relationship) should not be auto-recreated — the recreated config is missing the critical context
- **Date**: 2026-03-04

### L-024: CGDisplayMirrorsDisplay() detection is unreliable
- **Symptom**: switching resolution fails in HiDPI mode; `CGDisplayMirrorsDisplay(physicalID)` returns `kCGNullDirectDisplay`
- **Cause**: macOS's mirror detection API does not always recognize a mirroring relationship established via `CGConfigureDisplayMirrorOfDisplay`
- **Fix**: add `VirtualDisplayService.virtualDisplayID(for:)` as a fallback in `resolvedTargetDisplayID()`
- **Lesson**: the behavior of a system API may not match its documentation; a fallback is needed
- **Date**: 2026-03-04

### L-025: choosing a HiDPI approach — mirroring is a dead end, plist override is the right way
- **Symptom**: creating a virtual display → using CGConfigureDisplayMirrorOfDisplay to mirror it to the external display in order to get HiDPI modes triggers the system "Screen Mirroring" UI + mouse stutter across screens + pure mirror mode
- **Cause**: the WindowServer on Apple Silicon manages hardware mirroring strictly, and CGConfigureDisplayMirrorOfDisplay triggers a full mirror reconfiguration flow
- **Fix**: switch to a plist override (write to /Library/Displays/Contents/Resources/Overrides/), which is BetterDisplay's approach. Requires administrator privileges (NSAppleScript "with administrator privileges"); takes effect after reconnecting the display once enabled
- **Lesson**: do not use CGConfigureDisplayMirrorOfDisplay for HiDPI; on Apple Silicon it is a dead end

### L-026: loading private framework symbols — dlsym, not @_silgen_name
- **Symptom**: declaring the private function with @_silgen_name("CoreDisplay_Display_GetUserBrightness") compiles but fails to link (undefined symbol)
- **Cause**: @_silgen_name requires the symbol to be visible at link time, and CoreDisplay is a private framework that is not on the default link path
- **Fix**: load at runtime with dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_LAZY) + dlsym
- **Lesson**: always use dlopen+dlsym for private framework symbols; do not use @_silgen_name

### L-027: display.pixelWidth is the current resolution, not the native resolution
- **Symptom**: scale-resolutions in the HiDPI plist override is an empty array
- **Cause**: display.pixelWidth/pixelHeight (from CGDisplayPixelsWide/High) was passed in as the native resolution, but the display may currently be running at a non-native resolution
- **Fix**: use display.availableModes.max(by: width*height) to get the largest available mode as the native resolution
- **Lesson**: CGDisplayPixelsWide/High returns the pixel size of the current mode, not the physical resolution of the panel
