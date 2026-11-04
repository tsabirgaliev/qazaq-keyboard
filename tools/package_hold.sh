#!/usr/bin/env bash
# Build + sign the "Kazakh – Long Press" input method into build/"Kazakh PC+ Hold.app". Does NOT install it.
# Usage: tools/package_hold.sh [signing identity | -]   (default: first Apple Development identity, else ad hoc)
# Needs src/"Kazakh - PC+.keylayout" (tools/build_keylayout.py) — the input method bundles its own copy.
set -euo pipefail
cd "$(dirname "$0")/.."
APP="build/Kazakh PC+ Hold.app"
RES="$APP/Contents/Resources"
IDENTITY="${1:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development[^"]*\)".*/\1/p' | head -1)}"
IDENTITY="${IDENTITY:--}"

rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$RES/en.lproj"
uv run --no-project python -I tools/build_variants.py "$RES/variants.json"
swiftc -O -swift-version 5 -framework Cocoa -framework InputMethodKit hold/Sources/*.swift -o "$APP/Contents/MacOS/KazakhHold"
cp hold/Info.plist "$APP/Contents/Info.plist"
cp hold/en.lproj/InfoPlist.strings "$RES/en.lproj/"
cp "src/Kazakh - PC+.keylayout" "$RES/"
swift hold/make_icon.swift "$RES/icon.tiff"   # "ҚҚ" menu icon
plutil -lint "$APP/Contents/Info.plist" "$RES/en.lproj/InfoPlist.strings" >/dev/null
codesign --force --sign "$IDENTITY" --options runtime "$APP"
codesign --verify --deep --strict "$APP"
echo "built $APP (signed with: $IDENTITY)"
