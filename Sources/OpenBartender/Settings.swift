import AppKit
import Carbon.HIToolbox
import Combine
import ServiceManagement

/// Single source of truth for user preferences, bridged to `UserDefaults` and
/// observable by both SwiftUI (Preferences/Onboarding) and `MenuBarController`.
final class Settings: ObservableObject {
    static let shared = Settings()

    private let d = UserDefaults.standard

    enum Key {
        static let autoHideDelay        = "autoHideDelay"        // seconds; 0 = off
        static let alwaysHiddenEnabled  = "alwaysHiddenEnabled"
        static let hotKeyEnabled        = "hotKeyEnabled"
        static let hotKeyCode           = "hotKeyCode"
        static let hotKeyCarbonMods     = "hotKeyCarbonMods"
        static let hotKeyDisplay        = "hotKeyDisplay"
        static let hasOnboarded         = "hasOnboarded"
        static let toggleStyle          = "toggleStyle"
        static let dividerStyle         = "dividerStyle"
    }

    @Published var autoHideDelay: Int {
        didSet { d.set(autoHideDelay, forKey: Key.autoHideDelay) }
    }
    @Published var alwaysHiddenEnabled: Bool {
        didSet { d.set(alwaysHiddenEnabled, forKey: Key.alwaysHiddenEnabled) }
    }
    @Published var hotKeyEnabled: Bool {
        didSet { d.set(hotKeyEnabled, forKey: Key.hotKeyEnabled) }
    }
    @Published var hotKeyCode: Int {
        didSet { d.set(hotKeyCode, forKey: Key.hotKeyCode) }
    }
    @Published var hotKeyCarbonMods: Int {
        didSet { d.set(hotKeyCarbonMods, forKey: Key.hotKeyCarbonMods) }
    }
    @Published var hotKeyDisplay: String {
        didSet { d.set(hotKeyDisplay, forKey: Key.hotKeyDisplay) }
    }
    @Published var hasOnboarded: Bool {
        didSet { d.set(hasOnboarded, forKey: Key.hasOnboarded) }
    }
    @Published var toggleStyle: String {
        didSet { d.set(toggleStyle, forKey: Key.toggleStyle) }
    }
    @Published var dividerStyle: String {
        didSet { d.set(dividerStyle, forKey: Key.dividerStyle) }
    }

    /// Backed by the login-item service rather than defaults.
    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin(launchAtLogin) }
    }

    private init() {
        d.register(defaults: [
            Key.autoHideDelay: 0,
            Key.alwaysHiddenEnabled: false,
            Key.hotKeyEnabled: true,
            Key.hotKeyCode: Int(kVK_ANSI_B),
            Key.hotKeyCarbonMods: Int(cmdKey | optionKey),
            Key.hotKeyDisplay: "⌥⌘B",
            Key.hasOnboarded: false,
            Key.toggleStyle: ToggleStyle.chevronCompact.rawValue,
            Key.dividerStyle: DividerStyle.diagonal.rawValue,
        ])

        autoHideDelay       = d.integer(forKey: Key.autoHideDelay)
        alwaysHiddenEnabled = d.bool(forKey: Key.alwaysHiddenEnabled)
        hotKeyEnabled       = d.bool(forKey: Key.hotKeyEnabled)
        hotKeyCode          = d.integer(forKey: Key.hotKeyCode)
        hotKeyCarbonMods    = d.integer(forKey: Key.hotKeyCarbonMods)
        hotKeyDisplay       = d.string(forKey: Key.hotKeyDisplay) ?? "⌥⌘B"
        hasOnboarded        = d.bool(forKey: Key.hasOnboarded)
        toggleStyle         = d.string(forKey: Key.toggleStyle) ?? ToggleStyle.chevronCompact.rawValue
        dividerStyle        = d.string(forKey: Key.dividerStyle) ?? DividerStyle.diagonal.rawValue
        launchAtLogin       = (SMAppService.mainApp.status == .enabled)
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled, SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            } else if !enabled, SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("OpenBartender: launch-at-login failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Hotkey helpers

    /// Convert AppKit modifier flags (from the recorder) into Carbon flags.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option)  { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey) }
        return carbon
    }

    /// Build a display string like "⌥⌘B" from modifiers + a key label.
    static func displayString(flags: NSEvent.ModifierFlags, key: String) -> String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option)  { s += "⌥" }
        if flags.contains(.shift)   { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s + key.uppercased()
    }
}
