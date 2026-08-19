import SwiftUI

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
        .frame(width: 460, height: 420)
    }
}
