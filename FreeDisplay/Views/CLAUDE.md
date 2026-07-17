# Views — SwiftUI View Layer

> Presentation and interaction only. ❌ Do not write business logic in a View, and do not call a Service directly.

## Structure

- **MenuBarView.swift** — the main menu bar view; the entry container for every feature
- **DisplayDetailView.swift** — the per-display expanded panel; the container for collapsible Sections
- Each Section corresponds to its own View file (BrightnessSliderView, ColorProfileView, etc.)

## File List

| File | Purpose |
|------|------|
| MenuBarView.swift | Main menu bar view + entry points for every Section |
| DisplayDetailView.swift | Display expanded panel (12 Sections) |
| BrightnessSliderView.swift | Brightness/contrast sliders |
| ResolutionSliderView.swift | Resolution slider |
| DisplayModeListView.swift | Resolution mode list (favorites pinned to the top) |
| ArrangementView.swift | Display arrangement (thumbnails distinguish built-in from external screens) |
| ColorProfileView.swift | ICC Profile selection |
| SystemColorView.swift | System color configuration |
| ImageAdjustmentView.swift | Image adjustment (gamma/contrast) |
| VirtualDisplayView.swift | HiDPI virtual display |
| NotchView.swift | Notch mask |
| MainDisplayView.swift | Main display settings |
| AutoBrightnessView.swift | Ambient light auto-brightness |

## Key Patterns

- `@EnvironmentObject var displayManager: DisplayManager` — injected globally
- `@ObservedObject` is used for shared singletons (❌ do not wrap `.shared` in @StateObject)
- Row components that need hover/loading state → extract them into a standalone `struct` (❌ do not use a @ViewBuilder function)
- Component naming: reusable rows are `XxxRow` or `XxxRowView`
- One uniform hover effect: `.background(isHovered ? Color.primary.opacity(0.07) : .clear)`

## Change Checklist

- Adding a Section → change DisplayDetailView.swift + check the MenuBarView layout
- Adding a tool entry point → change the tools area of MenuBarView.swift
- Adding a row component → it MUST be a standalone struct, it cannot be a @ViewBuilder function
