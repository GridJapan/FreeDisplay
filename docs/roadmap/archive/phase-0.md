# Phase 0: Project Initialization ⏳

> Executed automatically by project-planner

## Task List

- [ ] Create the project directory structure
  ```
  FreeDisplay/
  ├── project.yml                    # xcodegen project configuration
  ├── FreeDisplay/
  │   ├── App/
  │   │   ├── FreeDisplayApp.swift   # @main entry point, MenuBarExtra
  │   │   └── AppDelegate.swift      # NSApplicationDelegate, permission requests
  │   ├── Views/                     # SwiftUI view layer
  │   ├── ViewModels/                # ViewModel layer
  │   ├── Models/                    # Data models
  │   ├── Services/                  # Low-level services (DDC, display management, etc.)
  │   ├── Utilities/                 # Utility functions
  │   ├── Resources/
  │   │   └── Assets.xcassets/       # Icon resources
  │   └── FreeDisplay.entitlements   # Entitlement declarations
  └── docs/
      └── roadmap/                   # Where this file lives
  ```
  - Implementation hint: use `mkdir -p` to create all directories

- [ ] Create `project.yml` (xcodegen configuration)
  - Implementation hint: configure a macOS app target, minimum deployment macOS 14.0, App Sandbox off,
    Hardened Runtime configured, linking IOKit.framework, CoreGraphics.framework,
    ScreenCaptureKit.framework, ColorSync.framework.
    The entitlements file points at FreeDisplay/FreeDisplay.entitlements
  - Verification: `xcodegen generate` successfully generates FreeDisplay.xcodeproj

- [ ] Create `FreeDisplay/FreeDisplay.entitlements`
  - Implementation hint: turn off App Sandbox (`com.apple.security.app-sandbox` = false),
    enable the Hardened Runtime related entitlements
  - Verification: the file exists and is valid XML

- [ ] Create `FreeDisplay/App/FreeDisplayApp.swift`
  - Implementation hint: use `@main` + the SwiftUI `App` protocol,
    `MenuBarExtra("FreeDisplay", systemImage: "display")` to create the menu bar icon,
    with a "FreeDisplay v0.1" text item + a "Quit" button in the menu for now.
    Set `.menuBarExtraStyle(.window)` to support custom views.
  - Verification: after building and running, a display icon appears in the menu bar and clicking it pops up a panel

- [ ] Create `FreeDisplay/App/AppDelegate.swift`
  - Implementation hint: `NSApplicationDelegate`, hide the Dock icon in
    `applicationDidFinishLaunching` (`NSApp.setActivationPolicy(.accessory)`)
  - Verification: after running there is no Dock icon, only the menu bar is visible

- [ ] Create `FreeDisplay/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
  - Implementation hint: use the standard macOS app icon set Contents.json template, without any actual icon files for now
  - Verification: no asset catalog warnings when xcodegen generates the project

- [ ] Create skeleton files (with TODO comments)
  - `FreeDisplay/Models/DisplayInfo.swift`: `class DisplayInfo: ObservableObject, Identifiable` stores information about a single display
  - `FreeDisplay/Services/DisplayManager.swift`: `class DisplayManager: ObservableObject` manages all displays
  - `FreeDisplay/Services/DDCService.swift`: `class DDCService` DDC/CI I2C communication
  - `FreeDisplay/Views/MenuBarView.swift`: skeleton of the main menu view
  - Each file contains imports, the class declaration, key method signatures + `// TODO: Phase N` comments

- [ ] Generate the Xcode project with xcodegen and build it
  - Implementation hint: `cd ~/Desktop/FreeDisplay && xcodegen generate && xcodebuild -scheme FreeDisplay -configuration Debug build`
  - Verification: `xcodebuild build` succeeds with no compile errors

## Phase Acceptance

```bash
cd ~/Desktop/FreeDisplay
xcodegen generate   # successfully generates the .xcodeproj
xcodebuild -scheme FreeDisplay -configuration Debug build  # build succeeds
# After running: a display icon appears in the menu bar; clicking it pops up "FreeDisplay v0.1" + a Quit button
```
