#!/usr/bin/env python3
"""Eenmalige merge + scene-plaatsing voor lichtprops v2 (niet in CI)."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/tmp/lichtprops_v2")
EXCLUDE_MAPS = {"archief_2_v3_licht"}


def merge_json() -> None:
    lights_lp = json.loads((OUT / "lights_lichtprops.json").read_text())
    index_lp = json.loads((OUT / "maps_index_lichtprops.json").read_text())
    presets_lp = json.loads((OUT / "presets_lichtprops.json").read_text())
    lights_path = ROOT / "data/hd2d/lights.json"
    index_path = ROOT / "data/hd2d/maps_index.json"
    presets_path = ROOT / "data/hd2d/presets.json"
    lights = json.loads(lights_path.read_text())
    index = json.loads(index_path.read_text())
    presets = json.loads(presets_path.read_text())
    added_l = added_i = 0
    for k, v in lights_lp.get("assets", {}).items():
        if k in lights["assets"]:
            continue
        lights["assets"][k] = v
        added_l += 1
    for k, v in index_lp.items():
        if k.startswith("_"):
            continue
        if k in index:
            continue
        index[k] = v
        added_i += 1
    replaced = 0
    for mid, block in presets_lp.get("maps", {}).items():
        if mid in EXCLUDE_MAPS:
            continue
        presets["maps"][mid] = block
        replaced += 1
    lights_path.write_text(json.dumps(lights, indent=1) + "\n")
    index_path.write_text(json.dumps(index, indent=1) + "\n")
    presets_path.write_text(json.dumps(presets, indent=1) + "\n")
    print(f"merge: lights+{added_l} index+{added_i} presets maps {replaced}")


def scene_path_for(map_id: str, presets_lp: dict) -> str:
    rec = presets_lp.get("maps", {}).get(map_id, {})
    return str(rec.get("scene", ""))


def patch_scenes() -> None:
    placements = json.loads((OUT / "placements.json").read_text())
    presets_lp = json.loads((OUT / "presets_lichtprops.json").read_text())
    script_res = "res://scripts/hd2d/lichtprop_decor.gd"
    for mid, props in placements.get("maps", {}).items():
        if mid in EXCLUDE_MAPS:
            continue
        rel_scene = scene_path_for(mid, presets_lp)
        if not rel_scene:
            print("skip no scene", mid)
            continue
        tscn = ROOT / rel_scene.removeprefix("res://")
        if not tscn.is_file():
            print("missing", tscn)
            continue
        text = tscn.read_text()
        if "[node name=\"Lichtprops\"" in text:
            text = re.sub(
                r"\n\[node name=\"Lichtprops\".*",
                "",
                text,
                flags=re.DOTALL,
            )
        lines = text.splitlines()
        # strip trailing load_steps recount later
        ext_resources: list[str] = []
        tex_ids: dict[str, str] = {}
        script_id = ""
        sub_resources: list[str] = []
        prop_nodes: list[str] = []
        uid = 9000
        for i, p in enumerate(props):
            prop = p["prop"]
            tex_path = f"res://assets/sprites/lichtprops/{prop}.png"
            if prop not in tex_ids:
                uid += 1
                eid = f"lp_tex_{prop}"
                tex_ids[prop] = eid
                ext_resources.append(
                    f'[ext_resource type="Texture2D" path="{tex_path}" id="{eid}"]'
                )
            if not script_id:
                uid += 1
                script_id = "lp_script"
                ext_resources.append(
                    f'[ext_resource type="Script" path="{script_res}" id="{script_id}"]'
                )
            flip = "true" if p.get("flip") else "false"
            hf = int(p.get("hframes", 1))
            name = f"Lp_{prop}_{p['x']}_{p['y']}"
            prop_nodes.append(
                f'\n[node name="{name}" type="Sprite2D" parent="Objects"]\n'
                f"position = Vector2({p['x']}, {p['y']})\n"
                f"texture = ExtResource(\"{tex_ids[prop]}\")\n"
                f"hframes = {hf}\n"
                f"flip_h = {flip}\n"
                f"script = ExtResource(\"{script_id}\")\n"
                f'prop_id = "{prop}"'
            )
        if "[ext_resource" in text:
            insert_at = 0
            for j, ln in enumerate(lines):
                if ln.startswith("[gd_scene"):
                    m = re.search(r"load_steps=(\d+)", ln)
                    if m:
                        old = int(m.group(1))
                        new_steps = old + len(ext_resources)
                        lines[j] = re.sub(
                            r"load_steps=\d+",
                            f"load_steps={new_steps}",
                            ln,
                        )
                if ln.startswith("[ext_resource") and insert_at == 0:
                    insert_at = j
            # dedupe existing ext for same textures
            existing = set(lines)
            new_ext = [e for e in ext_resources if e not in existing]
            if insert_at:
                lines = lines[:insert_at] + new_ext + lines[insert_at:]
            else:
                lines = [lines[0]] + new_ext + lines[1:]
        else:
            lines[0] = re.sub(
                r"load_steps=\d+",
                f"load_steps={1 + len(ext_resources)}",
                lines[0],
            )
            lines = [lines[0]] + ext_resources + lines[1:]
        # append props before EOF
        out_text = "\n".join(lines).rstrip() + "".join(prop_nodes) + "\n"
        tscn.write_text(out_text)
        print("placed", mid, len(props), "->", tscn.name)


def main() -> None:
    merge_json()
    patch_scenes()


if __name__ == "__main__":
    main()
