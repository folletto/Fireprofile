#!/usr/bin/env bash
# build.sh — Compiles Fireprofile and packages it as a macOS .app bundle.
# Run from the project root: ./build.sh
set -euo pipefail

APP_NAME="Fireprofile"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_DIR=".build/release"


# -- Compiling ---------------------------------------------------------------------
echo "🔨  Compiling ${APP_NAME} (release)…"
swift build -c release


# -- Assembling --------------------------------------------------------------------
echo "📦  Assembling ${BUNDLE_NAME}…"
rm -rf "${BUNDLE_NAME}"
mkdir -p "${BUNDLE_NAME}/Contents/MacOS"
mkdir -p "${BUNDLE_NAME}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}"  "${BUNDLE_NAME}/Contents/MacOS/"
cp "Resources/Info.plist"      "${BUNDLE_NAME}/Contents/"

# Copy all resource files (icons etc.) into Contents/Resources/
for f in Resources/*; do
    fname="$(basename "$f")"
    [ "$fname" = "Info.plist" ] && continue
    cp "$f" "${BUNDLE_NAME}/Contents/Resources/"
done


# -- Signing -----------------------------------------------------------------------
echo "✍️   Ad-hoc signing…"
codesign --force --deep --sign - "${BUNDLE_NAME}" 2>/dev/null || {
    echo "   (codesign skipped — not blocking)"
}


# -- Done --------------------------------------------------------------------------
echo ""
echo "✅  Done!  →  ${BUNDLE_NAME}"
echo ""
echo "Deployment layout (all items in the same folder):"
echo "   ${BUNDLE_NAME}/    ← this app"
echo "   Firefox.app/        ← copy your Firefox here"

