# File Tree — FreeDisplay (Annotated)

> Complete annotated directory structure. See [CLAUDE.md](CLAUDE.md) for the quick reference and [relationships.md](relationships.md) for module relationships.

---

```
FreeDisplay/
├── docs/                           # Project documentation directory
│   ├── roadmap/                    # Phase planning docs (produced by the planner; do not edit the structure by hand)
│   │   ├── CLAUDE.md               # roadmap overview and description of the current phase
│   │   ├── phase-0.md              # Phase 0: base scaffolding
│   │   ├── phase-1.md              # Phase 1: display enumeration + menu bar entry point
│   │   ├── phase-2.md              # Phase 2: DDC brightness/contrast control
│   │   ├── phase-3.md              # Phase 3: resolution switching
│   │   ├── phase-4.md              # Phase 4: rotation + arrangement
│   │   ├── phase-5.md              # Phase 5: color management (ICC Profile)
│   │   ├── phase-6.md              # Phase 6: image adjustment (Gamma/software filters)
│   │   ├── phase-7.md              # Phase 7: advanced display management
│   │   ├── phase-8.md              # Phase 8: screen mirroring
│   │   ├── phase-9.md              # Phase 9: screen streaming + picture-in-picture
│   │   ├── phase-10.md             # Phase 10: virtual displays
│   │   ├── phase-11.md             # Phase 11: auto brightness + config protection
│   │   ├── phase-12.md             # Phase 12: system color picker + video filters + settings
│   │   ├── phase-13.md             # Phase 13: critical bug fixes
│   │   ├── phase-14.md             # Phase 14: performance optimization
│   │   ├── phase-15.md             # Phase 15: other enhancements
│   │   ├── phase-16.md             # Phase 16: HiDPI virtual displays + presets
│   │   └── phase-17.md             # Phase 17: UI/UX polish
│   ├── codemap/                    # Code navigation map (this directory)
│   │   ├── CLAUDE.md               # Quick reference index (module summary, high-risk files, task table)
│   │   ├── file-tree.md            # Complete annotated directory structure (this file)
│   │   └── relationships.md        # Module relationship diagram + services internal dependencies + data flow
│   ├── BLOCKING.md                 # Blocking issue tracking (read before starting work)
│   ├── habits.md                   # Record of development preferences and working habits
│   ├── lessons.md                  # Pitfalls and lessons learned
│   └── ROADMAP.md                  # Overall progress tracking (autopilot relies on this to track [x] marks)
├── FreeDisplay/                    # Swift source directory (xcodegen includes every .swift automatically)
│   ├── App/                        # App entry point, SwiftUI App lifecycle
│   │   ├── AppDelegate.swift       # NSApplicationDelegate, ensures the app shows only in the menu bar; changes affect the App lifecycle hooks
│   │   └── FreeDisplayApp.swift    # @main entry point, creates DisplayManager and mounts MenuBarView; changes affect the entire App initialization chain
│   ├── Models/                     # Data model layer (pure data, no side effects)
│   │   ├── DisplayInfo.swift       # ⚠️ Core display model, 12+ @Published properties; every View/Service depends on this class, so adding or removing a property requires a global grep to stay in sync
│   │   ├── DisplayMode.swift       # Value type for a single display mode (resolution + refresh rate + HiDPI flag); changes to the enumeration logic affect resolution switching and the mode list display
│   │   └── DisplayPreset.swift     # Display configuration preset models: DisplayPreset (the preset) + DisplayPresetEntry (a single-display snapshot); Codable, persisted by PresetService
│   ├── Services/                   # Business logic layer, interacts directly with system frameworks
│   │   ├── ArrangementService.swift        # Reads/writes display positions via CGDisplayConfiguration, supports setting the main display; setPosition/setAsMainDisplay are now async, with the CG transaction running inside CGHelpers.runWithTimeout; changes affect drag arrangement and main display switching
│   │   ├── AutoBrightnessService.swift     # Reads the IOKit AppleLMUController ambient light sensor, polls on a timer and maps lux→brightness; changes affect auto brightness accuracy and battery drain
│   │   ├── BrightnessService.swift         # Unified brightness interface: IODisplayGetFloatParameter for the built-in display, DDC VCP 0x10 for external displays; changes affect every brightness read/write path
│   │   ├── CGHelpers.swift                 # Shared helper for blocking CG calls: CGHelpers.runWithTimeout(seconds:fallback:operation:) runs blocking WindowServer IPC operations on a background thread with timeout protection; used by ArrangementService, MirrorService, ResolutionService, and VirtualDisplayService
│   │   ├── ColorProfileService.swift       # ICC Profile enumeration (scans 3 system directories) and switching (ColorSync API); changes affect the color profile list and switching
│   │   ├── DDCService.swift                # ⚠️ Core of IOKit I2C DDC/CI communication: IOFramebuffer lookup, VCP read/write, 5-second TTL cache, 3 retries; the low-level dependency of almost every external display feature, so change it with extreme care
│   │   ├── DisplayManager.swift            # ⚠️ Display enumeration (CGGetOnlineDisplayList) + CGDisplay hot-plug callback + arrangeExternalAboveBuiltin() automatic external display positioning; @Published displays is injected globally, so changes affect the entire display list data flow
│   │   ├── GammaService.swift              # Software gamma adjustment: CGSetDisplayTransferByFormula/Table, supports contrast/gain/color temperature/quantization/inversion; the sole entry point for every gamma/software brightness write; changes affect image adjustment effects
│   │   ├── HiDPIService.swift              # Writes /Library/Displays/...plist to inject HiDPI scaled modes, requires administrator privileges; changes affect the HiDPI override generation logic
│   │   ├── LaunchService.swift             # Manages launch at login via SMAppService (macOS 13+); changes only affect the Launch at Login feature
│   │   ├── MirrorService.swift             # Enabling/stopping hardware-level screen mirroring via CGDisplayConfiguration; enableMirror/disableMirror are now async, with the CG transaction running inside CGHelpers.runWithTimeout; changes affect the mirroring feature
│   │   ├── NotchOverlayManager.swift       # Creates a black mask NSWindow over the notch area of the built-in display (screenSaver level); changes affect the visual result and window level of the notch mask
│   │   ├── ResolutionService.swift         # Switches display modes via CGConfigureDisplayWithDisplayMode; applyModeSync is now async, with the entire CG transaction running inside CGHelpers.runWithTimeout; resolvedTargetDisplayID() falls back to VirtualDisplayService for mirror detection; changes affect the success rate of resolution switching
│   │   ├── SettingsService.swift           # Persists global and per-display settings via UserDefaults + JSON files; when changing it, mind the key naming (the fd. prefix is mandatory) and backward compatibility
│   │   ├── UpdateService.swift             # Checks for new versions via the GitHub Releases API, with semantic version comparison; changes affect the update check logic
│   │   ├── VirtualDisplayService.swift     # Virtual display creation/destruction: CGVirtualDisplay private API (vendorID must be non-zero, e.g. 0xEEEE, and creation must be on the main thread), HiDPI via mirror mode, CGHelpers.runWithTimeout timeout protection, hiDPILog file debug log, Sendable extensions for ObjC types; the HiDPI config only takes effect at runtime and is not persisted; changes affect virtual displays and the one-click HiDPI preset feature
│   │   └── PresetService.swift             # Preset management: save/load/apply display configuration presets; uses DisplayManagerAccessor to read the current display state; presets.json is stored in ~/Library/Application Support/FreeDisplay/
│   ├── Utilities/                  # Utility extensions
│   │   └── NSScreenExtension.swift         # NSScreen extension: look up an NSScreen by CGDirectDisplayID, get the displayID; depended on by NotchView and NotchOverlayManager
│   ├── FreeDisplay-Bridging-Header.h       # Private API declarations: CGVirtualDisplay (macOS 14+) and IOAVService (Apple Silicon DDC); property names have been verified against the Chromium source (maxPixelsWide/maxPixelsHigh, not maxPixelSize)
│   └── Views/                      # SwiftUI view layer
│       ├── ArrangementView.swift           # Multi-display drag arrangement canvas (thumbnails distinguish built-in from external) + set as main display button; depends on ArrangementService
│       ├── AutoBrightnessView.swift        # Auto brightness toggle + sensitivity slider + ambient light lux readout; depends on AutoBrightnessService
│       ├── BrightnessSliderView.swift      # Per-display brightness slider (200ms debounce) + global combined brightness control; depends on BrightnessService + DDCService
│       ├── ColorProfileView.swift          # ICC Profile list (grouped into recommended/all) and switching; depends on ColorProfileService
│       ├── DisplayDetailView.swift         # ⚠️ Per-display expansion panel, the container for the collapsible Sections (three groups); adding or removing a Section requires changing this file and keeping MenuBarView in sync
│       ├── DisplayModeListView.swift       # Resolution mode list (grouped into HiDPI/native/other), star to pin favorites to the top, click to switch; depends on ResolutionService
│       ├── ImageAdjustmentView.swift       # 11 image adjustment sliders (contrast/Gamma/gain/color temperature/individual channels/quantization/inversion); depends on GammaService
│       ├── MainDisplayView.swift           # The "Set as main display" row; shows a status label when it already is the main display; depends on ArrangementService
│       ├── MenuBarView.swift               # ⚠️ Main menu bar view: display list + expand/collapse + tools area + settings area + PresetListView; the entry container for every feature, so changes affect the global layout
│       ├── NotchView.swift                 # Notch information display + mask toggle (shown only for a built-in display that has a notch); depends on NotchOverlayManager
│       ├── ResolutionSliderView.swift      # Horizontal drag slider for resolution (applied on release); depends on ResolutionService, reads DisplayInfo.availableModes
│       ├── SystemColorView.swift           # System color picker (NSColorSampler) + HEX/RGB/HSB display + history; depends on SettingsService to persist the color history
│       ├── HiDPIView.swift                 # HiDPI Override status row (plist approach) + write/restore buttons; depends on HiDPIService
│       ├── VirtualDisplayView.swift        # Virtual display config list + creation form (preset resolutions) + one-click HiDPI preset; depends on VirtualDisplayService
│       └── SavePresetView.swift            # Saves the current display state as a preset; inline form (name + icon picker); calls PresetService.captureCurrentState + addPreset
├── FreeDisplay.xcodeproj/          # Xcode project file (generated by xcodegen; do not edit by hand)
├── .gitignore                      # Git ignore rules
├── build.sh                        # Quick build script
├── CLAUDE.md                       # Claude context entry point (project rules, decision conventions)
└── project.yml                     # xcodegen configuration; after changing it you must rerun xcodegen generate
```
