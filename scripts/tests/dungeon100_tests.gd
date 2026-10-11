extends Node
## ALLEEN VOOR TESTEN - 100-verdiepingen-kerker: REGELS, RUSTPUNTEN en HUD (taak 'dungeon100-regels').
## Start:  godot --path . -- --dungeon100regelstest [--shots=/pad/map]
##   Deel A: pure regels (dungeon100_rules.gd): rustverdiepingen, checkpoint_for, nederlaag-plan, HUD-tekst.
##   Deel B: GameState: nieuw spel, opslaan/laden (ook oude of kapotte saves), game over (respawn).
##   Deel C: HUD 'Verdieping X/100': verborgen buiten de kerker en in een gevecht, goede tekst/plek.
##   Deel D: het rustpunt (scène): HP/MP vol, checkpoint gaat alleen omhoog, opslaan, Ja/Nee.
##   Deel E: nederlaag in de kerker: dood is dungeon uit (wereldkaart bij de ingang, echte party terug).
##           Vluchten houdt de run. Echte scènewissel via GameState.end_battle("lose").
## Met --shots=map: d100_hud_*.png (384x216 + _3x). Zit niet in de export (scripts/tests/*).

const R := preload("res://scripts/dungeon/dungeon100_rules.gd")
const Gen := preload("res://scripts/dungeon/dungeon100_generator.gd")
const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const Bestiary := preload("res://scripts/data/endgame_bestiary.gd")
const RustpuntC := preload("res://scripts/dungeon/dungeon100_rustpunt.gd")
const WarperC := preload("res://scripts/dungeon/dungeon100_warper.gd")
const PA := preload("res://scripts/party_actions.gd")
const CD := preload("res://scripts/data/codex_data.gd")
const EchoGrot := preload("res://scripts/data/echo_grot.gd")
const HUD_PATH := "res://scripts/ui/dungeon100_hud.gd"
const TOWN := "res://scenes/maps/wilgendal.tscn"
## Stand-in voor de kerker-scène (die komt van de generator-branch): een bestaande kleine map.
const STAND_IN := "res://scenes/maps/esdoorn.tscn"

var failures := 0
var passes := 0
var shots := ""
var _saved_scene := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	GameState.encounter_multiplier = 0.0
	_saved_scene = R.dungeon_scene
	seed(100100)
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func():
		check("waakhond: test klaar binnen 300 s", false)
		print("RESULT FOUT (waakhond)")
		get_tree().quit(1))
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	print("=== Deel A: regels ===")
	_rules_tests()
	print("=== Deel B: GameState (nieuw spel, save/load, game over) ===")
	_state_tests()
	print("=== Deel C: HUD ===")
	await _hud_tests()
	print("=== Deel D: rustpunt ===")
	await _rustpunt_tests()
	print("=== Deel E: nederlaag in de kerker ===")
	await _defeat_tests()
	print("=== Deel F: warpers ===")
	await _warper_tests()
	R.dungeon_scene = _saved_scene
	print("DUNGEON100TEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	Engine.time_scale = 1.0
	await pframes(10)
	get_tree().quit(1 if failures else 0)


# ================================================================ deel A
func _rules_tests() -> void:
	var rest: Array = []
	for f in range(-5, 120):
		if R.is_rest_floor(f):
			rest.append(f)
	check("rustverdiepingen: precies 10, 20, ... 100", rest == [10, 20, 30, 40, 50, 60, 70, 80, 90, 100])
	check("0 en 101 zijn geen rustverdieping", not R.is_rest_floor(0) and not R.is_rest_floor(101))
	check("verdieping 1..100 geldig, 0 en 101 niet", R.is_valid_floor(1) and R.is_valid_floor(100)
			and not R.is_valid_floor(0) and not R.is_valid_floor(101) and not R.is_valid_floor(-3))
	check("checkpoint_for: 1-9 = 0 (nog geen rustpunt)", R.checkpoint_for(1) == 0 and R.checkpoint_for(9) == 0
			and R.checkpoint_for(0) == 0 and R.checkpoint_for(-4) == 0)
	check("checkpoint_for: 10 = 10, 19 = 10, 20 = 20, 99 = 90, 100 = 100",
			R.checkpoint_for(10) == 10 and R.checkpoint_for(19) == 10 and R.checkpoint_for(20) == 20
			and R.checkpoint_for(99) == 90 and R.checkpoint_for(100) == 100)
	check("checkpoint_for: boven 100 wordt 100", R.checkpoint_for(250) == 100)
	check("next_rest_floor: 1 -> 10, 10 -> 10, 11 -> 20, 91 -> 100, 100 -> 100, 0 / 101 -> 0",
			R.next_rest_floor(1) == 10 and R.next_rest_floor(10) == 10 and R.next_rest_floor(11) == 20
			and R.next_rest_floor(91) == 100 and R.next_rest_floor(100) == 100
			and R.next_rest_floor(0) == 0 and R.next_rest_floor(101) == 0)
	check("floors_until_rest: 7 -> 3, 10 -> 0, 0 -> 0", R.floors_until_rest(7) == 3 and R.floors_until_rest(10) == 0
			and R.floors_until_rest(0) == 0)
	var ok := true
	for f in range(1, 101):
		var cp := R.checkpoint_for(f)
		ok = ok and cp <= f and f - cp < 10 and (cp == 0 or R.is_rest_floor(cp))
		ok = ok and (R.is_rest_floor(f) == (cp == f))
	check("checkpoint_for klopt voor alle 100 verdiepingen", ok)
	check("HUD-tekst: 'Floor 12/100'", R.hud_text(12) == "Floor 12/100" and R.hud_text(1) == "Floor 1/100"
			and R.hud_text(100) == "Floor 100/100")
	check("HUD-tekst klemt op 0..100", R.hud_text(500) == "Floor 100/100" and R.hud_text(-2) == "Floor 0/100")
	check("HUD alleen op verdieping 1..100", R.shows_hud(1) and R.shows_hud(100) and not R.shows_hud(0)
			and not R.shows_hud(101) and not R.shows_hud(-1))
	check("checkpoint_after_rest: nieuw rustpunt telt, lager verlaagt niet, geen rustverdieping = niets",
			R.checkpoint_after_rest(0, 10) == 10 and R.checkpoint_after_rest(10, 30) == 30
			and R.checkpoint_after_rest(50, 20) == 50 and R.checkpoint_after_rest(20, 27) == 20
			and R.checkpoint_after_rest(0, 0) == 0)
	var p := R.defeat_plan(27, 20)
	check("nederlaag in de kerker (ook met rustpunt 20): dungeon uit, niet verdieping 1, echt goud blijft",
			p["leave"] and not p["to_dungeon"] and p["respawn_floor"] == 0 and not p["new_run"]
			and is_equal_approx(p["gold_keep"], 1.0))
	p = R.defeat_plan(5, 0)
	check("nederlaag zonder rustpunt: precies hetzelfde (het rustpunt telt niet meer mee)",
			p["leave"] and not p["to_dungeon"] and p["respawn_floor"] == 0 and not p["new_run"])
	p = R.defeat_plan(0, 30)
	check("game over buiten de kerker: gewoon het dorp, half goud, geen run", not p["leave"] and not p["to_dungeon"]
			and p["respawn_floor"] == 0 and not p["new_run"] and is_equal_approx(p["gold_keep"], 0.5))
	p = R.defeat_plan(27, 20, false)
	check("kerker-scène ontbreekt: dood is nog steeds dungeon uit (niet het dorp, niet verdieping 1)",
			p["leave"] and not p["to_dungeon"] and p["respawn_floor"] == 0 and not p["new_run"])
	check("defeat_plan hangt niet van het (kapotte) rustpunt af", R.defeat_plan(40, 35) == R.defeat_plan(40, 0) and R.defeat_plan(40, 30) == R.defeat_plan(40, 0))
	check("START_SPAWN/WORLD_* komen overeen met de generator", R.START_SPAWN == Gen.SPAWN_FROM_ABOVE and R.WORLD_SCENE == Gen.WORLD_SCENE
			and R.WORLD_SPAWN == Gen.WORLD_SPAWN)
	check("start alleen via ECHO, niet via de wereldkaart", EchoGrot.blokkeert_wereldkaart(EchoGrot.WERELD, EchoGrot.DUNGEON)
			and not EchoGrot.blokkeert_wereldkaart(EchoGrot.DUNGEON, EchoGrot.DUNGEON)
			and EchoGrot.KAMER == R.WORLD_SCENE and EchoGrot.KAMER_SPAWN == R.WORLD_SPAWN
			and EchoGrot.ZIN_EERSTE.begins_with("De Diepe Grot."))
	var party := [{"hp": 0, "max_hp": 30, "mp": 1, "max_mp": 8}, {"hp": 5, "max_hp": 20, "mp": 0, "max_mp": 4}]
	var pages := [{"hp": 0, "max_hp": 12, "mp": 0, "max_mp": 3}]
	R.heal_party(party, pages)
	check("heal_party: party en Codex-bondgenoot HP/MP vol (ook KO)", party[0]["hp"] == 30 and party[0]["mp"] == 8
			and party[1]["hp"] == 20 and party[1]["mp"] == 4 and pages[0]["hp"] == 12 and pages[0]["mp"] == 3)
	var d := R.load_data({"floor": 37.0, "checkpoint": 30.0, "best": 41.0})
	check("load_data: gewone waarden blijven (floats uit JSON worden ints)", _core(d) == {"floor": 37, "checkpoint": 30, "best": 41, "seed": 0})
	d = R.load_data({"floor": 999, "checkpoint": "x", "best": -4})
	check("load_data: rommel -> 0", _core(d) == {"floor": 0, "checkpoint": 0, "best": 0, "seed": 0})
	d = R.load_data({"floor": 5, "checkpoint": 37, "best": 2})
	check("load_data: checkpoint 37 wordt 30, best is minstens de verdieping/het checkpoint", d["checkpoint"] == 30
			and d["best"] == 30 and d["floor"] == 5)
	check("load_data: geen dictionary -> alles 0 en leeg", _core(R.load_data(null)) == {"floor": 0, "checkpoint": 0, "best": 0, "seed": 0}
			and _core(R.load_data([1, 2])) == {"floor": 0, "checkpoint": 0, "best": 0, "seed": 0}
			and R.load_data(null)["permanent"] == {} and R.load_data(null)["snapshot"] == {})
	check("best_after gaat alleen omhoog", R.best_after(10, 4) == 10 and R.best_after(10, 12) == 12 and R.best_after(0, 300) == 100)
	check("warpers: verdieping 1, 25, 50, 75 en 99 (100 is geen warper)",
			R.WARPER_FLOORS == [1, 25, 50, 75, 99] and R.is_warper_floor(1) and R.is_warper_floor(25)
			and R.is_warper_floor(50) and R.is_warper_floor(75) and R.is_warper_floor(99)
			and not R.is_warper_floor(100) and not R.is_warper_floor(2) and not R.is_warper_floor(0) and not R.is_warper_floor(49))
	check("alleen de start-warper waarschuwt niet", not R.warper_warns(1) and R.warper_warns(25)
			and R.warper_warns(50) and R.warper_warns(75) and R.warper_warns(99) and not R.warper_warns(100))
	check("bereiken ontgrendelt alleen die warper-verdieping", R.unlock_warper([], 1) == [1]
			and R.unlock_warper([1], 25) == [1, 25] and R.unlock_warper([1, 25], 40) == [1, 25]
			and R.unlock_warper([1], 99) == [1, 99] and R.unlock_warper([1, 25, 50, 75, 99], 50) == [1, 25, 50, 75, 99]
			and R.unlock_warper([1, 100, 2], 0) == [1])
	check("niet-bereikte warper is dicht", not R.warper_open([1], 25) and not R.warper_open([1], 99)
			and not R.warper_open([], 1) and R.warper_open([1, 25], 25))
	check("waarschuwing is de vertrekvraag, Ja en Nee", R.WARPER_WARNING == "Weet je zeker dat je de dungeon wilt verlaten?"
			and R.WARPER_YES == "Ja" and R.WARPER_NO == "Nee"
			and R.WARPER_SPAWN == Gen.SPAWN_WARPER and R.WORLD_SPAWN == EchoGrot.KAMER_SPAWN)
	check("verdieping 25 heet De Schaduw van H-6", Scaling.boss_for_floor(25)["name"] == "De Schaduw van H-6"
			and Scaling.boss_for_floor(50)["name"] == "De Cyclus"
			and Scaling.boss_for_floor(75)["name"] == "De Rechter"
			and Scaling.boss_for_floor(99)["name"] == "De Stem")
	check("verdieping 100 is geen baas", Scaling.boss_for_floor(100).is_empty() and not Scaling.is_boss_floor(100)
			and not Gen.is_boss_floor(100))
	check("bestiariumcitaat van de canon-bazen, letterlijk",
			Bestiary.entry("d100_baas_25")["desc"] == "Een donkere echo van Dennis zelf. Hij beweegt zoals Dennis beweegt, vecht zoals Dennis vecht — maar hij zwijgt. Sapientia laat hier zien wat er gebeurt als iemand zijn naam verliest. De Schaduw kent geen verleden, geen Noor, geen Opa. Alleen het getal: H-6."
			and Bestiary.entry("d100_baas_50")["desc"] == "Een eindeloos draaiende machine, half organisch half staal. Hij kent geen begin en geen einde — hij begint gewoon opnieuw. Sapientia's logica in één vorm: geen rust, geen verlossing, alleen herhaling. Wie hem verslaat, heeft niets gewonnen. Hij draait toch wel door."
			and Bestiary.entry("d100_baas_75")["desc"] == "Een gigantisch oog met armen die alle kanten op grijpen. Hij weegt, hij meet, hij oordeelt. Wat hij weegt is geen daad, maar een mens. En de mens is altijd te licht bevonden — behalve één. De Rechter is Sapientia's twijfel: ze zoekt iemand die zwaarder weegt dan ze verwachtte."
			and Bestiary.entry("d100_baas_99")["desc"] == "Geen lichaam. Geen gedaante. Alleen een stem, en glitches die de wereld om je heen vervormen. De Stem spreekt alsof hij je kent — en hij kent je ook. Hier spreekt Sapientia zelf. Niet als vijand, maar als iets dat op je heeft gewacht.")
	var migrated := R.load_data({"floor": 60, "checkpoint": 50, "best": 60})
	check("oude save zonder 'warpers': open tot de huidige verdieping (60 = 1, 25 en 50)",
			migrated["warpers"] == [1, 25, 50])
	check("oude save op 99 ontgrendelt alle warpers, op 0 (ook met best 100) geen",
			R.load_data({"floor": 99})["warpers"] == [1, 25, 50, 75, 99]
			and R.load_data({"floor": 0, "best": 100})["warpers"] == []
			and R.load_data({"floor": 100})["warpers"] == [1, 25, 50, 75, 99])
	check("aanwezige sleutel 'warpers' wordt niet aangevuld", R.load_data({"floor": 99, "warpers": [1]})["warpers"] == [1]
			and R.load_data({"floor": 50, "warpers": []})["warpers"] == []
			and R.load_data(null)["warpers"] == [])
	var placed := true
	for seed_i in [1, 42, 20240607]:
		for wf in [1, 25, 50, 75, 99]:
			var gd: Dictionary = Gen.generate(seed_i, wf)
			var slot: Vector2i = gd.get("warper_slot", Gen.NO_TILE)
			var spawn: Vector2i = gd.get("warper_spawn", Gen.NO_TILE)
			var room: Dictionary = gd.get("room", {})
			placed = placed and slot != Gen.NO_TILE and spawn != Gen.NO_TILE
			placed = placed and room.has("warper") and room.get("spawns", {}).has(R.WARPER_SPAWN)
			placed = placed and absi(slot.x - spawn.x) + absi(slot.y - spawn.y) == 1
			placed = placed and slot != gd["spawn_up"] and slot != gd["rest_slot"]
		placed = placed and Gen.generate(seed_i, 2).get("warper_slot", Gen.NO_TILE) == Gen.NO_TILE
		placed = placed and not Gen.generate(seed_i, 100).get("room", {}).has("warper")
		placed = placed and Gen.generate(seed_i, 100).get("warper_slot", Gen.NO_TILE) == Gen.NO_TILE
	check("generator zet een warper op 1, 25, 50, 75 en 99 (niet op 2 of 100), spawn ernaast", placed)


# ================================================================ deel B
func _state_tests() -> void:
	check("GameState.dungeon100_floor bestaat en begint op 0", GameState.dungeon100_floor == 0)
	GameState.new_game("Dennis")
	GameState.dungeon100_floor = 42
	GameState.dungeon100_checkpoint = 40
	GameState.dungeon100_best = 44
	GameState.dungeon100_warpers = [1, 50, 99]
	GameState.new_game("Dennis")
	check("nieuw spel zet verdieping, checkpoint, best en warpers terug op 0", GameState.dungeon100_floor == 0
			and GameState.dungeon100_checkpoint == 0 and GameState.dungeon100_best == 0
			and GameState.dungeon100_warpers.is_empty())

	GameState.current_map = TOWN
	GameState.dungeon100_floor = 37
	GameState.dungeon100_checkpoint = 30
	GameState.dungeon100_best = 38
	var path := "user://dungeon100_roundtrip.json"
	check("opslaan lukt", GameState.save_game(Vector2i(3, 4), Vector2i.DOWN, path))
	var raw := GameState.read_save(path)
	check("save bevat het blok 'dungeon100'", raw.has("dungeon100") and raw["dungeon100"] is Dictionary
			and int(raw["dungeon100"]["checkpoint"]) == 30)
	GameState.new_game("Dennis")
	check("laden lukt", GameState.load_game(path))
	check("laden zet verdieping 37, checkpoint 30, best 38 terug", GameState.dungeon100_floor == 37
			and GameState.dungeon100_checkpoint == 30 and GameState.dungeon100_best == 38)

	raw.erase("dungeon100")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(raw))
	f.close()
	GameState.dungeon100_floor = 50
	GameState.dungeon100_checkpoint = 50
	check("oude save zonder 'dungeon100' laadt (alles 0)", GameState.load_game(path) and GameState.dungeon100_floor == 0
			and GameState.dungeon100_checkpoint == 0 and GameState.dungeon100_best == 0)
	raw["dungeon100"] = "kapot"
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(raw))
	f.close()
	check("kapot 'dungeon100'-blok laadt zonder fout (alles 0)", GameState.load_game(path) and GameState.dungeon100_floor == 0
			and GameState.dungeon100_checkpoint == 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	# warpers in het bestaande dungeon100-blok; de vier menuslots blijven vier
	GameState.new_game("Dennis")
	check("vier menuslots", GameState.SLOT_COUNT == 4 and GameState.slot_path(1).ends_with("save_1.json")
			and GameState.slot_path(2).ends_with("save_2.json") and GameState.slot_path(3).ends_with("save_3.json")
			and GameState.slot_path(4).ends_with("save_4.json") and GameState.slot_path(5) == "")
	GameState.active_slot = 2
	GameState.dungeon100_begin_run()
	GameState.dungeon100_floor = 50
	GameState.dungeon100_warpers = [1, 50]
	var slot2 := GameState.slot_path(2)
	check("opslaan in slot 2", slot2 != "" and GameState.save_game(Vector2i(8, 8), Vector2i.DOWN))
	var slot_raw := GameState.read_save(slot2)
	check("slot 2: warpers zitten in het blok dungeon100, niet in een vijfde slot",
			slot_raw.get("slot", 0) == 2 and slot_raw["dungeon100"] is Dictionary
			and R.clean_warpers(slot_raw["dungeon100"]["warpers"]) == [1, 50]
			and int(slot_raw["dungeon100"]["floor"]) == 50 and not slot_raw.has("warpers"))
	GameState.new_game("Dennis")
	check("laden van slot 2 zet de warpers terug", GameState.load_game(slot2) and GameState.dungeon100_warpers == [1, 50]
			and GameState.dungeon100_floor == 50)
	GameState.dungeon100_end_run(true)
	check("einde van de run leegt de warpers (verdieping 0)", GameState.dungeon100_warpers.is_empty()
			and GameState.dungeon100_floor == 0 and not GameState.dungeon100_run_active())
	GameState.active_slot = 1
	DirAccess.remove_absolute(ProjectSettings.globalize_path(slot2))

	# game over (respawn) zonder kerker: precies zoals altijd
	GameState.new_game("Dennis")
	GameState.gold = 100
	GameState.party[0]["hp"] = 0
	GameState.respawn()
	check("game over buiten de kerker: half goud, spawn 'start', party vol",
			GameState.gold == 50 and GameState.pending_spawn == GameState.RESPAWN_SPAWN
			and GameState.party[0]["hp"] == GameState.party[0]["max_hp"] and GameState.dungeon100_floor == 0)
	# in de kerker: respawn() = dood is dungeon uit (wereldkaart bij de ingang), ook met een rustpunt
	R.dungeon_scene = STAND_IN
	GameState.new_game("Dennis")
	GameState.gold = 101
	GameState.inventory["kruid"] = 2
	GameState.party[0]["level"] = 6
	GameState.dungeon100_begin_run()
	GameState.dungeon100_floor = 6
	GameState.gold = 40
	GameState.inventory["sterk_drankje"] = 4
	GameState.party[0]["level"] = 9
	GameState.party[0]["hp"] = 0
	GameState.dungeon100_permanent["d100_zwaard_2"] = 1
	GameState.respawn()
	check("game over op verdieping 6: dungeon uit, verdieping 0, echt goud en level terug, spawn bij de ingang",
			GameState.dungeon100_floor == 0 and GameState.gold == 101 and GameState.pending_spawn == R.WORLD_SPAWN
			and GameState.party[0]["level"] == 6 and GameState.party[0]["hp"] == GameState.party[0]["max_hp"]
			and not GameState.dungeon100_run_active() and GameState.item_count("kruid") == 2
			and GameState.item_count("sterk_drankje") == 0 and GameState.item_count("d100_zwaard_2") == 1
			and GameState.item_count("drankje") == 3
			and GameState.dungeon100_best == 6 and GameState.dungeon100_checkpoint == 0)
	# met rustpunt: dat telt niet als terugkeerpunt (de run is al voorbij, dus dit is gewone game over)
	GameState.gold = 80
	GameState.dungeon100_floor = 0
	GameState.party[0]["hp"] = 0
	GameState.respawn()
	check("buiten de kerker na de run: half goud, spawn 'start'",
			GameState.gold == 40 and GameState.pending_spawn == GameState.RESPAWN_SPAWN and GameState.dungeon100_floor == 0)
	R.dungeon_scene = _saved_scene
	GameState.new_game("Dennis")
	_strip_and_scroll_tests()
	GameState.new_game("Dennis")


## De grot neemt de hele party mee (ook wie zich later aansloot) en elke Codex-pagina, allemaal
## op level 1 zonder uitrusting en zonder spreuken. Een rol uit een kist leert één spreuk terug.
func _strip_and_scroll_tests() -> void:
	GameState.join_member("noor", 8, ["eiken_staf"])
	GameState.join_member("lotte", 6, [])
	GameState.party[0]["level"] = 9
	GameState.party[1]["spells"].append("genees")
	var noor_weapon := str(GameState.party[1].get("equip", {}).get("wapen", ""))
	var moss := GameState.codex_add("mosslijm", 5)
	var worm := GameState.codex_add("inktwurm", 8)
	var konijn := GameState.codex_add("moskonijn", 4)
	var geest := GameState.codex_add("papiergeest", 4)
	var fused := CD.make_fusion_page(konijn, geest, "codex_fuse_test")
	GameState.codex_pages.append(fused)
	var moss_uid := str(moss["uid"])
	var worm_uid := str(worm["uid"])
	var fuse_uid := str(fused["uid"])
	var fuse_name := str(fused["name"])
	var fuse_gen := int(fused["fusion"]["generation"])
	var fuse_element := str(fused["element"])
	GameState.codex_set_active(worm_uid)
	var next_before := GameState.codex_next_id
	check("voor de grot: Noor level 8 met spreuken en staf, Ink Worm kent Ink Spit",
			int(GameState.party[1]["level"]) == 8 and (GameState.party[1]["spells"] as Array).has("vuur")
			and (GameState.party[1]["spells"] as Array).has("bliksem") and (GameState.party[1]["spells"] as Array).has("genees")
			and noor_weapon == "eiken_staf" and (worm["skills"] as Array).has("inktspuw")
			and (moss["skills"] as Array).has("mosheling") and not fused.is_empty())
	check("de run begint", GameState.dungeon100_begin_run())
	var ids: Array = []
	var stripped := true
	for h in GameState.party:
		ids.append(str(h["id"]))
		stripped = stripped and int(h["level"]) == 1 and (h["spells"] as Array).is_empty()
		for slot in h.get("equip", {}):
			stripped = stripped and str(h["equip"][slot]) == ""
	check("hele party mee op level 1, zonder spreuken en zonder uitrusting",
			stripped and ids == ["dennis", "noor", "lotte"] and GameState.party.size() == 3)
	var run_moss := GameState.codex_page(moss_uid)
	var run_worm := GameState.codex_page(worm_uid)
	var run_fuse := GameState.codex_page(fuse_uid)
	check("Codex gaat mee op level 1, zelfde uid, alleen vaardigheden van level 1",
			int(run_moss.get("level", 0)) == 1 and int(run_worm.get("level", 0)) == 1
			and (run_moss.get("skills", []) as Array) == CD.skills_at("mosslijm", 1)
			and not (run_worm.get("skills", []) as Array).has("inktspuw")
			and (run_worm.get("skills", []) as Array) == CD.skills_at("inktwurm", 1)
			and GameState.codex_active == worm_uid and GameState.codex_next_id == next_before)
	check("gefuseerde pagina houdt naam, element en generatie, maar is level 1",
			int(run_fuse.get("level", 0)) == 1 and str(run_fuse.get("name", "")) == fuse_name
			and str(run_fuse.get("element", "")) == fuse_element
			and int(run_fuse.get("fusion", {}).get("generation", 0)) == fuse_gen
			and (run_fuse.get("skills", []) as Array) == CD.skills_at(str(run_fuse.get("species", "")), 1))
	var dennis: Dictionary = GameState.party[0]
	var inv := {"spreuk_vuur": 1}
	var refused := PA.use_item(inv, "spreuk_vuur", dennis)
	check("Dennis leert geen magie van een rol", not refused["ok"] and inv.has("spreuk_vuur")
			and (dennis["spells"] as Array).is_empty() and str(refused["text"]) == "Dennis leert geen magie.")
	var noor: Dictionary = GameState.party[1]
	noor["max_mp"] = 0
	noor["mp"] = 0
	var taught := PA.use_item(inv, "spreuk_vuur", noor)
	check("Fire Scroll leert Noor Fire, vult haar MP en is op", taught["ok"] and (noor["spells"] as Array).has("vuur")
			and not inv.has("spreuk_vuur") and int(noor["max_mp"]) >= 4 and int(noor["mp"]) >= 4
			and str(taught["text"]) == "Noor learns Fire!")
	var again := {"spreuk_vuur": 1}
	var second := PA.use_item(again, "spreuk_vuur", noor)
	check("een rol voor een spreuk die je al kent doet niets", not second["ok"] and int(again["spreuk_vuur"]) == 1
			and (noor["spells"] as Array).size() == 1 and int(noor["max_mp"]) == 4)
	var mp_before := int(noor["max_mp"])
	var genees := {"spreuk_genees": 1}
	var healed := PA.use_item(genees, "spreuk_genees", noor)
	check("Heal Scroll leert Noor Heal (Grade 1 licht) zonder de MP-voorraad te verlagen", healed["ok"]
			and (noor["spells"] as Array).has("genees") and not genees.has("spreuk_genees")
			and int(noor["max_mp"]) == mp_before)
	dennis["hp"] = 0
	var bliksem := {"spreuk_bliksem": 1}
	var ko := PA.use_item(bliksem, "spreuk_bliksem", dennis)
	check("een bewusteloze held leert niets", not ko["ok"] and int(bliksem["spreuk_bliksem"]) == 1)
	dennis["hp"] = int(dennis["max_hp"])
	var noor_rol := {"spreuk_bliksem": 1}
	var noor_learn := PA.use_item(noor_rol, "spreuk_bliksem", noor)
	check("Noor kan tijdens de run Lightning leren", noor_learn["ok"] and (noor["spells"] as Array).has("bliksem")
			and int(noor["max_mp"]) >= 7)
	check("een rol is in het veld te gebruiken", PA.item_usable_in_field("spreuk_vuur") and PA.item_block_reason("spreuk_vuur") == ""
			and PA.item_effect_text("spreuk_vuur") == "Teaches the spell Fire.")
	check("de run eindigt", GameState.dungeon100_end_run(false))
	check("na de grot: levels, spreuken, staf en Codex zijn weer van voor de run",
			int(GameState.party[0]["level"]) == 9 and (GameState.party[0]["spells"] as Array).is_empty()
			and int(GameState.party[0]["max_mp"]) == 0
			and int(GameState.party[1]["level"]) == 8
			and (GameState.party[1]["spells"] as Array).has("vuur") and (GameState.party[1]["spells"] as Array).has("bliksem")
			and (GameState.party[1]["spells"] as Array).has("genees")
			and str(GameState.party[1].get("equip", {}).get("wapen", "")) == "eiken_staf"
			and int(GameState.party[2]["level"]) == 6 and (GameState.party[2]["spells"] as Array).has("genees")
			and int(GameState.codex_page(moss_uid).get("level", 0)) == 5
			and (GameState.codex_page(worm_uid).get("skills", []) as Array).has("inktspuw")
			and int(GameState.codex_page(fuse_uid).get("level", 0)) > 1
			and GameState.codex_active == worm_uid)


func _core(d: Dictionary) -> Dictionary:
	return {"floor": d["floor"], "checkpoint": d["checkpoint"], "best": d["best"], "seed": d["seed"]}


# ================================================================ deel C
func _hud() -> Node:
	return GameState.get_node_or_null("Dungeon100Hud")


func _hud_tests() -> void:
	GameState.new_game("Dennis")
	GameState.story_step = load("res://scripts/data/story_data.gd").KLAAR
	GameState.has_return_point = false
	GameState.change_map(TOWN, "start")
	await wait_scene("Wilgendal")
	await wait_fade()
	var hud := _hud()
	check("HUD hangt onder GameState (blijft bij scènewissels)", hud != null and hud.get_script().resource_path == HUD_PATH)
	if hud == null:
		return
	check("HUD-laag ligt onder tekstvak (5) en touch (10)", hud.layer < Dialog.layer and hud.layer < 10)
	await pframes(3)
	check("buiten de kerker (verdieping 0): HUD verborgen", not hud.visible)
	GameState.dungeon100_floor = 12
	await pframes(3)
	check("verdieping 12: HUD zichtbaar met 12", hud.visible and hud.shown_floor == 12)
	check("HUD geeft de tekst 'Floor 12/100'", R.hud_text(hud.shown_floor) == "Floor 12/100")
	check("HUD houdt het hoogste bereikte verdieping bij (best = 12)", GameState.dungeon100_best == 12)
	var r: Rect2 = hud.pill_rect()
	check("HUD staat linksboven in beeld (niet over de MENU-knop rechtsboven)", r.position.x >= 4 and r.position.y >= 2
			and r.end.x < 200 and r.end.y < 30)
	var touch: Control = scene().get_node_or_null("TouchControls/Control")
	check("HUD botst niet met de MENU-knop (touch)", touch != null and not r.intersects(touch.menu_rect()))
	check("HUD botst niet met D-pad, A, B of KERN", touch != null and not r.intersects(Rect2(touch.dpad_center() - Vector2.ONE * touch.dpad_radius,
			Vector2.ONE * touch.dpad_radius * 2.0)) and not r.intersects(touch.kern_rect()))
	check("HUD vangt geen tikken (mouse_filter = ignore)", hud.view.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	await screenshot("d100_hud_floor12")
	GameState.dungeon100_floor = 1
	await pframes(3)
	check("verdieping 1: HUD toont 1", hud.visible and hud.shown_floor == 1)
	GameState.dungeon100_floor = 10
	await pframes(3)
	check("verdieping 10 (rustverdieping): HUD zichtbaar", hud.visible and hud.shown_floor == 10 and R.is_rest_floor(hud.shown_floor))
	await screenshot("d100_hud_floor10_rust")
	GameState.dungeon100_floor = 100
	await pframes(3)
	check("verdieping 100: HUD zichtbaar, breedste tekst past in beeld", hud.visible and hud.pill_rect().end.x < 200)
	await screenshot("d100_hud_floor100")
	GameState.in_battle = true
	await pframes(3)
	check("in een gevecht: HUD verborgen", not hud.visible)
	GameState.in_battle = false
	await pframes(3)
	check("gevecht voorbij: HUD weer zichtbaar", hud.visible)
	GameState.dungeon100_floor = 0
	await pframes(3)
	check("uit de kerker (0): HUD weer verborgen", not hud.visible)
	GameState.dungeon100_floor = 250
	await pframes(3)
	check("ongeldige verdieping (250): HUD verborgen", not hud.visible)
	GameState.dungeon100_floor = 0


# ================================================================ deel D
func _rustpunt_tests() -> void:
	GameState.new_game("Dennis")
	GameState.story_step = load("res://scripts/data/story_data.gd").KLAAR
	GameState.has_return_point = false
	GameState.change_map(TOWN, "start")
	await wait_scene("Wilgendal")
	await wait_fade()
	var pl := player()
	var rp: Node2D = RustpuntC.create(pl.get_tile() + Vector2i(2, 0))
	scene().get_node("Objects").add_child(rp)
	await pframes(2)
	check("rustpunt: scène laadt als Dungeon100Rustpunt (boekpunt, type 'rustpunt')", rp is Dungeon100Rustpunt and rp.type == "rustpunt"
			and rp.info.get("save", false))
	check("rustpunt: 1 tile, blokkeert (StaticBody2D met botsvorm)", rp is StaticBody2D and rp.get_node_or_null("CollisionShape2D") != null)
	check("rustpunt: plek = midden van de gevraagde tile", rp.position == Vector2(pl.get_tile() + Vector2i(2, 0)) * 16.0 + Vector2(8, 8))
	check("rustpunt: gouden gloed", rp.aura_color == Color("f0c674"))

	# op verdieping 20 aanraken: genezen + checkpoint 20 + opslaan (Ja)
	GameState.dungeon100_floor = 20
	GameState.party[0]["hp"] = 1
	GameState.party[0]["mp"] = 0
	GameState.dungeon100_checkpoint = 10
	rp.interact(pl)
	await pframes(2)
	check("aanraken opent een tekstvak", Dialog.is_open)
	await close_dialog_until_choice()
	check("na de tekst komt de vraag 'opslaan?' met Ja/Nee", Dialog.choices.size() == 2 and "save" in str(Dialog._lines[0]).to_lower())
	for i in 6:
		await press_interact()       # keuze 0 = Ja (eerste druk maakt de tekst af)
		if await wait_until(func(): return rp.last_result in ["saved", "failed"], 0.5):
			break
	check("party volledig hersteld (HP en MP)", GameState.party[0]["hp"] == GameState.party[0]["max_hp"]
			and GameState.party[0]["mp"] == GameState.party[0]["max_mp"])
	check("checkpoint is nu 20 (was 10)", GameState.dungeon100_checkpoint == 20 and rp.last_activated)
	check("best = 20", GameState.dungeon100_best == 20)
	check("Ja = opgeslagen", rp.last_result == "saved" and GameState.has_save())
	var saved := GameState.read_save()
	check("de save bevat checkpoint 20 en verdieping 20", int(saved["dungeon100"]["checkpoint"]) == 20 and int(saved["dungeon100"]["floor"]) == 20)
	await close_dialog()
	await wait_until(func(): return not rp.busy, 2.0)

	# lager rustpunt opnieuw: checkpoint blijft 20; Nee = niet opslaan
	GameState.dungeon100_floor = 10
	GameState.party[0]["hp"] = 2
	rp.interact(pl)
	await pframes(2)
	await close_dialog_until_choice()
	await answer_no(rp)
	await close_dialog()
	check("lager rustpunt (10) verlaagt het checkpoint niet", GameState.dungeon100_checkpoint == 20 and not rp.last_activated)
	check("Nee = niet opgeslagen, maar wel genezen", rp.last_result == "declined" and GameState.party[0]["hp"] == GameState.party[0]["max_hp"])

	# verdieping zonder rustpunt-regel (bv. 13) of buiten de kerker: herstelt, checkpoint blijft
	await wait_until(func(): return not rp.busy, 2.0)
	GameState.dungeon100_floor = 13
	GameState.party[0]["hp"] = 3
	rp.interact(pl)
	await pframes(2)
	await close_dialog_until_choice()
	await answer_no(rp)
	await close_dialog()
	check("rustpunt op verdieping 13: herstelt maar checkpoint blijft 20", GameState.dungeon100_checkpoint == 20
			and GameState.party[0]["hp"] == GameState.party[0]["max_hp"])
	await wait_until(func(): return not rp.busy, 2.0)

	# hogere rustverdieping met het rustpunt op beeld (HUD + rustpunt samen)
	GameState.dungeon100_floor = 30
	await pframes(3)
	await screenshot("d100_rustpunt_floor30")
	rp.queue_free()
	GameState.dungeon100_floor = 0


## Tekstvak sluiten tot de keuzevraag (Ja/Nee) in beeld is.
func close_dialog_until_choice() -> void:
	for i in 20:
		if Dialog.choices.size() == 2 and Dialog.is_open and not Dialog._lines.is_empty() \
				and "save" in str(Dialog._lines[0]).to_lower():
			break
		await press_interact()
		await pframes(2)
	await pframes(10)


## B = laatste keuze (Nee); een druk tijdens het typen telt niet, dus herhalen.
func answer_no(rp: Node) -> void:
	for i in 8:
		await tap("cancel")
		if await wait_until(func(): return rp.last_result == "declined", 0.4):
			return


# ================================================================ deel E
func _defeat_tests() -> void:
	# 1. nederlaag in de kerker: echte scènewissel naar de wereldkaart bij de ingang, run voorbij
	GameState.new_game("Dennis")
	GameState.story_step = load("res://scripts/data/story_data.gd").KLAAR
	R.dungeon_scene = STAND_IN
	GameState.gold = 200
	GameState.party[0]["level"] = 4
	GameState.dungeon100_begin_run()
	GameState.dungeon100_floor = 26
	GameState.dungeon100_checkpoint = 20
	GameState.dungeon100_best = 26
	GameState.gold = 150
	GameState.party[0]["level"] = 7
	GameState.party[0]["hp"] = 0
	GameState.return_map = TOWN
	GameState.in_battle = true
	check("game-over-tekst: death means out of the Archive", GameState.defeat_text(false).contains("out of the Archive"))
	GameState.end_battle("lose")
	var ok := await wait_scene("EchoKamer", 20.0)
	await wait_fade()
	var wsp: Node2D = scene().get_node_or_null("Spawns/ingang")
	check("verlies in de kerker: ECHO's Kamer, niet de kerker en niet verdieping 1",
			ok and scene().scene_file_path == R.WORLD_SCENE and wsp != null
			and tile() == Vector2i((wsp.position / 16.0).floor())
			and not GameState.story_flags.has(EchoGrot.FLAG_RESULTAAT))
	check("verlies: verdieping 0, echt goud 200, level 4 terug, rustpunt weg, HP vol, best 26, run voorbij",
			GameState.dungeon100_floor == 0 and GameState.gold == 200 and GameState.dungeon100_best == 26
			and GameState.party[0]["level"] == 4 and GameState.dungeon100_checkpoint == 0
			and GameState.party[0]["hp"] == GameState.party[0]["max_hp"] and not GameState.in_battle
			and not GameState.dungeon100_run_active())
	var hud := _hud()
	await pframes(3)
	check("na het verlies is de HUD verborgen (niet verdieping 1)", hud != null and not hud.visible)

	# 2. vluchten in de kerker verandert de verdieping niet (eerst een nieuwe run, want de vorige is uit)
	GameState.dungeon100_begin_run()
	GameState.dungeon100_floor = 33
	GameState.dungeon100_checkpoint = 30
	GameState.return_map = STAND_IN
	GameState.in_battle = true
	GameState.end_battle("flee")
	await wait_until(func(): return not GameState.in_battle and not GameState.changing_map, 20.0)
	await pframes(10)
	check("vluchten: verdieping en checkpoint blijven (33 / 30), run loopt door",
			GameState.dungeon100_floor == 33 and GameState.dungeon100_checkpoint == 30 and GameState.dungeon100_run_active())
	GameState.dungeon100_end_run(true)
	GameState.dungeon100_floor = 0
	R.dungeon_scene = _saved_scene


# ================================================================ deel F
func _warper_tests() -> void:
	GameState.new_game("Dennis")
	GameState.story_step = load("res://scripts/data/story_data.gd").KLAAR
	GameState.has_return_point = false
	GameState.change_map(TOWN, "start")
	var town_ok := await wait_scene("Wilgendal")
	await wait_fade()
	check("wilgendal geladen voor de warper", town_ok and player() != null)
	if player() == null:
		return
	GameState.dungeon100_begin_run()
	GameState.dungeon100_floor = 1
	GameState.dungeon100_warpers = [1]
	var pl := player()
	var start := tile()
	var wp: Node2D = WarperC.create(start + Vector2i(1, 0))
	scene().get_node("Objects").add_child(wp)
	await pframes(2)
	check("warper: scène laadt (boek, type 'warper'), 1 tile", wp is Dungeon100Warper and wp.type == "warper"
			and wp is StaticBody2D and wp.position == Vector2(start + Vector2i(1, 0)) * 16.0 + Vector2(8, 8))
	wp.interact(pl)
	await pframes(2)
	var quiet: bool = await wait_until(func():
		return Dialog.is_open and Dialog.choices.is_empty() and not Dialog._lines.is_empty() \
				and str(Dialog._lines[0]) == R.GROT_INTRO
	, 3.0)
	check("verdieping 1 waarschuwt niet", quiet and R.WARPER_WARNING not in str(Dialog._lines[0]))
	await close_dialog()
	await wait_until(func(): return not wp.busy, 2.0)
	check("na de start-tekst staan verdieping en tegel nog steeds", GameState.dungeon100_floor == 1 and tile() == start
			and wp.last_result == "start")

	# verdieping 25: waarschuwing. Annuleren verplaatst niet.
	GameState.dungeon100_floor = 25
	wp.interact(pl)
	var warned: bool = await wait_until(_warning_open, 3.0)
	check("verdieping 25 waarschuwt: '%s'" % R.WARPER_WARNING, warned)
	await screenshot("d100_warper_waarschuwing")
	Dialog.cancel()
	await pframes(2)
	if wp.last_result != "cancelled":
		Dialog.cancel()
	await wait_until(func(): return wp.last_result == "cancelled" and not wp.busy, 2.0)
	check("annuleren op 25 blijft: verdieping en tegel ongewijzigd",
			wp.last_result == "cancelled" and GameState.dungeon100_floor == 25 and tile() == start
			and GameState.dungeon100_run_active())

	# verdieping 99: Ja gaat naar ECHO's Kamer.
	GameState.dungeon100_floor = 99
	wp.interact(pl)
	warned = await wait_until(_warning_open, 3.0)
	check("verdieping 99 waarschuwt hetzelfde", warned)
	Dialog.choose(0)
	var moved := await wait_scene("EchoKamer", 20.0)
	await wait_fade()
	var wsp: Node2D = scene().get_node_or_null("Spawns/ingang")
	check("verdieping 99 gaat naar ECHO's Kamer",
			moved and scene().scene_file_path == R.WORLD_SCENE and wsp != null
			and tile() == Vector2i((wsp.position / 16.0).floor())
			and GameState.dungeon100_floor == 0 and not GameState.dungeon100_run_active()
			and not GameState.story_flags.has(EchoGrot.FLAG_RESULTAAT))


# ================================================================ hulp
func _warning_open() -> bool:
	return Dialog.is_open and Dialog.choices.size() == 2 and not Dialog._lines.is_empty() \
			and str(Dialog._lines[0]) == R.WARPER_WARNING and Dialog.choices[0] == R.WARPER_YES \
			and Dialog.choices[1] == R.WARPER_NO


func scene() -> Node:
	return get_tree().current_scene


func player() -> CharacterBody2D:
	var s := scene()
	return s.get_node_or_null("Objects/Player") if s else null


func tile() -> Vector2i:
	var p := player()
	return p.get_tile() if p else Vector2i(-99, -99)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_scene(scene_name: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.name == scene_name and s.is_node_ready() and not GameState.changing_map:
			await pframes(2)
			return true
		await get_tree().process_frame
	return false


func wait_until(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func wait_fade() -> void:
	await wait_until(func(): return Transition._rect.color.a <= 0.01, 3.0)
	await pframes(2)


func press_interact() -> void:
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(2)


func tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await pframes(2)
	Input.action_release(action)
	await pframes(2)


func close_dialog() -> void:
	for i in 30:
		if not Dialog.is_open:
			break
		await press_interact()
		await pframes(2)
	await pframes(2)


## Screenshot: native 384x216 + _3x (1152x648).
func screenshot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot mogelijk (headless?)")
		return
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join(name + ".png"))
	var big := img.duplicate()
	big.resize(1152, 648, Image.INTERPOLATE_NEAREST)
	big.save_png(shots.path_join(name + "_3x.png"))
	print("INFO  screenshot: ", shots.path_join(name + ".png"), " ", img.get_size(), " + _3x ", big.get_size())
