import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A small click-to-record shortcut field, bridged into SwiftUI.
struct HotKeyRecorder: NSViewRepresentable {
    func makeNSView(context: Context) -> RecorderView { RecorderView() }
    func updateNSView(_ nsView: RecorderView, context: Context) { nsView.refresh() }
}

final class RecorderView: NSView {
    private let settings = Settings.shared
    private var recording = false {
        didSet { refresh() }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.borderWidth = 1
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let text = recording ? "Type shortcut…" : (settings.hotKeyDisplay.isEmpty ? "Click to record" : settings.hotKeyDisplay)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: recording ? NSColor.secondaryLabelColor : NSColor.labelColor,
        ]
        let size = text.size(withAttributes: attrs)
        let point = NSPoint(x: (bounds.width - size.width) / 2,
                            y: (bounds.height - size.height) / 2)
        text.draw(at: point, withAttributes: attrs)
    }

    func refresh() {
        layer?.borderColor = (recording ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        recording.toggle()
        if recording { window?.makeFirstResponder(self) }
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }

        if event.keyCode == UInt16(kVK_Escape) { // cancel
            window?.makeFirstResponder(nil)
            return
        }

        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        // Require at least one "real" modifier so we don't capture bare keys.
        guard mods.contains(.command) || mods.contains(.option) || mods.contains(.control) else {
            NSSound.beep()
            return
        }

        let key = (event.charactersIgnoringModifiers ?? "").uppercased()
        settings.hotKeyCode = Int(event.keyCode)
        settings.hotKeyCarbonMods = Int(Settings.carbonModifiers(from: mods))
        settings.hotKeyDisplay = Settings.displayString(flags: mods, key: key)

        window?.makeFirstResponder(nil)
    }
}
