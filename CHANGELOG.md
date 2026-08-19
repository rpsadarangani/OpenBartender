# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

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
