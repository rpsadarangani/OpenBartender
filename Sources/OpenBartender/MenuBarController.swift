import AppKit
import Combine

/// Core of OpenBartender.
///
/// Up to three status items, laid out left → right:
///
///   [ always-hidden icons ] [ sepA ⋯ ] [ hidden icons ] [ sepB ⟋ ] [ toggle ‹ ]
///
/// The user Cmd-drags menu-bar icons into the zones. A divider whose width is
/// blown up to 10,000 px pushes everything to its LEFT off the screen edge.
/// Because the zones nest (sepB sits right of sepA), three states are possible:
///
///   • Collapsed      sepB huge                 → hides everything but the toggle
///   • Show hidden    sepB normal, sepA huge     → hidden zone visible, always-hidden still tucked away
///   • Reveal all     sepB normal, sepA normal   → everything visible
///
/// No Accessibility permission required — we only resize our own status items.
final class MenuBarController: NSObject {

    private let statusBar = NSStatusBar.system
    private let settings = Settings.shared

    private let toggleItem: NSStatusItem
    private let primaryDivider: NSStatusItem      // sepB
    private var alwaysHiddenDivider: NSStatusItem? // sepA (only when enabled)

    private let expandedWidth: CGFloat = 22
    private let collapsedWidth: CGFloat = 10_000

    private var cancellables = Set<AnyCancellable>()
    private var autoHideTimer: Timer?
    private var hoverTimer: Timer?

    /// Transiently revealing the hidden zone because the pointer is in the menu bar.
    private var hoverPeeking = false {
        didSet { if oldValue != hoverPeeking { applyState() } }
    }

    /// Primary "hidden" zone collapsed?
    private var isCollapsed = true {
        didSet { applyState() }
    }
    /// Deep "always hidden" zone currently revealed? (only meaningful when expanded)
    private var alwaysHiddenRevealed = false {
        didSet { applyState() }
    }

    override init() {
        // Create right-to-left so the toggle stays right-most (new status items
        // insert to the left of existing ones).
        toggleItem     = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        primaryDivider = statusBar.statusItem(withLength: 22)
        super.init()

        configureItems()
        rebuildAlwaysHiddenDivider()
        wireHotKey()
        observeSettings()
        applyState()
        updateHoverMonitoring()
    }

    // MARK: - Item setup

    private func configureItems() {
        primaryDivider.autosaveName = "com.openbartender.divider.primary"
        toggleItem.autosaveName     = "com.openbartender.toggle"

        if let b = primaryDivider.button {
            attach(b)
            b.toolTip = "Cmd-drag icons to the LEFT of this divider to manage them"
        }
        if let b = toggleItem.button {
            attach(b)
            b.toolTip = "OpenBartender — click to show/hide menu bar icons"
        }
    }

    private func rebuildAlwaysHiddenDivider() {
        if settings.alwaysHiddenEnabled, alwaysHiddenDivider == nil {
            let item = statusBar.statusItem(withLength: expandedWidth)
            item.autosaveName = "com.openbartender.divider.alwaysHidden"
            if let b = item.button {
                attach(b)
                b.toolTip = "Icons LEFT of this divider are always hidden until revealed"
            }
            alwaysHiddenDivider = item
            applyIcons()
        } else if !settings.alwaysHiddenEnabled, let item = alwaysHiddenDivider {
            statusBar.removeStatusItem(item)
            alwaysHiddenDivider = nil
            alwaysHiddenRevealed = false
        }
    }

    private func attach(_ button: NSStatusBarButton) {
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    // MARK: - State

    private func applyState() {
        // A hover-peek temporarily expands the primary divider without touching
        // the persistent collapsed state.
        let showHidden = !isCollapsed || hoverPeeking
        primaryDivider.length = showHidden ? expandedWidth : collapsedWidth
        alwaysHiddenDivider?.length = alwaysHiddenRevealed ? expandedWidth : collapsedWidth
        applyIcons()
        isCollapsed ? cancelAutoHide() : scheduleAutoHideIfNeeded()
    }

    /// Refresh the menu-bar glyphs from the user's chosen styles.
    private func applyIcons() {
        let toggle = ToggleStyle(rawValue: settings.toggleStyle) ?? .chevronCompact
        let divider = DividerStyle(rawValue: settings.dividerStyle) ?? .diagonal

        if let b = toggleItem.button {
            if toggle == .custom {
                applyCustomToggle(to: b)
            } else {
                b.title = ""
                b.image = symbol(toggle.symbolName(collapsed: isCollapsed), "Toggle menu bar icons")
            }
        }
        primaryDivider.button?.image =
            symbol(divider.symbolName, "OpenBartender divider")
        alwaysHiddenDivider?.button?.image =
            symbol(divider.alwaysHiddenSymbolName, "OpenBartender always-hidden divider")
    }

    /// Render the toggle as a user-supplied image or emoji/text.
    private func applyCustomToggle(to button: NSStatusBarButton) {
        let path = settings.customToggleImage
        if !path.isEmpty, let image = NSImage(contentsOfFile: path) {
            let height: CGFloat = 18
            let ratio = image.size.width / max(image.size.height, 1)
            image.size = NSSize(width: height * ratio, height: height)
            image.isTemplate = false // preserve the user's colours
            button.image = image
            button.title = ""
        } else if !settings.customToggleText.isEmpty {
            button.image = nil
            button.title = settings.customToggleText
        } else {
            button.title = ""
            button.image = symbol("chevron.compact.left", "Toggle menu bar icons")
        }
    }

    func toggleCollapsed() {
        if !isCollapsed { alwaysHiddenRevealed = false } // collapsing hides the deep zone too
        isCollapsed.toggle()
    }

    private func toggleAlwaysHidden() {
        guard settings.alwaysHiddenEnabled else { return }
        if isCollapsed { isCollapsed = false }
        alwaysHiddenRevealed.toggle()
    }

    // MARK: - Auto-hide

    private func scheduleAutoHideIfNeeded() {
        cancelAutoHide()
        let delay = TimeInterval(settings.autoHideDelay)
        guard delay > 0 else { return }
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.toggleCollapsed()
        }
    }

    private func cancelAutoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }

    // MARK: - Show on hover

    private func updateHoverMonitoring() {
        if settings.showOnHover {
            guard hoverTimer == nil else { return }
            // Poll the pointer location — no event monitor, so no permission needed.
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
                self?.pollHover()
            }
        } else {
            hoverTimer?.invalidate()
            hoverTimer = nil
            hoverPeeking = false
        }
    }

    private func pollHover() {
        // Only peek when the user currently has the zone collapsed.
        guard settings.showOnHover, isCollapsed else {
            hoverPeeking = false
            return
        }
        let loc = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(loc, $0.frame, false) }) else {
            hoverPeeking = false
            return
        }
        var menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        if menuBarHeight <= 0 { menuBarHeight = 24 } // auto-hidden menu bar fallback
        hoverPeeking = loc.y >= screen.frame.maxY - menuBarHeight
    }

    // MARK: - Hotkey / settings observation

    private func wireHotKey() {
        HotKeyManager.shared.onTrigger = { [weak self] in self?.toggleCollapsed() }
        applyHotKey()
    }

    private func applyHotKey() {
        HotKeyManager.shared.update(enabled: settings.hotKeyEnabled,
                                    keyCode: UInt32(settings.hotKeyCode),
                                    carbonModifiers: UInt32(settings.hotKeyCarbonMods))
    }

    private func observeSettings() {
        settings.$alwaysHiddenEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildAlwaysHiddenDivider(); self?.applyState() }
            .store(in: &cancellables)

        Publishers.Merge3(
            settings.$hotKeyEnabled.map { _ in () },
            settings.$hotKeyCode.map { _ in () },
            settings.$hotKeyCarbonMods.map { _ in () }
        )
        .dropFirst()
        .receive(on: RunLoop.main)
        .sink { [weak self] in self?.applyHotKey() }
        .store(in: &cancellables)

        Publishers.MergeMany(
            settings.$toggleStyle.map { _ in () },
            settings.$dividerStyle.map { _ in () },
            settings.$customToggleText.map { _ in () },
            settings.$customToggleImage.map { _ in () }
        )
        .dropFirst()
        .receive(on: RunLoop.main)
        .sink { [weak self] in self?.applyIcons() }
        .store(in: &cancellables)

        settings.$showOnHover
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateHoverMonitoring() }
            .store(in: &cancellables)
    }

    // MARK: - Clicks & menu

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let secondary = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.option) ?? false)

        if secondary {
            present(menu: buildMenu(), from: sender)
        } else if sender == alwaysHiddenDivider?.button {
            toggleAlwaysHidden()
        } else {
            toggleCollapsed()
        }
    }

    private func present(menu: NSMenu, from sender: NSStatusBarButton) {
        let item: NSStatusItem
        if sender == primaryDivider.button { item = primaryDivider }
        else if sender == alwaysHiddenDivider?.button { item = alwaysHiddenDivider! }
        else { item = toggleItem }
        item.menu = menu
        sender.performClick(nil)
        item.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addAction(isCollapsed ? "Show Menu Bar Icons" : "Hide Menu Bar Icons",
                       #selector(menuToggle), self)

        if settings.alwaysHiddenEnabled {
            menu.addAction(alwaysHiddenRevealed ? "Hide Always-Hidden Icons" : "Reveal Always-Hidden Icons",
                           #selector(menuToggleAlwaysHidden), self)
        }

        menu.addItem(.separator())
        menu.addAction("Preferences…", #selector(openPreferences), self, key: ",")
        menu.addAction("Setup Guide…", #selector(openOnboarding), self)
        menu.addItem(.separator())
        menu.addAction("About OpenBartender", #selector(openOnboarding), self)
        menu.addAction("Quit OpenBartender", #selector(quit), self, key: "q")
        return menu
    }

    @objc private func menuToggle() { toggleCollapsed() }
    @objc private func menuToggleAlwaysHidden() { toggleAlwaysHidden() }
    @objc private func openPreferences() { AppWindows.shared.showPreferences() }
    @objc private func openOnboarding() { AppWindows.shared.showOnboarding() }
    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Helpers

    private func symbol(_ name: String, _ description: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)
        image?.isTemplate = true
        return image
    }
}

private extension NSMenu {
    func addAction(_ title: String, _ action: Selector, _ target: AnyObject, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        addItem(item)
    }
}
