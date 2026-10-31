extends Node
## WM1 testdekking (--wm1dekkingtest): drie tot nu toe ongeteste scripts (zie TEST_DEKKING_WM1.md).
## - scripts/data/dungeon100_reward.gd  (beloning verdieping 100: codex / wapens / ring)
## - scripts/core/atlas_zuinig.gd       (texture-padding uit op tegelatlassen)
## - scripts/battle/hd_ui.gd            (halve HD-textures + cache, terugval)
## Start: godot --path . -- --wm1dekkingtest

const Reward := preload("res://scripts/data/dungeon100_reward.gd")
const Zuinig := preload("res://scripts/core/atlas_zuinig.gd")
const Hd := preload("res://scripts/battle/hd_ui.gd")

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	_reward_tests()
	_atlas_tests()
	_hd_tests()
	print("WM1DEKKINGTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _reward_tests() -> void:
	check("reward: drie keuzes, drie ids", Reward.KEUZES.size() == 3 and Reward.IDS.size() == 3)
	for id in Reward.IDS:
		check("reward: geldig(%s)" % id, Reward.geldig(id))
	check("reward: onbekende keuze ongeldig", not Reward.geldig("goud") and not Reward.geldig(""))

	GameState.new_game("Dax")
	GameState.dungeon100_permanent = {}
	GameState.dungeon100_delivered = {}
	var pagina_voor := GameState.codex_pages.size()
	Reward.geef("codex")
	check("reward codex: ECHO-pagina erbij", GameState.codex_pages.size() == pagina_voor + 1
			and str((GameState.codex_pages.back() as Dictionary).get("species", "echo")) == "echo")
	check("reward codex: ECHO gezien", GameState.is_seen("echo"))

	var ring_voor := GameState.item_count(Reward.RING_ID)
	Reward.geef("ring")
	check("reward ring: in de tas", GameState.item_count(Reward.RING_ID) == ring_voor + 1)
	check("reward ring: permanent + geleverd", int(GameState.dungeon100_permanent.get(Reward.RING_ID, 0)) == 1
			and int(GameState.dungeon100_delivered.get(Reward.RING_ID, 0)) == 1)
	Reward.geef("ring")
	check("reward ring: tweede keer telt op", int(GameState.dungeon100_permanent.get(Reward.RING_ID, 0)) == 2)

	Reward.geef("wapens")
	for id in Reward.WAPENS:
		check("reward wapens: %s permanent" % id, int(GameState.dungeon100_permanent.get(id, 0)) == 1)
	var held: Dictionary = GameState.party[0]
	check("reward wapens: leider draagt een G4-wapen",
			str((held.get("equip", {}) as Dictionary).get("wapen", "")) in Reward.WAPENS)

	var leeg := GameState.inventory.duplicate(true)
	Reward.geef("onzin")
	check("reward: onbekende keuze verandert de tas niet", GameState.inventory == leeg)

	check("draagt_ring: lege party", not Reward.draagt_ring([]))
	check("draagt_ring: rommel in de party", not Reward.draagt_ring([null, 3, "x"]))
	check("draagt_ring: ander accessoire", not Reward.draagt_ring([{"equip": {"accessoire": "iets"}}]))
	check("draagt_ring: ring om", Reward.draagt_ring([{"equip": {}}, {"equip": {"accessoire": Reward.RING_ID}}]))


func _atlas_tests() -> void:
	var img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	var ts := TileSet.new()
	var a := TileSetAtlasSource.new()
	a.texture = ImageTexture.create_from_image(img)
	var b := TileSetAtlasSource.new()
	b.texture = ImageTexture.create_from_image(img)
	b.use_texture_padding = false
	ts.add_source(a)
	ts.add_source(b)
	check("atlas: padding staat standaard aan", a.use_texture_padding)

	var wortel := Node.new()
	var tak := Node.new()
	wortel.add_child(tak)
	var laag1 := TileMapLayer.new()
	laag1.tile_set = ts
	tak.add_child(laag1)
	var laag2 := TileMapLayer.new()
	laag2.tile_set = ts  # zelfde TileSet: maar één keer tellen
	wortel.add_child(laag2)
	check("atlas: toepassen telt alleen de bron met padding", Zuinig.toepassen(wortel) == 1)
	check("atlas: padding nu uit", not a.use_texture_padding and not b.use_texture_padding)
	check("atlas: tweede keer niets te doen", Zuinig.toepassen(wortel) == 0)
	a.use_texture_padding = true
	check("atlas: tileset_zuinig los", Zuinig.tileset_zuinig(ts) == 1 and not a.use_texture_padding)
	var kaal := Node.new()
	kaal.add_child(TileMapLayer.new())  # zonder tile_set
	check("atlas: laag zonder TileSet geeft 0", Zuinig.toepassen(kaal) == 0)
	wortel.free()
	kaal.free()


func _hd_tests() -> void:
	var terug := ImageTexture.create_from_image(Image.create(12, 12, false, Image.FORMAT_RGBA8))
	check("hd: ontbrekend pad geeft terugval", Hd.half_texture("res://bestaat/niet.png", terug) == terug)
	check("hd: ontbrekend pad zonder terugval geeft null", Hd.half_texture("res://bestaat/niet.png") == null)
	var pad := "res://assets/ui/window_hd.png"
	var t := Hd.half_texture(pad, terug)
	check("hd: window_hd geladen", t != null)
	if t is ImageTexture:
		var bron: Texture2D = load(pad)
		check("hd: halve maat", t.get_size() == bron.get_size() / 2.0)
		check("hd: cache geeft hetzelfde object", Hd.half_texture(pad) == t)
	var sb := StyleBoxTexture.new()
	sb.texture = terug
	var hd_sb := Hd.hd_style(sb, pad)
	check("hd: hd_style maakt een kopie", hd_sb != sb and sb.texture == terug)
	check("hd: is_hd na hd_style", Hd.is_hd(hd_sb) and (hd_sb as StyleBoxTexture).texture == t)
	var flat := StyleBoxFlat.new()
	check("hd: geen texture-stylebox blijft gelijk", Hd.hd_style(flat, pad) == flat)
	check("hd: StyleBoxFlat is niet hd", not Hd.is_hd(flat))
	var geen := StyleBoxTexture.new()
	check("hd: StyleBoxTexture zonder ImageTexture is niet hd", not Hd.is_hd(geen))
