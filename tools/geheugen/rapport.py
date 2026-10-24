#!/usr/bin/env python3
"""Maakt een markdown-rapport uit de JSON van wm1_meting.sh.

  python3 tools/geheugen/rapport.py <na-map>                 # alleen deze meting
  python3 tools/geheugen/rapport.py <na-map> <voor-map>      # voor/na-tabel (verschil = na - voor)
"""
import collections
import glob
import json
import os
import sys

MB = 1e6


def laad(pad):
    try:
        with open(pad) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def map_data(d):
    r = {"start": (laad(f"{d}/start.json") or {}).get("start"),
         "preload": (laad(f"{d}/start.json") or {}).get("preload"),
         "sessie": laad(f"{d}/sessie.json"),
         "tex": (laad(f"{d}/texaudit.json") or {}).get("texturen", []),
         "kaarten": {}, "gevecht": {}}
    for p in sorted(glob.glob(f"{d}/kaarten/*.json")):
        j = laad(p)
        if j and "kaart" in j:
            r["kaarten"][os.path.basename(p)[:-5]] = j["kaart"]
    for p in sorted(glob.glob(f"{d}/gevecht/*.json")):
        j = laad(p)
        if j and "gevecht" in j:
            r["gevecht"][os.path.basename(p)[:-5]] = j["gevecht"]
    r["info"] = laad(f"{d}/start.json") or {}
    return r


def mb(x):
    return f"{x / MB:.1f}"


def delta(a, b, fmt=mb):
    if b is None:
        return fmt(a)
    d = a - b
    return f"{fmt(a)} ({'+' if d > 0 else ''}{fmt(d) if fmt is mb else d})" if d else fmt(a)


def pct(a, b):
    return f"{(a - b) / b * 100:+.0f}%" if b else ""


def rij(label, na, voor, sleutel, fmt=mb):
    n = na[sleutel]
    if voor is None:
        return f"| {label} | {fmt(n)} |"
    v = voor[sleutel]
    if fmt is mb:
        return f"| {label} | {fmt(v)} | {fmt(n)} | {(n - v) / MB:+.1f} | {pct(n, v)} |"
    return f"| {label} | {fmt(v)} | {fmt(n)} | {n - v:+d} | {pct(n, v)} |"


def kop(voor):
    return ("| Meting | Voor | Na | Verschil | % |\n|---|---:|---:|---:|---:|" if voor is not None
            else "| Meting | Waarde |\n|---|---:|")


def dubbel(tex):
    groepen = collections.defaultdict(list)
    for t in tex:
        groepen[t["hash"]].append(t)
    uit = [g for g in groepen.values() if len(g) > 1 and g[0]["w"] * g[0]["h"] > 16]
    return sorted(uit, key=lambda g: -sum(x["vram"] for x in g[1:]))


def main():
    na = map_data(sys.argv[1])
    voor = map_data(sys.argv[2]) if len(sys.argv) > 2 else None
    uit = []
    info = na["info"]
    uit.append(f"Engine: {info.get('godot', '?')}, renderer {info.get('renderer', '?')} (adapter: {info.get('adapter', '?')}). "
               "MB = 10^6 bytes. Texturen = `RENDER_TEXTURE_MEM_USED`, statisch = `MEMORY_STATIC`, RSS = /proc (llvmpipe, dus ook GL-geheugen).\n")

    uit.append("### 1. Opstart (autoloads + achtergrond-preload, nog geen kaart)\n")
    uit.append(kop(voor))
    s, vs = na["start"], (voor["start"] if voor else None)
    for lab, k, f in [("Texturen (VRAM) MB", "textuur_mem", mb), ("Statisch geheugen MB", "statisch", mb),
                      ("Statisch piek MB", "statisch_piek", mb), ("RSS MB", "rss", mb),
                      ("Objecten", "objecten", str), ("Resources", "resources", str)]:
        uit.append(rij(lab, s, vs, k, f))
    if na["preload"]:
        p, vp = na["preload"], (voor["preload"] if voor else None)
        uit.append(f"| Vastgehouden preload-items (`GameState._loaded`) | " + (f"{vp['aantal']} | " if vp else "") +
                   f"{p['aantal']} |" + (f" {p['aantal'] - vp['aantal']:+d} | |" if vp else ""))
    uit.append("")

    uit.append("### 2. Per WM1-kaart, verse proces (totaal met de kaart open; baseline = opstart)\n")
    if voor is None:
        uit.append("| Kaart | Texturen MB | Statisch MB | RSS MB | Objecten | Resources | Knopen | Uniek tex | Laadtijd ms |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    else:
        uit.append("| Kaart | Texturen MB voor | na | Δ | Statisch MB voor | na | RSS MB voor | na | Resources voor | na |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    sommen = collections.Counter()
    for naam, k in na["kaarten"].items():
        n = k["na"]
        if voor is None or naam not in voor["kaarten"]:
            uit.append(f"| {naam} | {mb(n['textuur_mem'])} | {mb(n['statisch'])} | {mb(n['rss'])} | {n['objecten']} | {n['resources']} | {k['knopen']} | {k['texturen']['uniek']} | {k['laadtijd_ms']:.0f} |")
        else:
            v = voor["kaarten"][naam]["na"]
            uit.append(f"| {naam} | {mb(v['textuur_mem'])} | {mb(n['textuur_mem'])} | {(n['textuur_mem'] - v['textuur_mem']) / MB:+.1f} | {mb(v['statisch'])} | {mb(n['statisch'])} | {mb(v['rss'])} | {mb(n['rss'])} | {v['resources']} | {n['resources']} |")
            sommen["tex_v"] += v["textuur_mem"]
            sommen["tex_n"] += n["textuur_mem"]
            sommen["stat_v"] += v["statisch"]
            sommen["stat_n"] += n["statisch"]
            sommen["rss_v"] += v["rss"]
            sommen["rss_n"] += n["rss"]
            sommen["res_v"] += voor["kaarten"][naam]["na"]["resources"]
            sommen["res_n"] += n["resources"]
            sommen["n"] += 1
    if voor is not None and sommen["n"]:
        c = sommen["n"]
        uit.append(f"| **Gemiddelde ({c} kaarten)** | {sommen['tex_v'] / c / MB:.1f} | {sommen['tex_n'] / c / MB:.1f} | {(sommen['tex_n'] - sommen['tex_v']) / c / MB:+.1f} | {sommen['stat_v'] / c / MB:.1f} | {sommen['stat_n'] / c / MB:.1f} | {sommen['rss_v'] / c / MB:.1f} | {sommen['rss_n'] / c / MB:.1f} | {sommen['res_v'] / c:.0f} | {sommen['res_n'] / c:.0f} |")
    uit.append("")

    def atl(d):
        b = sum(k["texturen"].get("atlassen", {}).get("bronnen", 0) for k in d["kaarten"].values())
        m = sum(k["texturen"].get("atlassen", {}).get("met_padding", 0) for k in d["kaarten"].values())
        by = sum(k["texturen"].get("atlassen", {}).get("padding_bytes_rgba8", 0) for k in d["kaarten"].values())
        return b, m, by
    ab, am, aby = atl(na)
    if voor is not None:
        vb, vm, vby = atl(voor)
        uit.append(f"Tegelatlas-bronnen met `use_texture_padding` (opgevulde kopie in het geheugen), som over alle kaarten: voor {vm} van {vb} (atlas {mb(vby)} MB), na {am} van {ab} (atlas {mb(aby)} MB).\n")
    else:
        uit.append(f"Tegelatlas-bronnen met `use_texture_padding`, som over alle kaarten: {am} van {ab}.\n")

    uit.append("### 3. Sessie: alle kaarten achter elkaar in een proces (lekken/ophoping)\n")
    if na["sessie"]:
        e, ve = na["sessie"]["eind"], (voor["sessie"]["eind"] if voor and voor["sessie"] else None)
        uit.append(kop(voor))
        for lab, k, f in [("Texturen na afloop MB", "textuur_mem", mb), ("Statisch na afloop MB", "statisch", mb),
                          ("Statisch piek MB", "statisch_piek", mb), ("RSS na afloop MB", "rss", mb),
                          ("RSS piek MB", "rss_piek", mb), ("Objecten", "objecten", str), ("Resources", "resources", str)]:
            uit.append(rij(lab, e, ve, k, f))
        uit.append("")

    uit.append("### 4. WM1-gevechten (verse proces, totaal met gevecht open)\n")
    uit.append("| Gevecht (achtergrond) | Texturen MB voor | na | Statisch MB voor | na | Laadtijd ms voor | na |\n|---|---:|---:|---:|---:|---:|---:|")
    for naam, g in na["gevecht"].items():
        n = g["na"]
        if voor and naam in voor["gevecht"]:
            v = voor["gevecht"][naam]
            uit.append(f"| {naam} ({os.path.basename(g['achtergrond'])}) | {mb(v['na']['textuur_mem'])} | {mb(n['textuur_mem'])} | {mb(v['na']['statisch'])} | {mb(n['statisch'])} | {v['laadtijd_ms']:.0f} | {g['laadtijd_ms']:.0f} |")
        else:
            uit.append(f"| {naam} ({os.path.basename(g['achtergrond'])}) | - | {mb(n['textuur_mem'])} | - | {mb(n['statisch'])} | - | {g['laadtijd_ms']:.0f} |")
    uit.append("")

    tex = na["tex"]
    if tex:
        uit.append("### 5. Statische audit van alle png's (assets/, art/, world_warper/)\n")
        tot = sum(t["vram"] for t in tex)
        uit.append(f"- {len(tex)} textuurbestanden, samen {mb(tot)} MB als alles tegelijk geladen werd (nooit het geval).")
        fm = collections.Counter(t["formaat"] for t in tex)
        uit.append(f"- Formaten (Image.Format): {dict(fm)} (4 = RGB8, 5 = RGBA8). Mipmaps in beeldgegevens: {sum(1 for t in tex if t['mips'] > 0)} bestanden.")
        dub = dubbel(tex)
        sp = sum(sum(x['vram'] for x in g[1:]) for g in dub)
        uit.append(f"- Inhoudelijk identieke bestanden (zelfde pixels, andere naam): {len(dub)} groepen, {mb(sp)} MB overbodig als ze samen geladen zijn.")
        for g in dub[:12]:
            uit.append(f"  - {mb(g[0]['vram'])} MB x{len(g)}: " + ", ".join(f"`{x['pad'].replace('res://', '')}`" for x in g))
        top = sorted(tex, key=lambda t: -t["vram"])[:12]
        uit.append("- Zwaarste texturen:")
        for t in top:
            uit.append(f"  - {mb(t['vram'])} MB {t['w']}x{t['h']} `{t['pad'].replace('res://', '')}`")
    print("\n".join(uit))


main()
