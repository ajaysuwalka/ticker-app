#!/bin/bash
# Build, sign (Developer ID), notarize, staple, and package Ticker as a DMG for
# direct distribution OUTSIDE the App Store (the App Store's sandbox is
# incompatible with Ticker's Accessibility-based tracking — see docs/DISTRIBUTION.md).
#
# One-time setup (see docs/DISTRIBUTION.md):
#   1. Join the Apple Developer Program and create a "Developer ID Application" cert.
#   2. Store notarization credentials once:
#        xcrun notarytool store-credentials TickerNotary \
#          --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-pw"
#
# Usage:
#   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" ./tools/dist.sh [version]
set -euo pipefail

APP="Ticker"
BUNDLE="build/${APP}.app"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist 2>/dev/null || echo 1.0)}"
DMG="build/${APP}-${VERSION}.dmg"
NOTARY_PROFILE="${NOTARY_PROFILE:-TickerNotary}"

: "${DEVELOPER_ID:?Set DEVELOPER_ID to your 'Developer ID Application: NAME (TEAMID)' identity (see: security find-identity -v -p codesigning)}"

echo ">> [1/6] Building release..."
swift build -c release
BIN="$(swift build -c release --show-bin-path)/${APP}"

echo ">> [2/6] Assembling ${BUNDLE}..."
rm -rf "${BUNDLE}" "build/Pulse.app"
mkdir -p "${BUNDLE}/Contents/MacOS" "${BUNDLE}/Contents/Resources"
cp "${BIN}" "${BUNDLE}/Contents/MacOS/${APP}"
cp Info.plist "${BUNDLE}/Contents/Info.plist"
[ -f "Resources/${APP}.icns" ] && cp "Resources/${APP}.icns" "${BUNDLE}/Contents/Resources/${APP}.icns"

echo ">> [3/6] Signing with Developer ID + hardened runtime..."
# Hardened runtime (--options runtime) + secure timestamp are required for notarization.
# Ticker's features (Accessibility, event monitoring, ScreenCaptureKit) are gated by
# TCC at runtime, not by entitlements, so no special entitlements are needed.
codesign --force --deep --options runtime --timestamp \
  ${ENTITLEMENTS:+--entitlements "$ENTITLEMENTS"} \
  --sign "${DEVELOPER_ID}" "${BUNDLE}"
codesign --verify --strict --verbose=2 "${BUNDLE}"

echo ">> [4/6] Notarizing the app (this can take a few minutes)..."
ZIP="build/${APP}-notarize.zip"
ditto -c -k --sequesterRsrc --keepParent "${BUNDLE}" "${ZIP}"
xcrun notarytool submit "${ZIP}" --keychain-profile "${NOTARY_PROFILE}" --wait
rm -f "${ZIP}"

echo ">> [5/6] Stapling the ticket to the app..."
xcrun stapler staple "${BUNDLE}"

echo ">> [6/6] Building + notarizing the DMG..."
rm -f "${DMG}"
STAGING="$(mktemp -d)"
cp -R "${BUNDLE}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"
hdiutil create -volname "${APP} ${VERSION}" -srcfolder "${STAGING}" -ov -format UDZO "${DMG}"
rm -rf "${STAGING}"
xcrun notarytool submit "${DMG}" --keychain-profile "${NOTARY_PROFILE}" --wait
xcrun stapler staple "${DMG}"

echo ">> Verifying Gatekeeper acceptance..."
spctl -a -vvv -t install "${DMG}" || true
codesign --verify --deep --strict --verbose=2 "${BUNDLE}"

echo "OK - notarized & stapled ${DMG} (v${VERSION})"
echo "   Ship this DMG. Users double-click → drag Ticker to Applications, no Gatekeeper wall."
