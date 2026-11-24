# Qazaq (macOS input method)

Apple's "Russian – PC" layout, plus the Kazakh-only Cyrillic letters (and ё) on the **Option** layer and an
ABC-style press-and-hold popup for them. No dead keys. The menu-bar indicator is "ҚҚ". Cmd+key shortcuts use Latin
QWERTY (as in Russian – PC).

| Key | Option | Option+Shift (or Caps+Option) | Long press |
|---|---|---|---|
| А | ә | Ә | ә |
| Ы, И | і | І | і |
| Н | ң | Ң | ң |
| Г | ғ | Ғ | ғ |
| Ц | ү | Ү | ү |
| У | ұ | Ұ | ү ұ |
| К | қ | Қ | қ |
| О | ө | Ө | ө |
| Х | һ | Һ | һ |
| Е | ё | Ё | ё |

(Shift/Caps+long press gives the capitals.) These replace what Russian – PC has on Option for those keys
(Serbian/Macedonian/Belarusian letters, ÷ ± ∆ µ, and the curly quotes “ ” that were on Option+Х).

One more change: the bare Ё key (top-left, `` ` `` on a US keyboard) is unmapped and types `` ` `` / `~` as on the US layout.

> **Watch out for look-alike Ё:** on ANSI keyboards Apple's own Russian – PC types a *Latin* `Ë` (U+00CB) for Shift+Ё, which looks
> almost identical to Cyrillic `Ё` (U+0401) but breaks search, sorting and spell-check. Qazaq never produces it: capital Ё
> comes from Option+Shift+Е (or the Е long-press popup) and is always the Cyrillic letter.

## Long press
Hold any letter in the table above and a popup offers its variants (У offers Ү Ұ); Shift/Caps gives capitals.
Pick with 1–9, a click, or ←/→/Tab + Return; Esc or any other key keeps the letter. As in ABC, held letters and
digits don't repeat (punctuation, space and shortcuts do); `defaults write -g ApplePressAndHoldEnabled -bool false`
turns the popup and that off.

## Install
Download `Qazaq-<version>.pkg` from [Releases](https://github.com/tsabirgaliev/qazaq-keyboard/releases) and open it
(it installs `Qazaq.app` into `/Library/Input Methods`; Apple silicon and Intel, macOS 13+).
Log out and back in, then System Settings → Keyboard → Text Input → Input Sources → `+` → Kazakh → "Qazaq".
macOS asks you to approve a new input method ([why](#privacy)).
Uninstall: `sudo rm -rf "/Library/Input Methods/Qazaq.app" && sudo pkgutil --forget dev.tair.inputmethod.Qazaq.pkg`,
then log out/in.

### From source
```sh
tools/package.sh                       # builds build/Qazaq.app (signs with your Apple Development identity)
cp -R "build/Qazaq.app" ~/Library/Input\ Methods/
```
Don't also install the `.pkg` (two copies with the same bundle ID). Log out and back in, then System Settings → Keyboard → Text Input → Input Sources → `+` → Kazakh →
"Qazaq". macOS asks you to approve a new input method ([why](#privacy)); updating keeps that
approval only if every build is signed with the same identity.
To update: replace the app in `~/Library/Input Methods/` and run `pkill -x Qazaq` (macOS relaunches it).
Uninstall: delete the app from `~/Library/Input Methods/` and log out/in.

### Release (maintainer)
`tools/release.sh` builds `build/Qazaq-<version>.pkg` signed with Developer ID, notarizes and staples it; bump
`CFBundleShortVersionString`/`CFBundleVersion` in `qazaq/Info.plist` first. One-time setup is in the script's header
(Developer ID Application + Installer certificates, `xcrun notarytool store-credentials qazaq-notary`).
Then `gh release create v<version> build/Qazaq-<version>.pkg`.

## Privacy
When you add Qazaq, macOS warns that "the developer of the input source … can see what you type". It shows that
for every third-party input method, because the OS routes your keystrokes through it; it isn't specific to Qazaq.

What Qazaq does with them: nothing beyond the layout and the long-press popup. It has no network code, writes no
files, and never stores or logs what you type. The keystroke debug log used for development exists only in builds
made with `QAZAQ_DEBUG=1 tools/package.sh`; in every other build, including the releases, that code is compiled out.

You don't have to take this on trust:
- The whole input method is a handful of Swift files in `qazaq/Sources`. `grep -rn "URLSession\|Network\|socket" qazaq/Sources`
  finds nothing, and `QAZAQ_DEBUG` appears only in `Support.swift` and the build scripts.
- In a normal build the log writer isn't in the binary: `nm Qazaq.app/Contents/MacOS/Qazaq | swift demangle | grep -c FileHandle`
  prints `0` (a `QAZAQ_DEBUG=1` build has it).
- `nettop -p "$(pgrep -x Qazaq)"` (or Little Snitch) shows it makes no connections.
- If you'd rather not trust a downloaded binary at all, read the source and [build it yourself](#from-source), signed
  with your own identity. The released `.pkg` is signed and notarized but not bit-for-bit reproducible (signatures and
  timestamps differ per build), so building from source is the way to be sure of what runs.

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

## License

MIT, see [LICENSE](LICENSE).
