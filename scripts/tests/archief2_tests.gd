extends Node
## Headless suite voor Archief 2 (Het Levende Archief).
## Start: godot --path . -- --archief2test [--shots=/pad/map]

const WarperCanon := preload("res://world_warper/cutscene/canon_scenes.gd")
const GenezerScene := preload("res://world_warper/cutscene/genezer_scene.gd")
const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const KernData := preload("res://scripts/data/kern_data.gd")
const DungeonRooms := preload("res://scripts/data/dungeon_rooms.gd")
const Rooms := preload("res://scripts/data/archief2_rooms.gd")
const Archief2 := preload("res://scripts/data/archief2.gd")
const BossCore := preload("res://scripts/battle/boss_core.gd")
const PuzzleRooms := preload("res://scripts/data/puzzle_rooms.gd")
const PuzzleLogic := preload("res://scripts/puzzle/puzzle_logic.gd")
const Equipment := preload("res://scripts/equipment.gd")
const WarperEnter := preload("res://world_warper/flow/enter.gd")
const NaGenezer := preload("res://world_warper/flow/na_genezer.gd")
const WarperUnlock := preload("res://world_warper/flow/unlock.gd")
const HangerScene := preload("res://world_warper/cutscene/hanger_scene.gd")
const WarperDialoog := preload("res://world_warper/guide/dialoog.gd")
const WarperDreiging := preload("res://world_warper/cutscene/dreiging.gd")
const GENEZER_SCENE := "res://scenes/maps/archief_2_v4_genezer.tscn"
const AANVAL := 0
const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up"}
const AV := preload("res://scripts/data/archief2_vijanden.gd")
const CD := preload("res://scripts/data/codex_data.gd")
const LICHT_SCENE := "res://scenes/maps/archief_2_v3_licht.tscn"

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	print("=== Archief 2: data ===")
	_data()
	print("=== Archief 2: poort en platen ===")
	_poort_en_platen()
	print("=== Archief 2: Seren, Mosslijm, Mender ===")
	_lotte_en_genezer()
	print("=== Archief 2: muziek ===")
	_muziek()
	print("=== Archief 2: wereldkaart ===")
	await _wereldkaart()
	print("=== Archief 2: kamer, gevecht, warp ===")
	await _spel()
	print("=== Archief 2: na The Mender naar de hub ===")
	await _genezer_podium()
	await _na_genezer_hub()
	print("=== Archief 2: veldmenu > Scenes > The World Warper (alleen het filmpje) ===")
	await _scenes_warper_herhaling()
	print("=== Archief 2: vijanden (data en regels) ===")
	_vijanden()
	print("=== Archief 2: vijanden en Codex-bondgenoten in het gevecht ===")
	await _vijanden_gevecht()
	print("=== Archief 2: Deel G kas v8.1 blokvloer ===")
	await _kas_blok_tests()
	print("ARCHIEF2TEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	Engine.time_scale = 1.0
	await _pframes(10)
	get_tree().quit(1 if failures else 0)


func _data() -> void:
	var err: Array = KernData.validate(GD.ENEMIES)
	check("KernData.validate leeg %s" % [err], err.is_empty())
	check("levenskern hoort bij genezer", KernData.fragment_for_boss("genezer") == Archief2.KERN_ID)
	var f := KernData.fragment(Archief2.KERN_ID)
	check("kern-zin exact", str(f.get("beschrijving", "")) == Archief2.KERN_ZIN)
	var icon: Texture2D = load(str(f.get("icon", "")))
	check("levenskern-icoon 16x16", icon != null and icon.get_size() == Vector2(16, 16))
	for id in ["lotte_glitch", "wurger", "genezer"]:
		check("vijand %s" % id, GD.ENEMIES.has(id))
	check("Wurger HP/ATK/DEF canon", int(GD.ENEMIES["wurger"]["max_hp"]) == Archief2.WURGER_HP
			and int(GD.ENEMIES["wurger"]["atk"]) == Archief2.WURGER_ATK
			and int(GD.ENEMIES["wurger"]["def"]) == Archief2.WURGER_DEF
			and int(GD.ENEMIES["wurger"]["boss"]["max_hp"]) == Archief2.WURGER_HP
			and int(GD.ENEMIES["wurger"]["boss"]["atk"]) == Archief2.WURGER_ATK
			and int(GD.ENEMIES["wurger"]["boss"]["def"]) == Archief2.WURGER_DEF)
	check("Genezer HP/ATK/DEF canon", int(GD.ENEMIES["genezer"]["max_hp"]) == Archief2.GENEZER_HP
			and int(GD.ENEMIES["genezer"]["atk"]) == Archief2.GENEZER_ATK
			and int(GD.ENEMIES["genezer"]["def"]) == Archief2.GENEZER_DEF
			and int(GD.ENEMIES["genezer"]["boss"]["atk"]) == Archief2.GENEZER_ATK
			and int(GD.ENEMIES["genezer"]["boss"]["def"]) == Archief2.GENEZER_DEF)
	# v0.21: baas-uitzondering in battle.gd (max 256x200), gewone vijanden blijven op 194 hoog.
	var BattleC = load("res://scripts/battle/battle.gd")
	var gen_tex: Texture2D = load(str(GD.ENEMIES["genezer"]["sprite"]))
	check("Genezer-baas: is_boss, rug, 240x194 op ware grootte; baasgrens 256x200, gewoon 194",
			bool(GD.ENEMIES["genezer"].get("is_boss", false))
			and ResourceLoader.exists(str(GD.ENEMIES["genezer"].get("sprite_back", "")))
			and BattleC.BOSS_MAX_ART_W == 256 and BattleC.BOSS_MAX_ART_H == 200 and BattleC.MAX_ENEMY_ART_H == 194
			and BattleC.art_fit(gen_tex.get_size(), true) == 1.0
			and BattleC.art_fit(Vector2(256, 200), true) == 1.0
			and is_equal_approx(BattleC.art_fit(Vector2(256, 400), true), 0.5)
			and is_equal_approx(BattleC.art_fit(Vector2(512, 100), true), 0.5)
			and BattleC.art_fit(Vector2(90, 194), false) == 1.0
			and is_equal_approx(BattleC.art_fit(Vector2(90, 200), false), 194.0 / 200.0))
	var toegepast := BossCore.apply_boss(GD.ENEMIES["genezer"])
	check("Genezer-baas: opening, leech, zin", bool(toegepast.get("archief2_open", false))
			and bool(toegepast.get("archief2_leech", false))
			and str(toegepast.get("archief2_zin", "")) == Archief2.KERN_ZIN
			and int(toegepast.get("max_hp", 0)) == Archief2.GENEZER_HP)
	var wurg := BossCore.apply_boss(GD.ENEMIES["wurger"])
	check("Strangler zwak voor ijs en fysiek", bool(wurg.get("weak_matters", false))
			and "ijs" in wurg.get("weak", []) and "fysiek" in wurg.get("weak", []))
	check("Strangler: canon-zin in het bestiarium", str(GD.ENEMIES["wurger"]["desc"]) == "A vine with nowhere to go. The Old Humanity grew it as protection, but Sapientia turned its growth inward. Now it strangles what it should protect. Whoever defeats it hears it sigh — like an animal that wants to be set free.")
	check("Mender: canon-zin in het bestiarium", str(GD.ENEMIES["genezer"]["desc"]) == "He heals by taking. He gives nothing back. Sapientia's perfect servant: without doubt, without emotion, without end. Whoever sees him sees what humanity becomes if Sapientia wins — silent, whole, and empty.")
	check("thema kas en warper", DungeonRooms.THEMES.has("kas") and DungeonRooms.THEMES.has("warper_paars"))
	var kamers: Dictionary = Rooms.rooms()
	var breed := true
	for id in kamers:
		if DungeonRooms.ROOMS.has(id):
			breed = false
		var layout: Array = kamers[id].get("layout", [])
		if layout.is_empty():
			breed = false
		var w := str(layout[0]).length() if not layout.is_empty() else 0
		for row in layout:
			if str(row).length() != w:
				breed = false
		if not ResourceLoader.exists(str(Rooms.SCENES.get(id, ""))):
			breed = false
	check("11 kamers, zelfde regelbreedte, niet in ROOMS, scènes bestaan", breed and kamers.size() == 11)
	var plaat: Dictionary = kamers["archief_2_v1_plaat"]
	check("verdieping 1: één groei-plaat", plaat["platen"].size() == 1 and str(plaat["platen"][0]["soort"]) == "groei")
	var ketting: Dictionary = kamers["archief_2_v3_ketting"]
	check("verdieping 3: drie ketting-platen", ketting["platen"].size() == 3)
	check("tegen-plaat start volgroeid", int(kamers["archief_2_v3_tegen"]["platen"][0]["start"]) == 2
			and str(kamers["archief_2_v3_tegen"]["platen"][0]["soort"]) == "tegen")
	check("licht-plaat na Seren", str(kamers["archief_2_v3_licht"]["platen"][0]["soort"]) == "licht")
	var echo := " ".join(Archief2.ECHO_REGELS)
	check("kaartkamer: geen ECHO-uitleg meer (canon in de Hal), geen onderzoeker", echo.find("H-6") < 0
			and echo.find("onderzoeker") < 0 and echo.to_lower().find("digitale echo") < 0)
	var cat = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/actor_sfx.json"))
	var monsters: Dictionary = cat.get("monsters", {}) if cat is Dictionary else {}
	check("actor-sfx voor de drie bazen", monsters.has("lotte_glitch") and monsters.has("wurger")
			and monsters.has("genezer"))
	var maten := {
		"res://assets/tiles/dungeon/kas_tiles.png": Vector2(256, 80),
		"res://assets/tiles/dungeon/kas_tiles_v8.png": Vector2(256, 80),
		"res://assets/tiles/dungeon/kas_tiles_v8b.png": Vector2(256, 96),
		"res://assets/tiles/dungeon/kas_bibliotheek_v8.png": Vector2(256, 64),
		"res://assets/puzzle/groei_plaat.png": Vector2(48, 16),
		"res://assets/sprites/archief2/lotte_veld.png": Vector2(48, 96),
		"res://assets/sprites/archief2/lotte_glitch.png": Vector2(64, 80),
		"res://assets/sprites/archief2/genezer.png": Vector2(240, 194),
		"res://assets/sprites/archief2/genezer_rug.png": Vector2(240, 194),
		"res://assets/sprites/archief2/wurger.png": Vector2(80, 96),
		"res://assets/sprites/archief2/plaat_zaad.png": Vector2(16, 16),
		"res://assets/sprites/archief2/plaat_scheut.png": Vector2(16, 16),
		"res://assets/sprites/archief2/plaat_volgroeid.png": Vector2(16, 16),
		"res://assets/sprites/archief2/world_warper.png": Vector2(128, 64),
		"res://assets/sprites/archief2/echo.png": Vector2(32, 48),
		"res://assets/sprites/archief2/sapientia_glitch.png": Vector2(48, 48),
	}
	var art_ok := true
	for pad in maten:
		var tex: Texture2D = load(pad)
		if tex == null or tex.get_size() != maten[pad]:
			art_ok = false
	check("placeholder-maten", art_ok)


func _poort_en_platen() -> void:
	check("vlag = Archief 1 golem", Archief2.GOLEM_VLAG == SD.GOLEM_FLAG)
	check("dicht zonder vlag", not Archief2.open_na({}))
	check("open na de golem", Archief2.open_na({Archief2.GOLEM_VLAG: true}))
	GameState.new_game("Dax")
	var dicht: Dictionary = Story.pick("naar_leven")
	check("verhaal houdt de kas dicht", dicht.get("do") is Array)
	GameState.story_flags[SD.GOLEM_FLAG] = true
	var open: Dictionary = Story.pick("naar_leven")
	check("verhaal geeft de uitgang vrij", str(open.get("do", "")) == "default")
	var pr: Dictionary = PuzzleRooms.ROOMS["leven_v1_plaat"]
	var pl := PuzzleLogic.from_room(pr, "leven_v1_plaat")
	check("groei-plaat vóór de hendel blijft zaad", pl.try_grow("groei_brug") == "wacht" and pl.grow_stage("groei_brug") == 0
			and pl.is_solid(Vector2i(7, 2)))
	check("na de hendel groeit de plaat één stadium", pl.toggle_lever("hendel_kas") and pl.try_grow("groei_brug") == "groei"
			and pl.grow_stage("groei_brug") == 1 and pl.is_solid(Vector2i(7, 2)))
	check("tweede groei opent het pad", pl.try_grow("groei_brug") == "open" and pl.grow_open("groei_brug")
			and not pl.is_solid(Vector2i(7, 2)))
	var combi: Dictionary = PuzzleRooms.ROOMS["leven_v3_combi"]
	var combi_fouten: Array = PuzzleLogic.validate(combi)
	check("combinatiekamer is geldig %s" % [combi_fouten], combi_fouten.is_empty())
	check("ketting gaat naar de combinatiekamer", str(Rooms.rooms()["archief_2_v3_ketting"]["exits"]["n"]["map"]).ends_with("leven_v3_combi.tscn"))
	var cp := PuzzleLogic.from_room(combi, "leven_v3_combi")
	check("plaat wacht op hendel en kast", cp.try_grow("groei_combi") == "wacht" and cp.is_solid(Vector2i(5, 2)))
	check("alleen de hendel is niet genoeg", cp.toggle_lever("hendel_combi") and cp.try_grow("groei_combi") == "wacht")
	check("hendel weer uit", cp.toggle_lever("hendel_combi") == false)
	check("kast landt op de plaat", cp.try_push("kast_combi", Vector2i.RIGHT) and cp.try_push("kast_combi", Vector2i.RIGHT)
			and cp.plate_pressed("plaat_kast"))
	check("kast zonder hendel wacht nog", cp.try_grow("groei_combi") == "wacht")
	check("hendel en kast laten de plaat groeien", cp.toggle_lever("hendel_combi") and cp.try_grow("groei_combi") == "groei")
	check("tweede groei opent de spleet", cp.try_grow("groei_combi") == "open" and not cp.is_solid(Vector2i(5, 2)))
	check("groei + stap 0-1-2 en blijft", _groei_reeks())
	check("groei negeert licht", Archief2.volgende_staat("groei", 0, "licht", true) == 0)
	check("tegen krimpt en groeit niet", Archief2.volgende_staat("tegen", 2, "stap", false) == 1
			and Archief2.volgende_staat("tegen", 0, "stap", false) == 0
			and Archief2.volgende_staat("tegen", 1, "licht", true) == 1)
	check("licht alleen met magie", Archief2.volgende_staat("licht", 0, "licht", false) == 0
			and Archief2.volgende_staat("licht", 0, "licht", true) == 1
			and Archief2.volgende_staat("licht", 0, "stap", true) == 0)
	check("brug pas volgroeid", not Archief2.brug_open(0) and not Archief2.brug_open(1) and Archief2.brug_open(2))
	check("laatste ketting-plaat groeit niet vanzelf", Archief2.pas_ketting([0, 0, 0], 2) == [0, 0, 0])
	check("ketting activeert de volgende", Archief2.pas_ketting([0, 0, 0], 0) == [1, 1, 0]
			and Archief2.pas_ketting([1, 1, 0], 1) == [1, 2, 1])
	var mos := {"s": {"weak_matters": false, "weak": ["vuur"]}}
	var wurger := {"s": {"weak_matters": true, "weak": ["ijs", "fysiek"]}}
	var genezer := {"s": {"weak_matters": true, "weak": ["ijs", "zwaard"]}}
	var dennis := {"is_hero": true, "ally": false, "s": {"id": "dennis"}}
	var noor := {"is_hero": true, "ally": false, "s": {"id": "noor"}}
	check("gewone vijand: geen zwakte", Archief2.schaal_element(10, mos, "vuur") == 10
			and is_equal_approx(Archief2.zwakte_fysiek(dennis, mos), 1.0))
	check("Strangler: elke fysieke klap", is_equal_approx(Archief2.zwakte_fysiek(dennis, wurger), Archief2.ZWAK)
			and is_equal_approx(Archief2.zwakte_fysiek(noor, wurger), Archief2.ZWAK))
	check("Mender: zwaard van Dax, niet van Vesper", is_equal_approx(Archief2.zwakte_fysiek(dennis, genezer), Archief2.ZWAK)
			and is_equal_approx(Archief2.zwakte_fysiek(noor, genezer), 1.0))
	check("ijs telt, vuur niet", Archief2.schaal_element(10, genezer, "ijs") == 15
			and Archief2.schaal_element(10, genezer, "vuur") == 10)


func _groei_reeks() -> bool:
	var s := 0
	s = Archief2.volgende_staat("groei", s, "stap", false)
	if s != 1:
		return false
	s = Archief2.volgende_staat("groei", s, "stap", false)
	if s != 2:
		return false
	return Archief2.volgende_staat("groei", s, "stap", false) == 2


func _lotte_en_genezer() -> void:
	GameState.new_game("Dax")
	check("zonder Seren geen licht", not Archief2.lotte_heeft_licht())
	GameState.give_exp(GameState.party[0], GD.exp_for_level(7))
	check("Dax level 7", GameState.member_level("dennis") == 7)
	check("Seren sluit aan op dat level", Archief2.sluit_lotte_aan())
	var lotte := _held("lotte")
	check("level gelijk, priester, graad 1", GameState.member_level("lotte") == 7
			and str(lotte.get("class", "")) == "Priest"
			and lotte.get("spells", []) == ["genees", "rijp"])
	check("staf en gewaad", Equipment.equipped(lotte, "wapen") == "eiken_staf"
			and Equipment.equipped(lotte, "harnas") == "reisgewaad")
	check("Seren heeft Licht graad 1", Archief2.lotte_heeft_licht())
	GameState.archief2_lotte_join = false
	GameState.pending_story_loss = true
	var winst := GameState.archief2_verwerk_einde("win")
	check("winst: Seren sluit aan, geen game over", winst == "win" and GameState.archief2_lotte_join)
	GameState.archief2_lotte_join = false
	GameState.pending_story_loss = true
	var verlies := GameState.archief2_verwerk_einde("lose")
	check("verlies wordt verhaal, Seren sluit aan", verlies == "story" and GameState.archief2_lotte_join)
	GameState.archief2_lotte_join = false
	GameState.pending_story_loss = true
	var vlucht := GameState.archief2_verwerk_einde("flee")
	check("vluchten telt niet", vlucht == "flee" and not GameState.archief2_lotte_join)
	GameState.new_game("Dax")
	var voor := GameState.codex_pages.size()
	var tijdelijk := Archief2.bondgenoot_voor([], GameState.member_level("dennis"))
	check("zonder Codex: tijdelijke Mosslijm", bool(tijdelijk.get("tijdelijk", false))
			and str(tijdelijk["page"].get("name", "")) == "Mosslijm"
			and str(tijdelijk["page"].get("species", "")) == "mosslijm")
	Archief2.zet_bondgenoot(tijdelijk)
	check("tijdelijke bondgenoot komt niet in de Codex", GameState.codex_pages.size() == voor
			and str(GameState.archief2_temp_ally.get("name", "")) == "Mosslijm")
	GameState.archief2_temp_ally = {}
	var pagina := GameState.codex_add("glitchmot", 3)
	var gekozen := Archief2.bondgenoot_voor(GameState.codex_pages, 3)
	check("gevangen monster gaat voor", not bool(gekozen.get("tijdelijk", false))
			and str(gekozen["page"].get("uid", "")) == str(pagina.get("uid", "x")))
	check("opening ongeveer 30%", Archief2.openingslag(100) == 30 and Archief2.openingslag(42) == 13
			and Archief2.openingslag(10) == 3)
	var laag := Archief2.leech_resultaat(0.0, 100, 50, 220)
	var hoog := Archief2.leech_resultaat(1.0, 100, 50, 220)
	check("leech 8% en 12%, heal gelijk", int(laag["schade"]) == 8 and int(laag["heal"]) == 8
			and int(laag["hp_na"]) == 58 and int(hoog["schade"]) == 12 and int(hoog["heal"]) == 12)
	GameState.archief2_zet_plaat("archief_2_v1_plaat", "p1", 2)
	var data := GameState.state_data(Vector2i.ZERO, Vector2i.DOWN)
	check("plaat in de save", int(data["archief2"]["platen"].get("archief_2_v1_plaat:p1", 0)) == 2)
	data["archief2"] = {}
	check("apply_state zonder platen", GameState.apply_state(data))
	check("plaat valt terug op 0", GameState.archief2_plaat("archief_2_v1_plaat", "p1", 0) == 0)
	check("warp WM2/WM3 leeg", Archief2.warp_doel("wm2").is_empty() and Archief2.warp_doel("wm3").is_empty())
	var doel := Archief2.warp_doel("wilgendal")
	check("warp Willowdale", str(doel.get("map", "")) == Archief2.WERELD and str(doel.get("spawn", "")) == "van_wilgendal")
	var archief := Archief2.warp_doel("archief")
	check("warp Archief-ingang", str(archief.get("spawn", "")) == "van_archief")


func _held(id: String) -> Dictionary:
	for h in GameState.party:
		if str(h.get("id", "")) == id:
			return h
	return {}


func _wereldkaart() -> void:
	# Godot 4.7: load() wacht de loader-thread af zonder de message queue te legen
	# en loopt dan vast op deze scène. Eén frame tussendoor maakt de load af.
	ResourceLoader.load_threaded_request(Archief2.WERELD)
	while ResourceLoader.load_threaded_get_status(Archief2.WERELD) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var packed: PackedScene = ResourceLoader.load_threaded_get(Archief2.WERELD) as PackedScene
	var kaart := packed.instantiate()
	var grond: TileMapLayer = kaart.get_node("Ground")
	var trap: Node = kaart.get_node("Exits/Trap")
	var uit: Node = kaart.get_node("Exits/NaarKas")
	var spawn: Node2D = kaart.get_node("Spawns/van_kas")
	check("oude val blijft Archief 1", trap.position == Vector2(320, 544)
			and str(trap.target_map).ends_with("archief_ingang.tscn") and str(trap.event) == ""
			and trap.contains(Vector2i(20, 34)))
	var tegel := Vector2i((uit.position / 16.0).floor())
	var spawn_tegel := Vector2i((spawn.position / 16.0).floor())
	check("kas-uitgang op de bestaande vlag, achter de bergen", str(uit.event) == "naar_leven"
			and str(uit.target_map).ends_with("leven_ingang.tscn") and str(uit.target_spawn) == "ingang"
			and not uit.contains(Vector2i(20, 34)) and not uit.contains(Vector2i(19, 34))
			and tegel == Vector2i(14, 8))
	check("kas-terrein loopbaar maar niet vanaf het dorp (%s)" % _terrein(grond, tegel),
			_loopbaar(grond, tegel) and _afstand(grond, Vector2i(14, 31), tegel) < 0)
	check("spawn achter de bergen (%s)" % _terrein(grond, spawn_tegel), _loopbaar(grond, spawn_tegel)
			and spawn_tegel == Vector2i(14, 9) and spawn.facing == Vector2i(0, -1))
	kaart.free()


func _terrein(grond: TileMapLayer, t: Vector2i) -> String:
	var td := grond.get_cell_tile_data(t)
	if td == null:
		return "leeg"
	return str(td.get_custom_data("terrain"))


func _loopbaar(grond: TileMapLayer, t: Vector2i) -> bool:
	var td := grond.get_cell_tile_data(t)
	return td != null and not (str(td.get_custom_data("terrain")) in ["berg", "zee"])


func _afstand(grond: TileMapLayer, van: Vector2i, naar: Vector2i) -> int:
	var dist := {van: 0}
	var todo: Array[Vector2i] = [van]
	while not todo.is_empty():
		var t: Vector2i = todo.pop_front()
		if t == naar:
			return dist[t]
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = t + d
			if not dist.has(n) and _loopbaar(grond, n):
				dist[n] = dist[t] + 1
				todo.append(n)
	return -1


func _spel() -> void:
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	GameState.change_map(Archief2.PLAAT_SCENE, "zuid")
	check("groei-plaatkamer", await _wacht("Archief2V1Plaat"))
	var kamer := _scène()
	var poort := Vector2i(9, 4)
	check("brug dicht", kamer.cell(poort) == 59 and kamer.is_wall(poort))
	kamer.raak_plaat("p1", "licht")
	check("licht laat een groei-plaat met rust", int(kamer.plaat_van("p1").staat) == 0 and kamer.is_wall(poort))
	kamer.raak_plaat("p1", "stap")
	check("één stap: scheut, brug dicht", int(kamer.plaat_van("p1").staat) == 1 and kamer.is_wall(poort))
	kamer.raak_plaat("p1", "stap")
	check("twee stappen: pad open", int(kamer.plaat_van("p1").staat) == 2 and not kamer.is_wall(poort)
			and kamer.cell(poort) == 0)
	kamer.raak_plaat("p1", "stap")
	check("derde stap blijft volgroeid", int(kamer.plaat_van("p1").staat) == 2)
	await _shot("archief2_groeiplaat")
	var keuze := Archief2.bondgenoot_voor([], 1)
	Archief2.zet_bondgenoot(keuze)
	var speler: Node = kamer.get_node("Objects/Player")
	GameState.archief2_last_open = {}
	GameState.archief2_last_leech = {}
	GameState.start_battle(["genezer"], speler.get_tile(), speler.facing, "archief", true)
	check("Genezer-gevecht", await _wacht("Battle", 20.0))
	check("Genezer-gevecht speelt 'baas_archief2'", AudioManager.get_current_music() == "baas_archief2")
	var b := _gevecht()
	var zin := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 15000:
		b = _gevecht()
		if b != null and str(b.message_label.text).find(Archief2.KERN_ZIN) >= 0:
			zin = true
		if b != null and b.state == "command" and not GameState.archief2_last_open.is_empty():
			break
		await get_tree().process_frame
	check("opening toont de kern-zin", zin)
	var open: Dictionary = GameState.archief2_last_open
	var max_hp := int(open.get("max", 0))
	var dmg := int(open.get("schade", -1))
	check("eerste treffer ongeveer 30%% (%d/%d)" % [dmg, max_hp], max_hp > 0
			and dmg == Archief2.openingslag(max_hp)
			and absf(float(dmg) / float(max_hp) - 0.30) < 0.02)
	var bondgenoot := false
	if b != null:
		for c in b.heroes:
			if bool(c.get("ally", false)) and str(c.get("name", "")) == "Mosslijm":
				bondgenoot = true
	check("tijdelijke Mosslijm staat in het gevecht", bondgenoot and GameState.codex_pages.is_empty())
	if b != null and not b.enemies.is_empty():
		b.enemies[0]["s"]["hp"] = 120
	Engine.time_scale = 4.0
	await _ronde(b, AANVAL)
	await _wacht_tot(func() -> bool: return not GameState.archief2_last_leech.is_empty(), 20.0)
	await _wacht_staat(["command"], 20.0)
	var leech: Dictionary = GameState.archief2_last_leech
	var n := int(leech.get("schade", -1))
	var doel_max := max_hp
	check("leech healt hetzelfde aantal (%s)" % [leech], n > 0 and int(leech.get("heal", -2)) == n
			and int(leech.get("bij", -2)) == n and doel_max > 0
			and float(n) / float(doel_max) >= 0.07 and float(n) / float(doel_max) <= 0.13)
	# De Genezer kan vóór de held aan de beurt zijn en zich met leech boven 1 HP healen, of de slag
	# mist: dan is één ronde niet genoeg. Elke ronde opnieuw op 1 HP zetten tot het gevecht voorbij is.
	for _r in 6:
		if b == null or not is_instance_valid(b) or _scène() == null or _scène().name != "Battle":
			break
		if _r > 0 and str(b.get("state")) != "command":
			break     # overwinning loopt al (of geen nieuwe beurt): de taps hieronder ronden af
		if not b.enemies.is_empty():
			b.enemies[0]["s"]["hp"] = 1
		await _ronde(b, AANVAL)
		for _i in 12:
			if _scène() == null or _scène().name != "Battle":
				break
			if is_instance_valid(b) and str(b.get("state")) == "command":
				break
			await _tik("interact")
	for _i in 12:
		if _scène() == null or _scène().name != "Battle":
			break
		await _tik("interact")
	check("terug na de Mender", await _wacht("Archief2V1Plaat", 25.0))
	await _dialoog_dicht(90)
	check("Levenskern na winst", GameState.kernfragmenten.has(Archief2.KERN_ID)
			and str(KernData.fragment(Archief2.KERN_ID).get("beschrijving", "")) == Archief2.KERN_ZIN)
	check("Codex nog leeg na de tijdelijke bondgenoot", GameState.codex_pages.is_empty())
	GameState.gold = 7777
	GameState.story_flags["archief2_marker"] = true
	GameState.return_map = Archief2.PLAAT_SCENE
	GameState.has_return_point = true
	GameState.pending_boss = false
	GameState.pending_enemies = []
	GameState.pending_story_loss = true
	GameState.in_battle = true
	await GameState.end_battle("lose")
	check("verlies laadt de kamer opnieuw", await _wacht("Archief2V1Plaat", 20.0))
	await _pframes(8)
	await _dialoog_dicht(40)
	check("verlies is verhaal, goud en vlag blijven", GameState.last_battle_result == "story"
			and GameState.gold == 7777 and GameState.story_flags.has("archief2_marker"))
	check("Seren sluit aan na verlies, level gelijk", GameState.has_member("lotte")
			and GameState.member_level("lotte") == GameState.member_level("dennis")
			and Archief2.lotte_heeft_licht())
	_zonder_lotte()
	GameState.story_flags.erase("archief2_lotte_lid")
	GameState.return_map = Archief2.PLAAT_SCENE
	GameState.has_return_point = true
	GameState.pending_boss = false
	GameState.pending_enemies = []
	GameState.pending_story_loss = true
	GameState.archief2_lotte_join = false
	GameState.in_battle = true
	await GameState.end_battle("win")
	check("winst laadt de kamer", await _wacht("Archief2V1Plaat", 20.0))
	await _pframes(8)
	await _dialoog_dicht(40)
	check("Seren sluit aan na winst, level gelijk", GameState.last_battle_result == "win"
			and GameState.has_member("lotte")
			and GameState.member_level("lotte") == GameState.member_level("dennis"))
	GameState.change_map(LICHT_SCENE, "zuid")
	check("licht-plaatkamer", await _wacht("Archief2V3Licht"))
	var licht := _scène()
	licht.raak_plaat("l1", "stap")
	check("stap laat de licht-plaat met rust", int(licht.plaat_van("l1").staat) == 0 and licht.is_wall(Vector2i(9, 4)))
	licht.raak_plaat("l1", "licht")
	licht.raak_plaat("l1", "licht")
	check("Seren's licht opent het pad", int(licht.plaat_van("l1").staat) == 2 and not licht.is_wall(Vector2i(9, 4)))
	var voor_bytes := {}
	for slot in range(1, GameState.SLOT_COUNT + 1):
		var pad := GameState.slot_path(slot)
		var bestand := FileAccess.open(pad, FileAccess.WRITE)
		bestand.store_string("SLOT%d-ARCHIEF2-ONGEWIJZIGD" % slot)
		bestand.close()
		voor_bytes[slot] = FileAccess.get_file_as_bytes(pad)
	var terug := Archief2.warp_doel("wilgendal")
	GameState.in_battle = false
	GameState.changing_map = false
	GameState.encounter_multiplier = 0.0
	GameState.change_map(str(terug["map"]), str(terug["spawn"]))
	check("warp naar Willowdale", await _wacht("Wereldkaart", 20.0))
	var slots_gelijk := true
	for slot in range(1, GameState.SLOT_COUNT + 1):
		var nu := FileAccess.get_file_as_bytes(GameState.slot_path(slot))
		if nu != voor_bytes[slot]:
			slots_gelijk = false
	check("vier save-slots onaangeroerd", slots_gelijk and GameState.SLOT_COUNT == 4)
	Engine.time_scale = 1.0


## v0.23 podium (RPG ART): rij 5 is dicht tot De Genezer verslagen is (onzichtbare blokkades).
func _genezer_podium() -> void:
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	GameState.story_flags.erase("bewaker:archief_2_v4_genezer/genezer")
	GameState.in_battle = false
	GameState.changing_map = false
	GameState.change_map(GENEZER_SCENE, "zuid")
	var ok := await _wacht("Archief2V4Genezer", 20.0)
	check("podium: Genezer-kamer geladen", ok)
	if not ok:
		return
	await _dialoog_dicht(10)
	var k := _scène()
	var blok := get_tree().get_nodes_in_group("dungeon_blokkade")
	check("podium: 16 blokkades op rij 5 (alles behalve de Mender op 9-10)", blok.size() == 16
			and blok.all(func(b): return int(b.position.y) == 5 * 16 + 8))
	# vrije tegels bereikbaar vanaf de ingang (9,10) zonder door rij 5 of de Genezer te gaan
	var dicht := {}
	for b in blok:
		dicht[Vector2i(int(b.position.x) / 16, int(b.position.y) / 16)] = true
	dicht[Vector2i(9, 5)] = true
	dicht[Vector2i(10, 5)] = true
	var gezien := {Vector2i(9, 10): true}
	var rij := [Vector2i(9, 10)]
	while not rij.is_empty():
		var t: Vector2i = rij.pop_front()
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = t + d
			if gezien.has(n) or dicht.has(n) or not k._cells.has(n) or k.is_wall(n):
				continue
			gezien[n] = true
			rij.append(n)
	check("podium: noorduitgang (9,2) niet bereikbaar zonder gevecht", not gezien.has(Vector2i(9, 2)) and not gezien.has(Vector2i(3, 4)))
	check("podium: wel de Genezer zelf (trap 9,7 / 9,6)", gezien.has(Vector2i(9, 6)) and gezien.has(Vector2i(10, 6)))
	var speler: Node = k.get_node("Objects/Player")
	speler.position = Vector2(3, 6) * 16 + Vector2(8, 8)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("podium: speler kan op (3,6) niet omhoog door de blokkade", not speler._can_move(Vector2i.UP))
	GameState.story_flags["bewaker:archief_2_v4_genezer/genezer"] = true
	GameState.change_map(GENEZER_SCENE, "zuid")
	ok = await _wacht("Archief2V4Genezer", 20.0)
	await get_tree().create_timer(0.3).timeout
	check("podium: na de overwinning geen blokkades meer", ok and get_tree().get_nodes_in_group("dungeon_blokkade").is_empty())
	await _dialoog_dicht(10)


func _na_genezer_hub() -> void:
	var kamers: Dictionary = Rooms.rooms()
	var noord: Dictionary = kamers["archief_2_v4_genezer"]["exits"]["n"]
	check("noorduitgang blijft de kaartkamer", str(noord.get("map", "")) == Archief2.WARPER_SCENE
			and str(noord.get("spawn", "")) == "ingang" and ResourceLoader.exists(Archief2.WARPER_SCENE))
	check("hub is het exterieur", str(WarperEnter.HUB_SCENE).ends_with("exterieur.tscn") and str(WarperEnter.HUB_SPAWN) == "ingang")
	check("Pendant gloeit paars", HangerScene.PURPLE == Color("b07ae8"))
	var echo := " ".join(Archief2.ECHO_REGELS)
	check("H-6 niet meer in de kaartkamer (canon 17: Sapientia zegt het in de Hal)", not echo.contains("H-6"))
	var hubtekst := " ".join(WarperDreiging.lines())
	check("Hal-scène noemt H-6 maar onthult 'Proefpersoon' niet", hubtekst.contains("H-6")
			and not hubtekst.contains("Proefpersoon") and not hubtekst.contains("Test Subject"))
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	Engine.time_scale = 1.0
	GameState.story_flags[WarperUnlock.BEWAKER_VLAG] = true
	# De suite slaat het gevecht over. In het spel zet de net gewonnen bewaker pending.
	NaGenezer.pending = true
	check("levenskern voor de warp", GameState.grant_kern(Archief2.KERN_ID, "genezer"))
	GameState.pending_kern_absorb = Archief2.KERN_ID
	GameState.in_battle = false
	GameState.changing_map = false
	GameState.change_map(GENEZER_SCENE, "zuid")
	var kamer_ok := await _wacht("Archief2V4Genezer", 20.0)
	check("Genezer-kamer voor de warp", kamer_ok)
	if not kamer_ok:
		return
	var gezien: Array[String] = []
	var t0 := Time.get_ticks_msec()
	var hub := false
	var video_eerst := false
	var video_gezien := false
	while Time.get_ticks_msec() - t0 < 40000:
		var s := _scène()
		var vid: Node = s.find_child("GenezerVideo", true, false) if s != null else null
		if vid != null and not video_gezien:
			video_gezien = true
			video_eerst = true
			for r in WarperCanon.GENEZER:
				if gezien.has(str(r["text"])) or str(Dialog.text_label.text).contains(str(r["text"])):
					video_eerst = false
			await get_tree().create_timer(2.5).timeout
			check("filmpje: scherp (canvas_items, lineair), 720x1280", get_tree().root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
					and vid.video.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR and vid.video_path.ends_with("genezer_warper.ogv"))
			await _shot("genezer_video_frame")
			vid.skip_now()
			await get_tree().process_frame
		if s != null and s.name == "Hal" and s.is_node_ready() and not GameState.changing_map:
			hub = true
			break
		if Dialog.is_open:
			if Dialog._is_typing():
				Dialog.advance()
			else:
				var regel := str(Dialog.text_label.text)
				if regel != "" and (gezien.is_empty() or gezien[gezien.size() - 1] != regel):
					gezien.append(regel)
					if regel.contains("World Warper online") or regel.contains("glitches. Green turns grey"):
						await get_tree().create_timer(1.8).timeout
						await _shot("canon_genezer_warper" if regel.contains("online") else "canon_genezer_glitch")
				Dialog.advance()
		await get_tree().process_frame
	var tekst := " ".join(gezien)
	var canon := true
	for r in WarperCanon.GENEZER:
		if not tekst.contains(str(r["text"])):
			canon = false
	check("filmpje na de overwinning, vóór de dialoog van scène 1", video_gezien and video_eerst
			and GameState.story_flags.has(GenezerScene.VIDEO_FLAG))
	check("canon-scène 1 compleet vóór de Hal (%d regels)" % gezien.size(), canon)
	check("scène 1: vlag gezet", bool(GameState.story_flags.get(WarperCanon.FLAG_GENEZER, false)))
	check("geen H-6 in scène 1", not tekst.contains("H-6") and not tekst.contains("Proefpersoon"))
	check("party in de Hal", hub and str(GameState.current_map).ends_with("world_warper/maps/hal.tscn")
			and str(GameState.current_map) != Archief2.WARPER_SCENE)
	check("world_warper_unlocked na The Mender", GameState.world_warper_is_unlocked()
			and GameState.story_flags.has("archief2_naar_warper"))
	var ex := _scène()
	var spawn := ex.get_node_or_null("Spawns/ingang") if ex != null else null
	var speler := ex.get_node_or_null("Objects/Player") if ex != null else null
	check("spawn ingang van de Hal", ex != null and ex.name == "Hal" and spawn != null and speler != null
			and speler.position.distance_to(spawn.position) < 2.0)
	check("niet de kaartkamer Archief2Warper", ex != null and ex.name != "Archief2Warper")
	await get_tree().create_timer(0.4).timeout
	var hs := ex.get_node_or_null("HubBoot/HangerScene") if ex != null else null
	if hs == null and ex != null:
		hs = ex.find_child("HangerScene", true, false)
	check("Hal: canon-scène 2 speelt bij binnenkomst", hs != null and bool(hs.get("_playing")))
	await _shot("archief2_naar_hub")
	if hs != null:
		for _i in 60:
			if not bool(hs.get("_playing")):
				break
			hs.call("_advance")
			await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
	var warp := ex.find_child("WarpView", true, false) if ex != null else null
	check("na scène 3: vlaggen gezet en de wereldkaart (warp-view) open", hs != null and not bool(hs.get("_playing"))
			and bool(GameState.story_flags.get(WarperCanon.FLAG_DREIGING, false))
			and warp != null and warp.visible)
	await _shot("archief2_hal_warpview")
	if warp != null and warp.has_method("close"):
		warp.call("close")
	# Terug in de Genezer-kamer: scène 1 speelt niet opnieuw.
	check("scène 1 niet opnieuw", not GenezerScene.mag_spelen(GameState.story_flags))
	await _dialoog_dicht(8)


## v0.25 Bug (Dennis): de herhaling van 'The World Warper' in het scenes-scherm speelde na zijn filmpje
## nog een tweede (gescripte) cutscene. Nu: alleen het filmpje, daarna netjes terug in de lijst.
## (Het verhaal zelf, filmpje + canon-scène, is hierboven in _na_genezer_hub getest.)
func _scenes_warper_herhaling() -> void:
	await _dialoog_dicht(30)
	await _pframes(10)
	var flags_voor: Dictionary = GameState.story_flags.duplicate()
	var map_voor := str(_scène().scene_file_path) if _scène() != null else ""
	var m: Node = null
	for poging in 10:
		await _tik("menu")
		await _pframes(3)
		m = _scène().get_node_or_null("FieldMenu") if _scène() != null else null
		if m != null:
			break
		await _pframes(20)
	if m == null or not m.buttons.has("scenes"):
		check("scenes: veldmenu open", false)
		return
	m.buttons["scenes"].pressed.emit()
	await _pframes(4)
	var sc: Node = m.sub
	if sc == null or sc.name != "Scenes":
		check("scenes: scenes-scherm open", false)
		return
	check("scenes: 'The World Warper' ontgrendeld na het verhaal", GameState.scene_seen("ww_warper"))
	sc.choose("ww_warper")
	await _pframes(10)
	var gz: Node = get_tree().root.get_node_or_null("SceneReplay/CanonGenezer")
	var vs: Node = gz.video_speler if gz != null else null
	check("scenes: herhaling speelt Dax' filmpje", vs != null and is_instance_valid(vs) and str(vs.video_path).ends_with("genezer_warper.ogv"))
	if vs != null and is_instance_valid(vs):
		vs.skip_now()
	var ok: bool = await _wacht_tot(func(): return sc.playing == null, 5.0)
	var geen_tweede: bool = not Dialog.is_open and (not is_instance_valid(gz) or gz.regels_getoond.is_empty())
	for i in 40:     # een tweede scène zou nu dialoog openen
		await _pframes(1)
		geen_tweede = geen_tweede and not Dialog.is_open
	check("scenes: na het filmpje GEEN gescripte scène erachteraan, vanzelf terug in de lijst", ok and geen_tweede)
	check("scenes: terug in het scherm (focus, dialooglaag 5, geen restanten)", m.sub == sc and sc.buttons.any(func(b): return b.has_focus())
			and Dialog.layer == 5 and get_tree().root.get_node_or_null("SceneReplay") == null
			and get_tree().root.get_node_or_null("SceneReplayWeg") == null)
	check("scenes: herhaling raakt het verhaal niet (vlaggen en map gelijk)", GameState.story_flags == flags_voor
			and (str(_scène().scene_file_path) if _scène() != null else "") == map_voor)
	await _shot("scenes_terug_na_warper")
	sc.close()
	await _pframes(4)
	m.close()
	await _pframes(4)


func _zonder_lotte() -> void:
	var kept: Array = []
	for h in GameState.party:
		if str(h.get("id", "")) != "lotte":
			kept.append(h)
	GameState.party = kept


func _dialoog_dicht(frames: int) -> void:
	for _i in frames:
		if Dialog.is_open:
			Dialog.close()
		await get_tree().process_frame


func _scène() -> Node:
	return get_tree().current_scene


func _gevecht() -> Node:
	var s := _scène()
	return s if s != null and s.name == "Battle" else null


func _pframes(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _wacht(naam: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := _scène()
		if s != null and s.name == naam and s.is_node_ready() and not GameState.changing_map:
			await _pframes(2)
			return true
		await get_tree().process_frame
	return false


func _wacht_tot(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _wacht_staat(states: Array, timeout := 20.0) -> String:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var b := _gevecht()
		if b != null and b.state in states:
			return b.state
		await get_tree().process_frame
	return ""


func _tik(actie: String) -> void:
	await get_tree().physics_frame
	Input.action_press(actie)
	await _pframes(2)
	Input.action_release(actie)
	await _pframes(2)


func _kruis(b: Node, index: int) -> void:
	if b == null:
		return
	for _i in 120:
		if b.cross.active:
			break
		await get_tree().process_frame
	await _pframes(2)
	for _k in 3:
		if b.cross.selected == index:
			break
		if b.cross.selected != 0:
			await _tik(CROSS_BACK[b.cross.selected])
		else:
			await _tik(CROSS_DIRS[index])


func _ronde(b: Node, cmd: int) -> void:
	if b == null or not is_instance_valid(b):
		return
	if await _wacht_staat(["command"]) != "command":
		return
	await _kruis(b, cmd)
	await _tik("interact")
	if cmd == AANVAL:
		if await _wacht_staat(["target_enemy", "busy"], 8.0) == "target_enemy":
			await _tik("interact")


func _shot(naam: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join(naam + ".png"))


# ---------------------------------------------------------------- v0.21 Archief 2-vijanden
const VIJAND_VERWACHT := {
	"rankje": ["Tendril", ["vuur"], "bind"],
	"sporekop": ["Sporehead", ["ijs"], "poison"],
	"doornige_loper": ["Thorn Runner", ["vuur", "bliksem"], "charge"],
	"bloeiende_schrik": ["Blooming Dread", ["ijs"], "drain"],
	"wortelgeest": ["Rootghost", ["vuur", "licht"], "pull"],
}


func _combatant(naam: String, hp: int, max_hp: int, held: bool) -> Dictionary:
	return {"name": naam, "is_hero": held, "defending": false,
			"s": {"hp": hp, "max_hp": max_hp, "atk": 20, "def": 5, "agi": 5}}


func _vijanden() -> void:
	var nummers := {}
	for e in GD.ENEMIES.values():
		nummers[int(e.get("no", 0))] = int(nummers.get(int(e.get("no", 0)), 0)) + 1
	var in_kamers := {}
	var kamers: Dictionary = Rooms.ROOMS.duplicate(true)
	kamers.merge(Rooms.rooms())
	for k in kamers:
		for m in kamers[k].get("monsters", []):
			for id in m.get("group", []):
				in_kamers[str(id)] = true
	for id in VIJAND_VERWACHT:
		var want: Array = VIJAND_VERWACHT[id]
		var e: Dictionary = GD.ENEMIES.get(id, {})
		check("%s bestaat, naam %s, Natuur" % [id, want[0]], not e.is_empty() and str(e["name"]) == want[0]
				and str(e.get("element", "")) == AV.ELEMENT and bool(e.get("weak_matters", false)))
		if e.is_empty():
			continue
		check("%s zwak voor %s" % [id, want[1]], e["weak"] == want[1])
		var sk: Dictionary = e["skills"][0] if not (e["skills"] as Array).is_empty() else {}
		check("%s vaardigheid %s (%s)" % [id, want[2], sk.get("name", "")], str(sk.get("type", "")) == want[2]
				and float(sk.get("chance", 0.0)) > 0.0)
		var voor: Texture2D = load(str(e["sprite"]))
		var rug: Texture2D = load(str(e["sprite_back"]))
		var kaart: Texture2D = load("res://assets/map_monsters/%s.png" % id)
		check("%s art: voor/rug 90x90, kaart 32x64" % id, voor != null and rug != null and kaart != null
				and voor.get_size() == Vector2(90, 90) and rug.get_size() == Vector2(90, 90) and kaart.get_size() == Vector2(32, 64))
		check("%s eigen bestiariumnummer %d" % [id, int(e["no"])], int(nummers.get(int(e["no"]), 0)) == 1
				and str(e.get("desc", "")) != "")
		check("%s loopt in Archief 2" % id, in_kamers.has(id))
		var doel := {"s": e}
		var zwak_ok := true
		for el in ["vuur", "ijs", "bliksem", "licht", "natuur"]:
			var x := Archief2.schaal_element(100, doel, el)
			zwak_ok = zwak_ok and ((x > 100) == (el in want[1]))
		check("%s: zwakte telt (x%.1f), de rest niet" % [id, Archief2.ZWAK], zwak_ok)
	check("charge verdubbelt de schade", is_equal_approx(float(GD.ENEMIES["doornige_loper"]["skills"][0]["power"]), AV.CHARGE_POWER)
			and is_equal_approx(AV.CHARGE_POWER, 2.0))
	# regels op losse combatants
	var a := _combatant("Rankje", 30, 30, false)
	var h := _combatant("Dax", 50, 50, true)
	var zin := AV.apply(a, h, {"type": "bind"}, 5)
	check("binden: 1 beurt overslaan", int(h["skip"]) == 1 and str(h["skip_reden"]) == AV.SKIP_REDEN_BIND and "bound" in zin)
	h = _combatant("Dax", 50, 50, true)
	zin = AV.apply(a, h, {"type": "poison"}, 5)
	var gif: Array = h.get("dots", [])
	check("gif: 3 beurten, %d%% per ronde" % roundi(AV.POISON_PCT * 100.0), gif.size() == 1 and int(gif[0]["turns"]) == 3
			and is_equal_approx(float(gif[0]["pct"]), AV.POISON_PCT) and "poisoned" in zin)
	var schrik := _combatant("Blooming Dread", 10, 40, false)
	zin = AV.apply(schrik, h, {"type": "drain"}, 10)
	check("bijt + heelt zichzelf (helft van de schade)", int(schrik["s"]["hp"]) == 15 and "heals 5" in zin)
	schrik["s"]["hp"] = 39
	AV.apply(schrik, h, {"type": "drain"}, 10)
	check("heelt niet boven max HP", int(schrik["s"]["hp"]) == 40)
	var geest := _combatant("Rootghost", 30, 30, false)
	h = _combatant("Dax", 50, 50, true)
	h["defending"] = true
	AV.apply(geest, h, {"type": "pull"}, 5)
	check("trekken: doel getrokken, verdedigen weg, geen counter voor een vijand", h.get("pulled_by") == geest
			and not h["defending"] and int(geest.get("counter", 0)) == 0)
	check("getrokken: volgende aanval op de trekker, daarna niet meer", AV.pulled_target(h) == geest and AV.pulled_target(h) == null)
	AV.apply(geest, h, {"type": "pull"}, 5)
	geest["s"]["hp"] = 0
	check("dode trekker trekt niet", AV.pulled_target(h) == null)
	var dood := _combatant("X", 0, 10, true)
	check("geen effect op een KO-doel", AV.apply(a, dood, {"type": "bind"}, 1) == "" and not dood.has("skip"))
	# Codex
	check("Codex valideert %s" % [CD.validate()], CD.validate().is_empty())
	for id in AV.CODEX_IDS:
		var sid := CD.species_for_enemy(id)
		check("%s vangbaar (kans bij 1 HP %.2f)" % [id, CD.capture_chance(sid, 1, 30)], sid == id
				and bool(CD.species(sid)["capturable"]) and CD.capture_chance(sid, 1, 30) > 0.5)
	for id in ["doornige_loper", "bloeiende_schrik"]:
		check("%s niet vangbaar" % id, CD.species_for_enemy(id) == "")
	var want_sk := {"sporekop": ["gifspuw", "poison"], "rankje": ["rankgreep", "bind"], "wortelgeest": ["wortelzuiging", "pull"]}
	for id in want_sk:
		var page := CD.make_page(id, 3, "codex_t_" + id)
		check("%s-pagina kent %s (%s), Engelse naam" % [id, want_sk[id][0], want_sk[id][1]],
				(page["skills"] as Array).has(want_sk[id][0]) and str(CD.skill(want_sk[id][0])["type"]) == want_sk[id][1]
				and str(page["name"]) == VIJAND_VERWACHT[id][0])
	var counters := 0
	for k in CD.SKILLS:
		if bool(CD.SKILLS[k].get("counter", false)):
			counters += 1
	check("alleen de Wortelgeest heeft counter", counters == 1 and bool(CD.skill("wortelzuiging").get("counter", false)))


func _vijanden_gevecht() -> void:
	Engine.time_scale = 4.0
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	GameState.change_map(Archief2.PLAAT_SCENE, "zuid")
	if not await _wacht("Archief2V1Plaat", 20.0):
		check("kamer voor het vijandgevecht", false)
		return
	await _dialoog_dicht(30)
	GameState.codex_add("wortelgeest", 5, {})
	check("Wortelgeest is de bondgenoot", GameState.codex_pages.size() == 1 and GameState.codex_active != "")
	var speler: Node = _scène().get_node("Objects/Player")
	GameState.start_battle(["wortelgeest", "rankje", "sporekop"], speler.get_tile(), speler.facing, "archief", false, 2, true)
	if not await _wacht("Battle", 20.0):
		check("gevecht met Archief 2-vijanden", false)
		return
	var b := _gevecht()
	await _wacht_staat(["command"], 20.0)
	var held: Dictionary = {}
	var ally: Dictionary = {}
	for c in b.heroes:
		if bool(c.get("ally", false)):
			ally = c
		elif str(c["s"].get("id", "")) == "dennis":
			held = c
	var ew: Dictionary = b.enemies[0]
	var er: Dictionary = b.enemies[1]
	var es: Dictionary = b.enemies[2]
	check("gevecht: Rootghost, Tendril, Sporehead + bondgenoot", str(ew["name"]) == "Rootghost" and str(er["name"]) == "Tendril"
			and str(es["name"]) == "Sporehead" and not ally.is_empty() and not held.is_empty())
	for c in [held, ally, ew, er, es]:
		c["s"]["max_hp"] = 999
		c["s"]["hp"] = 999
	# Rankje bindt Dennis
	er["s"]["skills"][0]["chance"] = 1.0
	await b._execute({"type": "attack", "actor": er, "target": held})
	check("Tendril bindt Dax (1 beurt)", int(held.get("skip", 0)) == 1 and b.last_skill_effect.get("type") == "bind")
	var hp_r := int(er["s"]["hp"])
	await b._execute({"type": "attack", "actor": held, "target": er})
	check("gebonden Dax slaat over", int(held.get("skip", 0)) == 0 and int(er["s"]["hp"]) == hp_r)
	# Sporekop vergiftigt
	es["s"]["skills"][0]["chance"] = 1.0
	await b._execute({"type": "attack", "actor": es, "target": held})
	var hp_h := int(held["s"]["hp"])
	b._tick_ailments(held)
	check("Sporehead vergiftigt: gif tikt (%d -> %d), nog 2 beurten" % [hp_h, int(held["s"]["hp"])],
			int(held["s"]["hp"]) == hp_h - roundi(999 * AV.POISON_PCT) and int((held["dots"] as Array)[0]["turns"]) == 2)
	held["dots"] = []
	# Wortelgeest trekt Dennis: zijn klap op Tendril gaat naar de Wortelgeest
	ew["s"]["skills"][0]["chance"] = 1.0
	await b._execute({"type": "attack", "actor": ew, "target": held})
	check("Rootghost trekt Dax aan", held.get("pulled_by") == ew)
	var hp_w := int(ew["s"]["hp"])
	hp_r = int(er["s"]["hp"])
	await b._execute({"type": "attack", "actor": held, "target": er})
	check("getrokken klap raakt de Rootghost, niet Tendril", int(ew["s"]["hp"]) < hp_w and int(er["s"]["hp"]) == hp_r
			and not held.has("pulled_by"))
	# Bondgenoot (Wortelgeest): trekt een vijand + counter
	for e in [ew, er, es]:
		e["s"]["skills"][0]["chance"] = 0.0
	ew["s"]["hp"] = 500
	es["s"]["hp"] = 400
	b.codex.force_skill = "wortelzuiging"
	await b.codex.ally_turn({"actor": ally})
	check("bondgenoot trekt Tendril + counter klaar", er.get("pulled_by") == ally and int(ally.get("counter", 0)) == 1)
	hp_r = int(er["s"]["hp"])
	var c0: int = b.counters_done
	var hp_a := int(ally["s"]["hp"])
	await b._execute({"type": "attack", "actor": er, "target": held})
	check("Tendril moet de bondgenoot slaan, die counter geeft", int(ally["s"]["hp"]) < hp_a and int(er["s"]["hp"]) < hp_r
			and b.counters_done == c0 + 1 and int(ally.get("counter", 0)) == 0)
	ally["counter"] = 1
	AV.tick(ally)
	check("counter duurt tot het einde van de ronde", int(ally["counter"]) == 0)
	# Bondgenoot: gif (Sporekop) en binden (Rankje)
	b.codex.force_skill = "gifspuw"
	await b.codex.ally_turn({"actor": ally})
	check("bondgenoot-gif op een vijand (3 beurten)", (er.get("dots", []) as Array).any(func(d): return int(d["turns"]) == 3))
	b.codex.force_skill = "rankgreep"
	await b.codex.ally_turn({"actor": ally})
	check("bondgenoot bindt een vijand (1 beurt)", int(er.get("skip", 0)) == 1 and str(er["skip_reden"]) == AV.SKIP_REDEN_BIND)
	b.codex.force_skill = ""
	# Vangen: de Wortelgeest (Leeg Boek, vaste worp)
	ew["s"]["hp"] = 1
	b.codex.force_roll = 0.0
	await b.codex.capture(held, ew)
	check("Rootghost ingeschreven in de Codex", str(b.codex.last_capture.get("result", "")) == "gelukt"
			and GameState.codex_pages.size() == 2 and str(GameState.codex_pages[1]["species"]) == "wortelgeest")
	await _shot("archief2_vijanden")
	GameState.end_battle("flee")
	check("terug uit het vijandgevecht", await _wacht("Archief2V1Plaat", 20.0))
	Engine.time_scale = 1.0


func _muziek() -> void:
	const BattleScript := preload("res://scripts/battle/battle.gd")
	for key in ["levend_archief", "baas_archief2"]:
		var st: Resource = load("res://assets/audio/bgm/bgm_%s.ogg" % key)
		check("track %s: ogg-vorbis in het manifest, loopt, > 1 min" % key, AudioManager.has_music(key)
				and st is AudioStreamOggVorbis and (st as AudioStream).get_length() > 60.0
				and bool(AudioManager._bgm[key].get("loop", false)))
	var bad: Array[String] = []
	var paden: Array = ["res://scenes/maps/leven_ingang.tscn", "res://scenes/maps/leven_v1_plaat.tscn",
			"res://scenes/maps/leven_v3_combi.tscn"]
	paden.append_array(Rooms.SCENES.values())
	for p in paden:
		var inst: Node = (load(p) as PackedScene).instantiate()
		if str(inst.get("music_track")) != "levend_archief":
			bad.append(p.get_file())
		inst.free()
	var grot: Array[String] = []
	for g in ["bouwplaats", "mond", "nerf", "grendel", "geheim", "uitmond"]:
		var gi: Node = (load("res://scenes/maps/berggrot_%s.tscn" % g) as PackedScene).instantiate()
		if str(gi.get("music_track")) != "berggrot":
			grot.append(g)
		gi.free()
	var gst: Resource = load("res://assets/audio/bgm/bgm_berggrot.ogg")
	check("bouwplaats en berggrot spelen 'berggrot', echte loopende ogg (%s)" % [grot], grot.is_empty()
			and gst is AudioStreamOggVorbis and (gst as AudioStream).get_length() > 60.0)
	check("alle Archief 2-kamers spelen 'levend_archief' (%s)" % [bad], bad.is_empty())
	check("alleen de Genezer krijgt de baastrack", BattleScript.battle_music_for(["genezer"], true) == "baas_archief2"
			and BattleScript.battle_music_for(["wortelkoning"], true) == "gevecht_miniboss"
			and BattleScript.battle_music_for(["genezer"], false) == "gevecht_normaal"
			and BattleScript.battle_music_for(["mosslijm"], false) == "gevecht_normaal")


## Deel G (kas v8.1): effen vloer 0-3 op een even 2x2-vak (lay-out '.') -> blok A 80-83 / B 84-87 via
## archief_block_choice(x>>1, y>>1); al het andere blijft de tegel uit archief2_ground.gd.
func _kas_blok_tests() -> void:
	const A2G := preload("res://scripts/data/archief2_ground.gd")
	var DR := DungeonRooms
	var tex: Texture2D = load(str(DR.theme_data("kas")["tiles"]))
	check("G: kas-atlas v8.1 is 256x96", tex != null and tex.get_size() == Vector2(256, 96))
	var ts: TileSet = DungeonRoom.tileset(true, "kas")
	var src: TileSetAtlasSource = ts.get_source(0)
	check("G: tegelaantal volgt de hoogte (96 tegels, 80-95 bestaan)", src.get_tiles_count() == 96
			and range(80, 96).all(func(n): return src.has_tile(Vector2i(n % 16, n / 16))))
	var poly_ok := true
	for n in DR.KAS_BLOCK_A + DR.KAS_BLOCK_B + DR.KAS_FILLERS:
		if DR.is_solid(n, "kas") or src.get_tile_data(Vector2i(n % 16, n / 16), 0).get_collision_polygons_count(0) != 0:
			poly_ok = false
	check("G: 80-95 beloopbaar, geen botsingsvorm", poly_ok)
	var g := [[0, 1, 2, 3, 4], [2, 0, 1, 1, 0], [0, 0, 65, 1, 2], [1, 2, 3, 0, 1]]
	var lay := [".....", ".....", ".....", "....."]
	var blk: Array = DR.KAS_BLOCK_A if DR.archief_block_choice(0, 0) == 0 else DR.KAS_BLOCK_B
	check("G: vrij vak (0,0) = blok A/B in volgorde LB/RB/LO/RO", range(4).all(func(i):
			return DR.kas_floor_at(i & 1, i >> 1, g, lay) == blk[i]))
	check("G: vak met decor (65) blijft ongemoeid", DR.kas_floor_at(2, 2, g, lay) == 65
			and DR.kas_floor_at(3, 2, g, lay) == 1 and DR.kas_floor_at(3, 3, g, lay) == 0)
	check("G: onvolledig vak (kolom 4) blijft ongemoeid", DR.kas_floor_at(4, 1, g, lay) == 0)
	check("G: geblokkeerde lay-out ('#') -> geen blok", DR.kas_floor_at(0, 0, g, ["#....", ".....", ".....", "....."]) == 0)
	check("G: vaste hash (twee keer gelijk)", DR.kas_floor_at(1, 1, g, lay) == DR.kas_floor_at(1, 1, g, lay))
	var gezien := {}
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	for rid in ["archief_2_v1_entree", "archief_2_v2_gang", "archief_2_v3_licht", "archief_2_v4_hal"]:
		var room: Dictionary = Rooms.ROOMS[rid] if Rooms.ROOMS.has(rid) else DR.room(rid)
		var spawn: String = (room["spawns"] as Dictionary).keys()[0]
		GameState.change_map("res://scenes/maps/%s.tscn" % rid, spawn)
		if not await _wacht(str(rid).to_pascal_case()):
			check("G: %s geladen" % rid, false)
			continue
		var s := _scène()
		var grond: Array = A2G.GROUND[rid]
		var layout: Array = room["layout"]
		var ok := true
		var walk_ok := true
		for y in grond.size():
			for x in (grond[y] as Array).size():
				var t := Vector2i(x, y)
				var want: int = DR.kas_floor_at(x, y, grond, layout)
				if s.cell(t) != want:
					ok = false
				gezien[s.cell(t)] = true
				if s.is_wall(t) != DR.is_solid(int(grond[y][x]), "kas"):
					walk_ok = false
		check("G: %s: vloer = blok A/B of de oude grondtegel" % rid, ok)
		check("G: %s: beloopbaarheid gelijk aan de grondlaag" % rid, walk_ok)
	check("G: blok A en B komen beide voor", gezien.has(80) and gezien.has(84))
