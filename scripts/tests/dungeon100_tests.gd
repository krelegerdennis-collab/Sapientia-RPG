extends Node
## ALLEEN VOOR TESTEN - 100-verdiepingen-kerker: REGELS, RUSTPUNTEN en HUD (taak 'dungeon100-regels').
## Start:  godot --path . -- --dungeon100test [--shots=/pad/map]
##   Deel A: pure regels (dungeon100_rules.gd): rustverdiepingen, checkpoint_for, nederlaag-plan, HUD-tekst.
##   Deel B: GameState: nieuw spel, opslaan/laden (ook oude of kapotte saves), game over (respawn).
##   Deel C: HUD 'Verdieping X/100': verborgen buiten de kerker en in een gevecht, goede tekst/plek.
##   Deel D: het rustpunt (scène): HP/MP vol, checkpoint gaat alleen omhoog, opslaan, Ja/Nee.
##   Deel E: nederlaag op een kerkerverdieping: met checkpoint terug naar de kerker (op de rustverdieping),
##           zonder checkpoint naar Wilgendal; echte scènewissel via GameState.end_battle("lose").
## Met --shots=map: d100_hud_*.png (384x216 + _3x). Zit niet in de export (scripts/tests/*).

const R := preload("res://scripts/dungeon/dungeon100_rules.gd")
const RustpuntC := preload("res://scripts/dungeon/dungeon100_rustpunt.gd")
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
	check("HUD-tekst: 'Verdieping 12/100'", R.hud_text(12) == "Verdieping 12/100" and R.hud_text(1) == "Verdieping 1/100"
			and R.hud_text(100) == "Verdieping 100/100")
	check("HUD-tekst klemt op 0..100", R.hud_text(500) == "Verdieping 100/100" and R.hud_text(-2) == "Verdieping 0/100")
	check("HUD alleen op verdieping 1..100", R.shows_hud(1) and R.shows_hud(100) and not R.shows_hud(0)
			and not R.shows_hud(101) and not R.shows_hud(-1))
	check("checkpoint_after_rest: nieuw rustpunt telt, lager verlaagt niet, geen rustverdieping = niets",
			R.checkpoint_after_rest(0, 10) == 10 and R.checkpoint_after_rest(10, 30) == 30
			and R.checkpoint_after_rest(50, 20) == 50 and R.checkpoint_after_rest(20, 27) == 20
			and R.checkpoint_after_rest(0, 0) == 0)
	var p := R.defeat_plan(27, 20)
	check("nederlaag met checkpoint 20: terug naar verdieping 20, 75% goud", p["to_dungeon"] and p["respawn_floor"] == 20
			and is_equal_approx(p["gold_keep"], 0.75))
	p = R.defeat_plan(5, 0)
	check("nederlaag zonder checkpoint: naar het dorp, 50% goud", not p["to_dungeon"] and p["respawn_floor"] == 0
			and is_equal_approx(p["gold_keep"], 0.5))
	p = R.defeat_plan(0, 30)
	check("game over buiten de kerker: gewoon het dorp (checkpoint telt niet)", not p["to_dungeon"] and p["respawn_floor"] == 0)
	p = R.defeat_plan(27, 20, false)
	check("kerker-scène ontbreekt: terugval naar het dorp", not p["to_dungeon"] and p["respawn_floor"] == 0)
	p = R.defeat_plan(40, 35)
	check("kapot checkpoint (geen rustverdieping) wordt genegeerd", not p["to_dungeon"])
	var party := [{"hp": 0, "max_hp": 30, "mp": 1, "max_mp": 8}, {"hp": 5, "max_hp": 20, "mp": 0, "max_mp": 4}]
	var pages := [{"hp": 0, "max_hp": 12, "mp": 0, "max_mp": 3}]
	R.heal_party(party, pages)
	check("heal_party: party en Codex-bondgenoot HP/MP vol (ook KO)", party[0]["hp"] == 30 and party[0]["mp"] == 8
			and party[1]["hp"] == 20 and party[1]["mp"] == 4 and pages[0]["hp"] == 12 and pages[0]["mp"] == 3)
	var d := R.load_data({"floor": 37.0, "checkpoint": 30.0, "best": 41.0})
	check("load_data: gewone waarden blijven (floats uit JSON worden ints)", d == {"floor": 37, "checkpoint": 30, "best": 41})
	d = R.load_data({"floor": 999, "checkpoint": "x", "best": -4})
	check("load_data: rommel -> 0", d == {"floor": 0, "checkpoint": 0, "best": 0})
	d = R.load_data({"floor": 5, "checkpoint": 37, "best": 2})
	check("load_data: checkpoint 37 wordt 30, best is minstens de verdieping/het checkpoint", d["checkpoint"] == 30
			and d["best"] == 30 and d["floor"] == 5)
	check("load_data: geen dictionary -> alles 0", R.load_data(null) == {"floor": 0, "checkpoint": 0, "best": 0}
			and R.load_data([1, 2]) == {"floor": 0, "checkpoint": 0, "best": 0})
	check("best_after gaat alleen omhoog", R.best_after(10, 4) == 10 and R.best_after(10, 12) == 12 and R.best_after(0, 300) == 100)


# ================================================================ deel B
func _state_tests() -> void:
	check("GameState.dungeon100_floor bestaat en begint op 0", GameState.dungeon100_floor == 0)
	GameState.new_game("Dennis")
	GameState.dungeon100_floor = 42
	GameState.dungeon100_checkpoint = 40
	GameState.dungeon100_best = 44
	GameState.new_game("Dennis")
	check("nieuw spel zet verdieping, checkpoint en best terug op 0", GameState.dungeon100_floor == 0
			and GameState.dungeon100_checkpoint == 0 and GameState.dungeon100_best == 0)

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

	# game over (respawn) zonder kerker: precies zoals altijd
	GameState.new_game("Dennis")
	GameState.gold = 100
	GameState.party[0]["hp"] = 0
	GameState.respawn()
	check("game over buiten de kerker: half goud, spawn 'start', party vol",
			GameState.gold == 50 and GameState.pending_spawn == GameState.RESPAWN_SPAWN
			and GameState.party[0]["hp"] == GameState.party[0]["max_hp"] and GameState.dungeon100_floor == 0)
	# in de kerker zonder checkpoint
	GameState.gold = 101
	GameState.dungeon100_floor = 6
	GameState.dungeon100_checkpoint = 0
	GameState.respawn()
	check("game over op verdieping 6 zonder rustpunt: naar het dorp (verdieping 0, half goud)",
			GameState.dungeon100_floor == 0 and GameState.gold == 50 and GameState.pending_spawn == GameState.RESPAWN_SPAWN)
	# met checkpoint, maar kerker-scène bestaat niet
	R.dungeon_scene = "res://scenes/maps/bestaat_niet.tscn"
	GameState.gold = 100
	GameState.dungeon100_floor = 26
	GameState.dungeon100_checkpoint = 20
	GameState.respawn()
	check("scène ontbreekt: game over valt terug op het dorp, checkpoint blijft bewaard",
			GameState.dungeon100_floor == 0 and GameState.dungeon100_checkpoint == 20 and GameState.gold == 50)
	# met checkpoint en een bestaande scène
	R.dungeon_scene = STAND_IN
	GameState.gold = 100
	GameState.dungeon100_floor = 26
	GameState.dungeon100_checkpoint = 20
	GameState.party[0]["hp"] = 0
	GameState.respawn()
	check("game over op verdieping 26 met rustpunt 20: terug naar verdieping 20, 75 goud, spawn 'rustpunt', party vol",
			GameState.dungeon100_floor == 20 and GameState.gold == 75 and GameState.pending_spawn == R.REST_SPAWN
			and GameState.party[0]["hp"] == GameState.party[0]["max_hp"])
	check("checkpoint en best blijven na het verlies", GameState.dungeon100_checkpoint == 20)
	R.dungeon_scene = _saved_scene
	GameState.new_game("Dennis")


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
	check("HUD geeft de tekst 'Verdieping 12/100'", R.hud_text(hud.shown_floor) == "Verdieping 12/100")
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
	check("na de tekst komt de vraag 'opslaan?' met Ja/Nee", Dialog.choices.size() == 2 and "opslaan" in str(Dialog._lines[0]).to_lower())
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
				and "opslaan" in str(Dialog._lines[0]).to_lower():
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
	# 1. met checkpoint: de echte scènewissel naar de (stand-in) kerker
	GameState.new_game("Dennis")
	GameState.story_step = load("res://scripts/data/story_data.gd").KLAAR
	R.dungeon_scene = STAND_IN
	GameState.dungeon100_floor = 26
	GameState.dungeon100_checkpoint = 20
	GameState.dungeon100_best = 26
	GameState.gold = 200
	GameState.party[0]["hp"] = 0
	GameState.return_map = TOWN
	GameState.in_battle = true
	GameState.end_battle("lose")
	var ok := await wait_scene("Esdoorn", 20.0)
	await wait_fade()
	check("verlies met checkpoint: nieuwe scène is de kerker-scène", ok and scene().scene_file_path == STAND_IN)
	check("verlies met checkpoint: verdieping 20, 150 goud, HP vol, best blijft 26",
			GameState.dungeon100_floor == 20 and GameState.gold == 150 and GameState.dungeon100_best == 26
			and GameState.party[0]["hp"] == GameState.party[0]["max_hp"] and not GameState.in_battle)
	var hud := _hud()
	await pframes(3)
	check("na het verlies toont de HUD verdieping 20", hud != null and hud.visible and hud.shown_floor == 20)

	# 2. zonder checkpoint: naar Wilgendal, geen kerker
	GameState.dungeon100_floor = 7
	GameState.dungeon100_checkpoint = 0
	GameState.gold = 200
	GameState.party[0]["hp"] = 0
	GameState.return_map = STAND_IN
	GameState.in_battle = true
	GameState.end_battle("lose")
	ok = await wait_scene("Wilgendal", 20.0)
	await wait_fade()
	check("verlies zonder rustpunt: terug in Wilgendal, verdieping 0, half goud", ok and GameState.dungeon100_floor == 0
			and GameState.gold == 100 and scene().scene_file_path == TOWN)
	await pframes(3)
	check("... en de HUD is weer verborgen", hud != null and not hud.visible)

	# 3. winst of vluchten in de kerker verandert de verdieping niet
	GameState.dungeon100_floor = 33
	GameState.dungeon100_checkpoint = 30
	GameState.return_map = TOWN
	GameState.in_battle = true
	GameState.end_battle("flee")
	await wait_until(func(): return not GameState.in_battle and not GameState.changing_map, 20.0)
	await pframes(10)
	check("vluchten: verdieping en checkpoint blijven (33 / 30)", GameState.dungeon100_floor == 33 and GameState.dungeon100_checkpoint == 30)
	GameState.dungeon100_floor = 0
	R.dungeon_scene = _saved_scene


# ================================================================ hulp
func scene() -> Node:
	return get_tree().current_scene


func player() -> CharacterBody2D:
	var s := scene()
	return s.get_node_or_null("Objects/Player") if s else null


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
