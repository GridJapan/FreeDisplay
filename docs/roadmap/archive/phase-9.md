# Phase 9: Screen Streaming and Picture-in-Picture ✅

> Core value: BetterDisplay's most advanced feature — streaming a screen into a window + a floating picture-in-picture window

## Task List

- [x] Implement the screen capture engine (`FreeDisplay/Services/ScreenCaptureService.swift`)
  - Implementation hint:
    Use ScreenCaptureKit (macOS 12.3+):
    ```swift
    import ScreenCaptureKit

    // 1. get the shareable content
    let content = try await SCShareableContent.current
    let display = content.displays.first { $0.displayID == targetDisplayID }

    // 2. create the filter and configuration
    let filter = SCContentFilter(display: display!, excludingWindows: [])
    let config = SCStreamConfiguration()
    config.width = Int(display!.width)
    config.height = Int(display!.height)
    config.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60fps
    config.pixelFormat = kCVPixelFormatType_32BGRA
    config.showsCursor = true

    // 3. create and start the stream
    let stream = SCStream(filter: filter, configuration: config, delegate: self)
    try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())
    try await stream.startCapture()
    ```
    Output `CMSampleBuffer` → convert to `CIImage` → hand off to the view layer for rendering.
    Screen recording permission is required: an authorization dialog pops up on first use.
  - Verification: display frames can be obtained once capture starts

- [x] Implement the stream window (`FreeDisplay/Views/StreamWindow.swift`)
  - Implementation hint:
    Create a standalone NSWindow to show the captured image:
    - `NSWindow(contentRect:, styleMask: [.titled, .closable, .resizable], ...)`
    - Render the CMSampleBuffer with high performance using `MetalView` (MTKView) or `CAMetalLayer` for the content
    - Or use a SwiftUI `Image` converted from CIImage (lower performance, but simple)
    The Metal rendering path is recommended:
    ```swift
    class MetalStreamView: MTKView {
        // CMSampleBuffer → CVPixelBuffer → MTLTexture → render
    }
    ```
    Window support: scale the content proportionally when resizing.
  - Verification: the stream window shows the target display's image in real time

- [x] Implement the streaming options (`FreeDisplay/ViewModels/StreamViewModel.swift`)
  - Implementation hint: following the screen streaming area of the BetterDisplay screenshot, implement these options:
    - Show mouse cursor: `config.showsCursor = true/false`
    - 1:1 pixel mapping: window size = capture resolution
    - Integer scaling: the window's width and height can only be integer multiples/fractions of the capture resolution
    - Free aspect ratio: allow non-proportional scaling
    - Video filters: process frames with CIFilter (grayscale, blur, sharpen, etc.)
    - Enable cropping: show only part of the captured image in the window (the user can drag the crop box)
    - Flip (horizontal/vertical): CIFilter `CIAffineTransform`
    - Rotate (0°/90°/180°/270°): CIFilter `CIAffineTransform`
    - Zoom slider (0.1x~4.0x)
    - Underscan slider (percentage of the edges cropped)
    - Opacity slider (`window.alphaValue`)
    - "Restore stream on connect": persisted in UserDefaults
  - Verification: the streamed image actually changes when each option is toggled

- [x] Implement picture-in-picture (`FreeDisplay/Views/PiPWindow.swift`)
  - Implementation hint:
    Picture-in-picture = a smaller floating stream window + extra control options.
    Built as an extension of StreamWindow, adding:
    - Window level: normal level / above other windows / above the menu bar
      `window.level = .normal / .floating / .statusBar + 1`
    - Show/hide the title bar: `window.styleMask.insert/remove(.titled)`
    - Not movable: `window.isMovable = false`
    - Resizing disabled: `window.styleMask.remove(.resizable)`
    - Snap in 25% increments: snap to the nearest 25% screen-width position when the drag ends
    - Mouse click-through: `window.ignoresMouseEvents = true`
    - Window shadow: `window.hasShadow = true/false`
    - Exclude the PiP window (so it does not capture itself): ScreenCaptureKit's `excludingWindows` parameter
  - Verification: the PiP window floats above other windows and all options work

- [x] Implement the menu UI for streaming/PiP (`FreeDisplay/Views/StreamControlView.swift`, `PiPControlView.swift`)
  - Implementation hint:
    Two expandable sections: "Screen streaming" and "Picture-in-picture", following the BetterDisplay screenshot.
    Streaming area: target selection list + stop button + all option switches/sliders
    Picture-in-picture area: enable/auto-start + level selection + all option switches/sliders + flip and rotate button group
    Buttons at the bottom: "New stream configuration" / "New picture-in-picture setting" (supports multiple streams/PiPs running at once)
  - Verification: the UI matches the BetterDisplay screenshot exactly

## Phase Acceptance

- Screen streaming shows the target display's image in real time at a smooth frame rate
- All streaming options (cursor, zoom, rotation, cropping, filters, opacity) work
- The floating picture-in-picture window stays on top and all PiP options work
- Multiple streams/PiPs can run at the same time
- The UI matches the BetterDisplay screenshot

**After completion**: consider running project-optimize for a retrospective
