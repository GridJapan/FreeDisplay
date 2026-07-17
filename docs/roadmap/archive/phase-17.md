# Phase 17: Targeted Core Feature Fixes — DDC / HiDPI / Notch

> Goal: fix three technical issues affecting the core experience: DDC brightness control unavailable on Apple Silicon, HiDPI virtual display creation failing for external 2K displays, and the notch overlay NSWindow crash

## Preliminary Notes

This phase involves a private API bridging header and rewrites of two low-level services; the tasks have an ordering dependency:
**Task 1 (bridging header) must precede Tasks 2 and 3**; Task 4 (notch crash) is independent and can start in parallel with Task 1; Task 5 (integration testing) comes last.

---

## Task List

- [x] **Task 1**: Create the Objective-C bridging header (shared prerequisite for the DDC + virtual display private APIs)
  - Implementation notes:
    1. Create `FreeDisplay/FreeDisplay-Bridging-Header.h` in the project root, declaring the following:

       ```objc
       // ── CGVirtualDisplay private classes (macOS 14+ virtual displays) ────────
       #import <Foundation/Foundation.h>
       #import <CoreGraphics/CoreGraphics.h>

       @interface CGVirtualDisplayDescriptor : NSObject
       @property (nonatomic) uint32_t sizeInMillimeters;   // Diagonal size (millimeters)
       @property (nonatomic) CGSize   maxPixelSize;        // Maximum pixel resolution
       @property (nonatomic) CGColorSpaceRef colorSpace;
       @property (nonatomic) NSPoint  whitePoint;
       @property (nonatomic) NSPoint  redPrimary;
       @property (nonatomic) NSPoint  greenPrimary;
       @property (nonatomic) NSPoint  bluePrimary;
       @end

       @interface CGVirtualDisplaySettings : NSObject
       @property (nonatomic) BOOL hiDPI;
       - (void)addMode:(CGSize)size refreshRate:(double)hz;
       @end

       @interface CGVirtualDisplayMode : NSObject
       @property (nonatomic, readonly) CGSize  size;
       @property (nonatomic, readonly) double  refreshRate;
       @property (nonatomic, readonly) BOOL    hiDPI;
       @end

       @interface CGVirtualDisplay : NSObject
       - (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
       - (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
       @property (nonatomic, readonly) CGDirectDisplayID displayID;
       @end

       // ── CGSDisplayMode (advanced resolution switching) ───────────────────────
       typedef struct {
           uint32_t modeID;
           uint32_t width;
           uint32_t height;
           uint32_t depth;
           double   refreshRate;
           uint32_t flags;        // bit 0x20000 = HiDPI
       } CGSDisplayMode;

       extern CGError CGSConfigureDisplayMode(CGSConnectionID connection, CGDirectDisplayID display, uint32_t modeID);
       extern CGSConnectionID CGSMainConnectionID(void);

       // ── CoreDisplay (optional, for future reference) ─────────────────────────
       // extern CFDictionaryRef CoreDisplay_DisplayCreateInfoDictionary(CGDirectDisplayID display);

       // ── IOAVService (Apple Silicon DDC) ──────────────────────────────────────
       typedef void * IOAVServiceRef;
       extern IOAVServiceRef IOAVServiceCreate(CFAllocatorRef allocator);
       extern IOAVServiceRef IOAVServiceCreateWithService(CFAllocatorRef allocator, io_service_t service);
       extern IOReturn IOAVServiceReadI2C(IOAVServiceRef service,
                                          uint32_t chipAddress,
                                          uint32_t offset,
                                          void *outputBuffer,
                                          uint32_t outputBufferSize);
       extern IOReturn IOAVServiceWriteI2C(IOAVServiceRef service,
                                           uint32_t chipAddress,
                                           uint32_t dataAddress,
                                           void *inputBuffer,
                                           uint32_t inputBufferSize);
       ```

    2. Open `project.yml` and add the following under `targets.FreeDisplay.settings.base`:
       ```yaml
       SWIFT_OBJC_BRIDGING_HEADER: FreeDisplay/FreeDisplay-Bridging-Header.h
       ```
    3. Run `cd ~/Desktop/FreeDisplay && xcodegen generate`
    4. Run the verification chain to confirm it compiles (an unused bridging header should not cause errors either)
  - Verification: `xcodebuild -scheme FreeDisplay -configuration Debug build 2>&1 | tail -5` shows `BUILD SUCCEEDED`

---

- [x] **Task 2**: Rewrite DDCService to support Apple Silicon (IOAVService path)
  - Background: the existing `IOFBCopyI2CInterfaceForBus` + `IOI2CSendRequest` are Intel-era APIs and do not work at all on Apple Silicon. An ARM64 path needs to be added, keeping the Intel path as a fallback (for Hackintosh/VM users).
  - Implementation notes:
    1. **Add the ARM64 DDC write method** (`DDCService.swift`):
       ```swift
       // At the top of DDCService, the ARM64-specific path
       #if arch(arm64)
       private func findAVService(for displayID: CGDirectDisplayID) -> IOAVServiceRef? {
           // 1. Get the display's corresponding IOService via CGDisplayIOServicePort
           let port = CGDisplayIOServicePort(displayID)
           guard port != IO_OBJECT_NULL else { return nil }

           // 2. Walk up the IORegistry parent nodes to find DCPAVServiceProxy
           var iterator: io_iterator_t = 0
           let matchDict = IOServiceMatching("DCPAVServiceProxy")
           IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator)
           defer { IOObjectRelease(iterator) }

           var service = IOIteratorNext(iterator)
           while service != IO_OBJECT_NULL {
               defer { IOObjectRelease(service); service = IOIteratorNext(iterator) }
               let avService = IOAVServiceCreateWithService(kCFAllocatorDefault, service)
               // Use a harmless read test to confirm whether this is the right AVService
               var testBuf = [UInt8](repeating: 0, count: 12)
               let ret = IOAVServiceReadI2C(avService, 0x37, 0x51, &testBuf, 12)
               if ret == kIOReturnSuccess { return avService }
           }
           return nil
       }

       /// ARM64 DDC write: write a VCP value to an external display (e.g. brightness VCP=0x10)
       private func arm64Write(displayID: CGDirectDisplayID, command: UInt8, value: UInt16) -> Bool {
           guard let avService = findAVService(for: displayID) else { return false }
           // DDC/CI write packet format (note: dataAddress=0x51 is passed as a parameter, not put in the buffer)
           // buffer: [0x84, 0x03, vcpCode, valueHigh, valueLow, checksum]
           let valueHigh = UInt8((value >> 8) & 0xFF)
           let valueLow  = UInt8(value & 0xFF)
           var checksum  = UInt8(0x50 ^ 0x03 ^ command ^ valueHigh ^ valueLow)
           // 0x50 = 0x51 XOR'd with 0x01 (reply flag) — see the DDC/CI spec
           var buf: [UInt8] = [0x84, 0x03, command, valueHigh, valueLow, checksum]
           let ret = IOAVServiceWriteI2C(avService, 0x37, 0x51, &buf, UInt32(buf.count))
           return ret == kIOReturnSuccess
       }

       /// ARM64 DDC read: read the current VCP value
       private func arm64Read(displayID: CGDirectDisplayID, command: UInt8) -> (current: UInt16, max: UInt16)? {
           guard let avService = findAVService(for: displayID) else { return nil }
           // First send the VCP request packet (similar to write, opcode=0x01)
           var requestChecksum = UInt8(0x51 ^ 0x82 ^ 0x01 ^ command)
           var requestBuf: [UInt8] = [0x82, 0x01, command, requestChecksum]
           IOAVServiceWriteI2C(avService, 0x37, 0x51, &requestBuf, UInt32(requestBuf.count))
           // Wait for DDC to process it
           Thread.sleep(forTimeInterval: 0.04)
           // Read the response
           var replyBuf = [UInt8](repeating: 0, count: 12)
           let ret = IOAVServiceReadI2C(avService, 0x37, 0x51, &replyBuf, 12)
           guard ret == kIOReturnSuccess else { return nil }
           // replyBuf format: [len, 0x02, vcpCode, 0x00, maxHigh, maxLow, curHigh, curLow, ...]
           let maxVal  = UInt16(replyBuf[4]) << 8 | UInt16(replyBuf[5])
           let curVal  = UInt16(replyBuf[6]) << 8 | UInt16(replyBuf[7])
           return (curVal, maxVal)
       }
       #endif
       ```

    2. **Modify the dispatch logic in `write(displayID:command:value:)`**:
       ```swift
       func write(displayID: CGDirectDisplayID, command: UInt8, value: UInt16) -> Bool {
           #if arch(arm64)
           if arm64Write(displayID: displayID, command: command, value: value) {
               return true
           }
           // Optionally fall back to the software path when arm64 fails
           return false
           #else
           return intelWrite(displayID: displayID, command: command, value: value)
           #endif
       }
       ```
       Rename the existing Intel path methods to `intelWrite` / `intelRead` (the function signatures stay the same, only the names change).

    3. **Add software brightness fallback in `BrightnessService.swift`**:
       - Add a cache: `var isDDCAvailable: [CGDirectDisplayID: Bool] = [:]`
       - In `setBrightness(for:value:)`: first try the DDC write; if it fails and the display is external, call `applyGammaFallback(displayID:brightness:)` to simulate brightness using `CGSetDisplayTransferByTable`
       - `applyGammaFallback` implementation: build a linear ramp from 0 to `brightness` (0.0-1.0) and write it into the gamma table; visually equivalent to lowering brightness (the black level stays put, the white level drops)
       - After recording `isDDCAvailable[displayID] = false`, go straight to the software path and stop trying DDC

    4. **Add a mode indicator in `BrightnessSliderView.swift`** (optional but recommended):
       - Add a small label next to the slider title: "DDC" (blue) when DDC is available, "Software" (gray) in software mode
       - Implementation: read the state from `BrightnessService.shared.isDDCAvailable[display.id]`

  - File: `FreeDisplay/Services/DDCService.swift` (add the `#if arch(arm64)` block, rename the existing Intel code)
  - File: `FreeDisplay/Services/BrightnessService.swift` (add the software fallback logic)
  - File: `FreeDisplay/Views/BrightnessSliderView.swift` (optional: mode indicator label)
  - References: MonitorControl `Arm64DDC.swift`, the `m1ddc` project, alinpanaitiu.com/blog/journey-to-ddc-on-m1-macs/
  - Verification: drag the brightness slider for an external display → the display's brightness actually changes (DDC succeeded); for a display without DDC support → it automatically falls back to software dimming, the slider still works, and the label shows "Software"

---

- [x] **Task 3**: Implement real virtual display creation (CGVirtualDisplay API)
  - Background: `VirtualDisplayService.swift`'s `create(config:)` and `destroy(id:)` are currently placeholders returning `false`, making the HiDPI virtual display feature completely unusable. The implementation needs to use the `CGVirtualDisplay` private class exposed by the bridging header.
  - Implementation notes:
    1. **Implement `create(config:)` in `VirtualDisplayService.swift`**:
       ```swift
       // Hold a strong reference; releasing it = the virtual display disappears
       private var activeDisplayObjects: [CGDirectDisplayID: CGVirtualDisplay] = [:]

       func create(config: VirtualDisplayConfig) -> CGDirectDisplayID? {
           let descriptor = CGVirtualDisplayDescriptor()
           descriptor.sizeInMillimeters = 527  // A 24-inch diagonal is about 527mm (can be adjusted per config)
           descriptor.maxPixelSize = CGSize(width: CGFloat(config.width), height: CGFloat(config.height))
           descriptor.colorSpace   = CGColorSpace(name: CGColorSpace.sRGB)!
           // sRGB gamut reference values
           descriptor.whitePoint   = NSPoint(x: 0.3127, y: 0.3290)
           descriptor.redPrimary   = NSPoint(x: 0.6400, y: 0.3300)
           descriptor.greenPrimary = NSPoint(x: 0.3000, y: 0.6000)
           descriptor.bluePrimary  = NSPoint(x: 0.1500, y: 0.0600)

           let settings = CGVirtualDisplaySettings()
           settings.hiDPI = config.hiDPI
           // Add the main mode (actual pixel dimensions)
           settings.addMode(CGSize(width: CGFloat(config.width), height: CGFloat(config.height)),
                            refreshRate: Double(config.refreshRate))
           // If hiDPI, also add the logical resolution mode (half the physical)
           if config.hiDPI {
               settings.addMode(CGSize(width: CGFloat(config.width / 2),
                                       height: CGFloat(config.height / 2)),
                                refreshRate: Double(config.refreshRate))
           }

           let virtualDisplay = CGVirtualDisplay(descriptor: descriptor)
           guard virtualDisplay.applySettings(settings) else { return nil }
           let displayID = virtualDisplay.displayID
           guard displayID != kCGNullDirectDisplay else { return nil }
           activeDisplayObjects[displayID] = virtualDisplay  // Keep a strong reference
           return displayID
       }

       func destroy(id: CGDirectDisplayID) {
           activeDisplayObjects.removeValue(forKey: id)  // Release → the virtual display disappears
       }
       ```

    2. **Implement `enableHiDPIVirtual(for:physicalWidth:physicalHeight:)`**:
       ```swift
       /// Create a 2x virtual display for a physical external display and mirror to it, achieving HiDPI scaling
       func enableHiDPIVirtual(for displayID: CGDirectDisplayID,
                                physicalWidth: Int,
                                physicalHeight: Int) -> CGDirectDisplayID? {
           let config = VirtualDisplayConfig(
               name: "HiDPI Virtual",
               width: physicalWidth * 2,   // 2x the physical resolution, e.g. 2K→4K
               height: physicalHeight * 2,
               refreshRate: 60,
               hiDPI: true
           )
           guard let virtualID = create(config: config) else { return nil }
           // Mirror the physical display to the virtual display (physical as mirror source, virtual as mirror target)
           MirrorService.shared.startMirror(source: displayID, target: virtualID)
           return virtualID
       }
       ```

    3. **Implement `disableHiDPIVirtual(for:)`**:
       ```swift
       func disableHiDPIVirtual(for physicalDisplayID: CGDirectDisplayID) {
           // Find the virtual display associated with this physical display
           guard let virtualID = hiDPIVirtualMap[physicalDisplayID] else { return }
           MirrorService.shared.stopMirror(for: virtualID)
           destroy(id: virtualID)
           hiDPIVirtualMap.removeValue(forKey: physicalDisplayID)
       }
       // Needs to be added to VirtualDisplayService: private var hiDPIVirtualMap: [CGDirectDisplayID: CGDirectDisplayID] = [:]
       // After enableHiDPIVirtual returns virtualID, record: hiDPIVirtualMap[displayID] = virtualID
       ```

    4. **Update `HiDPIService.swift`**:
       - `enableHiDPI(for:)` should first try the virtual display path (`VirtualDisplayService.shared.enableHiDPIVirtual`)
       - If that fails (e.g. insufficient permissions), fall back to the plist override path
       - Distinguish the two paths in the UI: the virtual display path takes effect immediately, the plist path requires reconnecting the display

  - File: `FreeDisplay/Services/VirtualDisplayService.swift` (main implementation, replacing the placeholder false)
  - File: `FreeDisplay/Services/HiDPIService.swift` (switching the primary/fallback paths)
  - Note: the `CGVirtualDisplay` object must be kept strongly referenced (stored in the `activeDisplayObjects` dictionary); once ARC releases it, the virtual display disappears immediately
  - Note: `CGVirtualDisplayDescriptor.colorSpace` is a `CGColorSpaceRef` (Core Foundation); in Swift, create it with `CGColorSpace(name:)` and assign it directly — no manual retain needed
  - References: the BetterDummy project's bridging header, the KhaosT/CGVirtualDisplay example
  - Verification: turn on the HiDPI switch → a new "HiDPI Virtual" display appears in the system display list → scaled modes such as `1920×1080 (HiDPI)` appear in the resolution list → turn the switch off → the virtual display disappears

---

- [x] **Task 4**: Fix the notch overlay window crash (NSWindow lifecycle)
  - Background: the `NSWindow` created by `NotchOverlayManager` lacks `isReleasedWhenClosed = false`, so Swift holds a dangling pointer on close; `@State isHidingNotch` is out of sync with the manager's state; the new window is created before the old one is closed, causing ordering problems; `onChange` uses the deprecated single-parameter form.
  - Implementation notes:
    1. **`NotchOverlayManager.swift`** — window creation fix:
       ```swift
       // In the showOverlay(for:) method, add this immediately after window initialization:
       window.isReleasedWhenClosed = false  // ← Key: prevents a dangling pointer after close()
       ```

    2. **`NotchOverlayManager.swift`** — close ordering fix:
       ```swift
       func showOverlay(for screen: NSScreen) {
           // Close the old window first, then create the new one
           if let existing = overlayWindows[screen.displayID] {
               existing.close()
               overlayWindows.removeValue(forKey: screen.displayID)
           }
           // ... then create the new window
       }
       ```

    3. **`NotchOverlayManager.swift`** — add a query method:
       ```swift
       public func isShowingOverlay(for screen: NSScreen) -> Bool {
           return overlayWindows[screen.displayID] != nil
       }
       ```

    4. **`NotchView.swift`** — state sync fix:
       ```swift
       // Sync the initial state from the manager in body or .onAppear:
       .onAppear {
           isHidingNotch = NotchOverlayManager.shared.isShowingOverlay(for: screen)
       }
       ```

    5. **`NotchView.swift`** — deprecated onChange API fix:
       ```swift
       // Old (deprecated single-parameter form):
       // .onChange(of: isHidingNotch) { newValue in ... }
       // Change to the two-parameter form:
       .onChange(of: isHidingNotch) { _, newValue in
           // The handling logic is unchanged
       }
       ```

  - File: `FreeDisplay/Services/NotchOverlayManager.swift`
  - File: `FreeDisplay/Views/NotchView.swift` (if it exists; otherwise modify the View file containing the notch Toggle)
  - Verification: toggle the notch switch ON/OFF ten times → no crash; close the menu and reopen it → the notch switch state matches the actual overlay state; no EXC_BAD_ACCESS or objc over-release logs in Console.app

---

- [x] **Task 5**: Integration testing and UI updates
  - Implementation notes:
    1. **DDC verification**: connect the external HKC H2435Q → open FreeDisplay → drag the brightness slider → observe whether the display's physical brightness changes (judge by eye, or check whether IntegratedControlView's DDC read value echoes back)
    2. **HiDPI verification**: connect an external 2K display → turn on the HiDPI switch → check whether a new virtual display appears in System Preferences "Displays" → check whether `1920×1080 (Retina)` appears in the resolution list → select that resolution → check whether text is noticeably sharper
    3. **Notch verification**: built-in MacBook screen → notch switch ON → the overlay appears → OFF → the overlay disappears → repeat 10 times → no crash; close the menu and reopen → the state is consistent
    4. **Update `DisplayDetailView.swift` / `MenuBarView.swift`** (as needed):
       - If DDC falls back to software, show a software mode notice in the brightness control area
       - If the HiDPI virtual display is active, show a "HiDPI enabled (virtual display)" status
    5. **Update `docs/BLOCKING.md`**:
       - Mark B-002 (DDC unavailable on Apple Silicon) as resolved and move it to the "Resolved" section
       - Mark B-003 (HiDPI virtual display creation fails) as resolved and move it to the "Resolved" section
  - File: `FreeDisplay/Views/DisplayDetailView.swift` (minor changes as needed)
  - File: `FreeDisplay/Views/MenuBarView.swift` (minor changes as needed)
  - File: `docs/BLOCKING.md` (move the resolved items)
  - Verification: see the three manual tests above; compiles with no warnings and no errors

---

## Phase Acceptance

```bash
# 1. Compile check
cd ~/Desktop/FreeDisplay && xcodebuild -scheme FreeDisplay -configuration Debug build 2>&1 | tail -5

# 2. Manual test checklist:
# [ ] DDC: external display brightness slider → screen brightness actually changes (or the software mode label displays correctly)
# [ ] HiDPI: HiDPI switch ON → the virtual display appears → 1920x1080@2x is selectable → OFF → the virtual display disappears
# [ ] Notch: notch switch ON/OFF × 10 → no crash → the state matches the overlay
# [ ] Menu reopen: all the switch states above remain correct after closing and reopening the menu
```

**Phase acceptance criteria**: compiles successfully + all four manual tests above are satisfied
