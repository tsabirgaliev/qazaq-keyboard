#!/usr/bin/env bash
# Assemble build/"Kazakh PC+.bundle" from src/. Run from anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="Kazakh - PC+"
BUNDLE="build/Kazakh PC+.bundle"
BUNDLE_ID="dev.tair.keyboardlayout.kazakhpcplus"
SOURCE_ID="$BUNDLE_ID.kazakhpcplus"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/Resources/English.lproj"
cp "src/$NAME.keylayout" "$BUNDLE/Contents/Resources/$NAME.keylayout"
printf '"%s" = "%s";\n' "$NAME" "$NAME" > "$BUNDLE/Contents/Resources/English.lproj/InfoPlist.strings"

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleName</key>
	<string>$NAME</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundlePackageType</key>
	<string>BNDL</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>KLInfo_$NAME</key>
	<dict>
		<key>TISInputSourceID</key>
		<string>$SOURCE_ID</string>
		<key>TISIntendedLanguage</key>
		<string>kk</string>
		<key>TISIconIsTemplate</key>
		<true/>
		<key>TISIconLabels</key>
		<dict>
			<key>Primary</key>
			<string>ҚҚ</string>
		</dict>
	</dict>
</dict>
</plist>
PLIST
plutil -lint "$BUNDLE/Contents/Info.plist"
echo "built $BUNDLE"
