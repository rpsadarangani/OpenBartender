# Contributing to OpenBartender

Thanks for your interest in improving OpenBartender! 🎉

## Prerequisites

- macOS 13 or later
- Xcode Command Line Tools: `xcode-select --install`
  (a full Xcode install is **not** required)

## Development loop

```bash
git clone https://github.com/<you>/openbartender.git
cd openbartender

make debug     # compile
make run       # build the .app and launch it
make clean     # reset build artifacts
```

Source lives in `Sources/OpenBartender/`. See the "Project layout" section of
the [README](README.md) for what each file does.

## Coding conventions

- Swift, AppKit + a little SwiftUI. Keep the app dependency-free.
- No new runtime permissions: the whole point is that OpenBartender needs
  none. Anything requiring Accessibility/Screen Recording should be opt-in and
  clearly justified.
- Match the existing style (4-space indent, `// MARK:` sections).

## Submitting changes

1. Fork and create a feature branch.
2. Make sure `swift build -c release` and `./scripts/build-app.sh` both succeed.
3. Open a PR with a clear description and, for UI changes, a screenshot.

## Releasing (maintainers)

Tag a version and push — the `Release` workflow builds and attaches the zip:

```bash
git tag v0.2.0
git push origin v0.2.0
```
