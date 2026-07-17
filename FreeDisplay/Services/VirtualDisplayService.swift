import AppKit
import CoreGraphics
import Foundation
import IOKit

@_silgen_name("CGDisplayIOServicePort")
private func CGDisplayIOServicePort(_ display: CGDirectDisplayID) -> io_service_t

// CGVirtualDisplay and CGVirtualDisplaySettings are ObjC objects without Sendable
// conformance, but we only use them sequentially (create on main → pass to background
// for apply → use result on main), so @unchecked Sendable is safe here.
extension CGVirtualDisplayDescriptor: @unchecked @retroactive Sendable {}
extension CGVirtualDisplay: @unchecked @retroactive Sendable {}
extension CGVirtualDisplaySettings: @unchecked @retroactive Sendable {}

/// Manages virtual display configurations and creates CGVirtualDisplay instances
/// using the private CGVirtualDisplay API declared in the bridging header.
@MainActor
final class VirtualDisplayService: ObservableObject, @unchecked Sendable {
    static let shared = VirtualDisplayService()
    private init() {
        loadConfigs()
    }

    // MARK: - Config Model

    struct VirtualDisplayConfig: Codable, Identifiable, Equatable {
        let id: UUID
        var name: String
        var width: Int
        var height: Int
        var refreshRate: Double
        var hiDPI: Bool
        var autoCreate: Bool

        init(id: UUID = UUID(), name: String, width: Int, height: Int,
             refreshRate: Double = 60.0, hiDPI: Bool = true, autoCreate: Bool = true) {
            self.id = id
            self.name = name
            self.width = width
            self.height = height
            self.refreshRate = refreshRate
            self.hiDPI = hiDPI
            self.autoCreate = autoCreate
        }
    }

    // MARK: - State

    @Published var configs: [VirtualDisplayConfig] = []

    /// Active config IDs — populated when a CGVirtualDisplay is alive.
    @Published private(set) var activeConfigIDs: Set<UUID> = []

    /// Strong references to live CGVirtualDisplay objects.
    /// Releasing an entry causes the virtual display to disappear immediately.
    private var activeDisplayObjects: [UUID: CGVirtualDisplay] = [:]

    private let configsKey = "fd.VirtualDisplayConfigs"

    // MARK: - Queries

    func isActive(_ configID: UUID) -> Bool {
        activeConfigIDs.contains(configID)
    }

    /// Returns true if `displayID` is a virtual display managed by this service.
    func isVirtualDisplay(_ displayID: CGDirectDisplayID) -> Bool {
        activeDisplayObjects.values.contains { $0.displayID == displayID }
    }

    /// The config behind a live virtual display, or nil for a physical one.
    func configID(forDisplayID displayID: CGDirectDisplayID) -> UUID? {
        activeDisplayObjects.first { $0.value.displayID == displayID }?.key
    }

    // MARK: - Create / Destroy

    /// Creates a virtual display from the given config using CGVirtualDisplay private API.
    /// Returns true on success. The CGVirtualDisplay object is retained in `activeDisplayObjects`.
    /// The ENTIRE creation (descriptor build + CGVirtualDisplay init + apply) runs off the
    /// main actor via `runWithTimeout` because any of these calls can block on WindowServer IPC.
    /// Base name for the first panel; the ones after it get " 2", " 3"… appended.
    private static let baseDisplayName = "FreeDisplay GridJapan"

    /// Offered on top of the panel's own size, whenever they fit inside it.
    ///
    /// macOS derives a ladder of scaled modes on its own, but a sparse and opinionated one:
    /// under a 2560×1440 panel it hands out 1920×1080, 1600×900, 1280×720 and a few 4:3 sizes,
    /// and nothing else — neither 1920×1200 nor 2048×1152. Anything else has to be declared.
    ///
    /// **Two declared sizes close in pixel count cannot coexist.** The window server silently
    /// keeps one and drops the other; `apply` still reports success, and the loser simply never
    /// reaches `CGDisplayCopyAllDisplayModes`. Measured on a 2560×1440 panel, and deterministic
    /// across restarts — not a race, not a cache, not an artefact of declaration order:
    ///
    ///     2048×1152 (2,359,296) + 1920×1200 (2,304,000)   2.4% apart → one dropped
    ///     2000×1125 (2,250,000) + 1920×1200 (2,304,000)   2.4% apart → one dropped
    ///     2048×1152 (2,359,296) + 2000×1125 (2,250,000)   4.6% apart → both kept
    ///     2048×1280 (2,621,440) + 2048×1152 (2,359,296)  10.0% apart → both kept
    ///
    /// Where the cutoff really lies is unknown; only that ~2.4% loses and ~4.6% survives. Keep
    /// entries well spaced, and check the real mode list after adding one — nothing warns you,
    /// the size just isn't there.
    private static let standardModes: [(width: Int, height: Int)] = [
        (2048, 1280),
    ]

    /// Multiple panels are ordinary here — configs is a list and every autoCreate entry is
    /// created on launch — so identical names are a real possibility, and two displays calling
    /// themselves the same thing are indistinguishable both in the display list and to anything
    /// that tracks displays by name because IDs are not stable across reconnects.
    ///
    /// The serial number is split for the same reason one layer down: name is cosmetic, but
    /// vendor/product/serial is how macOS decides two panels are the same panel, and sharing
    /// it would let their wallpapers and arrangement bleed into each other. The first keeps
    /// serial 1, so nothing already on screen changes identity.
    private func identity(for config: VirtualDisplayConfig) -> (name: String, serial: UInt32) {
        let ordinal = (configs.firstIndex { $0.id == config.id } ?? 0) + 1
        let name = ordinal <= 1 ? Self.baseDisplayName : "\(Self.baseDisplayName) \(ordinal)"
        return (name, UInt32(ordinal))
    }

    @discardableResult
    func create(config: VirtualDisplayConfig) async -> Bool {
        let w = config.width
        let h = config.height
        let hiDPI = config.hiDPI
        let id = identity(for: config)

        // Step 1-2: Build descriptor + create CGVirtualDisplay ON MAIN ACTOR.
        // CGVirtualDisplay(descriptor:) requires the main thread (returns nil from background).
        let descriptor = CGVirtualDisplayDescriptor()
        let ppi: Double = 110.0
        descriptor.sizeInMillimeters = CGSize(
            width: Double(w) / ppi * 25.4,
            height: Double(h) / ppi * 25.4
        )
        descriptor.maxPixelsWide = UInt32(w)
        descriptor.maxPixelsHigh = UInt32(h)
        descriptor.name = id.name
        descriptor.vendorID = 0xEEEE  // non-zero required — 0 causes CGVirtualDisplay(descriptor:) to return nil
        descriptor.productID = 0x0001
        descriptor.serialNum = id.serial
        // DO NOT set queue or color primaries — they are not needed and may interfere with creation

        guard let virtualDisplay = CGVirtualDisplay(descriptor: descriptor) else {
            return false
        }

        // Step 3: Build settings with modes
        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = hiDPI

        var modes: [CGVirtualDisplayMode] = []
        let refreshRates: [Double] = [75.0, 60.0, 50.0]
        for rate in refreshRates {
            modes.append(CGVirtualDisplayMode(width: UInt(w), height: UInt(h), refreshRate: rate))
        }
        for extra in Self.standardModes where extra.width <= w && extra.height <= h
                                           && !(extra.width == w && extra.height == h) {
            for rate in refreshRates {
                modes.append(CGVirtualDisplayMode(width: UInt(extra.width), height: UInt(extra.height),
                                                  refreshRate: rate))
            }
        }
        if hiDPI {
            let hw = w / 2, hh = h / 2
            if hw >= 1, hh >= 1 {
                for rate in refreshRates {
                    modes.append(CGVirtualDisplayMode(width: UInt(hw), height: UInt(hh), refreshRate: rate))
                }
            }
            let qw = w / 4, qh = h / 4
            if qw >= 1, qh >= 1 {
                for rate in refreshRates {
                    modes.append(CGVirtualDisplayMode(width: UInt(qw), height: UInt(qh), refreshRate: rate))
                }
            }
        }
        settings.modes = modes

        // Step 4: Apply settings on BACKGROUND thread (blocks on WindowServer IPC).
        let vd = virtualDisplay
        let s = settings
        let applyResult: Bool = await CGHelpers.runWithTimeout(seconds: 10, fallback: false) {
            vd.apply(s)
        }
        guard applyResult else { return false }
        guard virtualDisplay.displayID != kCGNullDirectDisplay else { return false }

        // Back on main actor — store the strong reference
        activeDisplayObjects[config.id] = virtualDisplay
        activeConfigIDs.insert(config.id)

        restoreSavedMode(for: config, displayID: virtualDisplay.displayID)
        return true
    }

    // MARK: - Remembered resolution

    private let savedModesKey = "fd.VirtualDisplayModes"

    /// The resolution each virtual display was last switched to, keyed by config UUID.
    ///
    /// Not by display ID, and not by mode ID: a virtual display gets a fresh CGDirectDisplayID
    /// every time it is created (25, 29, 42, 46 within one afternoon here), and mode IDs are
    /// assigned per panel, so both are gone by the time there is anything to restore. The config
    /// UUID is the only handle that outlives the panel, and a width×height is the only
    /// description of a mode that outlives the panel's mode list.
    ///
    /// This is separate from `config.width`/`height`, which describe the panel itself — the
    /// largest the display can be. This is which of its modes was chosen.
    private var savedModes: [String: [String: Int]] {
        get { UserDefaults.standard.dictionary(forKey: savedModesKey) as? [String: [String: Int]] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: savedModesKey) }
    }

    /// Records the mode a virtual display was switched to, so creating it again restores it.
    /// Call with the panel's own size to forget the override.
    func rememberMode(width: Int, height: Int, forConfig id: UUID) {
        var all = savedModes
        let name = configs.first(where: { $0.id == id })?.name ?? "?"
        if let config = configs.first(where: { $0.id == id }), config.width == width, config.height == height {
            all.removeValue(forKey: id.uuidString)
            #if DEBUG
            print("[VirtualDisplayService] \(name) is back at its panel size — override forgotten")
            #endif
        } else {
            all[id.uuidString] = ["width": width, "height": height]
            #if DEBUG
            print("[VirtualDisplayService] remembered \(width)x\(height) for \(name)")
            #endif
        }
        savedModes = all
    }

    func forgetMode(forConfig id: UUID) {
        var all = savedModes
        all.removeValue(forKey: id.uuidString)
        savedModes = all
    }

    // MARK: - Holding a chosen resolution

    private var modeWatchTimer: Timer?
    private var pendingSizes: [UUID: (size: Size, since: Date)] = [:]

    private struct Size: Equatable {
        let width: Int
        let height: Int
    }

    /// How long a new size must survive on its own before it counts as chosen rather than as a
    /// glitch. Comfortably above the ~14s revert seen in testing: mistaking a revert for a
    /// choice loses the resolution the user picked, while being too patient only means an
    /// unwanted size lingers a few seconds longer before being corrected.
    private static let settleSeconds: TimeInterval = 20

    /// Watches each virtual display's resolution and holds it where it was put.
    ///
    /// A resolution chosen in System Settings does not stay chosen. Measured on a freshly
    /// created 2560×1440 panel: 2048×1280 applied straight away, then reverted on its own 14
    /// seconds later, with nothing on screen to explain it. FreeDisplay's own menu hides the
    /// same fault behind a retry (`DisplayModeListView` re-fires after 200ms, and that comment
    /// predates this fork) — but nothing retries on behalf of System Settings.
    ///
    /// Polled, because there is no event to hang this on: `CGDisplayRegisterReconfiguration`
    /// never fires for these changes. A probe that logged every callback for 40 seconds caught
    /// the switch and the revert by polling and saw not one callback for either.
    ///
    /// Telling a revert from a deliberate change is the subtle part, since a display at the
    /// wrong size looks identical either way. The tell is direction: a revert always lands back
    /// on the panel's own size, because that is what the display falls back to. A change made
    /// in System Settings lands on one of the smaller modes. So a drift *away* from the panel
    /// size is someone choosing something and is adopted; a drift *to* the panel size, when the
    /// remembered size was smaller, is the fault and gets undone.
    ///
    /// This is wrong in exactly one case: choosing the panel's own size in System Settings,
    /// when a smaller one was remembered, looks like a revert and is fought once. Setting the
    /// same size from FreeDisplay's own menu goes through `rememberMode` and works, and the
    /// alternative — trusting every drift — hands the resolution back to the fault this exists
    /// to correct.
    func startWatchingModes() {
        modeWatchTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.holdRememberedModes() }
        }
        RunLoop.main.add(timer, forMode: .common)
        modeWatchTimer = timer
    }

    private func holdRememberedModes() {
        for (configID, virtualDisplay) in activeDisplayObjects {
            let displayID = virtualDisplay.displayID
            guard displayID != kCGNullDirectDisplay,
                  let mode = CGDisplayCopyDisplayMode(displayID) else { continue }
            let now = Size(width: mode.width, height: mode.height)
            let name = configs.first(where: { $0.id == configID })?.name ?? "?"

            guard let saved = savedModes[configID.uuidString],
                  let w = saved["width"], let h = saved["height"] else {
                // Nothing remembered yet: whatever it settles at becomes the baseline.
                noteSettling(now, for: configID, name: name)
                continue
            }
            guard now != Size(width: w, height: h) else {
                pendingSizes.removeValue(forKey: configID)
                continue
            }

            guard let config = configs.first(where: { $0.id == configID }) else { continue }
            let panelSize = Size(width: config.width, height: config.height)
            let revertedToPanel = now == panelSize && Size(width: w, height: h) != panelSize

            if revertedToPanel {
                print("[VirtualDisplayService] \(name) fell back to \(now.width)x\(now.height), " +
                      "restoring \(w)x\(h)")
                applyMode(width: w, height: h, on: displayID, name: name)
                pendingSizes.removeValue(forKey: configID)
            } else {
                // A size someone picked. Adopt it, once it proves it is staying.
                noteSettling(now, for: configID, name: name)
            }
        }
    }

    /// Accepts a size as chosen once it has stayed put for `settleSeconds`.
    private func noteSettling(_ size: Size, for configID: UUID, name: String) {
        guard let pending = pendingSizes[configID], pending.size == size else {
            pendingSizes[configID] = (size, Date())
            return
        }
        guard Date().timeIntervalSince(pending.since) >= Self.settleSeconds else { return }
        #if DEBUG
        print("[VirtualDisplayService] \(name) held \(size.width)x\(size.height) — accepting")
        #endif
        rememberMode(width: size.width, height: size.height, forConfig: configID)
        pendingSizes.removeValue(forKey: configID)
    }

    private func applyMode(width: Int, height: Int, on displayID: CGDirectDisplayID, name: String) {
        let modes = CGDisplayCopyAllDisplayModes(displayID, nil) as? [CGDisplayMode] ?? []
        guard let target = modes.first(where: { $0.width == width && $0.height == height }) else {
            print("[VirtualDisplayService] \(width)x\(height) is gone for \(name)")
            return
        }
        var cfg: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&cfg) == .success else { return }
        CGConfigureDisplayWithDisplayMode(cfg, displayID, target, nil)
        let result = CGCompleteDisplayConfiguration(cfg, .permanently)
        #if DEBUG
        print("[VirtualDisplayService] applied \(width)x\(height) on \(name): \(result == .success)")
        #endif
    }

    /// Applies the remembered mode to a display that has just been created.
    ///
    /// Deliberately quiet on failure: a mode that no longer exists (the panel was recreated at a
    /// smaller size, or the standardModes list changed) leaves the display at its native size,
    /// which is a working display and not an error worth interrupting anyone over.
    private func restoreSavedMode(for config: VirtualDisplayConfig, displayID: CGDirectDisplayID) {
        guard let saved = savedModes[config.id.uuidString],
              let w = saved["width"], let h = saved["height"],
              w != config.width || h != config.height else { return }

        Task { @MainActor in
            // WindowServer has just registered the display; give its mode list a moment to
            // populate before asking for it.
            try? await Task.sleep(nanoseconds: 500_000_000)
            let modes = CGDisplayCopyAllDisplayModes(displayID, nil) as? [CGDisplayMode] ?? []
            guard let target = modes.first(where: { $0.width == w && $0.height == h }) else {
                print("[VirtualDisplayService] remembered mode \(w)×\(h) is gone for \(config.name)")
                return
            }
            var cfg: CGDisplayConfigRef?
            guard CGBeginDisplayConfiguration(&cfg) == .success else { return }
            CGConfigureDisplayWithDisplayMode(cfg, displayID, target, nil)
            let result = CGCompleteDisplayConfiguration(cfg, .permanently)
            #if DEBUG
            print("[VirtualDisplayService] restored \(w)×\(h) on \(config.name): \(result == .success)")
            #endif
        }
    }

    /// Destroys all active virtual displays. Called on app termination to avoid
    /// leaving stale displays registered with WindowServer.
    func destroyAll() {
        for uuid in activeConfigIDs {
            activeDisplayObjects.removeValue(forKey: uuid)
        }
        activeConfigIDs.removeAll()
    }

    /// Destroys the virtual display associated with `configID`.
    @discardableResult
    func destroy(configID: UUID) -> Bool {
        guard activeDisplayObjects[configID] != nil else {
            return false
        }

        // ARC releases the CGVirtualDisplay → virtual display disappears
        activeDisplayObjects.removeValue(forKey: configID)
        activeConfigIDs.remove(configID)

        return true
    }

    // MARK: - Config Management

    @discardableResult
    func addAndCreate(_ config: VirtualDisplayConfig) async -> Bool {
        guard !configs.contains(where: { $0.id == config.id }) else {
            return await create(config: config)
        }
        // Create first; only persist on success to avoid stale config if process crashes.
        if await create(config: config) {
            configs.append(config)
            saveConfigs()
            return true
        }
        return false
    }

    func removeConfig(id: UUID) {
        destroy(configID: id)
        configs.removeAll { $0.id == id }
        forgetMode(forConfig: id)
        saveConfigs()
    }

    // MARK: - Persistence

    private func loadConfigs() {
        guard let data = UserDefaults.standard.data(forKey: configsKey),
              let decoded = try? JSONDecoder().decode([VirtualDisplayConfig].self, from: data)
        else { return }
        configs = decoded

        // Re-create virtual displays marked autoCreate after WindowServer stabilises.
        let autoCreateConfigs = configs.filter { $0.autoCreate }
        if !autoCreateConfigs.isEmpty {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 800_000_000)
                for config in autoCreateConfigs {
                    // After a crash, a virtual display from the previous session may
                    // still be registered with WindowServer. Skip creation if an online
                    // virtual display with matching dimensions already exists.
                    guard !virtualDisplayAlreadyExists(named: identity(for: config).name) else {
                        #if DEBUG
                        print("[VirtualDisplayService] autoCreate skipped — \(identity(for: config).name) already online")
                        #endif
                        continue
                    }
                    _ = await create(config: config)
                }
                startWatchingModes()
            }
        } else {
            startWatchingModes()
        }
    }

    /// Returns true if any currently-online display matches the given pixel dimensions and
    /// has no associated IOKit service port (indicating it is a virtual/software display).
    /// Used by autoCreate to avoid duplicating a display that survived an app crash.
    /// Whether a virtual display already carrying this name is online.
    ///
    /// Keyed on the name, not the resolution. Matching by resolution meant two configs of the
    /// same size could never both exist — the second was mistaken for the first and skipped —
    /// and it did so unreliably, since whether the first had finished registering decided the
    /// outcome. Three 2560×1440 configs produced two displays because of it. Names are unique
    /// per ordinal, which is what makes them usable as identity.
    private func virtualDisplayAlreadyExists(named name: String) -> Bool {
        var displayCount: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &displayCount)
        guard displayCount > 0 else { return false }
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetOnlineDisplayList(displayCount, &displayIDs, &displayCount)
        for id in displayIDs {
            // A software/virtual display has no IOService entry (servicePort == 0 / MACH_PORT_NULL).
            // Physical displays always have a non-null service port.
            let servicePort = CGDisplayIOServicePort(id)
            guard servicePort == 0 || servicePort == MACH_PORT_NULL else { continue }
            let screen = NSScreen.screens.first {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == id
            }
            if screen?.localizedName == name { return true }
        }
        return false
    }

    private func saveConfigs() {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        UserDefaults.standard.set(data, forKey: configsKey)
    }
}
