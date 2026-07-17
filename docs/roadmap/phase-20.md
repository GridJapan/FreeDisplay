# Phase 20: Release preparation

> Status: Done | Estimate: medium complexity

## Goal

Take FreeDisplay from a development state to a distributable, official macOS app, with an icon, code cleanup, a DMG installer, and a GitHub Release.

## Tasks

### Task 1: Code cleanup + app icon
- [x] Delete the deprecated `HiDPIPresetRow` from MenuBarView (superseded by PresetListView)
- [x] Search for and clean up other unused code/dead code
- [x] Generate the app icon with a Python PIL/Pillow script: rounded-rectangle display + the letter "F" + a blue-purple gradient
- [x] Generate all AppIcon.appiconset sizes (16/32/64/128/256/512/1024)
- [x] Create `FreeDisplay/Assets.xcassets/AppIcon.appiconset/Contents.json` + the PNG files
- [x] Update project.yml to reference the AppIcon asset catalog

**Implementation notes**: generate a 1024×1024 PNG with a Python script and scale to each size with `sips -z H W`. project.yml needs `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` added.

### Task 2: Launch at Login (SMAppService)
- [x] Migrate the existing implementation in `LaunchService.swift` to `SMAppService.mainApp` (macOS 13+)
- [x] `register()` / `unregister()` replace the old API; requires `import ServiceManagement`
- [x] Confirm the existing `fd.launchAtLogin` toggle in SettingsService stays in sync correctly
- [x] First-launch prompt: if `fd.launchAtLogin` has never been set, show a one-time prompt

**Implementation notes**: `SMAppService.mainApp.register()` is one line of code. Check status with `.status == .enabled`.

### Task 3: Release build + ad-hoc signing + DMG packaging
- [x] Create the `scripts/build-dmg.sh` one-shot script
- [x] Release build: `xcodebuild -scheme FreeDisplay -configuration Release build`
- [x] Ad-hoc signing: `codesign --force --deep --sign - FreeDisplay.app` (the minimum requirement when there is no Developer ID)
- [x] Package the DMG with `hdiutil`: FreeDisplay.app + Applications shortcut
- [x] Explain in the README that the first open requires right click → Open (to bypass Gatekeeper)

**Implementation notes**: `hdiutil create -volname "FreeDisplay" -srcfolder build/ -ov -format UDZO FreeDisplay.dmg`. An app without a Developer ID signature has to be trusted manually by the user.

### Task 4: README + CHANGELOG + GitHub Release script
- [x] Write README.md: project overview, feature list, install instructions, screenshot placeholders, Gatekeeper bypass instructions
- [x] Write CHANGELOG.md: collect the main changes from Phases 0-20
- [x] Create `scripts/release.sh`: build → sign → package DMG → `gh release create`
- [x] Add a download badge to the README

**Implementation notes**: screenshots have to be captured by a person running the app and using `screencapture`; use placeholders for now. `gh release create v1.0.0 --title "FreeDisplay v1.0.0" --notes-file CHANGELOG.md *.dmg`.

### Task 5: UpdateService completion
- [x] Confirm UpdateService's update check logic points at the GitHub Releases API
- [x] Use the placeholder URL `https://api.github.com/repos/OWNER/FreeDisplay/releases/latest` (to be replaced by the user at release time)
- [x] Show a download link in the menu bar when a new version is detected
- [x] Confirm the "Check for updates on launch" toggle in the settings UI works

**Implementation notes**: the GitHub Releases API returns JSON; parse `tag_name` and compare it against the current `CFBundleShortVersionString`.

## Acceptance criteria

```bash
# Release build
xcodebuild -scheme FreeDisplay -configuration Release build 2>&1 | tail -3

# DMG packaging
./scripts/build-dmg.sh

# Verification
# 1. Double-click the DMG to install → drag to Applications → launches normally
# 2. The app icon shows correctly in the Dock/Finder
# 3. The Launch at Login toggle works
# 4. README/CHANGELOG content is complete
```
