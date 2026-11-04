# Kazakh – PC+ (macOS keyboard layout)

Apple's "Russian – PC" layout, plus the nine Kazakh-only Cyrillic letters on the **Option** layer.
No dead keys. No icon file: the menu-bar indicator is the text label "ҚҚ" (`TISIconLabels` in Info.plist). Cmd+key shortcuts use Latin QWERTY (as in Russian – PC).

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

## Install
```sh
tools/package.sh                                   # builds build/Kazakh PC+.bundle
cp -R "build/Kazakh PC+.bundle" ~/Library/Keyboard\ Layouts/
```
Log out and back in, then System Settings → Keyboard → Text Input → Input Sources → `+` → Kazakh → "Kazakh - PC+".
Uninstall: delete the bundle from `~/Library/Keyboard Layouts/` and log out/in.

## Rebuild from scratch
```sh
swift tools/extract_base.swift build/base.json                    # dump Apple's Russian PC via UCKeyTranslate
uv run --no-project python -I tools/build_keylayout.py            # base + overlay -> src/*.keylayout
tools/package.sh
swift tools/extract_base.swift build/new.json "register:$HOME/Library/Keyboard Layouts/Kazakh PC+.bundle" \
      dev.tair.keyboardlayout.kazakhpcplus.kazakhpcplus    # dump the installed layout
uv run --no-project python -I tools/verify.py                     # compare against Russian PC
```
Change the overlay in `OVERLAY` at the top of `tools/build_keylayout.py`.

## Long-press popup (optional input method)
"Kazakh - PC+ Hold" is the same layout plus an ABC-style press-and-hold popup: hold Н and a popup offers Ң,
hold У for Ұ Ү, and likewise for А Ы Г Ц К О Х (Shift/Caps gives capitals). Pick with 1–9, a click, or ←/→/Tab + Return;
Esc or any other key keeps the letter. As in ABC, held letters and digits don't repeat (punctuation, space and
shortcuts do); `defaults write -g ApplePressAndHoldEnabled -bool false` turns the popup and that off.
It is a separate input source that bundles its own copy of the layout, so it doesn't need the layout bundle above.
```sh
tools/package_hold.sh                       # builds build/Kazakh PC+ Hold.app (signs with your Apple Development identity)
cp -R "build/Kazakh PC+ Hold.app" ~/Library/Input\ Methods/
```
Log out and back in, then Input Sources → `+` → Kazakh → "Kazakh - PC+ Hold". macOS asks you to approve a new input
method (it can see what you type); updating keeps that approval only if every build is signed with the same identity.
Limitations: Terminal doesn't pass arrow keys to input methods (use the numbers); password fields bypass all input methods.

## Known limitation
macOS resolves modern keyboard types (40+) to the layout's ANSI key set. On ISO/JIS hardware the key left of Z
therefore types `ё` instead of Apple's `]`/`[`; every other key is identical. ANSI keyboards are unaffected.
