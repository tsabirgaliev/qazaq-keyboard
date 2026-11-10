# Qazaq (macOS input method)

Apple's "Russian – PC" layout, plus the nine Kazakh-only Cyrillic letters on the **Option** layer and an ABC-style
press-and-hold popup for them. No dead keys. The menu-bar indicator is "ҚҚ". Cmd+key shortcuts use Latin QWERTY
(as in Russian – PC).

| Key | Option | Option+Shift (or Caps+Option) |
|---|---|---|
| А | ә | Ә |
| Ы | і | І |
| Н | ң | Ң |
| Г | ғ | Ғ |
| Ц | ү | Ү |
| У | ұ | Ұ |
| К | қ | Қ |
| О | ө | Ө |
| Х | һ | Һ |

These replace what Russian – PC has on Option for those keys (Serbian/Macedonian/Belarusian letters, ÷ ± ∆ µ,
and the curly quotes “ ” that were on Option+Х).

One deliberate fix: on ANSI keyboards Apple's Russian – PC types a Latin `Ë` for Shift+Ё; this layout types Cyrillic `Ё`.

## Long press
Hold Н and a popup offers Ң, hold У for Ү Ұ, hold И (like Ы) for І, and likewise for А Г Ц К О Х (Shift/Caps gives
capitals).
Pick with 1–9, a click, or ←/→/Tab + Return; Esc or any other key keeps the letter. As in ABC, held letters and
digits don't repeat (punctuation, space and shortcuts do); `defaults write -g ApplePressAndHoldEnabled -bool false`
turns the popup and that off.

## Install
Download `Qazaq-<version>.pkg` from [Releases](https://github.com/tsabirgaliev/qazaq-keyboard/releases) and open it
(it installs `Qazaq.app` into `/Library/Input Methods`; Apple silicon and Intel, macOS 13+).
Log out and back in, then System Settings → Keyboard → Text Input → Input Sources → `+` → Kazakh → "Qazaq".
macOS asks you to approve a new input method (it can see what you type).
Uninstall: `sudo rm -rf "/Library/Input Methods/Qazaq.app" && sudo pkgutil --forget dev.tair.inputmethod.Qazaq.pkg`,
then log out/in.

### From source
```sh
tools/package.sh                       # builds build/Qazaq.app (signs with your Apple Development identity)
cp -R "build/Qazaq.app" ~/Library/Input\ Methods/
```
Don't also install the `.pkg` (two copies with the same bundle ID). Log out and back in, then System Settings → Keyboard → Text Input → Input Sources → `+` → Kazakh →
"Qazaq". macOS asks you to approve a new input method (it can see what you type); updating keeps that
approval only if every build is signed with the same identity.
To update: replace the app in `~/Library/Input Methods/` and run `pkill -x Qazaq` (macOS relaunches it).
Uninstall: delete the app from `~/Library/Input Methods/` and log out/in.

### Release (maintainer)
`tools/release.sh` builds `build/Qazaq-<version>.pkg` signed with Developer ID, notarizes and staples it; bump
`CFBundleShortVersionString`/`CFBundleVersion` in `qazaq/Info.plist` first. One-time setup is in the script's header
(Developer ID Application + Installer certificates, `xcrun notarytool store-credentials qazaq-notary`).
Then `gh release create v<version> build/Qazaq-<version>.pkg`.

## Rebuild from scratch
```sh
swift tools/extract_base.swift build/base.json                    # dump Apple's Russian PC via UCKeyTranslate
uv run --no-project python -I tools/build_keylayout.py            # base + overlay -> src/*.keylayout
tools/package.sh                                             # input method, bundles that .keylayout
# install it (above), then dump its copy of the layout and compare against Russian PC:
swift tools/extract_base.swift build/new.json "register:$HOME/Library/Input Methods/Qazaq.app" \
      dev.tair.inputmethod.Qazaq.keylayout.Qazaq
uv run --no-project python -I tools/verify.py
```
Change the overlay in `OVERLAY` at the top of `tools/build_keylayout.py`.

## Limitations
- Terminal doesn't pass arrow keys to input methods (use the numbers); password fields bypass all input methods.
- In Ghostty a pick erases the letter with a backspace (DEL) and types the variant, held letters without variants
  still repeat, and Return or an arrow key while the popup is open only closes it.
- macOS resolves modern keyboard types (40+) to the layout's ANSI key set. On ISO/JIS hardware the key left of Z
  therefore types `ё` instead of Apple's `]`/`[`; every other key is identical. ANSI keyboards are unaffected.
