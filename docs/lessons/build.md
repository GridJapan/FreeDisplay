# Pitfalls — Xcode / Build

> Updated: 2026-03-05

## Xcode / Build

- xcodegen does not generate Info.plist automatically → you must set `GENERATE_INFOPLIST_FILE: YES` in project.yml
- Calling ScreenCaptureKit (`SCShareableContent.current`) from a `@MainActor` context raises a non-Sendable error (even with `SWIFT_STRICT_CONCURRENCY: minimal` set) → fix: `@preconcurrency import ScreenCaptureKit`
- Under Swift 6 strict concurrency, singletons raise Sendable errors → mark the class `@unchecked Sendable` + set `SWIFT_STRICT_CONCURRENCY: minimal` in the project

## Phase 12 / Wrap-up

- After adding service/view files you must run `xcodegen generate` to regenerate the xcodeproj, otherwise other files referencing the new types report "cannot find in scope"
- If a Services file uses `CGDirectDisplayID`, it needs `import CoreGraphics` (`import Foundation` alone is not enough)
- `NSWorkspace.shared` needs `import AppKit` (Foundation alone is not enough)
- Swift 6 emits a non-Sendable warning when an `NSObject` subclass is used as a singleton → mark it `@unchecked Sendable` to resolve
- `SMAppService` (launch at login) is available on macOS 13+ and needs `import ServiceManagement`
