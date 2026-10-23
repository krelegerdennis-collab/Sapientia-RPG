# SAPIENTIA – final map sprites (Dax, Seren, Vesper) – 20 Oct 2026

## Format
- 72x128 transparent PNG, 24x32 frames. Columns: stand, stepA, stepB. Rows: down, left, right, up (same layout as the existing kaart sheets).
- 1px outline, light from top-left. All colours are in tools/som/sapientia_palette.json, with no off-palette colours (see palettes.json).
- Colour counts: dax_wm1 22, dax_wm2 20, seren_wm1 24, vesper_wm1 23. Each character uses <=15 colours in palette A (skin/hair/eye/line/hl) and <=15 in palette B (clothes/gear).

## Files -> repo (do not copy automatically; review first)
| final_trio file | replaces in code_battlesim/repo |
|---|---|
| dax_wm1.png    | assets/sprites/som/kaart/dax_wm1.png |
| dax_wm2.png    | assets/sprites/som/kaart/dax_wm2.png |
| seren_wm1.png  | assets/sprites/som/kaart/seren_wm1.png |
| vesper_wm1.png | assets/sprites/som/kaart/vesper.png (rename!) |

How it is loaded: scripts/data/kaart_stijl.gd `speler_sheet()` takes `party[0].name` in lower case ("Dax", "Seren", "Vesper"), so it uses the name and not the battle ids dennis/lotte/noor.
- It tries `<helden>/<naam>_<held_variant>.png` first, then `<naam>.png`, then `<naam>_wm2.png`. `helden` = res://assets/sprites/som/kaart/.
- Exactly one area in gebieden.json has held_variant "wm1". Elsewhere Vesper loads `vesper.png`, so ship her sheet as vesper.png. Keeping a vesper_wm1.png copy as well is optional.
- The existing .png.import files keep working when the PNG is replaced under the same name.

## Extras
- lineup_<name>.png: all 12 frames at 4x. lineup_trio_vs_anime.png: crop of the official key art next to front/right/right-step/left/back frames of all three.
- walk_<name>_6x.gif: walk cycles for all 4 directions.

## Design notes
- Human race model = Dax. Seren and Vesper are built on his grids (head outline, face style, legs) and get their own bodies, hair and outfits from ref/anime/*.jpg.
- Dax: v71 + a cool outline rim so he reads on dark dungeon floors. The new purple crystal pendant (e8b8ff/a466f0, 2px) is in the WM1 front view only, not in WM2.
- Seren: pale blonde braid with a blue ribbon, white robe with hood over a white-blue dress, light-blue hem, dark staff with a blue crystal.
- Vesper: brown high ponytail with a purple ribbon, dark hooded cape with purple trim and a tree emblem, dark top, short skirt, thigh-high socks, brown boots, dark staff with a purple glowing orb.

## Open points
- Seren WM2 (seren_wm2.png) has not been redone; it still has the old look.
- Orion, Bram and Kael have not been redone in this style.
- Door size: check that 24x32 figures fit the SoM door and arch tiles (16px grid). Not tested in-engine.
- Dax's sword can be added later as a scabbard on his back (side/back views). Keep the glowing blade for battle and cutscenes.
- Dax WM2 has the same rim but no pendant.
- Nothing has been tested in Godot. The images were checked offline only.
