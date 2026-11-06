#!/usr/bin/env python3
"""Maak het masterpalet als GIMP-palet (.gpl) en paletkaart (.png) uit de ene bron.

Bron (enige waarheid): tools/som/sapientia_palette.json (RPG ART, ook gebruikt door
tools/som/export_tilesets.py). Dit script voegt GEEN kleuren toe; het zet de ramps
alleen om, met de FX-namen (vuur, bliksem, heal, arcane, glitch) als commentaar.

Gebruik (vanuit de repo-root):
    python3 tools/art_audit/maak_gpl.py              # schrijft docs/art/masterpalet.gpl
    python3 tools/art_audit/maak_gpl.py --png docs/art/polish/r1/masterpalet.png
    python3 tools/art_audit/maak_gpl.py --check      # exit 1 als het .gpl niet klopt met de JSON
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT: Path = Path(__file__).resolve().parents[2]
BRON: Path = REPO_ROOT / "tools" / "som" / "sapientia_palette.json"
GPL: Path = REPO_ROOT / "docs" / "art" / "masterpalet.gpl"

# Welke ramp hoort bij welk effect (alleen documentatie; geen extra kleuren).
FX_RAMPS: dict[str, str] = {
    "Red/Danger": "FX vuur (spell_vuur)",
    "Gold": "FX bliksem (kern), schadegetal",
    "Blue (Lotte/UI)": "FX bliksem (rand) + glitch-cyaan 40e0e8/c8f4ff",
    "Mint": "FX heal (licht)",
    "Teal": "FX heal (schaduw), vijver",
    "Glitch Purple": "FX arcane paars",
    "Glitch Magenta": "FX glitch-magenta (SAPIENTIA-titel, codex_capture_fx)",
}

RGB = tuple[int, int, int]


def lees_bron(pad: Path = BRON) -> dict[str, list[RGB]]:
    data = json.loads(pad.read_text(encoding="utf-8"))
    ramps: dict[str, list[RGB]] = {}
    for naam, kleuren in data.items():
        ramps[naam] = [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in kleuren]  # type: ignore[misc]
    return ramps


def maak_gpl_tekst(ramps: dict[str, list[RGB]]) -> str:
    regels = [
        "GIMP Palette",
        "Name: Sapientia masterpalet",
        "Columns: 6",
        "# Gegenereerd door tools/art_audit/maak_gpl.py uit tools/som/sapientia_palette.json.",
        "# Niet met de hand bewerken: pas de JSON aan en draai het script opnieuw.",
        f"# {sum(len(v) for v in ramps.values())} kleuren in {len(ramps)} ramps (donker naar licht).",
    ]
    for naam, kleuren in ramps.items():
        extra = f" -- {FX_RAMPS[naam]}" if naam in FX_RAMPS else ""
        regels.append(f"# {naam}{extra}")
        for i, (r, g, b) in enumerate(kleuren):
            regels.append(f"{r:3d} {g:3d} {b:3d}\t{naam} {i + 1}")
    return "\n".join(regels) + "\n"


def maak_png(ramps: dict[str, list[RGB]], uit: Path, cel: int = 12) -> None:
    from PIL import Image, ImageDraw

    breedte = max(len(v) for v in ramps.values())
    img = Image.new("RGB", (breedte * cel, len(ramps) * cel), (24, 24, 32))
    teken = ImageDraw.Draw(img)
    for rij, kleuren in enumerate(ramps.values()):
        for kol, kleur in enumerate(kleuren):
            x, y = kol * cel, rij * cel
            teken.rectangle([x, y, x + cel - 1, y + cel - 1], fill=kleur)
    img.save(uit)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Masterpalet .gpl/.png uit sapientia_palette.json.")
    parser.add_argument("--uit", type=Path, default=GPL, help="pad van het .gpl")
    parser.add_argument("--png", type=Path, help="schrijf ook een paletkaart (PNG)")
    parser.add_argument("--check", action="store_true", help="alleen controleren, niets schrijven")
    args = parser.parse_args(argv)

    ramps = lees_bron()
    tekst = maak_gpl_tekst(ramps)
    if args.check:
        if not args.uit.is_file() or args.uit.read_text(encoding="utf-8") != tekst:
            print(f"FOUT: {args.uit} loopt niet gelijk met {BRON.name}; draai maak_gpl.py", file=sys.stderr)
            return 1
        print(f"OK: {args.uit} klopt met {BRON.name}")
        return 0
    args.uit.write_text(tekst, encoding="utf-8")
    print(f"{args.uit} geschreven")
    if args.png:
        maak_png(ramps, args.png)
        print(f"{args.png} geschreven")
    return 0


if __name__ == "__main__":
    sys.exit(main())
