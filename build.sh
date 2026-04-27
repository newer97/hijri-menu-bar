#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen not found. Install with: brew install xcodegen"
    exit 1
fi

echo "Generating Xcode project…"
xcodegen generate >/dev/null

# Auto-detect signing: use Developer ID if available, otherwise ad-hoc.
SIGN_OVERRIDES=()
if [ -n "${CI:-}" ] || ! security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID Application"; then
    echo "Using ad-hoc signing (no Developer ID found, or running in CI)."
    SIGN_OVERRIDES=(
        DEVELOPMENT_TEAM=
        CODE_SIGN_IDENTITY=-
        CODE_SIGN_STYLE=Manual
        ENABLE_HARDENED_RUNTIME=NO
        CODE_SIGNING_REQUIRED=NO
        CODE_SIGNING_ALLOWED=YES
    )
fi

echo "Building…"
xcodebuild \
    -project HijriMenuBar.xcodeproj \
    -scheme HijriMenuBar \
    -configuration Release \
    -derivedDataPath build \
    "${SIGN_OVERRIDES[@]}" \
    -quiet build

APP_SRC="build/Build/Products/Release/HijriMenuBar.app"
APP_DST="HijriMenuBar.app"

if [ ! -d "$APP_SRC" ]; then
    echo "Build failed: $APP_SRC not found"
    exit 1
fi

rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"

# When falling back to ad-hoc signing, re-sign the bundle defensively so the
# embedded widget extension is consistent.
if [ ${#SIGN_OVERRIDES[@]} -gt 0 ]; then
    codesign --force --deep --sign - "$APP_DST" 2>/dev/null || true
fi

echo
echo "Built $APP_DST"
echo "Run:     open $APP_DST"
echo "Install: cp -R $APP_DST /Applications/ && open /Applications/$APP_DST"
echo "Widgets: After installing to /Applications, right-click Desktop → Edit Widgets."
