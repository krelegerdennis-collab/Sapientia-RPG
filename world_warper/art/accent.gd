extends RefCounted
## World Warper: kleuraccent per Archief (CANON.md besluit 14). Art van RPG ART (batch 5/6, v0.21):
## grijs = het bestand zonder achtervoegsel (Archief 1), anders <naam>_<accent>.png ernaast.
## Paars licht, de romp en het icoon zijn universeel; sapientia_glitch en hanger_gloed hebben geen varianten.
##
## Welk Archief? story_flags["warper_archief"] (1-6) als die gezet is; anders het hoogste Archief
## waarvan de bewaker verslagen is (BEWAKERS). TIJDELIJKE AANNAME: de hub toont het accent van het
## laatst voltooide Archief (nu: Archief 2 na De Genezer, groen).

const ACCENTS := {1: "", 2: "groen", 3: "oranje", 4: "roze", 5: "blauw", 6: "rood"}
const FLAG := "warper_archief"
## Archief -> bewaker-vlag die het voltooit. Archief 3-6 bestaan nog niet.
const BEWAKERS := {2: "bewaker:archief_2_v4_genezer/genezer"}
## Alleen deze bestanden hebben varianten.
const MET_ACCENT := [
	"res://world_warper/art/tiles.png",
	"res://world_warper/art/echo.png",
	"res://world_warper/art/pc.png",
	"res://world_warper/art/warp_platform.png",
	"res://world_warper/art/bord_hal.png",
	"res://world_warper/art/bord_kamers.png",
	"res://world_warper/art/bord_warp.png",
	"res://world_warper/art/tafel.png",
	"res://world_warper/art/toonbank.png",
	"res://world_warper/art/party.png",
	"res://world_warper/art/vlak_warp.png",
	"res://world_warper/art/vlak_gezelschap.png",
	"res://assets/sprites/archief2/world_warper.png",
	"res://assets/sprites/archief2/echo.png",
]
const HANGER_GLOED := "res://world_warper/art/hanger_gloed.png"
const HANGER_FRAMES := 4
const HANGER_FRAME := Vector2i(16, 16)
const HANGER_FRAME_TIME := 0.16


static func suffix(archief: int) -> String:
	return str(ACCENTS.get(clampi(archief, 1, 6), ""))


## Pad van de variant voor dit Archief (het basispad als er geen variant is).
static func path(base: String, archief: int) -> String:
	var s := suffix(archief)
	if s == "" or not (base in MET_ACCENT):
		return base
	var p := base.get_basename() + "_" + s + "." + base.get_extension()
	return p if ResourceLoader.exists(p) else base


## Huidig Archief voor de vlaggen 'flags'.
static func archief_for(flags: Dictionary) -> int:
	if flags.has(FLAG) and int(flags[FLAG]) >= 1:
		return clampi(int(flags[FLAG]), 1, 6)
	var best := 1
	for n in BEWAKERS:
		if bool(flags.get(BEWAKERS[n], false)):
			best = maxi(best, int(n))
	return best


static func current() -> int:
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return 1
	return archief_for(gs.get("story_flags") if gs.get("story_flags") is Dictionary else {})


## Basispad terug uit een (variant)pad.
static func base_of(p: String) -> String:
	for b in MET_ACCENT:
		if p == b:
			return b
		for n in ACCENTS:
			if str(ACCENTS[n]) != "" and p == b.get_basename() + "_" + str(ACCENTS[n]) + "." + b.get_extension():
				return b
	return ""


static func _swap(tex: Texture2D, archief: int) -> Texture2D:
	if tex == null:
		return null
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		var inner := _swap(at.atlas, archief)
		if inner == at.atlas:
			return tex
		var copy := at.duplicate() as AtlasTexture
		copy.atlas = inner
		return copy
	var b := base_of(tex.resource_path)
	if b == "":
		return tex
	var want := path(b, archief)
	if want == tex.resource_path:
		return tex
	return load(want) as Texture2D


## Zet alle Warper-art onder 'root' op het accent van 'archief' (sprites, texture-rects, tegels).
static func apply_to(root: Node, archief: int) -> int:
	var n := 0
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is Sprite2D or node is TextureRect or node is TextureButton:
			var prop := "texture_normal" if node is TextureButton else "texture"
			var old: Texture2D = node.get(prop)
			var nieuw := _swap(old, archief)
			if nieuw != old:
				node.set(prop, nieuw)
				n += 1
		elif node is TileMapLayer:
			var ts: TileSet = (node as TileMapLayer).tile_set
			if ts == null:
				continue
			var changed: TileSet = null
			for i in ts.get_source_count():
				var src := ts.get_source(ts.get_source_id(i))
				if src is TileSetAtlasSource:
					var nt := _swap((src as TileSetAtlasSource).texture, archief)
					if nt != (src as TileSetAtlasSource).texture:
						if changed == null:
							changed = ts.duplicate(true) as TileSet
						(changed.get_source(ts.get_source_id(i)) as TileSetAtlasSource).texture = nt
			if changed != null:
				(node as TileMapLayer).tile_set = changed
				n += 1
	return n
