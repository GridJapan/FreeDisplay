# Phase 21: Feature trimming — remove unused features

> Status: Done | Estimate: medium complexity

## Goal

Remove the features that aren't useful (rotation, streaming/PiP, color mode invert, mirroring UI), slim down the codebase, and reduce the maintenance burden.

## Tasks

### Task 1: Remove the rotation feature
- [x] Delete `Services/RotationService.swift`
- [x] Delete `Views/RotationView.swift`
- [x] `DisplayDetailView.swift`: remove the `showRotation` state, the rotation DetailRow, the RotationView embed, and loadExpanded/saveExpanded("rotation")
- [x] `DisplayInfo.swift`: remove the `rotation: Double` property (grep to confirm no other references)
- [x] `ConfigProtectionService.swift`: remove the `RotationService.shared.setRotation` calls (about 2 of them), the `ProtectedItems.rotation` field, and the `DisplayConfig.rotation` field
- [x] `ConfigProtectionView.swift`: remove the rotation protection toggle

**Implementation notes**: first grep `RotationService\|RotationView\|\.rotation` to find all references, then clean them up one by one.

### Task 2: Remove streaming + PiP + video filters
- [x] Delete `Services/ScreenCaptureService.swift`
- [x] Delete `ViewModels/StreamViewModel.swift`
- [x] Delete `Views/StreamControlView.swift`
- [x] Delete `Views/StreamWindow.swift`
- [x] Delete `Views/PiPControlView.swift`
- [x] Delete `Views/PiPWindow.swift`
- [x] Delete `Views/VideoFilterWindow.swift`
- [x] `DisplayDetailView.swift`: remove the `showStream` and `showPiP` state + the corresponding DetailRows + embeds
- [x] `MenuBarView.swift`: remove VideoFilterMenuEntry and SystemColorMenuEntry (if present)

**Implementation notes**: these 7 files are islands; after deleting them, grep `ScreenCaptureService\|StreamViewModel\|StreamControlView\|PiPControlView\|PiPWindow\|VideoFilter` to confirm no references are left.

### Task 3: Remove color modes (invert/grayscale) and the mirroring UI
- [x] Delete `Views/ColorModeView.swift`
- [x] Delete `Views/MirrorView.swift` (keep `Services/MirrorService.swift`, which HiDPI depends on)
- [x] `DisplayDetailView.swift`: remove the `showColorMode` and `showMirror` state + the corresponding DetailRows + embeds
- [x] `DisplayDetailView.swift`: clean up the `colorModeDesc`-related state (keep `colorSpaceName`, which ColorProfile needs)

**Implementation notes**: MirrorService.swift must not be deleted! VirtualDisplayService's HiDPI feature depends on MirrorService.enableMirror/disableMirror.

### Task 4: Build verification + cleanup
- [x] `xcodegen generate && xcodebuild -scheme FreeDisplay -configuration Debug build`
- [x] Update `docs/CODEMAP.md`: remove the entries for the deleted files
- [x] Update `README.md`: remove the deleted features from the feature list
- [x] Update `CHANGELOG.md`: add a v1.1.0 entry recording the feature trimming

## Acceptance criteria

```bash
# Builds successfully
xcodebuild -scheme FreeDisplay -configuration Debug build 2>&1 | tail -3

# Confirm the files are deleted
ls FreeDisplay/Services/RotationService.swift 2>&1  # should not exist
ls FreeDisplay/Views/RotationView.swift 2>&1         # should not exist
ls FreeDisplay/Views/StreamControlView.swift 2>&1    # should not exist

# Confirm no references are left
grep -r "RotationService\|RotationView\|StreamControlView\|PiPControlView\|ColorModeView\|MirrorView" FreeDisplay/ --include="*.swift" | grep -v "^Binary"
# should return nothing
```
