#!/usr/bin/env bash
# Builds OpenBartender.app from the SwiftPM executable. No Xcode required —
# only the Command Line Tools (`xcode-select --install`).
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP_NAME="OpenBartender"
APP_BUNDLE="${APP_NAME}.app"
BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)"

if [ ! -f Resources/AppIcon.icns ]; then
    echo "==> Generating app icon…"
    rm -rf build/AppIcon.iconset
    swift scripts/make-icon.swift build/AppIcon.iconset
    iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
fi

echo "==> Compiling (${CONFIG})…"
swift build -c "${CONFIG}"

echo "==> Assembling ${APP_BUNDLE}…"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BIN_PATH}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist       "${APP_BUNDLE}/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

# Ad-hoc code signature so macOS treats the bundle consistently
# (and so launch-at-login via SMAppService can register).
codesign --force --deep --sign - "${APP_BUNDLE}" >/dev/null 2>&1 || \
    echo "    (codesign skipped — app still runs)"

echo "==> Done: ${PWD}/${APP_BUNDLE}"
echo "    Run it with:  open ${APP_BUNDLE}"
echo "    Install with: cp -r ${APP_BUNDLE} /Applications/"
