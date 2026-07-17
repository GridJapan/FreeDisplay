# AGENTS.md — FreeDisplay Project Harness Configuration

> This file defines the harness rules for AI agents working on this project.
> AI agents MUST read this file before making any changes.
> For deeper context, read CLAUDE.md first.

## Project Overview

- **Name**: FreeDisplay
- **Language**: Swift 6.0 (concurrency checking set to minimal)
- **Framework**: SwiftUI (MenuBarExtra) + AppKit
- **Package Manager**: none (zero third-party dependencies, system frameworks only)
- **Build Tool**: XcodeGen (`project.yml`) + xcodebuild
- **Minimum OS**: macOS 14.0
- **Architecture**: MVVM — View → ViewModel → Service

## Architecture Rules

### Layer Separation

```
Views/          → UI presentation; only read from the ViewModel, or read a Service directly (simple cases)
ViewModels/     → State management; bridges View and Service
Services/       → Business logic; interacts with system frameworks (IOKit/CoreGraphics/DDC)
Models/         → Pure data structures (DisplayInfo, DisplayMode, DisplayPreset)
```

- The View layer is FORBIDDEN from calling CoreGraphics / IOKit / the CGSet* family of APIs directly
- Writing the gamma table MUST go through GammaService; bypassing it is not allowed
- BrightnessService (software brightness) writes through GammaService; it does not call CGSetDisplayTransferByTable directly

### Module Boundaries

| Directory | Responsibility |
|------|------|
| `FreeDisplay/Services/` | All system-level operations (DDC, brightness, resolution, HiDPI, arrangement, etc.) |
| `FreeDisplay/Views/` | SwiftUI views; filename format: `XxxView.swift` or `XxxRow.swift` |
| `FreeDisplay/ViewModels/` | State management; 1:1 with a View or shared across Views |
| `FreeDisplay/Models/` | Data structures, no side effects |
| `FreeDisplay/Utilities/` | General-purpose utility functions |
| `FreeDisplay/Resources/` | Static resources |
| `docs/` | Project documentation (do not change the structure) |
| `scripts/` | Build and release scripts |

### Protected Files

The following files require an explicit justification before being modified:

- `FreeDisplay/FreeDisplay.entitlements` — permission declarations; changes affect code signing and the App Sandbox
- `project.yml` — XcodeGen configuration; after changing it you MUST re-run `xcodegen generate`
- `ExportOptions.plist` — release signing configuration
- `docs/roadmap/` — planning documents; only update the `[x]` progress markers, do not change the structure

## Coding Standards

### Style Guide

- Swift 6.0 syntax; backward-compatible constructs are not allowed
- Prefer SwiftUI views; use AppKit only when necessary
- Private frameworks (CoreDisplay, etc.) MUST be loaded at runtime with `dlopen` + `dlsym`; `@_silgen_name` is FORBIDDEN

### Naming Conventions

- Service classes: `XxxService.swift`; singletons use `static let shared`
- View files: `XxxView.swift`
- Reusable row components: `XxxRow` (struct, supports `@State`)
- UserDefaults keys: MUST carry the `fd.` prefix (e.g. `fd.launchAtLogin`)
- Bare keys (e.g. `"launchAtLogin"`) are FORBIDDEN

### SwiftUI Component Rules

- Row components that need local state (`isHovered`, `isLoading`) → MUST be a standalone `struct`
- Using a `@ViewBuilder` function to host a component that carries `@State` is FORBIDDEN

### Concurrency Rules

- Swift 6 concurrency error → prefer `@MainActor` or `@unchecked Sendable`
- Long-lived C callbacks (e.g. CGDisplayRegisterReconfigurationCallback) → use `Unmanaged.passRetained(self)`, and `release()` when unregistering
- `passUnretained` is FORBIDDEN (dangling pointer risk)
- Only make genuinely slow operations async (filesystem scans, network requests); microsecond-scale IOKit calls stay synchronous

## Testing Requirements

### Verification Commands

```bash
# Build check (Debug) — run after every change
cd ~/Desktop/FreeDisplay && xcodebuild -scheme FreeDisplay -configuration Debug build 2>&1 | tail -20

# Ripple-effect check (when interfaces/models have changed)
grep -r "DisplayInfo\|DisplayManager\|DDCService" FreeDisplay/ --include="*.swift" | grep -v "^Binary"

# Regenerate the xcodeproj (must be run when project.yml has changed)
cd ~/Desktop/FreeDisplay && xcodegen generate

# Release build + package the DMG
cd ~/Desktop/FreeDisplay && ./build.sh
```

### Test Coverage

- This project has no automated test suite (it is heavily hardware-dependent; testing is primarily manual)
- New DDC features MUST be verified manually on a real external display
- New HiDPI features require reconnecting the display to verify they take effect

## Git Discipline

### Branch Naming

- `feature/xxx` — new features
- `fix/xxx` — bug fixes
- `refactor/xxx` — refactoring
- `phase-N/xxx` — changes corresponding to a ROADMAP Phase

### Commit Message Format

Follow Conventional Commits:

```
feat: add automatic brightness adjustment
fix: fix the HiDPI plist write permission issue
refactor: extract GammaService to centrally manage the transfer function
```

### Co-Author Line

```
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

## Forbidden Operations

- Do NOT: call `CGSetDisplayTransferByTable` / `CGSetDisplayTransferByFormula` directly (bypassing GammaService)
- Do NOT: call `CGDisplayRestoreColorSyncSettings()` (a global reset) — use `GammaService.resetSingleDisplay(displayID)`
- Do NOT: use `CGConfigureDisplayMirrorOfDisplay` to implement HiDPI (on Apple Silicon it triggers hardware mirroring + mouse stutter)
- Do NOT: use `@_silgen_name` to reference private framework symbols (undefined symbol at link time)
- Do NOT: use `CGDisplayVendorNumber/ModelNumber` to match IOKit services (unreliable for some displays)
- Do NOT: set `DisplayProductName` in the plist (it overrides the system display name)
- Do NOT: modify the `docs/roadmap/` directory structure
- Do NOT: add third-party dependencies (project policy: zero dependencies)
- Do NOT: access low-level system framework APIs directly from the View layer

## Agent-Specific Notes

### Start-of-Work Checklist

1. Read `docs/BLOCKING.md` first; if there are P0/P1 items, resolve them first
2. Read `docs/roadmap/CLAUDE.md` to understand the current Phase
3. Read `docs/codemap/CLAUDE.md` → `docs/codemap/file-tree.md` to locate the relevant files

### Ripple-Effect Check After Changes

- Changed a `DisplayInfo` property → grep every reference and update them in sync
- Changed `project.yml` → you MUST run `xcodegen generate`
- Added a Service/View file → update `docs/codemap/file-tree.md`
- Phase task complete → mark `[x]` in both `docs/roadmap/phase-N.md` and `docs/ROADMAP.md`
- Hit a pitfall → write it up in `docs/lessons/{topic}.md` and update the index
- Sleep/wake-related changes → confirm the Service responds to `NSWorkspace.didWakeNotification`

### Situations That Require Stopping to Ask the User

- A new private API (CoreDisplay, etc.) needs to be used
- SIP must be disabled or special system permissions are required
- The architectural direction changes (MVVM changed to another pattern)

### Core Framework Quick Reference

| Framework | Purpose |
|------|------|
| CoreGraphics | Display enumeration, resolution, arrangement |
| IOKit | DDC/CI I2C communication, brightness/contrast |
| ColorSync | ICC Profile management |
| CGVirtualDisplay (private) | Virtual displays; vendorID MUST be non-zero, must be called on the main thread |
| CoreDisplay (dlsym) | Reading built-in screen brightness |

<!-- Generated by Harness Engineering system on 2026-03-12. Review and customize. -->
