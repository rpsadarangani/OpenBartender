import AppKit

// OpenBartender runs as a menu-bar-only agent (no Dock icon, no main window).
// `.accessory` is the runtime equivalent of LSUIElement.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()
