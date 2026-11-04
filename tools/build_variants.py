"""Generate the long-press table for the input method from OVERLAY in build_keylayout.py.

Output: JSON {base letter: [variants]} for lower and upper case, e.g. {"н": ["ң"], "Н": ["Ң"], ...}.
Like ABC's press-and-hold popup, the base letter itself is not listed (it is already typed).
Run:  uv run --no-project python -I tools/build_variants.py build/variants.json
"""
import importlib.util
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

spec = importlib.util.spec_from_file_location("build_keylayout", ROOT / "tools" / "build_keylayout.py")
build_keylayout = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build_keylayout)
OVERLAY = build_keylayout.OVERLAY

# Long-press groups by letter similarity (as Apple's iOS Kazakh keyboard does): holding У offers both
# Ұ (its Option letter) and Ү (Option+Ц). Kazakh alphabet order: У Ұ Ү.
EXTRA = {"у": ("ү", "Ү")}


def build() -> dict[str, list[str]]:
    table: dict[str, list[str]] = {}
    for base, (lo, up) in OVERLAY.items():
        extra = EXTRA.get(base)
        table[base] = [lo] + ([extra[0]] if extra else [])
        table[base.upper()] = [up] + ([extra[1]] if extra else [])
    return table


def check(table: dict[str, list[str]]) -> None:
    for base, (lo, up) in OVERLAY.items():
        assert table.get(base, [None])[0] == lo, f"{base}: first variant must be its Option letter {lo}"
        assert table.get(base.upper(), [None])[0] == up, f"{base.upper()}: first variant must be {up}"
    for base, variants in table.items():
        assert len(base) == 1 and all(len(v) == 1 for v in variants), base
        assert base not in variants and len(set(variants)) == len(variants), base
        assert len(variants) <= 9, f"{base}: only 9 number keys"


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "build" / "variants.json"
    table = build()
    check(table)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(table, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wrote {out} ({len(table)} keys)")


if __name__ == "__main__":
    main()
