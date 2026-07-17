# Phase 15: Interaction Polish

> Goal: give every operation immediate visual feedback and make the interaction feel responsive and fluid overall

## Task List

- [x] Add loading states and visual feedback to all slow operations
  - Implementation notes:
    1. `DisplayModeListView.swift`: when switching resolutions, show a small `ProgressView()` on the clicked row and disable the other rows
    2. `ColorProfileView.swift`: show a ProgressView on the corresponding row while applying an ICC profile
    3. `MirrorView.swift`: show status while enabling/disabling mirroring
    4. Unified pattern: create a `LoadingButton` component — after being clicked, it automatically shows a spinner until the async operation completes
    5. For every async Service method, call sites uniformly use the `Task { isLoading = true; defer { isLoading = false }; await ... }` pattern
  - Verification: click any switch operation → the loading animation appears immediately → it disappears on completion

- [x] Add live value display and haptic feedback to Slider operations
  - Implementation notes:
    1. Every Slider (brightness, contrast, gamma, etc.) shows the current percentage value beside it, updating live while dragging
    2. On release, briefly highlight the value text (change its color with `withAnimation(.easeOut(duration: 0.3))`)
    3. Add `.sensoryFeedback(.selection, trigger: value)` to sliders, or use `NSHapticFeedbackManager` (on a MacBook trackpad)
    4. Unify the value display format: `"75%"` rather than `"0.75"` or `"0%"` (image adjustment currently shows 0% because the value really is 0, but the format must be consistent)
  - Verification: drag a slider → the percentage next to it follows live → a subtle animation gives feedback on release

- [x] Add Section expand/collapse animations
  - Implementation notes:
    1. In `DisplayDetailView.swift`, wrap the state toggle of every Section's expand/collapse in `withAnimation(.spring(response: 0.3, dampingFraction: 0.8))`
    2. Add enter/exit animations to Section content with `.transition(.opacity.combined(with: .move(edge: .top)))`
    3. Rotate the Section header's arrow icon 90°→0° on expand using `.rotationEffect` (or animate a chevron.right → chevron.down switch)
    4. Make sure the animation does not hurt performance: a collapsed Section's content should be conditionally rendered with `if expanded { ... }` rather than hidden via opacity
  - Verification: click a Section header → the content expands/collapses smoothly with the arrow rotation animation

- [x] Improve the overall feel of the menu
  - Implementation notes:
    1. Add a hover effect to row clicks: `.onHover { isHovered = $0 }` + a background color transition `Color.primary.opacity(isHovered ? 0.05 : 0)`
    2. Add a scale animation on button press: `.scaleEffect(isPressed ? 0.97 : 1.0)` + `.animation(.easeInOut(duration: 0.1))`
    3. Use `Divider().opacity(0.3)` between list items to make the visual hierarchy clearer
    4. Check that all Toggle switches have a consistent style and that state changes are smooth
  - Verification: hovering over rows fades a highlight in and out → clicking gives slight scale feedback → the whole thing feels responsive

- [x] Fix the @StateObject singleton anti-pattern
  - Implementation notes:
    1. `MenuBarView.swift`: `@StateObject private var updateService = UpdateService.shared` → change to `@ObservedObject private var updateService = UpdateService.shared`
    2. Same for `SettingsService.shared`
    3. Check everywhere a View wraps a shared singleton in `@StateObject` and uniformly change them to `@ObservedObject`
    4. Only objects the View itself creates and owns should use `@StateObject` (e.g. `@StateObject private var vm = SomeViewModel()`)
  - Verification: compiles successfully + opening and closing the menu repeatedly causes no flicker from duplicate subscriptions

**Phase Acceptance**: compiles successfully + subjectively smooth and responsive: clicks give immediate feedback, slider dragging is smooth, expand/collapse is animated, no stutter
