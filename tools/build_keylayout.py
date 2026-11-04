#!/usr/bin/env python3
"""Build src/Qazaq.keylayout from build/base.json (Russian PC dump) + Kazakh overlay.

Run:  uv run --no-project python tools/build_keylayout.py
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASE = ROOT / "build" / "base.json"
OUT = ROOT / "src" / "Qazaq.keylayout"

NAME = "Qazaq"
KEYBOARD_ID = -23917  # custom layouts use negative IDs
SRC = "com.apple.keylayout.RussianWin"

# Cyrillic base letter on the key -> (Option output, Option+Shift / Caps+Option output)
OVERLAY = {
    "а": ("ә", "Ә"),
    "ы": ("і", "І"),
    "н": ("ң", "Ң"),
    "г": ("ғ", "Ғ"),
    "ц": ("ү", "Ү"),
    "у": ("ұ", "Ұ"),
    "к": ("қ", "Қ"),
    "о": ("ө", "Ө"),
    "х": ("һ", "Һ"),
}

# keyMap index -> (state name in base.json, modifier combos)
MAPS = [
    ("base", [""]),
    ("shift", ["anyShift caps?"]),
    ("caps", ["caps"]),
    ("option", ["anyOption"]),
    ("optionShift", ["anyShift caps? anyOption"]),
    ("capsOption", ["caps anyOption"]),
    ("command", ["caps? command"]),
    ("commandShift", ["anyShift caps? command"]),
    ("commandOption", ["caps? anyOption command"]),
    ("commandOptionShift", ["anyShift caps? anyOption command"]),
    ("control", ["anyShift? caps? anyOption? command? control"]),
]
DEFAULT_INDEX = len(MAPS) - 1

# Keyboard type IDs -> map set. This is the standard Ukelele/Apple list. macOS ignores explicit entries for
# modern types (40+); those resolve to the ANSI set, so ISO/JIS hardware gets ANSI keys 10/50 (see README).
LAYOUTS = [
    (0, 17, "ANSI"), (18, 18, "ISO"), (21, 23, "ISO"), (30, 30, "ISO"),
    (194, 194, "ISO"), (197, 197, "ISO"), (200, 201, "ISO"), (206, 207, "ISO"),
]
SET_SOURCE = {"ANSI": "ansi", "ISO": "iso"}  # JIS == ISO for RussianWin


def esc(s: str) -> str:
    out = []
    for ch in s:
        o = ord(ch)
        if o < 0x20 or o == 0x7F or ch in "&<>\"'":
            out.append(f"&#x{o:04X};")
        else:
            out.append(ch)
    return "".join(out)


def load():
    data = json.loads(BASE.read_text())[SRC]
    for t in data.values():
        for st in t.values():
            for k, v in st.items():
                if v.get("dead"):
                    sys.exit(f"dead key found (state key {k}); generator does not handle dead keys")
    return data


def apply_fixes_and_overlay(data):
    report = []
    for tname, states in data.items():
        base = states["base"]
        # Apple quirk: ANSI Shift/Caps+Ё gives Latin Ë (U+00CB). Use Cyrillic Ё (U+0401).
        for sname, st in states.items():
            for code, v in st.items():
                if v.get("out") == "Ë":
                    v["out"] = "Ё"
                    report.append(f"fix  {tname}/{sname}/code {code}: Latin Ë -> Cyrillic Ё")
        letter_code = {}
        for code, v in base.items():
            o = v.get("out", "")
            if o in OVERLAY and int(code) < 94:  # skip alias codes
                letter_code.setdefault(o, []).append(code)
        for letter, (lo, up) in OVERLAY.items():
            codes = letter_code.get(letter)
            if not codes or len(codes) != 1:
                sys.exit(f"{tname}: key for {letter!r} not unique/found: {codes}")
            c = codes[0]
            for sname, new in (("option", lo), ("optionShift", up), ("capsOption", up)):
                old = states[sname][c].get("out")
                if tname == "ansi":
                    report.append(f"over {sname:<11} code {c:>3} ({letter}): {old!r} -> {new!r}")
                states[sname][c] = {"out": new}
    return report


def emit(data) -> str:
    L = []
    L.append('<?xml version="1.1" encoding="UTF-8"?>')
    L.append('<!DOCTYPE keyboard SYSTEM "file://localhost/System/Library/DTDs/KeyboardLayout.dtd">')
    L.append(f'<keyboard group="126" id="{KEYBOARD_ID}" name="{NAME}" maxout="1">')
    L.append("\t<layouts>")
    for first, last, ms in LAYOUTS:
        L.append(f'\t\t<layout first="{first}" last="{last}" mapSet="{ms}" modifiers="mods"/>')
    L.append("\t</layouts>")
    L.append(f'\t<modifierMap id="mods" defaultIndex="{DEFAULT_INDEX}">')
    for i, (_, combos) in enumerate(MAPS):
        L.append(f'\t\t<keyMapSelect mapIndex="{i}">')
        for c in combos:
            L.append(f'\t\t\t<modifier keys="{c}"/>')
        L.append("\t\t</keyMapSelect>")
    L.append("\t</modifierMap>")
    for ms, tname in SET_SOURCE.items():
        L.append(f'\t<keyMapSet id="{ms}">')
        for i, (sname, _) in enumerate(MAPS):
            L.append(f'\t\t<keyMap index="{i}">')
            st = data[tname][sname]
            for code in sorted(st, key=int):
                out = st[code].get("out", "")
                if out == "":
                    continue
                L.append(f'\t\t\t<key code="{code}" output="{esc(out)}"/>')
            L.append("\t\t</keyMap>")
        L.append("\t</keyMapSet>")
    L.append("</keyboard>")
    return "\n".join(L) + "\n"


def main():
    data = load()
    report = apply_fixes_and_overlay(data)
    print("\n".join(report))
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(emit(data), encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
