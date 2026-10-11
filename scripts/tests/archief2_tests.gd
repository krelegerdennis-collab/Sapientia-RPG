extends Node
## Headless suite voor Archief 2 (Het Levende Archief).
## Start: godot --path . -- --archief2test [--shots=/pad/map]

const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const KernData := preload("res://scripts/data/kern_data.gd")
const DungeonRooms := preload("res://scripts/data/dungeon_rooms.gd")
const Rooms := preload("res://scripts/data/archief2_rooms.gd")
const Archief2 := preload("res://scripts/data/archief2.gd")
const BossCore := preload("res://scripts/battle/boss_core.gd")
const PuzzleRooms := preload("res://scripts/data/puzzle_rooms.gd")
const PuzzleLogic := preload("res://scripts/puzzle/puzzle_logic.gd")
const AANVAL := 0
const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up"}
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
	print("=== Archief 2: Lotte, Mosslijm, Genezer ===")
	_lotte_en_genezer()
	print("=== Archief 2: wereldkaart ===")
	_wereldkaart()
	print("=== Archief 2: kamer, gevecht, warp ===")
	await _spel()
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
	check("Wurger HP/ATK/DEF TODO(design)", int(GD.ENEMIES["wurger"]["max_hp"]) == Archief2.WURGER_HP
			and int(GD.ENEMIES["wurger"]["atk"]) == Archief2.WURGER_ATK
			and int(GD.ENEMIES["wurger"]["def"]) == Archief2.WURGER_DEF)
	check("Genezer HP TODO(design)", int(GD.ENEMIES["genezer"]["max_hp"]) == Archief2.GENEZER_HP)
	var toegepast := BossCore.apply_boss(GD.ENEMIES["genezer"])
	check("Genezer-baas: opening, leech, zin", bool(toegepast.get("archief2_open", false))
			and bool(toegepast.get("archief2_leech", false))
			and str(toegepast.get("archief2_zin", "")) == Archief2.KERN_ZIN
			and int(toegepast.get("max_hp", 0)) == Archief2.GENEZER_HP)
	var wurg := BossCore.apply_boss(GD.ENEMIES["wurger"])
	check("Wurger zwak voor ijs en fysiek", bool(wurg.get("weak_matters", false))
			and "ijs" in wurg.get("weak", []) and "fysiek" in wurg.get("weak", []))
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
	check("licht-plaat na Lotte", str(kamers["archief_2_v3_licht"]["platen"][0]["soort"]) == "licht")
	var echo := " ".join(Archief2.ECHO_REGELS)
	check("ECHO-naam, geen onderzoeker", echo.find("ECHO") >= 0 and echo.find("onderzoeker") < 0
			and echo.to_lower().find("digitale echo") < 0)
	var cat = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/actor_sfx.json"))
	var monsters: Dictionary = cat.get("monsters", {}) if cat is Dictionary else {}
	check("actor-sfx voor de drie bazen", monsters.has("lotte_glitch") and monsters.has("wurger")
			and monsters.has("genezer"))
	var maten := {
		"res://assets/tiles/dungeon/kas_tiles.png": Vector2(256, 80),
		"res://assets/puzzle/groei_plaat.png": Vector2(48, 16),
		"res://assets/sprites/archief2/lotte_veld.png": Vector2(48, 96),
		"res://assets/sprites/archief2/lotte_glitch.png": Vector2(64, 80),
		"res://assets/sprites/archief2/genezer.png": Vector2(64, 80),
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
	GameState.new_game("Dennis")
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
	check("Wurger: elke fysieke klap", is_equal_approx(Archief2.zwakte_fysiek(dennis, wurger), Archief2.ZWAK)
			and is_equal_approx(Archief2.zwakte_fysiek(noor, wurger), Archief2.ZWAK))
	check("Genezer: zwaard van Dennis, niet van Noor", is_equal_approx(Archief2.zwakte_fysiek(dennis, genezer), Archief2.ZWAK)
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
	GameState.new_game("Dennis")
	check("zonder Lotte geen licht", not Archief2.lotte_heeft_licht())
	GameState.give_exp(GameState.party[0], GD.exp_for_level(7))
	check("Dennis level 7", GameState.member_level("dennis") == 7)
	check("Lotte sluit aan op dat level", Archief2.sluit_lotte_aan())
	var lotte := _held("lotte")
	check("level gelijk, priester, graad 1", GameState.member_level("lotte") == 7
			and str(lotte.get("class", "")) == "Priest"
			and lotte.get("spells", []) == ["genees", "rijp"])
	check("staf en gewaad", Equipment.equipped(lotte, "wapen") == "eiken_staf"
			and Equipment.equipped(lotte, "harnas") == "reisgewaad")
	check("Lotte heeft Licht graad 1", Archief2.lotte_heeft_licht())
	GameState.archief2_lotte_join = false
	GameState.pending_story_loss = true
	var winst := GameState.archief2_verwerk_einde("win")
	check("winst: Lotte sluit aan, geen game over", winst == "win" and GameState.archief2_lotte_join)
	GameState.archief2_lotte_join = false
	GameState.pending_story_loss = true
	var verlies := GameState.archief2_verwerk_einde("lose")
	check("verlies wordt verhaal, Lotte sluit aan", verlies == "story" and GameState.archief2_lotte_join)
	GameState.archief2_lotte_join = false
	GameState.pending_story_loss = true
	var vlucht := GameState.archief2_verwerk_einde("flee")
	check("vluchten telt niet", vlucht == "flee" and not GameState.archief2_lotte_join)
	GameState.new_game("Dennis")
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
	check("warp Wilgendal", str(doel.get("map", "")) == Archief2.WERELD and str(doel.get("spawn", "")) == "van_wilgendal")
	var archief := Archief2.warp_doel("archief")
	check("warp Archief-ingang", str(archief.get("spawn", "")) == "van_archief")


func _held(id: String) -> Dictionary:
	for h in GameState.party:
		if str(h.get("id", "")) == id:
			return h
	return {}


func _wereldkaart() -> void:
	var packed: PackedScene = load(Archief2.WERELD)
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
	check("kas-uitgang op de bestaande vlag", str(uit.event) == "naar_leven"
			and str(uit.target_map).ends_with("leven_ingang.tscn") and str(uit.target_spawn) == "ingang"
			and not uit.contains(Vector2i(20, 34)) and tegel == Vector2i(19, 34))
	check("tegel uitgang loopbaar (%s)" % _terrein(grond, tegel), _loopbaar(grond, tegel))
	check("spawn loopbaar (%s)" % _terrein(grond, spawn_tegel), _loopbaar(grond, spawn_tegel)
			and spawn_tegel == Vector2i(19, 33))
	kaart.free()


func _terrein(grond: TileMapLayer, t: Vector2i) -> String:
	var td := grond.get_cell_tile_data(t)
	if td == null:
		return "leeg"
	return str(td.get_custom_data("terrain"))


func _loopbaar(grond: TileMapLayer, t: Vector2i) -> bool:
	var td := grond.get_cell_tile_data(t)
	return td != null and not (str(td.get_custom_data("terrain")) in ["berg", "zee"])


func _spel() -> void:
	GameState.new_game("Dennis")
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
	check("eerste treffer ongeveer 30% (%d/%d)" % [dmg, max_hp], max_hp > 0
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
	if b != null and not b.enemies.is_empty():
		b.enemies[0]["s"]["hp"] = 1
	await _ronde(b, AANVAL)
	for _i in 12:
		if _scène() == null or _scène().name != "Battle":
			break
		await _tik("interact")
	check("terug na de Genezer", await _wacht("Archief2V1Plaat", 25.0))
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
	check("Lotte sluit aan na verlies, level gelijk", GameState.has_member("lotte")
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
	check("Lotte sluit aan na winst, level gelijk", GameState.last_battle_result == "win"
			and GameState.has_member("lotte")
			and GameState.member_level("lotte") == GameState.member_level("dennis"))
	GameState.change_map(LICHT_SCENE, "zuid")
	check("licht-plaatkamer", await _wacht("Archief2V3Licht"))
	var licht := _scène()
	licht.raak_plaat("l1", "stap")
	check("stap laat de licht-plaat met rust", int(licht.plaat_van("l1").staat) == 0 and licht.is_wall(Vector2i(9, 4)))
	licht.raak_plaat("l1", "licht")
	licht.raak_plaat("l1", "licht")
	check("Lotte's licht opent het pad", int(licht.plaat_van("l1").staat) == 2 and not licht.is_wall(Vector2i(9, 4)))
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
	check("warp naar Wilgendal", await _wacht("Wereldkaart", 20.0))
	var slots_gelijk := true
	for slot in range(1, GameState.SLOT_COUNT + 1):
		var nu := FileAccess.get_file_as_bytes(GameState.slot_path(slot))
		if nu != voor_bytes[slot]:
			slots_gelijk = false
	check("vier save-slots onaangeroerd", slots_gelijk and GameState.SLOT_COUNT == 4)
	Engine.time_scale = 1.0


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
