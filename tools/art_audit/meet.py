#!/usr/bin/env python3
"""Art-meting: meet alle PNG's onder assets/ en schrijf één CSV-rij per bestand.

Alleen lezen: dit script opent de PNG's, maar schrijft of wijzigt nooit een asset.

Gebruik (vanuit de repo-root):
    python3 tools/art_audit/meet.py
    python3 tools/art_audit/meet.py --palet pad/naar/master.gpl
    python3 tools/art_audit/meet.py --palet master.png --assets assets --uit art_meting.csv
    python3 tools/art_audit/meet.py --negeer '**/*_n.png' --negeer 'tmp/**'

Kolommen:
    pad                  pad t.o.v. de map waarin gescand wordt (assets/...)
    breedte, hoogte      in pixels
    deelbaar_door_16     ja als breedte EN hoogte deelbaar zijn door 16
    unieke_kleuren       aantal unieke RGBA-waarden van zichtbare pixels (alpha > 0);
                         volledig transparante pixels tellen niet mee
    buiten_palet         aantal unieke RGB-kleuren van zichtbare pixels die niet in
                         het masterpalet staan; leeg zonder --palet
    alpha_alleen_0_255   ja als elke pixel alpha 0 of 255 heeft
    semi_transparant     aantal pixels met 0 < alpha < 255

Masterpalet:
    .gpl  GIMP-palet ("R G B naam"-regels)
    .png  alle RGB-kleuren van pixels met alpha > 0
"""
from __future__ import annotations

import argparse
import csv
import fnmatch
import sys
from pathlib import Path

from PIL import Image

KOLOMMEN: list[str] = [
    "pad",
    "breedte",
    "hoogte",
    "deelbaar_door_16",
    "unieke_kleuren",
    "buiten_palet",
    "alpha_alleen_0_255",
    "semi_transparant",
]

REPO_ROOT: Path = Path(__file__).resolve().parents[2]

RGB = tuple[int, int, int]


def lees_gpl(pad: Path) -> set[RGB]:
    kleuren: set[RGB] = set()
    for regel in pad.read_text(encoding="utf-8", errors="replace").splitlines():
        regel = regel.strip()
        if not regel or regel.startswith("#") or regel.startswith("GIMP Palette"):
            continue
        if regel.startswith(("Name:", "Columns:")):
            continue
        delen = regel.split()
        if len(delen) < 3:
            continue
        try:
            r, g, b = (int(d) for d in delen[:3])
        except ValueError:
            continue
        kleuren.add((r, g, b))
    return kleuren


def lees_png_palet(pad: Path) -> set[RGB]:
    with Image.open(pad) as img:
        rgba = img.convert("RGBA")
    kleuren = rgba.getcolors(maxcolors=rgba.width * rgba.height) or []
    return {(r, g, b) for _, (r, g, b, a) in kleuren if a > 0}


def lees_palet(pad: Path) -> set[RGB]:
    if pad.suffix.lower() == ".gpl":
        return lees_gpl(pad)
    if pad.suffix.lower() == ".png":
        return lees_png_palet(pad)
    raise ValueError(f"onbekend paletformaat (verwacht .png of .gpl): {pad}")


def meet_png(pad: Path, palet: set[RGB] | None) -> dict[str, object]:
    with Image.open(pad) as img:
        rgba = img.convert("RGBA")
    breedte, hoogte = rgba.size

    kleuren = rgba.getcolors(maxcolors=max(1, breedte * hoogte)) or []
    zichtbaar = [kleur for _, kleur in kleuren if kleur[3] > 0]

    alpha_hist = rgba.getchannel("A").histogram()
    semi = sum(alpha_hist[1:255])

    buiten: object = ""
    if palet is not None:
        rgb_zichtbaar = {(r, g, b) for r, g, b, _ in zichtbaar}
        buiten = len(rgb_zichtbaar - palet)

    return {
        "breedte": breedte,
        "hoogte": hoogte,
        "deelbaar_door_16": "ja" if breedte % 16 == 0 and hoogte % 16 == 0 else "nee",
        "unieke_kleuren": len(zichtbaar),
        "buiten_palet": buiten,
        "alpha_alleen_0_255": "ja" if semi == 0 else "nee",
        "semi_transparant": semi,
    }


def zoek_pngs(map_: Path) -> list[Path]:
    return sorted(p for p in map_.rglob("*") if p.is_file() and p.suffix.lower() == ".png")


def glob_match(rel: str, patroon: str) -> bool:
    """Of het volledige posix-pad de glob dekt. `**` is nul of meer mappen."""
    pat = [deel for deel in patroon.replace("\\", "/").split("/") if deel]
    if not pat:
        return False
    return _segmenten(rel.split("/") if rel else [], pat)


def _segmenten(delen: list[str], pat: list[str]) -> bool:
    # `**` als heel segment; pathlib 3.12 laat `**` niet over mappen heen lopen.
    i = j = 0
    ster_i = ster_j = -1
    while i < len(delen):
        if j < len(pat) and pat[j] == "**":
            ster_i, ster_j = i, j
            j += 1
        elif j < len(pat) and fnmatch.fnmatchcase(delen[i], pat[j]):
            i += 1
            j += 1
        elif ster_j >= 0:
            ster_i += 1
            i, j = ster_i, ster_j + 1
        else:
            return False
    while j < len(pat) and pat[j] == "**":
        j += 1
    return j == len(pat)


def is_genegeerd(pad: Path, globs: list[str]) -> bool:
    """True als het repo-relatieve pad bij een --negeer-glob hoort. Lege lijst: nooit."""
    if not globs:
        return False
    opgelost = pad.resolve()
    try:
        rel = opgelost.relative_to(REPO_ROOT).as_posix()
    except ValueError:
        rel = opgelost.as_posix()
    return any(glob_match(rel, patroon) for patroon in globs)


def zonder_negeer(map_: Path, globs: list[str]) -> tuple[list[Path], int]:
    """PNG's die overblijven, plus hoeveel --negeer eruit haalde. Geen standaardlijst."""
    pngs = zoek_pngs(map_)
    if not globs:
        return pngs, 0
    houden: list[Path] = []
    genegeerd = 0
    for png in pngs:
        if is_genegeerd(png, globs):
            genegeerd += 1
        else:
            houden.append(png)
    return houden, genegeerd


def meet_map(assets: Path, uit: Path, palet: set[RGB] | None, negeer: list[str] | None = None) -> int:
    """Meet alle PNG's onder `assets` en schrijf de CSV naar `uit`. Geeft het aantal rijen terug."""
    pngs, _genegeerd = zonder_negeer(assets, negeer or [])
    basis = assets.parent
    with uit.open("w", newline="", encoding="utf-8") as f:
        schrijver = csv.DictWriter(f, fieldnames=KOLOMMEN)
        schrijver.writeheader()
        for png in pngs:
            rij: dict[str, object] = {"pad": png.relative_to(basis).as_posix()}
            try:
                rij.update(meet_png(png, palet))
            except Exception as fout:  # kapotte PNG: rij blijft leeg, scan gaat door
                print(f"WAARSCHUWING: {rij['pad']}: {fout}", file=sys.stderr)
            schrijver.writerow(rij)
    return len(pngs)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Meet alle PNG's onder assets/ (alleen lezen).")
    parser.add_argument("--palet", type=Path, help="masterpalet als .png of .gpl (optioneel)")
    parser.add_argument("--assets", type=Path, default=REPO_ROOT / "assets",
                        help="map om te scannen (standaard: <repo>/assets)")
    parser.add_argument("--uit", type=Path, default=Path("art_meting.csv"),
                        help="uitvoer-CSV (standaard: ./art_meting.csv)")
    parser.add_argument("--negeer", action="append", default=None, metavar="GLOB",
                        help="glob op het repo-relatieve pad; sla treffers over (herhaalbaar)")
    args = parser.parse_args(argv)

    if not args.assets.is_dir():
        parser.error(f"map bestaat niet: {args.assets}")
    palet = lees_palet(args.palet) if args.palet else None

    assets = args.assets.resolve()
    globs: list[str] = args.negeer or []
    aantal = meet_map(assets, args.uit, palet, globs)
    print(f"{aantal} PNG's gemeten -> {args.uit}")
    if args.negeer:
        print(f"{zonder_negeer(assets, globs)[1]} genegeerd")
    return 0


if __name__ == "__main__":
    sys.exit(main())
