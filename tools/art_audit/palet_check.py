#!/usr/bin/env python3
"""Paletcheck: per PNG het aantal unieke kleuren buiten het masterpalet.

Alleen lezen (gebruikt meet.py). Waarschuwt, blokkeert niet: exitcode is altijd 0,
behalve met --streng (dan 1 als er een bestand buiten het palet valt).
In GitHub Actions (GITHUB_ACTIONS=true) komen de afwijkers als ::warning in de log.

Gebruik (vanuit de repo-root):
    python3 tools/art_audit/palet_check.py
    python3 tools/art_audit/palet_check.py --assets assets/sprites/som --top 50
    python3 tools/art_audit/palet_check.py --palet docs/art/masterpalet.gpl --streng
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import meet  # noqa: E402

STANDAARD_PALET: Path = meet.REPO_ROOT / "docs" / "art" / "masterpalet.gpl"


def check(assets: Path, palet: set[meet.RGB]) -> list[tuple[str, int, int]]:
    """Geeft (pad, buiten_palet, unieke_kleuren) per PNG, slechtste eerst."""
    rijen: list[tuple[str, int, int]] = []
    basis = assets.parent
    for png in meet.zoek_pngs(assets):
        try:
            m = meet.meet_png(png, palet)
        except Exception as fout:  # kapotte PNG: melden, doorgaan
            print(f"WAARSCHUWING: {png}: {fout}", file=sys.stderr)
            continue
        rijen.append((png.relative_to(basis).as_posix(), int(m["buiten_palet"]), int(m["unieke_kleuren"])))
    rijen.sort(key=lambda r: (-r[1], r[0]))
    return rijen


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Kleuren buiten het masterpalet per PNG (alleen lezen).")
    parser.add_argument("--palet", type=Path, default=STANDAARD_PALET, help="masterpalet (.gpl of .png)")
    parser.add_argument("--assets", type=Path, default=meet.REPO_ROOT / "assets", help="map om te scannen")
    parser.add_argument("--top", type=int, default=20, help="hoeveel afwijkers tonen (0 = alle)")
    parser.add_argument("--streng", action="store_true", help="exit 1 als er afwijkers zijn")
    args = parser.parse_args(argv)

    if not args.assets.is_dir():
        parser.error(f"map bestaat niet: {args.assets}")
    palet = meet.lees_palet(args.palet)
    rijen = check(args.assets.resolve(), palet)
    fout = [r for r in rijen if r[1] > 0]

    print(f"Paletcheck: {len(palet)} paletkleuren, {len(rijen)} PNG's, "
          f"{len(rijen) - len(fout)} schoon, {len(fout)} met kleuren buiten het palet")
    toon = fout if args.top == 0 else fout[:args.top]
    for pad, buiten, uniek in toon:
        print(f"  {buiten:5d} buiten / {uniek:5d} uniek  {pad}")
    if os.environ.get("GITHUB_ACTIONS") == "true" and fout:
        print(f"::warning title=Paletcheck::{len(fout)} van {len(rijen)} PNG's hebben kleuren buiten "
              f"{args.palet.name} (niet blokkerend)")
        for pad, buiten, _ in toon:
            print(f"::warning file={pad},title=Buiten palet::{buiten} kleuren buiten het masterpalet")
    return 1 if (args.streng and fout) else 0


if __name__ == "__main__":
    sys.exit(main())
