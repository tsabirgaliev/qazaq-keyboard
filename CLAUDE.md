# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A macOS keyboard layout, "Kazakh - PC+": Apple's built-in "Russian – PC" (`com.apple.keylayout.RussianWin`) plus the nine Kazakh-only letters on the Option layer. No dead keys; the menu-bar indicator is a text label (`TISIconLabels` = `ҚҚ`), deliberately no icon file. `README.md` has the key table and install steps. Optionally, the `hold/` input method adds an ABC-style long-press popup on top of the same layout (see below).

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
## Long-press input method (`hold/`)

"Kazakh - PC+ Hold" (`dev.tair.inputmethod.KazakhPCPlus`, mode `….kk`) is a keyboard-type IMKit input method: it calls `overrideKeyboardWithKeyboardNamed:@"Kazakh - PC+"` so the client types with the `.keylayout` bundled in its Resources, returns NO for every event, and only steps in on key repeats (`HoldController.swift`): letter/digit repeats are swallowed (ABC's measured rule) and a repeat of a letter in `variants.json` opens the popup (`PopupPanel.swift`); picking calls `insertText(_:replacementRange:)` over the typed letter.
- Build: `tools/package_hold.sh` (runs `tools/build_variants.py`, which generates `variants.json` from `OVERLAY` + `EXTRA` and asserts it's consistent). Sign every build with the same Apple Development identity: ad hoc (`-`) builds get a new identity each time and macOS re-asks to approve the input method.
- Debug log: `defaults write dev.tair.inputmethod.KazakhPCPlus debug -bool true` → `/tmp/kazakhhold.log` (logs keystrokes, so off by default).
- Why not the obvious designs: macOS's own press-and-hold has no Cyrillic popup (Apple's "Kazakh" too; the `TextInput_kk` tables are iOS data, SIP-protected). A third-party *palette* IM (like Apple's PressAndHold.app) gets activate/deactivate but never key events — only the current input source does. A CGEventTap helper would need Accessibility + Input Monitoring.
- Client quirks found by testing: TextEdit ignores `insertText` sent while it handles an arrow key (so arrows only move the highlight; the text changes on pick); Terminal never routes arrow keys to IMs and returns no line rect (`firstRect` works); clients reconnecting after the IM process restarts get no `activateServer`, so the override is also applied in `init` and lazily in `handle`; the very first key after a restart can still be missed.
- Ghostty has no text model: `selectedRange` is `{0,0}`, `replacementRange` is ignored, and it encodes keys the IM swallows unless marked text is up. So a `{0,0}` caret after typing a letter means "terminal": `open` marks a placeholder space (suppresses Ghostty's key encoding while the popup is open) and `pick` commits DEL + variant (Ghostty sends committed text to the pty raw). Its own keyDown path drops text starting with a control char, but committed text after marked text bypasses that.
- Claude Desktop (Electron) and Ghostty return uninitialized garbage from `firstRect` (≈`(1.6e-314, 0, …)`); `onScreen` rejects it and the line rect is used. Claude Desktop's `attributedSubstring` readback after a pick is stale (log says "text now н" although it worked).
- Testing happens in a Tart macOS VM (synthetic CGEvents over SSH need Accessibility granted to `/usr/libexec/sshd-keygen-wrapper`; selecting a newly installed IM via TIS only works from a GUI-session process after a re-login). Don't send synthetic keys while System Settings may be showing an approval prompt, and don't kill Settings to get focus.
