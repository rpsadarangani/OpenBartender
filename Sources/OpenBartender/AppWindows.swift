import AppKit
import SwiftUI

/// Owns the app's auxiliary windows. Since OpenBartender is an `.accessory`
/// app (no Dock icon), we create plain `NSWindow`s hosting SwiftUI and keep
/// strong references so they aren't deallocated while on screen.
final class AppWindows: NSObject, NSWindowDelegate {
    static let shared = AppWindows()

    private var preferences: NSWindow?
    private var onboarding: NSWindow?

    func showPreferences() {
        if preferences == nil {
            preferences = makeWindow(title: "OpenBartender Preferences",
                                     size: NSSize(width: 460, height: 420),
                                     content: PreferencesView())
        }
        bringToFront(preferences)
    }

    func showOnboarding() {
        if onboarding == nil {
            onboarding = makeWindow(title: "Welcome to OpenBartender",
                                    size: NSSize(width: 520, height: 460),
                                    content: OnboardingView { [weak self] in
                                        self?.onboarding?.close()
                                    })
        }
        bringToFront(onboarding)
    }

    // MARK: - Plumbing

    private func makeWindow<Content: View>(title: String, size: NSSize, content: Content) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false)
        window.title = title
        window.contentView = NSHostingView(rootView: content)
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        return window
    }

    private func bringToFront(_ window: NSWindow?) {
        NSApp.setActivationPolicy(.regular) // temporarily show in Dock so window can focus
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Return to menu-bar-only once no auxiliary windows remain visible.
        DispatchQueue.main.async {
            let anyVisible = [self.preferences, self.onboarding].contains { $0?.isVisible == true }
            if !anyVisible { NSApp.setActivationPolicy(.accessory) }
        }
    }
}
