#!/bin/bash
# Builds Ticker via SwiftPM, assembles a proper .app bundle, and ad-hoc signs it
# (required so macOS can grant it Accessibility permission).
set -euo pipefail

APP="Ticker"
BUNDLE="build/${APP}.app"
CONFIG="${1:-release}"

# UNIVERSAL=1 builds a fat arm64 + x86_64 binary (Apple Silicon *and* Intel).
# Releases set this; plain dev builds stay host-arch for speed. The cross-arch
# slice requires full Xcode (SwiftPM's --arch uses xcbuild) — CI has it.
ARCH_FLAGS=""
if [ "${UNIVERSAL:-0}" = "1" ]; then
    ARCH_FLAGS="--arch arm64 --arch x86_64"
    echo ">> Compiling UNIVERSAL (arm64 + x86_64, ${CONFIG})..."
else
    echo ">> Compiling (${CONFIG})..."
fi
swift build -c "${CONFIG}" ${ARCH_FLAGS}
BIN="$(swift build -c "${CONFIG}" ${ARCH_FLAGS} --show-bin-path)/${APP}"

echo ">> Assembling ${BUNDLE} ..."
rm -rf "${BUNDLE}"
# Remove any legacy "Pulse.app" bundle from before the rename so it can't keep
# launching at login as a duplicate menu-bar app.
rm -rf "build/Pulse.app"
mkdir -p "${BUNDLE}/Contents/MacOS" "${BUNDLE}/Contents/Resources"
cp "${BIN}" "${BUNDLE}/Contents/MacOS/${APP}"
echo ">> Architectures: $(lipo -archs "${BUNDLE}/Contents/MacOS/${APP}")"
cp Info.plist "${BUNDLE}/Contents/Info.plist"
if [ -f Resources/Ticker.icns ]; then
    cp Resources/Ticker.icns "${BUNDLE}/Contents/Resources/Ticker.icns"
fi

# Localizations: copy every Resources/<lang>.lproj into the bundle so SwiftUI's
# Text/Toggle/Label (which look up Bundle.main) find the translated strings.
for lproj in Resources/*.lproj; do
    [ -d "${lproj}" ] || continue
    cp -R "${lproj}" "${BUNDLE}/Contents/Resources/"
done

# Prefer a STABLE self-signed identity so macOS keeps Accessibility / Screen
# Recording permission across rebuilds (ad-hoc signatures change every build,
# which makes macOS forget the grant and re-prompt). Set PULSE_SIGN_IDENTITY, or
# create a self-signed code-signing cert named "Ticker Code Signing" (see GUIDE).
# Note: no -v — a self-signed cert reads as "untrusted" and is hidden by -v, but
# codesign can still sign with it, which is all we need for stable TCC identity.
IDENTITY="${PULSE_SIGN_IDENTITY:-}"
if [ -z "${IDENTITY}" ] && security find-identity -p codesigning 2>/dev/null | grep -q "Ticker Code Signing"; then
    IDENTITY="Ticker Code Signing"
fi

if [ -n "${IDENTITY}" ]; then
    echo ">> Signing with stable identity: ${IDENTITY}"
    codesign --force --deep --sign "${IDENTITY}" "${BUNDLE}"
else
    echo ">> Ad-hoc signing (permissions will reset on each rebuild — see GUIDE to make them stick)"
    codesign --force --deep --sign - "${BUNDLE}"
fi

echo "OK - built ${BUNDLE}"
echo "   Run it with:  open \"${BUNDLE}\""
