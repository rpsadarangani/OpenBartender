import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    @ObservedObject private var settings = Settings.shared

    private let delayOptions: [(String, Int)] = [
        ("Off", 0), ("5 seconds", 5), ("10 seconds", 10), ("30 seconds", 30), ("1 minute", 60),
    ]

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)

                Picker("Auto-hide after", selection: $settings.autoHideDelay) {
                    ForEach(delayOptions, id: \.1) { Text($0.0).tag($0.1) }
                }

                Toggle("Reveal on hover", isOn: $settings.showOnHover)
                Text("When hidden, move the pointer to the menu bar to peek at your icons; they re-hide when you leave.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                Picker("Toggle icon", selection: $settings.toggleStyle) {
                    ForEach(ToggleStyle.allCases) { style in
                        Label {
                            Text(style.title)
                        } icon: {
                            Image(systemName: style.symbolName(collapsed: false))
                        }
                        .tag(style.rawValue)
                    }
                }
                Picker("Divider icon", selection: $settings.dividerStyle) {
                    ForEach(DividerStyle.allCases) { style in
                        Label {
                            Text(style.title)
                        } icon: {
                            Image(systemName: style.symbolName)
                        }
                        .tag(style.rawValue)
                    }
                }
                if settings.toggleStyle == ToggleStyle.custom.rawValue {
                    TextField("Emoji or text", text: $settings.customToggleText, prompt: Text("e.g. 🍸"))
                    HStack {
                        Button("Choose Image…", action: chooseImage)
                        if !settings.customToggleImage.isEmpty {
                            Button("Remove Image") { settings.clearCustomToggleImage() }
                        }
                        Spacer()
                        if !settings.customToggleImage.isEmpty {
                            Text((settings.customToggleImage as NSString).lastPathComponent)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                        }
                    }
                    Text("An image takes priority over text and is scaled to menu-bar height.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Changes apply to the menu bar immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Always-Hidden Zone") {
                Toggle("Enable a second, always-hidden zone", isOn: $settings.alwaysHiddenEnabled)
                Text("Adds a dotted divider (⋯). Icons to its left stay hidden even when you reveal the main zone — surface them only on demand.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Global Shortcut") {
                Toggle("Enable global shortcut", isOn: $settings.hotKeyEnabled)
                HStack {
                    Text("Toggle icons")
                    Spacer()
                    HotKeyRecorder()
                        .frame(width: 140, height: 24)
                        .disabled(!settings.hotKeyEnabled)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 620)
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .gif, .image]
        panel.prompt = "Use Icon"
        if panel.runModal() == .OK, let url = panel.url {
            settings.setCustomToggleImage(from: url)
        }
    }
}
