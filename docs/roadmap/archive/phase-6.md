# Phase 6: Image Adjustment ✅

> Core value: software-level color adjustment — contrast, gamma, gain, color temperature, independent RGB channels

## Task List

- [x] Implement the gamma table adjustment engine (`FreeDisplay/Services/GammaService.swift`)
  - Implementation hint:
    macOS implements software-level color adjustment through the gamma table. Core APIs:
    ```swift
    // get the current gamma table
    CGGetDisplayTransferByTable(displayID, capacity, &redTable, &greenTable, &blueTable, &sampleCount)
    // set a custom gamma table
    CGSetDisplayTransferByTable(displayID, sampleCount, redTable, greenTable, blueTable)
    // or use formula mode (more common)
    CGSetDisplayTransferByFormula(displayID,
      redMin, redMax, redGamma,
      greenMin, greenMax, greenGamma,
      blueMin, blueMax, blueGamma)
    ```
    Wrap these in a high-level interface:
    - `setGamma(displayID, value: Double)` — overall gamma (0.1~3.0, default 1.0)
    - `setGain(displayID, value: Double)` — overall gain (mapped to the max parameter)
    - `setColorTemperature(displayID, kelvin: Int)` — color temperature (converted to RGB ratios)
    - `setRGBGamma(displayID, r/g/b: Double)` — independent RGB gamma
    - `setRGBGain(displayID, r/g/b: Double)` — independent RGB gain
    - `resetGamma(displayID)` — reset via `CGDisplayRestoreColorSyncSettings()`
    Color temperature to RGB conversion: use the Planckian locus approximation formula (Tanner Helland algorithm),
    taking a temperature in K as input and producing RGB ratio coefficients.
  - Verification: the screen becomes noticeably brighter/darker after `setGamma(displayID, 0.5)`

- [x] Implement software contrast adjustment (`GammaService` extension)
  - Implementation hint:
    Contrast is implemented by adjusting the min/max range of the gamma table:
    - Increase contrast: widen the max - min gap
    - Decrease contrast: narrow the max - min gap
    Formula: `min = 0.5 - contrast/2`, `max = 0.5 + contrast/2`, with contrast in the range 0~1.
    Note: external displays can also set hardware contrast via DDC VCP 0x12 (the DDC foundation is already in place from Phase 2).
  - Verification: the image's contrast changes noticeably after adjusting contrast

- [x] Implement color inversion (`GammaService` extension)
  - Implementation hint:
    Color inversion = swapping min and max in the gamma table:
    `CGSetDisplayTransferByFormula(displayID, 1,0,1, 1,0,1, 1,0,1)` performs a full inversion.
    Or use the accessibility API `CGDisplaySetInvertedPolarity(true)` if available.
  - Verification: all screen colors are inverted once inversion is enabled

- [x] Implement the image adjustment UI (`FreeDisplay/Views/ImageAdjustmentView.swift`)
  - Implementation hint:
    An expandable "Image adjustment" section following the BetterDisplay screenshot:
    several slider groups arranged vertically:
    1. Contrast — Slider (⊙ icon) 0%
    2. Gamma — Slider (✦ icon) 0%
    3. Gain — Slider (⚡ icon) 0%
    4. Color temperature — Slider (🔥 icon) 0%
    5. Quantization — Slider (📊 icon) unlimited
    ---divider---
    6. Gamma (red) R — Slider 0%
    7. Gamma (green) G — Slider 0%
    8. Gamma (blue) B — Slider 0%
    ---divider---
    9. Gain (red) R — Slider 0%
    10. Gain (green) G — Slider 0%
    11. Gain (blue) B — Slider 0%
    ---
    ⚠️ "Adjustments may affect HDR content!" warning text
    Buttons at the bottom: Invert colors / Pause color adjustment / Reset image adjustment
    Each Slider has an icon and label on the left and shows a percentage value on the right.
  - Verification: the UI matches the BetterDisplay screenshot exactly

- [x] Implement the quantization feature (`GammaService` extension)
  - Implementation hint:
    Quantization = a visual simulation of reduced color bit depth. Implemented by making the gamma table stepped:
    map the 256 gray levels onto N levels (N = the quantization level), producing a banding effect.
    "Unlimited" = no quantization (the original 256 levels).
  - Verification: noticeable color banding appears when quantization is set to a low value

## Phase Acceptance

- All 11 sliders work correctly
- Gamma/gain/color temperature adjustments actually change the screen's color
- Independent RGB channel adjustment works
- The invert colors / pause / reset buttons work
- The UI matches the BetterDisplay image adjustment screenshot

**After completion**: consider running project-optimize for a retrospective
