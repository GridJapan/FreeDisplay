# Roadmap — FreeDisplay

> Created: 2026-03-02 | Goal: a free macOS display management menu bar app that fully replaces BetterDisplay

## Background and motivation

BetterDisplay is the most full-featured display management tool on macOS, but it is expensive. This project aims to build a free, open source alternative with equivalent functionality, covering all the core features: DDC control, HiDPI management, screen streaming/picture-in-picture, virtual displays, and so on.

## Requirements summary

### Feature domain 1: Basic display management
- Multi-display detection and list display (built-in + external)
- Brightness slider control (DDC protocol for external, system API for built-in)
- Resolution switching (including the HiDPI mode list, native + scaled modes)
- Set as main display
- Screen rotation (90°/180°/270°)
- Arrange displays (visual drag and drop)

### Feature domain 2: Full DDC/CI control
- Read and set brightness, contrast, volume
- Input source switching
- Read and update all VCP parameters from the device

### Feature domain 3: Color and image
- Color mode switching (8-bit/10-bit, SDR/HDR, framebuffer type)
- ICC color profile switching
- Image adjustment (contrast, gamma, gain, color temperature, independent RGB channel adjustment)
- Invert colors

### Feature domain 4: Screen mirroring and streaming
- Screen mirroring (select source → target)
- Screen streaming (with flip/rotate/scale/underscan/opacity/crop/video filters)
- Picture-in-picture (floating window, with options for level, lock, click-through, shadow, etc.)

### Feature domain 5: Advanced features
- Virtual display/dummy display creation and management
- Config protection (prevent the system from resetting resolution/refresh rate/color and other settings)
- Auto brightness
- Display notch management
- Prevent sleep while connected

## Technical approach overview

- **Stack**: Swift 6.2 + SwiftUI (MenuBarExtra) + IOKit + CoreGraphics + ScreenCaptureKit + ColorSync
- **Architecture**: macOS menu bar app (MenuBarExtra), MVVM architecture, project managed by xcodegen
- **Minimum OS**: macOS 14.0 (CGVirtualDisplay requires macOS 14+)
- **Key constraints**: requires Accessibility permission (DDC) and Screen Recording permission (streaming), App Sandbox disabled

### Core design decisions

| Decision | Choice | Reason |
|------|------|------|
| UI framework | SwiftUI MenuBarExtra | Natively supported on macOS 13+, lightweight, no Dock icon |
| Project management | xcodegen + project.yml | CLI-friendly, avoids managing .xcodeproj by hand |
| DDC communication | IOKit I2C direct communication | No third-party dependency; references the MonitorControl open source implementation |
| Screen capture | ScreenCaptureKit | Official Apple API, macOS 12.3+, replaces the deprecated CGDisplayStream |
| Virtual display | CGVirtualDisplay | Official API on macOS 14+, more stable than the older IOKit approach |
| Color management | ColorSync + CoreGraphics | Native system ICC management |
| Architecture | MVVM | SwiftUI best practice, View-ViewModel-Service layering |

## Phase overview

| Phase | Name | Status | Details |
|-------|------|------|------|
| 0-17 | Archived | ✅ | [archive/](archive/) |
| 18 | Stability hardening | ✅ | [phase-18.md](phase-18.md) |
| 19 | Display preset system | ✅ | [phase-19.md](phase-19.md) |
| 20 | Release preparation | ✅ | [phase-20.md](phase-20.md) |
| 21 | Feature trimming | ✅ | [phase-21.md](phase-21.md) |
| 22 | Auto brightness rewrite | ✅ | [phase-22.md](phase-22.md) |

## Decision log

| Date | Decision | Alternatives | Rationale |
|------|------|---------|------|
| 2026-03-02 | Use xcodegen instead of a hand-made Xcode project | SPM executable, manual xcodeproj | CLI-friendly, git-manageable, generates xcodeproj automatically |
| 2026-03-02 | MenuBarExtra instead of NSStatusItem | NSStatusItem + NSPopover | Native SwiftUI, more concise code, supported on macOS 13+ |
| 2026-03-02 | Minimum macOS 14 | macOS 12/13 | CGVirtualDisplay requires 14+; the user is currently on macOS 15 |
| 2026-03-02 | No third-party dependencies | MonitorControl/Lunar libraries | Fully self-contained, and a way to learn the low-level APIs |
| 2026-03-04 | Phase 18-20 planning | Continue bug fixing | Features are complete; focus on stability → preset system → release and distribution |

## Requirements sign-off log

| Date | Item confirmed | Content |
|------|--------|------|
| 2026-03-02 | Feature scope | User confirmed: all features are wanted, including streaming/PiP/virtual displays |
| 2026-03-02 | Project location | ~/Desktop/FreeDisplay |
| 2026-03-02 | Dev environment | Xcode installed, xcodegen 2.44.1 installed |
| 2026-03-02 | User hardware | MacBook built-in display + HKC H2435Q 2K external display |
| 2026-03-04 | HiDPI debugging notes | Constraints such as non-zero CGVirtualDisplay vendorID, creation on the main thread, and HiDPI config being purely runtime have been recorded in lessons |
