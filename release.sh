#!/bin/bash
#
# release.sh — build, sign, notarize, staple, and attach a release artifact.
#
# Run this from your Mac (it needs Xcode, your Developer ID cert in Keychain,
# the notarization .p8, and `gh` authenticated). The CI workflow does the
# same thing on a hosted runner; this is the local equivalent for when you
# want to ship without depending on GitHub Actions.
#
# Usage:
#   ./release.sh <tag>                # uses defaults below
#   TAG=v1.0.1 ./release.sh           # override tag from env
#
# Required env (or edit the defaults below):
#   DEVELOPER_ID_TEAM   — team identifier the cert belongs to
#   DEVELOPER_ID_NAME   — full common name of the Developer ID cert
#   NOTARY_API_KEY      — path to AuthKey_*.p8
#   NOTARY_API_KEY_ID   — 10-char Key ID
#   NOTARY_API_ISSUER   — Issuer UUID

set -euo pipefail

cd "$(dirname "$0")"

TAG="${1:-${TAG:-v1.0.0}}"

DEVELOPER_ID_TEAM="${DEVELOPER_ID_TEAM:-XF983AFG67}"
DEVELOPER_ID_NAME="${DEVELOPER_ID_NAME:-Developer ID Application: shaden alawaji ($DEVELOPER_ID_TEAM)}"
NOTARY_API_KEY="${NOTARY_API_KEY:-$HOME/Downloads/AuthKey_6G55389M9N.p8}"
NOTARY_API_KEY_ID="${NOTARY_API_KEY_ID:-6G55389M9N}"
NOTARY_API_ISSUER="${NOTARY_API_ISSUER:-2c766156-b3e4-4aa7-9905-18d51e67eac7}"

if [ ! -f "$NOTARY_API_KEY" ]; then
    echo "Notary API key not found at: $NOTARY_API_KEY"
    echo "Set NOTARY_API_KEY to its path or place it at the default location."
    exit 1
fi

echo "── Tag:           $TAG"
echo "── Cert:          $DEVELOPER_ID_NAME"
echo "── Team:          $DEVELOPER_ID_TEAM"
echo "── Notary key:    $NOTARY_API_KEY"
echo

# 1. Generate Xcode project from project.yml.
echo "[1/7] Generating Xcode project…"
xcodegen generate >/dev/null

# 2. Build with Developer ID + hardened runtime + secure timestamp.
echo "[2/7] Building (Developer ID + hardened runtime)…"
rm -rf build HijriMenuBar.app
xcodebuild \
    -project HijriMenuBar.xcodeproj \
    -scheme HijriMenuBar \
    -configuration Release \
    -derivedDataPath build \
    DEVELOPMENT_TEAM="$DEVELOPER_ID_TEAM" \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID_NAME" \
    CODE_SIGN_STYLE=Manual \
    ENABLE_HARDENED_RUNTIME=YES \
    OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
    -quiet build

cp -R build/Build/Products/Release/HijriMenuBar.app .

# 3. Package for notarization.
echo "[3/7] Packaging for notarization…"
rm -f HijriMenuBar.zip
ditto -c -k --keepParent HijriMenuBar.app HijriMenuBar.zip

# 4. Submit to Apple notary service.
echo "[4/7] Submitting to Apple notary service (this can take a few minutes)…"
SUBMISSION_JSON=$(mktemp)
trap 'rm -f "$SUBMISSION_JSON"' EXIT

if ! xcrun notarytool submit HijriMenuBar.zip \
        --key "$NOTARY_API_KEY" \
        --key-id "$NOTARY_API_KEY_ID" \
        --issuer "$NOTARY_API_ISSUER" \
        --wait \
        --output-format json \
        | tee "$SUBMISSION_JSON"; then
    echo
    echo "notarytool submit failed."
    exit 1
fi

STATUS=$(/usr/bin/plutil -extract status raw -o - -- "$SUBMISSION_JSON" 2>/dev/null || echo "")
SUBMISSION_ID=$(/usr/bin/plutil -extract id raw -o - -- "$SUBMISSION_JSON" 2>/dev/null || echo "")

if [ "$STATUS" != "Accepted" ]; then
    echo
    echo "Notarization failed (status: $STATUS). Fetching log…"
    if [ -n "$SUBMISSION_ID" ]; then
        xcrun notarytool log "$SUBMISSION_ID" \
            --key "$NOTARY_API_KEY" \
            --key-id "$NOTARY_API_KEY_ID" \
            --issuer "$NOTARY_API_ISSUER" || true
    fi
    exit 1
fi

# 5. Staple the ticket so the .app carries proof of notarization offline.
echo "[5/7] Stapling notarization ticket…"
xcrun stapler staple HijriMenuBar.app
xcrun stapler validate HijriMenuBar.app
spctl --assess --type exec --verbose HijriMenuBar.app

# 6. Re-package with the stapled ticket inside.
echo "[6/7] Repackaging…"
rm -f HijriMenuBar.zip
ditto -c -k --keepParent HijriMenuBar.app HijriMenuBar.zip
ls -lh HijriMenuBar.zip

# 7. Push to GitHub Release.
echo "[7/7] Uploading to GitHub release $TAG…"
if gh release view "$TAG" >/dev/null 2>&1; then
    gh release upload "$TAG" HijriMenuBar.zip --clobber
else
    gh release create "$TAG" HijriMenuBar.zip \
        --title "$TAG" \
        --generate-notes \
        --notes "$(cat <<'BODY'
## Install

1. Download `HijriMenuBar.zip`, unzip, and drag `HijriMenuBar.app` into `/Applications`.
2. Double-click to launch — the build is **signed and notarized**, so Gatekeeper opens it without warnings.
3. The Hijri date appears in your menu bar — click it for the calendar.

### Add the widgets

After launching once, right-click your Desktop → **Edit Widgets**, find **Hijri Menu Bar** in the sidebar, and drag any size of the **Hijri Date** or **Prayer Times** widget onto the desktop.
BODY
)"
fi

echo
echo "Done. Release: $(gh release view "$TAG" --json url --jq .url)"
