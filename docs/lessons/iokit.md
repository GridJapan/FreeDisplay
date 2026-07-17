# Pitfalls — IOKit

> Updated: 2026-03-05

## IOKit / DDC

- In the CF dictionary returned by `IODisplayCreateInfoDictionary`, `DisplayVendorID` and `DisplayProductID` have type `Int` (not `UInt32`) → try casting to UInt32 first, then to Int
- `IODisplayCreateInfoDictionary` returns `Unmanaged<CFDictionary>?`; use `.takeRetainedValue()` to get the value (ARC-managed)
- The matching parameter of `IOServiceGetMatchingServices` consumes the CFDictionary reference; no manual release is needed
- IOKit's I2C submodule is an `explicit module` and is not covered by `import IOKit` → you need `import IOKit.i2c` (I2C functions) and `import IOKit.graphics` (IODisplay*FloatParameter functions)
- `IOI2CRequest` lives inside a `#pragma pack(push, 4)` struct; the `sendTransactionType`/`replyTransactionType` fields have type `IOOptionBits` (UInt32, not UInt8)
- `kIODisplayBrightnessKey` is a `#define "brightness"`, and Swift does not bridge string macros automatically → use `"brightness" as CFString` directly
- Swift's `Array.withUnsafeMutableBytes` holds an exclusive mutable borrow, so the original array cannot be subscripted inside the closure → read the data through a raw buffer pointer instead (`replyRaw.bindMemory(to: UInt8.self)`), or capture `.count` ahead of time outside the closure
- `IOFBCopyI2CInterfaceForBus(framebuffer, busIndex, &interface)` is a cleaner API than manually looking up the IOFramebufferI2CInterface child node; recommended
- A `BrightnessService` method that accesses `@MainActor`-isolated `DisplayInfo` properties must be marked `@MainActor`; the actual DDC I/O runs asynchronously on DDCService's internal ddcQueue and does not block the MainActor

## IOKit / Screen Rotation (Phase 4)

- `CGDisplayIOServicePort` is now completely **unavailable** (not deprecated) in the latest macOS SDK and errors out directly; it must be replaced by walking the IOKit registry
- Alternative approach: walk `IODisplayConnect` → match on vendor/model → `IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent)` to get the IOFramebuffer (exactly the same pattern as DDCService.framebufferService)
- Screen rotation: `IORegistryEntrySetCFProperty(fb, "IOFBTransform", NSNumber(value: index))` + `IOServiceRequestProbe(fb, 0x00000400)` to trigger it; rotation index = 0/1/2/3 corresponds to 0°/90°/180°/270°
- `import IOKit.graphics` is required for the graphics constants that `IOServiceRequestProbe` needs

## IOKit / Ambient Light Sensor (Phase 11)

- `AppleLMUController` is an IOKit service obtained via `IOServiceGetMatchingService`; after opening a connection with `IOServiceOpen`, use `IOConnectCallMethod(port, 0, nil, 0, nil, 0, &output, &outputCount, nil, &outputStructSize)` to read the two-channel (left/right) sensor UInt64 values
- The struct size parameters of `IOConnectCallMethod` are `Int` (size_t = Int in Swift) and cannot be passed as `nil` → you must pass `0` or a pointer to a variable (`&outputStructSize`)
- After creating a new Swift file, if other files reference types in it, you must first run `xcodegen generate` to regenerate the xcodeproj, otherwise "cannot find in scope"
- When the `init` of a `@MainActor` class accesses properties of other `@MainActor` classes, `init` must also be marked `@MainActor`, otherwise Swift 6 strict concurrency errors out

## IOKit Display Matching (Phase 13-15)

### L-003: vendor+model IOKit matching is unreliable
- **Symptom**: DisplayInfo shows the name "Display 2"; the DDC brightness slider has no effect
- **Cause**: the values returned by CGDisplayVendorNumber/ModelNumber and IOKit's DisplayVendorID/DisplayProductID are not necessarily the same (they do not match on the HKC H2435Q, at least), which makes IODisplayConnect service matching fail
- **Fix**: get the name from NSScreen.localizedName (system API, most reliable); look up the IOKit service with CGDisplayIOServicePort (deprecated but still usable)
- **Lesson**: do not assume that different frameworks (CoreGraphics vs IOKit) use identical identifiers for the same hardware. Prefer system-level APIs (NSScreen) over low-level IOKit lookups
- **Date**: 2026-03-03

### L-004: do not make microsecond-scale operations async
- **Symptom**: Phase 14 changed the name lookup in DisplayInfo.init to async, which made users see "Display N" flash before it updated to the real name (and sometimes it never updated)
- **Cause**: the IOKit name lookup only takes microseconds, and making it async introduced a race condition (refreshDisplays may be called multiple times, and a later call overwrites the async result of an earlier one)
- **Fix**: rolled back to a synchronous call
- **Lesson**: making something async is only worthwhile for genuinely slow operations (>100ms). Making a microsecond-scale operation async only introduces complexity and bugs
- **Date**: 2026-03-03

## Apple Silicon DDC (Phase 17)

### L-005: the IOFramebuffer I2C API does not work at all on Apple Silicon
- **Symptom**: DDC brightness/contrast control has no effect on any external display
- **Cause**: `IOFBCopyI2CInterfaceForBus` / `IOI2CSendRequest` are Intel-era IOFramebuffer APIs; on Apple Silicon (M1/M2/M3/M4) these calls return silently without sending any I2C data
- **Fix**: use the IOAVService private API (`IOAVServiceCreateWithService` + `IOAVServiceWriteI2C` / `IOAVServiceReadI2C`), locating external displays through the DCPAVServiceProxy IOKit service
- **Lesson**: macOS uses completely different display communication APIs on different CPU architectures. MonitorControl and BetterDisplay both use IOAVService. See alinpanaitiu.com/blog/journey-to-ddc-on-m1-macs/
- **Date**: 2026-03-03
