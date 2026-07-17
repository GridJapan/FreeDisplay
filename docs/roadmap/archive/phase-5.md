# Phase 5: Color Management ✅

> Core value: ICC color profile switching, color mode management

## Task List

- [x] Implement ICC profile enumeration (`FreeDisplay/Services/ColorProfileService.swift`)
  - Implementation hint:
    Use the ColorSync framework to enumerate the system's ICC profiles:
    ```swift
    import ColorSync
    // get all ICC profiles
    let profileIterator = ColorSyncProfileIterateInstalledProfiles()
    ```
    Or scan the ICC profile directories on the file system:
    - `/Library/ColorSync/Profiles/`
    - `/System/Library/ColorSync/Profiles/`
    - `~/Library/ColorSync/Profiles/`
    Get the current display's profile: `CGDisplayCopyColorSpace(displayID)` →
    `CGColorSpace.name` for the name.
    Profile model: `name: String`, `path: URL`, `colorSpace: String` (RGB/CMYK etc.).
  - Verification: can list all ICC profiles on the system, including Display P3, sRGB, Adobe RGB, etc.

- [x] Implement ICC profile switching (`ColorProfileService` extension)
  - Implementation hint:
    Use the ColorSync API to set the profile for a given display:
    ```swift
    ColorSyncDeviceSetCustomProfiles(
      kColorSyncDisplayDeviceClass,
      deviceID,  // CGDirectDisplayID converted to CFUUIDRef
      profileInfo  // [kColorSyncDeviceDefaultProfileID: profileURL]
    )
    ```
    Note: the display UUID must be obtained via `CGDisplayCreateUUIDFromDisplayID`.
  - Verification: the display's color changes noticeably after switching profiles

- [x] Implement the color profile UI (`FreeDisplay/Views/ColorProfileView.swift`)
  - Implementation hint:
    An expandable "Color profile" section.
    Show the current profile at the top (e.g. "Color LCD") with a blue icon.
    A categorized list below:
    1. Profiles specific to the current display
    2. The "Generic RGB profiles" group (white-on-blue label)
    3. The list of all system profiles (AAA, ACES CG Linear, Adobe RGB, Apple RGB...)
    Each row: a circular icon on the left (⊙/⊕) + the profile name.
    Clicking switches to it.
    Follow the layout of the color profile area in the BetterDisplay screenshot.
  - Verification: the profile list is shown in full and clicking switches profiles

- [x] Implement the color mode UI (`FreeDisplay/Views/ColorModeView.swift`)
  - Implementation hint:
    An expandable "Color mode" section.
    Show the current mode information (e.g. "Internal (8-bit)") + labels (SDR/RGB/full range).
    List the available options:
    - Uniformity Calibration
    - GPU Dithering
    Framebuffer type selection:
    - standard framebuffer, inverted framebuffer, grayscale framebuffer, inverted grayscale framebuffer
    Use `CGDisplayCopyDisplayMode` to get the current color information.
    The framebuffer type comes from `CGDisplayModeCopyPixelEncoding`.
    Follow the color mode area of the BetterDisplay screenshot.
  - Verification: the color mode information is displayed correctly

## Phase Acceptance

- The ICC profile list is complete (contains all the profiles in the screenshot)
- Profile switching works and the colors actually change
- Color mode information is displayed correctly
- The UI layout matches the BetterDisplay screenshot

**After completion**: consider running project-optimize for a retrospective
