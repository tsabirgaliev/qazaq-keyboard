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

## Known limitation
macOS resolves modern keyboard types (40+) to the layout's ANSI key set. On ISO/JIS hardware the key left of Z
therefore types `ё` instead of Apple's `]`/`[`; every other key is identical. ANSI keyboards are unaffected.
