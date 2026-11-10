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

# Long-press lists that differ from a key's own Option letter, in popup order (uppercase is derived).
# Grouped by letter similarity, as Apple's iOS Kazakh keyboard does: У offers Ү and Ұ (Ұ is its Option
# letter, Ү is Option+Ц); И offers І like Ы does (И has no Option letter).
GROUPS = {"у": "үұ", "и": "і"}


def build() -> dict[str, list[str]]:
    lists = {base: GROUPS.get(base, lo) for base, (lo, _) in OVERLAY.items()} | GROUPS
    table: dict[str, list[str]] = {}
    for base, variants in lists.items():
        table[base] = list(variants)
        table[base.upper()] = [v.upper() for v in variants]
    return table


def check(table: dict[str, list[str]]) -> None:
    for base, (lo, up) in OVERLAY.items():
        assert lo in table.get(base, []), f"{base}: variants must include its Option letter {lo}"
        assert up in table.get(base.upper(), []), f"{base.upper()}: variants must include {up}"
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
