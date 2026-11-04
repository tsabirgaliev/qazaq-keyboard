#!/usr/bin/env python3
"""Compare the compiled Kazakh - PC+ dump (build/new.json) against Russian PC (build/base.json).
Run: uv run --no-project python -I tools/verify.py"""
import json, subprocess, sys
from pathlib import Path
R = Path(__file__).resolve().parent.parent / "build"
base = json.loads((R / "base.json").read_text())["com.apple.keylayout.RussianWin"]
new = next(iter(json.loads((R / "new.json").read_text()).values()))
OVER = {"а": "ә", "ы": "і", "н": "ң", "г": "ғ", "ц": "ү", "у": "ұ", "к": "қ", "о": "ө", "х": "һ"}
bad, known, checked, overlaid = [], [], 0, 0
for t in ("ansi", "iso", "jis"):
    letter_code = {base[t]["base"][c]["out"]: c for c in base[t]["base"] if int(c) < 94 and base[t]["base"][c].get("out") in OVER}
    expected_over = {}
    for ltr, lo in OVER.items():
        c = letter_code[ltr]
        expected_over[("option", c)] = lo
        expected_over[("optionShift", c)] = lo.upper()
        expected_over[("capsOption", c)] = lo.upper()
    for s, keys in base[t].items():
        for c, v in keys.items():
            exp = expected_over.get((s, c), v.get("out", ""))
            if exp == "Ë":
                exp = "Ё"  # intentional Ë -> Ё fix
            got = new[t][s].get(c, {}).get("out", "")
            checked += 1
            overlaid += (s, c) in expected_over
            if got != exp:
                if t != "ansi" and c in ("50", "94"):
                    known.append((t, s, c))  # ISO/JIS hardware resolves to the ANSI set (documented limitation)
                else:
                    bad.append((t, s, c, exp, got))
print(f"known ISO/JIS key-50 differences (documented): {len(known)}")
print(f"checked {checked} outputs ({overlaid} Kazakh overlay), mismatches: {len(bad)}")
for b in bad[:30]:
    print("  MISMATCH", b)

# Long-press (press-and-hold) picks its Kazakh variants from the source's language, so it must lead with kk.
SOURCE_ID = "dev.tair.keyboardlayout.kazakhpcplus.kazakhpcplus"
r = subprocess.run(["swift", str(R.parent / "tools" / "languages.swift"), SOURCE_ID], capture_output=True, text=True)
langs = r.stdout.split()
lang_ok = bool(langs) and langs[0] == "kk"
print(f"input-source languages: {langs[:4]}... -> {'OK' if lang_ok else 'FAIL (long-press will not use Kazakh variants)'}")
sys.exit(1 if bad or not lang_ok else 0)
