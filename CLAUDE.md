# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A macOS keyboard layout, "Kazakh - PC+": Apple's built-in "Russian – PC" (`com.apple.keylayout.RussianWin`) plus the nine Kazakh-only letters on the Option layer. No dead keys; the menu-bar indicator is a text label (`TISIconLabels` = `ҚҚ`), deliberately no icon file. `README.md` has the key table and install steps.

## Pipeline (build/ is generated, src/ is generated-but-kept)

The `.keylayout` is never hand-edited; it is generated from a dump of Apple's own layout:

1. `swift tools/extract_base.swift build/base.json` — dumps Russian PC and US via `UCKeyTranslate` for every keycode × modifier state × keyboard type (ansi/iso/jis).
2. `uv run --no-project python -I tools/build_keylayout.py` — applies the Kazakh overlay (`OVERLAY` dict) and the `Ë`→`Ё` fix to the dump and writes `src/Kazakh - PC+.keylayout`.
3. `tools/package.sh` — wraps it into `build/Kazakh PC+.bundle` (Info.plist, InfoPlist.strings; no icns).
4. Install: `cp -R "build/Kazakh PC+.bundle" ~/Library/Keyboard\ Layouts/` then log out/in (macOS only rescans at login).
5. Verify (no logout needed): dump the installed layout and diff against Russian PC:
   ```sh
   swift tools/extract_base.swift build/new.json "register:$HOME/Library/Keyboard Layouts/Kazakh PC+.bundle" dev.tair.keyboardlayout.kazakhpcplus.kazakhpcplus
   uv run --no-project python -I tools/verify.py
   ```

`verify.py` is the only test; it must report 0 mismatches. Always reinstall the bundle (`rm -rf` the old one first) before step 5, and check the extractor didn't print `cannot load …` — if it fails, `build/new.json` is stale and verify.py will pass against old data.

## Gotchas learned the hard way

- Use `uv` for Python (user preference); `-I` keeps stray local modules from being imported.
- `xmllint` can't parse the file as-is: it uses XML 1.1 (needed for control-char references like `&#x0008;`). To DTD-validate, sed the version to 1.0 and replace control refs in a scratch copy, then `xmllint --dtdvalid /System/Library/DTDs/KeyboardLayout.dtd`.
- The registered input-source ID is derived by macOS, not just from `TISInputSourceID`; it changed once (`…kazakhpcplus.keylayout.Kazakh-PC` → `…kazakhpcplus.kazakhpcplus`) when the bundle changed. List sources via `TISCreateInputSourceList` if the extractor can't find it. Registration only works for bundles inside `~/Library/Keyboard Layouts`, not `build/`.
- `<layouts>` keyboard-type ranges: macOS ignores explicit entries for modern types (40+) and resolves them to the ANSI set, so ISO/JIS hardware gets ANSI keys 10/50 (key left of Z types `ё` instead of `]`). Extensive experiments found no `<layout>` configuration that fixes this; `LAYOUTS` in `build_keylayout.py` is the standard Ukelele/Apple list. This Mac is ANSI. `verify.py` treats the ISO/JIS key-50 diffs as known.
- Apple's Russian PC Command layer is already Latin QWERTY, so it's copied as-is (not derived from US).
- Every Option key the overlay uses already had Apple symbols (Serbian/Macedonian letters, ÷ ± ∆ µ, curly quotes “ ” on Option+Х); overwriting was an explicit user decision.
- Dead end: macOS press-and-hold (long-press accent picker) does not work for Cyrillic. Apple's `TextInput_kk` variant tables are iOS keyboard data; held keys on Apple's own built-in "Kazakh" layout also show no popup (and don't repeat). Custom layouts can't add variants (tables are SIP-protected). A long-press UX would need a custom input method (IMKit) app.
