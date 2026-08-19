import SwiftUI

struct OnboardingView: View {
    @ObservedObject private var settings = Settings.shared
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "menubar.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .padding(.top, 28)

            Text("Welcome to OpenBartender")
                .font(.title).bold()

            Text("Tidy up your menu bar in three steps.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                step(1, "menubar.dock.rectangle",
                     "Find the divider (⟋) and chevron (‹) that OpenBartender added to your menu bar.")
                step(2, "hand.draw",
                     "Hold ⌘ (Command) and drag the icons you want to manage so they sit to the LEFT of the divider.")
                step(3, "eye.slash",
                     "Click the chevron — or press your global shortcut (\(settings.hotKeyDisplay)) — to hide and show them.")
            }
            .padding(.horizontal, 32)

            Spacer()

            HStack {
                Button("Open Preferences…") { AppWindows.shared.showPreferences() }
                Spacer()
                Button("Got it") {
                    settings.hasOnboarded = true
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 520, height: 460)
    }

    private func step(_ number: Int, _ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text("Step \(number)").font(.caption).foregroundStyle(.secondary)
                Text(text)
            }
        }
    }
}
