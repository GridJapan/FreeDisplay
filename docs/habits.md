# Working habits — FreeDisplay

> Updated: 2026-03-02

## Build and test

- Build command: `cd ~/Desktop/FreeDisplay && xcodebuild -scheme FreeDisplay -configuration Debug build 2>&1 | tail -5`
- After changing project.yml you must run `xcodegen generate` before building
- Build output is very long; only the last few lines matter (`| tail -5`)

## Code style

- Keep SwiftUI views declarative; extract complex logic into a ViewModel/Service
- Annotate all ObservableObject classes with @MainActor (satisfies Swift 6 concurrency checking)
- Use the singleton pattern for the Service layer (`static let shared`), marked `@unchecked Sendable`

## Project management

- xcodegen manages the project; do not edit .xcodeproj by hand
- Put new files in the corresponding subdirectory under FreeDisplay/; xcodegen picks them up automatically
- Update the `[x]` markers in the roadmap after each Phase is done

## Agent execution quality control

- Instructions given to agents must contain **precise code changes** (which line to change and what to change it to), not high-level descriptions
- Compiles ≠ works; runtime behavior needs to be verified
- Features involving hardware interaction (DDC, IOKit) are hard for agents to verify and need manual testing to confirm

## Multi-agent optimization workflow (validated in Rounds 3-4)

- **Separate scanning from fixing**: first run 4 scan agents in parallel (read-only), collect every issue, then dispatch fix agents — the fix agents then have full context and don't miss related fixes
- **Scans must cover "feature interaction chains"**: don't just scan for single-file bugs; cover each feature's full "user action → UI → Service → system API → callback" chain — cross-Service interaction issues only surface this way
- **Fix P0s first, compile once per batch**: don't pile up too many changes before compiling, or failures are hard to localize
- **0 warnings is the quality floor**: clear all warnings before the end of each round

## SwiftUI component development

- Row components that need local state such as hover/loading → extract into a standalone struct (don't use a @ViewBuilder function; @ViewBuilder doesn't support @State)
- Naming convention: reusable row components use `XxxRow` or `XxxRowView`; private structs take the `private` modifier
- Standard hover effect template: `@State private var isHovered = false` + `.background(Color.primary.opacity(isHovered ? 0.06 : 0))` + `.onHover { isHovered = $0 }` + `.animation(.easeInOut(duration: 0.15), value: isHovered)`

## Multi-agent UX polish workflow (validated over 3 rounds)

- **Group by feature domain**: assign MenuBar/DetailView/Sliders/FeatureViews to different agents; don't let two agents edit the same file
- **Read before changing**: tell the agent to "read the whole file first, then make the changes on the list" to keep it from editing on assumptions
- **Verify by compiling at the end of each round**: after all agents report back, run `xcodebuild` as a final build check
- **Improvement lists must be specific**: instructions to agents must include the target struct name, the @State variable name, and the exact modifier code, not a high-level description like "add a hover effect"

## Debugging patterns

- **File log debugging**: when stdout/stderr isn't visible (e.g. a menu bar app), write a `~/Desktop/xxx_debug.log` file to trace execution flow — more reliable than print/NSLog
- **Reference implementation verification**: don't guess at private APIs; find a known-working open source project (Chromium, BetterDisplay, node-mac-virtual-display) as an authoritative reference and check property names and call conventions against it

## UX patterns

- **One-click preset pattern**: wrapping a multi-step operation (create virtual display + set resolution + arrange) into a single toggle gives the best user experience; applies to any feature where "only the combination of actions is meaningful"

## HiDPI development notes

- **plist override is the only viable HiDPI approach**: write to `/Library/Displays/Contents/Resources/Overrides/`; requires administrator privileges (NSAppleScript); takes effect after reconnecting the display
- **Don't set DisplayProductName in the override plist**: it overrides the system display name
- **Getting the native resolution**: use `availableModes.max()` rather than `CGDisplayPixelsWide/High` (the latter returns the current resolution)
- **Loading private frameworks**: always use dlopen+dlsym, not @_silgen_name (which causes a linker error)
