#!/usr/bin/env python3
"""Rapport over de inhoud van een Godot 4.3 .pck (of APK): grootte per categorie.

Gebruik:
  python3 tools/apk_size/pck_rapport.py <pck|apk> [--project <dir>] [--md] [--top N]

--project: projectmap met de `.import`-bestanden; daarmee worden geimporteerde
bestanden (`res://.godot/imported/...`) terug naar hun bron (`res://assets/...`)
herleid, zodat de categorie op bronmap klopt. Zonder --project valt het terug op
de extensie van het geimporteerde bestand.
"""
import argparse
import os
import re
import struct
import sys
import zipfile
from collections import defaultdict


def lees_pck(data: bytes) -> list:
    """Geeft [(pad, offset, grootte)] terug voor een PCK v2 (Godot 4.x)."""
    if data[:4] != b"GDPC":
        raise ValueError("geen GDPC-magic")
    versie, major, minor, patch, flags, file_base = struct.unpack_from("<IIIIIQ", data, 4)
    pos = 4 + 4 * 5 + 8 + 16 * 4
    (aantal,) = struct.unpack_from("<I", data, pos)
    pos += 4
    uit = []
    for _ in range(aantal):
        (plen,) = struct.unpack_from("<I", data, pos)
        pos += 4
        pad = data[pos:pos + plen].rstrip(b"\0").decode("utf-8")
        pos += plen
        offset, grootte = struct.unpack_from("<QQ", data, pos)
        pos += 16 + 16 + 4  # md5 + flags
        uit.append((pad, offset + (file_base if versie >= 2 else 0), grootte))
    return uit


def laad_pck(pad: str) -> list:
    """.pck: ruwe bestandsgroottes. .apk: gecomprimeerde grootte per zip-entry (wat echt in de APK zit);
    projectbestanden staan in de APK onder `assets/` en worden terug naar `res://` vertaald."""
    if pad.endswith(".pck"):
        with open(pad, "rb") as f:
            return lees_pck(f.read())
    uit = []
    with zipfile.ZipFile(pad) as z:
        for i in z.infolist():
            if i.filename.startswith("assets/"):
                uit.append(("res://" + i.filename[len("assets/"):], 0, i.compress_size))
            elif i.filename.startswith("lib/"):
                uit.append(("apk://engine/" + i.filename, 0, i.compress_size))
            else:
                uit.append(("apk://overig/" + i.filename, 0, i.compress_size))
    return uit


def bron_map(project: str) -> dict:
    """dest_file -> source_file uit alle .import-bestanden."""
    kaart = {}
    if not project:
        return kaart
    for root, dirs, files in os.walk(project):
        dirs[:] = [d for d in dirs if d not in (".git", ".godot", "wacht")]
        for n in files:
            if not n.endswith(".import"):
                continue
            try:
                tekst = open(os.path.join(root, n), encoding="utf-8").read()
            except OSError:
                continue
            m = re.search(r'source_file="([^"]+)"', tekst)
            d = re.search(r"dest_files=\[(.*?)\]", tekst, re.S)
            if not (m and d):
                continue
            for dest in re.findall(r'"([^"]+)"', d.group(1)):
                kaart[dest] = m.group(1)
    return kaart


EXT_NAAR_CAT = {
    ".ctex": "beeld (geimporteerd)", ".sample": "sfx (geimporteerd)",
    ".oggvorbisstr": "muziek (geimporteerd)", ".ogv": "video", ".scn": "scenes",
    ".tscn": "scenes", ".gd": "scripts", ".gdc": "scripts", ".json": "data (json)",
    ".res": "resources", ".tres": "resources", ".fontdata": "fonts", ".ttf": "fonts",
}


def categorie(pad: str, bron: str) -> str:
    p = bron or pad
    if p.startswith("apk://engine/"):
        return "engine (libgodot_android.so)"
    if p.startswith("apk://overig/"):
        return "APK overig (manifest, res/, classes.dex)"
    if p.startswith("res://assets/audio/bgm/"):
        return "muziek (bgm)"
    if p.startswith("res://assets/audio/sfx/"):
        return "sfx"
    if p.startswith("res://assets/video/"):
        return "video (.ogv)"
    if p.startswith("res://assets/") or p.startswith("res://art/"):
        if p.lower().endswith((".png", ".webp", ".jpg", ".svg")):
            return "afbeeldingen (png/ctex)"
        if p.startswith("res://assets/fonts/"):
            return "fonts"
        return "assets overig"
    if p.startswith("res://icon.png"):
        return "afbeeldingen (png/ctex)"
    if p.startswith("res://scripts/") or p.startswith("res://pvp/scripts") or p.endswith((".gd", ".gdc")):
        return "scripts"
    if p.startswith("res://scenes/") or p.endswith((".tscn", ".scn")):
        return "scenes"
    if p.startswith("res://world_warper/") or p.startswith("res://pvp/"):
        ext = os.path.splitext(p)[1]
        return "data/overige mappen (world_warper, pvp)" if ext != ".gd" else "scripts"
    if p.startswith("res://docs/") or p.startswith("res://tools/") or p.startswith("res://wacht/"):
        return "NIET-SPEL (docs/tools/wacht)"
    if p.startswith("res://data/") or p.endswith(".json"):
        return "data (json)"
    ext = os.path.splitext(p)[1]
    return EXT_NAAR_CAT.get(ext, "overig (" + (ext or "geen ext") + ")")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("bestand")
    ap.add_argument("--project", default="")
    ap.add_argument("--md", action="store_true")
    ap.add_argument("--top", type=int, default=0)
    a = ap.parse_args()
    items = laad_pck(a.bestand)
    kaart = bron_map(a.project)
    per_cat = defaultdict(lambda: [0, 0])
    groot = []
    for pad, off, size in items:
        bron = kaart.get(pad, "")
        c = categorie(pad, bron)
        per_cat[c][0] += 1
        per_cat[c][1] += size
        groot.append((size, bron or pad))
    totaal = sum(v[1] for v in per_cat.values())
    rijen = sorted(per_cat.items(), key=lambda kv: -kv[1][1])
    if a.md:
        print("| categorie | bestanden | bytes | MiB |")
        print("|---|---:|---:|---:|")
        for c, (n, b) in rijen:
            print(f"| {c} | {n} | {b} | {b / 1048576:.2f} |")
        print(f"| **totaal** | {len(items)} | {totaal} | {totaal / 1048576:.2f} |")
    else:
        for c, (n, b) in rijen:
            print(f"{c:45s} {n:6d} {b:12d} {b / 1048576:8.2f} MiB")
        print(f"{'TOTAAL':45s} {len(items):6d} {totaal:12d} {totaal / 1048576:8.2f} MiB")
    if a.top:
        print()
        for size, p in sorted(groot, reverse=True)[:a.top]:
            print(f"{size:10d}  {p}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
