# Phase 19: Display preset system

> Status: Done | Estimate: medium complexity

## Goal

Extend one-click HiDPI into a general display preset system, letting the user save the current display state as a preset and switch between configurations with one click.

## Tasks

### Task 1: Preset data model
- [x] Create `Models/DisplayPreset.swift`, defining the preset struct:
  - `id: UUID`, `name: String`, `icon: String` (SF Symbol name)
  - `displays: [DisplayPresetEntry]`, where each entry contains:
    - `displayUUID: String` (matches the physical display)
    - `width: Int`, `height: Int`, `isHiDPI: Bool` (target resolution)
    - `brightness: Double?` (optional brightness)
    - `arrangement: CGPoint?` (optional arrangement position)
    - `enableHiDPIVirtual: Bool` (whether to enable the HiDPI virtual display)
- [x] Create `Services/PresetService.swift`: load/save/apply presets
- [x] Store presets in `~/Library/Application Support/FreeDisplay/presets.json`

**Implementation notes**: match displays with `display.displayUUID` (stable UUID generation logic already exists). When applying a preset, skip any entry whose display is not online.

### Task 2: Built-in default presets
- [x] "HiDPI mode": reuse the current HiDPIPresetRow logic (enableHiDPIVirtual + 1920×1080 + arrangement)
- [x] "Native mode": disable HiDPI virtual + restore the display's native resolution + arrangement
- [x] Built-in presets cannot be deleted; mark them `isBuiltin: true`

**Implementation notes**: migrate HiDPIPresetRow's turnOn/turnOff logic into PresetService.applyPreset(), and change HiDPIPresetRow to call PresetService.

### Task 3: Save current state as a preset
- [x] Add a "Save as preset" button to the menu bar (below the preset list)
- [x] Clicking it opens an inline form: enter a name, pick an icon
- [x] Automatically capture the resolution, HiDPI state, brightness, and arrangement position of all current displays
- [x] Save to presets.json

**Implementation notes**: refer to the inline form pattern in CreateVirtualDisplayForm. Use a Picker plus a few predefined SF Symbols for icon selection.

### Task 4: Preset list and one-click switching
- [x] Show the preset list in MenuBarView (replace the HiDPIPresetRow slot with a preset section)
- [x] Each preset shows: icon + name + whether it currently matches (a green "Current" badge)
- [x] Click a preset → apply (show a loading spinner)
- [x] Long press/right click → delete (non-built-in presets)

**Implementation notes**: preset match detection: iterate over each DisplayPresetEntry and check whether the current resolution and HiDPI state agree. Mark it "Current" if they all agree.

## Acceptance criteria

```bash
# Builds successfully
xcodebuild -scheme FreeDisplay -configuration Debug build 2>&1 | tail -3

# Manual testing
# 1. Enable HiDPI → save as preset "Work mode" → disable HiDPI → click "Work mode" → HiDPI is restored
# 2. Switch to 1280×720 → save as preset "Low resolution" → switch between the two presets
# 3. The built-in "HiDPI mode" and "Native mode" cannot be deleted
```
