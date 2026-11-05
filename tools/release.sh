#!/usr/bin/env bash
# Build the notarized download: build/Qazaq-<version>.pkg, an installer that puts Qazaq.app in /Library/Input Methods.
# Needs (once): "Developer ID Application" and "Developer ID Installer" certificates in the login keychain
# (Xcode → Settings → Accounts → Manage Certificates; account holder of a paid Apple Developer Program team), and
#   xcrun notarytool store-credentials qazaq-notary --apple-id <apple id> --team-id <team id> --password <app-specific>
# Usage: tools/release.sh [--no-notarize]
#   Env overrides: APP_IDENTITY, INSTALLER_IDENTITY, NOTARY_PROFILE (default qazaq-notary).
#   --no-notarize builds an unnotarized pkg (unsigned if there is no installer identity) to check the packaging.
set -euo pipefail
cd "$(dirname "$0")/.."
NOTARIZE=1; [[ ${1:-} == --no-notarize ]] && NOTARIZE=0
PROFILE="${NOTARY_PROFILE:-qazaq-notary}"
identity() { security find-identity -v $2 | sed -n "s/.*\"\($1[^\"]*\)\".*/\1/p" | head -1; }
APP_ID="${APP_IDENTITY:-$(identity 'Developer ID Application' '-p codesigning')}"
PKG_ID="${INSTALLER_IDENTITY:-$(identity 'Developer ID Installer' '')}"
die() { echo "release: $*" >&2; exit 1; }
[[ -n $APP_ID ]] || die "no 'Developer ID Application' certificate in the keychain"
if (( NOTARIZE )); then
  [[ $APP_ID == "Developer ID Application"* ]] || die "notarization needs a Developer ID Application identity, not '$APP_ID'"
  [[ -n $PKG_ID ]] || die "no 'Developer ID Installer' certificate in the keychain"
  xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1 \
    || die "no notary credentials '$PROFILE' (run: xcrun notarytool store-credentials $PROFILE …)"
fi

VERSION="$(plutil -extract CFBundleShortVersionString raw qazaq/Info.plist)"
PKG="build/Qazaq-$VERSION.pkg"
tools/package.sh "$APP_ID"

# Component package. BundleIsRelocatable=false: otherwise Installer "upgrades" any Qazaq.app it finds elsewhere
# (~/Library/Input Methods, build/) instead of installing to /Library/Input Methods.
ROOT=build/pkg/root; SCRIPTS=build/pkg/scripts
rm -rf build/pkg; mkdir -p "$ROOT" "$SCRIPTS"
ditto build/Qazaq.app "$ROOT/Qazaq.app"
pkgbuild --analyze --root "$ROOT" build/pkg/component.plist >/dev/null
plutil -replace 0.BundleIsRelocatable -bool false build/pkg/component.plist
cat > "$SCRIPTS/postinstall" <<'EOF'
#!/bin/sh
# Quit a running (older) copy; macOS relaunches the input method on the next key press.
/usr/bin/pkill -x Qazaq || true
exit 0
EOF
chmod +x "$SCRIPTS/postinstall"
pkgbuild --root "$ROOT" --component-plist build/pkg/component.plist --scripts "$SCRIPTS" \
         --identifier dev.tair.inputmethod.Qazaq.pkg --version "$VERSION" \
         --install-location "/Library/Input Methods" build/pkg/Qazaq.pkg >/dev/null

# Product archive (what users download), signed with the installer identity when there is one.
rm -f "$PKG"
productbuild ${PKG_ID:+--sign "$PKG_ID" --timestamp} --package build/pkg/Qazaq.pkg "$PKG" >/dev/null

if (( NOTARIZE )); then
  OUT="$(xcrun notarytool submit "$PKG" --keychain-profile "$PROFILE" --wait --output-format plist)"
  STATUS="$(plutil -extract status raw - <<<"$OUT")"
  if [[ $STATUS != Accepted ]]; then
    xcrun notarytool log "$(plutil -extract id raw - <<<"$OUT")" --keychain-profile "$PROFILE" >&2 || true
    die "notarization: $STATUS"
  fi
  xcrun stapler staple "$PKG"
  spctl --assess --type install -vv "$PKG"
fi
shasum -a 256 "$PKG"
echo "built $PKG$( (( NOTARIZE )) || echo ' (NOT notarized)')"
(( NOTARIZE )) && echo "publish: gh release create v$VERSION '$PKG' --title 'Qazaq $VERSION'"
exit 0
