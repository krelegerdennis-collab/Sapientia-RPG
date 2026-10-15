# Phase 4: SoM-style fences (hekken)
Build: `python3 build.py` (reuses phase-1 `p1common`/`terrain` and `somlib`). Master palette only (checked), 1px INK outline, light top-left, contact shadow like the phase-3 props. Wood ramp = slot group `hout` (recolours with the phase-1 palettes: `wilgendal`, `herfst`, `donker_glitch`).

## Files (out/)
* `hekken_{wilgendal,herfst,donker_glitch}.png`: 256x32, 16px cells, transparent (overlay layer). `hekken_slots.png` = slot map (R group, G shade, B ramp; kind `hout`).
* `hekken_opaque_<palette>.png`: same cells with the Willowdale grass baked in (opaque), for a 1:1 swap of the old opaque tile.
* `hekken_index.json`: per tile name, col/row, mask, role, solid, `collision_polygon`, plus `autotile_lookup_mask_to_atlas_xy`, gate coordinates, old-fence data.
* `hekken_tileset_snippet.txt`: draft `TileSetAtlasSource` lines (physics polygon + custom_data) in the same form as `dorp.tres`.
* `demo_hekken_<palette>.png`: 16x9 sample map.

## Layout and mask
Row 0 = **autotile, atlas col = mask**, mask bits **N=1 E=2 S=4 W=8** (same order as the repo's path/cobble masks); bit set = neighbour cell is fence or gate. Gate-H counts as E+W, gate-V as N+S.
| mask | tile | | mask | tile |
|---|---|---|---|---|
| 0 | lone post | | 7 / 11 / 13 / 14 | T (stem E / N / W / S) |
| 1,2,4,8 | end (open N/E/S/W) | | 5 / 10 | straight N-S / E-W |
| 3,6,12,9 | corners NE, SE, SW, NW | | 15 | cross |
Row 1: `hek_10_b` (E-W with a post, use every 3rd-4th tile for rhythm), `hek_05_b` (N-S with a taller post), gates: col 2 `hek_poort_h_dicht`, col 3 `hek_poort_h_open`, col 4 `hek_poort_v_dicht`, col 5 `hek_poort_v_open`. Names: `hek_<mask:02d>`.
Look: E-W runs are 3px pointed pickets on two rails (4px period, seamless over the tile edge), posts with caps at corners/ends/T/gates; N-S runs are a thin side-on rail with a capped post per tile. Gate H open = leaf swung toward the viewer (end-on); gate V open = leaf swung east (face-on).

## Collision (per piece)
* Every fence piece (masks 0-15, `_b` variants) and both **closed** gates: full 16x16 tile, polygon `-8,-8, 8,-8, 8,8, -8,8` (identical to the old hek).
* **Open gates: no collision** (the whole tile is walkable; posts/leaf are decoration inside the tile). Switch tile `hek_poort_*_dicht` <-> `_open` + the physics polygon when the gate opens.
* Tile size is 16x16 for all pieces; no piece overhangs, so no walk-behind rows.

## Old fence in the repo (for the 1:1 swap)
* `assets/tiles/dorp.png` (864x16 strip, 54 tiles): **tile index 50**, 16x16, opaque dark-green/grey rails on a grass background. `assets/tiles/dorp.tres`: tile 50 has the full-tile polygon and `custom_data_0 = "hek"`. `tools/build_maps.gd`: map char `"-"` -> 50, `TOWN_SOLID` contains 50, `TOWN_TERRAIN[50] = "hek"`.
* `scripts/data/wilgendal_dorp.gd` `GROND/TEGEL` has no `-` tile; the fence visible in the screenshot comes from that old tile 50 / the old dorp tileset. Other fences in the repo: `assets/sprites/buiten/bouw_hek.png` (32x16 red-white construction barrier, a prop, left alone) and `scripts/puzzle/gate.gd` (iron puzzle gate, 64x16, left alone).
* Swap options: (a) overlay layer above Ground with `hekken_<pal>.png` and compute the mask from the 4 neighbours; (b) put `hekken_opaque_<pal>.png` in the Ground tileset (same 16x16 opaque cells, grass included) and replace every old 50 by `mask -> atlas (mask,0)`. Old single tile = `hek_10` (E-W) is the nearest equivalent if no autotiling is wanted.
* GDScript idea: `mask = (N?1:0)|(E?2:0)|(S?4:0)|(W?8:0); set_cell(pos, src, Vector2i(mask,0))`.

## Previews (preview/)
`hekken_demo_4x.png` (1024x576, best one), `hekken_sheet_4x.png`, `hekken_oud_vs_nieuw_6x.png` (old tile 50 above, new run below), `hekken_palettes_5x.png` (3 palettes).

## Open points
* Straight N-S runs are drawn side-on (thin rail + posts), so they look different from E-W runs; this is the usual JRPG view but not a picket face.
* Hek_10 has no wear variants (broken/mossy); only the post variant.
* The old tile is opaque and recoloured by the tileset; if Forge keeps the old tile in some maps, both styles can't be mixed in one run without the mask tile ends showing.
* The vertical gate closed is a simple board between posts; it reads as a gate mostly through the latch.
* Gate open/closed animation is two states, no in-between frames.
