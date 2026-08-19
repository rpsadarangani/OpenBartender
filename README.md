# OpenBartender

An open-source menu bar manager for macOS — hide the menu bar icons you don't
always need and reveal them on demand. A free, Bartender-style utility.

- 🪶 **Lightweight** — a single native AppKit agent, no background daemons.
- 🔒 **No Accessibility permission required** — it only ever resizes its *own*
  status items (the global hotkey uses Carbon, which also needs no permission).
- ⌨️ **Global shortcut** — toggle icons from anywhere (default `⌥⌘B`, rebindable).
- 🗂️ **Two zones** — a normal "hidden" zone plus an optional deeper
  "always-hidden" zone you reveal only on demand.
- ⚙️ **Preferences window** — launch-at-login, auto-hide delay, hotkey recorder.
- 🎨 **Customizable icons** — pick the toggle and divider glyphs (chevron, arrow,
  eye, dots…); changes apply to the menu bar live.
- 👋 **First-run onboarding** so the ⌘-drag step is never a surprise.
- 🧰 **No Xcode required to build** — just the Command Line Tools + SwiftPM.
- 📜 **MIT licensed.**

## How it works

macOS doesn't let an app touch *other* apps' menu bar icons directly. Instead,
OpenBartender adds its own status items and controls their width. A divider
whose width is blown up to 10,000 px pushes everything to its **left** off the
screen edge. Because the zones nest, three states are possible:

```
[ always-hidden icons ] [ ⋯ sepA ] [ hidden icons ] [ ⟋ sepB ] [ ‹ toggle ]
        └─ revealed on demand ─┘        └─ toggled with the chevron ─┘

Collapsed    sepB huge                → only the toggle shows
Show hidden  sepB normal, sepA huge   → hidden zone visible; always-hidden tucked away
Reveal all   both normal              → everything visible
```

This is the same technique used by Hidden Bar and Dozer — proven and
permission-free. (The optional always-hidden zone is off by default; enable it
in Preferences.)

## Download

1. Grab the latest `OpenBartender-*.zip` from the
   [**Releases**](../../releases/latest) page.
2. Unzip it and drag **OpenBartender.app** into `/Applications`.
3. **First launch** (the app is not yet notarized, so Gatekeeper will warn):
   right-click the app → **Open** → **Open**. Alternatively:

   ```bash
   xattr -dr com.apple.quarantine /Applications/OpenBartender.app
   open /Applications/OpenBartender.app
   ```

There's no window — look for the **`⟋`** divider and **`‹`** chevron in your
menu bar, and the onboarding guide that appears on first run.

## Build from source

Requires macOS 13+ and the Xcode Command Line Tools (`xcode-select --install`).
A full Xcode install is **not** required.

```bash
git clone https://github.com/rpsadarangani/OpenBartender.git
cd OpenBartender
make run                        # builds OpenBartender.app and launches it
# or: ./scripts/build-app.sh && cp -r OpenBartender.app /Applications/
```

Handy targets: `make build`, `make app`, `make run`, `make zip`, `make clean`.

## Usage

1. After launching, you'll see a **divider (⟋)** and a **chevron (‹)** in the menu bar.
2. Hold **⌘ (Command)** and **drag** the menu bar icons you want to manage so
   they sit to the **left of the divider**.
3. **Click the chevron** to hide/show those icons.
4. **Right-click** (or **⌥-click**) either icon for the menu:
   - Show/Hide Menu Bar Icons
   - Auto-hide After (Off / 5s / 10s / 30s)
   - Launch at Login
   - About / Quit

Your collapsed/expanded state and icon positions persist across restarts.

## Project layout

```
Package.swift                       SwiftPM manifest (executable target)
Sources/OpenBartender/
  main.swift                        NSApplication bootstrap (.accessory / LSUIElement)
  AppDelegate.swift                 Creates the controller; shows onboarding on first run
  MenuBarController.swift           Status items, three-zone collapse logic, menu
  Settings.swift                    UserDefaults-backed, observable preference store
  HotKeyManager.swift               Carbon global hotkey (no permission needed)
  HotKeyRecorder.swift              Click-to-record shortcut field (AppKit → SwiftUI)
  PreferencesView.swift             SwiftUI settings window
  OnboardingView.swift              SwiftUI first-run guide
  AppWindows.swift                  Hosts the SwiftUI windows for an accessory app
Resources/Info.plist                Bundle metadata (LSUIElement = true)
Resources/AppIcon.icns              Generated app icon
scripts/build-app.sh                Compiles + assembles OpenBartender.app
scripts/make-icon.swift             Renders the app icon programmatically
```

## Roadmap / ideas

- A second "always hidden" section (three-item model, like Bartender's).
- A real Preferences window (SwiftUI) instead of the About alert.
- Search / triggers to temporarily reveal a specific icon.
- Signed + notarized release builds and a Homebrew cask.

## License

MIT — see [LICENSE](LICENSE).
