#!/usr/bin/env python3
"""Append Wachtershuis-interieur ART-paden aan tools/handwerk.txt (alleen append)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HAND = ROOT / "tools" / "handwerk.txt"
TILES = ROOT / "assets" / "tiles" / "huis_interieur"
PROPS = ROOT / "assets" / "sprites" / "binnen" / "huis_props"

def main() -> None:
    lines = [
        "# Wachtershuis-interieur (ART huis_interieur_art), 32x21. Geen placeholders.",
    ]
    for p in sorted(TILES.glob("*.png")):
        lines.append(str(p.relative_to(ROOT)).replace("\\", "/"))
    for p in sorted(PROPS.glob("*.png")):
        if p.name.startswith("_"):
            continue
        lines.append(str(p.relative_to(ROOT)).replace("\\", "/"))
    for name in (
        "keuken_fornuis.png",
        "keuken_fornuis_gloed.png",
        "deurkozijn.png",
        "keukenkast.png",
        "doorframe_32.png",
    ):
        rel = f"assets/sprites/binnen/{name}"
        if (ROOT / rel).is_file():
            lines.append(rel)
    block = "\n".join(lines) + "\n"
    text = HAND.read_text(encoding="utf-8")
    if lines[1] in text:
        print("handwerk: al aanwezig, overslaan")
        return
    HAND.write_text(text.rstrip() + "\n" + block, encoding="utf-8")
    print(f"handwerk: {len(lines)-1} paden toegevoegd")


if __name__ == "__main__":
    main()
