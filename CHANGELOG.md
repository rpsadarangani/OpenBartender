# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]
### Fixed
- **macOS 26+**: icons no longer hid. macOS 26 moved menu bar layout into
  Control Center, where a divider wider than the space available overlaps its
  neighbours instead of pushing them off, so the fixed 10,000 px width stopped
  working. On macOS 26 and later the divider is now sized to the widest length
  that still fits, measured from OpenBartender's own status items — still no
  permissions. macOS 13–15 keep the original behaviour, unchanged.

## [0.3.0]
### Added
- **Reveal on hover**: when icons are hidden, move the pointer to the menu bar
  to peek at them; they re-hide when you leave. Uses pointer polling, so still
  no Accessibility permission.
- **Custom toggle icon**: pick "Custom (emoji / image)" in Appearance to use any
  emoji/text, or choose your own image (scaled to menu-bar height).

## [0.2.1]
### Added
- Appearance preferences: choose the menu-bar **toggle icon** (chevron, arrow,
  triangle, eye, half-circle) and **divider icon** (slash, dots, dot, dash,
  bars). Changes apply to the menu bar live.

## [0.2.0]
### Added
- Global keyboard shortcut to toggle icons (default `⌥⌘B`), via Carbon — no
  Accessibility permission required.
- SwiftUI Preferences window: launch-at-login, auto-hide delay, hotkey recorder,
  always-hidden toggle.
- Optional second "always-hidden" zone (three nested collapse states).
- First-run onboarding window explaining the ⌘-drag step.
- Generated app icon.

## [0.1.0]
### Added
- Initial release: hide/show menu bar icons using the expanding-divider
  technique. Menu-bar-only agent, no permissions, builds without Xcode.
