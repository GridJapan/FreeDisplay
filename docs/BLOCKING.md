# Blocking Issues — FreeDisplay

> Updated: 2026-03-02 | **Required reading before starting work; unresolved P0/P1 issues must be handled first**

## Scheduling rules

1. Read this file → if there are P0/P1 issues → **resolve them one by one from highest priority to lowest, clear them all before working on the ROADMAP**
2. If there are only P2 issues → you may start on ROADMAP tasks and resolve the P2s along the way
3. Once resolved → move to the "Resolved" section below and write down the solution
4. When you hit a new blocking issue during work → add it here immediately

---

## 🔴 P0 — Hard blockers

(none)

---

## 🟡 P1 — High priority

(none)

---

## 🔵 P2 — Normal priority

(none)

---

## ✅ Resolved

### ~~B-004: HiDPI virtual display triggers the system mirroring UI + mouse movement stutter~~
- **Solution**: `CGConfigureDisplayMirrorOfDisplay` triggers hardware mirroring mode on Apple Silicon, which is a dead end. Switched to the same plist override approach BetterDisplay uses: write `scale-resolutions` to `/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-XXXX/DisplayProductID-XXXX`. Requires administrator privileges (NSAppleScript); takes effect after reconnecting the display. All mirroring-related code has been removed (enableHiDPIVirtual/disableHiDPIVirtual/hiDPIMirrorMap etc.).
- **Resolved on**: 2026-03-05
- **Lesson**: There are only two paths to HiDPI on macOS: (1) plist override (the BetterDisplay approach, requires admin + reconnect) (2) CGVirtualDisplay pure virtual display (not mirrored with a physical screen). ❌ Never use CGConfigureDisplayMirrorOfDisplay.

### ~~B-002: CGVirtualDisplay is a private API with no public headers~~
- **Solution**: The user approved the use of private APIs. Created FreeDisplay-Bridging-Header.h declaring the CGVirtualDisplay + IOAVService interfaces; VirtualDisplayService now implements full virtual display creation/destruction.
- **Resolved on**: 2026-03-03

### ~~B-003: DDC brightness control does not work on some external displays~~
- **Solution**: Root cause confirmed: the IOFramebuffer I2C API that DDCService uses does not work at all on Apple Silicon. Added an IOAVService ARM64 DDC path (locating external displays via DCPAVServiceProxy), plus a CGSetDisplayTransferByTable gamma table software brightness fallback.
- **Resolved on**: 2026-03-03

### ~~B-001: DisplayInfo.name only shows "Display N" instead of the real display name~~
- **Solution**: Use `IOServiceMatching("IODisplayConnect")` + `IODisplayCreateInfoDictionary` to enumerate all IODisplayConnect services, match on DisplayVendorID + DisplayProductID, and take the product name for the first locale from the DisplayProductName dictionary; built-in displays simply return "Built-in Display"
- **Resolved on**: 2026-03-02
- **Lesson**: Integer values in IOKit CF dictionaries may be Int rather than UInt32, so both types must be attempted

### ~~B-000: Missing GENERATE_INFOPLIST_FILE causes build failure~~
- **Solution**: Add `GENERATE_INFOPLIST_FILE: YES` to the project.yml settings
- **Resolved on**: 2026-03-02
- **Lesson**: xcodegen does not generate Info.plist automatically; it must be enabled explicitly

### ~~B-000b: DDCService static singleton fails Swift 6 concurrency checks~~
- **Solution**: Mark the class `@unchecked Sendable` and set `SWIFT_STRICT_CONCURRENCY: minimal` in project.yml
- **Resolved on**: 2026-03-02
- **Lesson**: Under Swift 6 strict concurrency checking, singletons must be explicitly marked Sendable
