extends Node
## Balans Archief 1 in Action (PR7, Forge 21 okt 2026). Bewaakt:
##  - elke gewone vijand in archief_v1..v4 kost een verse Dax op het verwachte level van de tier gemiddeld
##    3-4 volle slagen (SomData.ACTION_AREAS.archief1 "hits"), via de echte schadeformule;
##  - vijanden slaan in Action harder dan in Classic (atk-factor > 1) en de arena gebruikt de gebiedsregels;
##  - Classic (turn-based) krijgt exact de oude stats; unieke vijanden en kamers buiten het gebied ongewijzigd.
##    (Bazen: altijd turn-based met Classic-stats, bewaakt in --somroomstest.)
## Start: godot --path . -- --balansarchief1test [--shots=/pad/map]

const SomData := preload("res://scripts/data/som_data.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const DR := preload("res://scripts/data/dungeon_rooms.gd")
const Balans := preload("res://tools/battlesim/archief1_balans.gd")
const GANG := "res://scenes/maps/archief_v1_gang.tscn"

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.get_slice("=", 1)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	print("=== Balans Archief 1 (Action) ===")
	_data()
	_slagen()
	_winst()
	await _arena_en_classic()
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	print("BALANSTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAILED", passes, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _data() -> void:
	var a: Dictionary = SomData.ACTION_AREAS.get("archief1", {})
	check("ACTION_AREAS.archief1 bestaat met rooms/tier_level/hp_hits/hits/atk", a.has("rooms") and a.has("tier_level") and a.has("hp_hits") and a.has("hits") and a.has("atk"))
	var tiers_ok := true
	for t in [1, 2, 3, 4]:
		var tr: Dictionary = a.get("tiers", {}).get(t, {})
		tiers_ok = tiers_ok and tr.has("atk") and tr.has("cooldown") and a.get("targets", {}).has(t)
	check("elke tier 1-4 heeft eigen atk/cooldown en een doel", tiers_ok)
	var n := 0
	for rid in DR.ROOMS:
		if str(rid).begins_with("archief_v"):
			var inn := SomData.action_area(str(rid)) == "archief1"
			check("%s hoort bij archief1" % rid, inn == (int(str(rid).substr(9, 1)) in [1, 2, 3, 4]))
			n += 1 if inn else 0
	check("8 kamers in archief1 (%d)" % n, n == 8)
	check("kamer buiten het gebied: geen regels", SomData.action_area("woud_1") == "" and SomData.attack_cooldown("woud_1") == SomData.ATTACK_COOLDOWN)
	var uniek := {"max_hp": 50, "atk": 10, "def": 3, "unique": true}
	check("unieke vijand ongewijzigd", SomData.apply_action_area(uniek, "archief_v1_gang", 1) == uniek)
	var gewoon := {"max_hp": 5, "atk": 10, "def": 0}
	check("buiten het gebied ongewijzigd", SomData.apply_action_area(gewoon, "dk_ingang", 1) == gewoon)


func _slagen() -> void:
	var a: Dictionary = SomData.ACTION_AREAS["archief1"]
	var lo := float(a["hits"][0])
	var hi := float(a["hits"][1])
	seed(20261021)
	var gezien := {}
	for r in Balans.kamers(true):
		for d in r["enemies"]:
			var k := "%s@%d" % [d["id"], int(r["tier"])]
			if gezien.has(k):
				continue
			var lv := int(a["tier_level"].get(int(r["tier"]), 1))
			var h := Balans.dax(lv)
			var x := Balans.slagen(float(GameState.effective_stat(h, "atk")), d)
			gezien[k] = x
			check("%s: verse Dax lv %d heeft %.2f volle slagen nodig (doel %.0f-%.0f)" % [k, lv, x, lo, hi], x >= lo and x <= hi)
	check("alle gewone vijanden uit archief_v1..v4 gemeten (%d)" % gezien.size(), gezien.size() >= 10)


## Dax solo op het verwachte level, 150 gevechten per kamer (action_sim-model): winst/verlies per tier binnen
## SomData.ACTION_AREAS.archief1.targets, en geleidelijk oplopend (gemiddelde winst per tier daalt niet stijgend).
func _winst() -> void:
	var a: Dictionary = SomData.ACTION_AREAS["archief1"]
	var b: Node = Balans.new()
	b.fights = 150
	var per_tier := {}
	for r in b.verwacht():
		var t := int(r["tier"])
		if not per_tier.has(t):
			per_tier[t] = {"win": [], "loss": [], "ids": []}
		per_tier[t]["win"].append(float(r["win"]))
		per_tier[t]["loss"].append(float(r["loss"]))
		per_tier[t]["ids"].append("%s %d%%/%d%%" % [r["id"], roundi(r["win"] * 100.0), roundi(r["loss"] * 100.0)])
	var vorige := 2.0
	for t in [1, 2, 3, 4]:
		var d: Dictionary = per_tier.get(t, {"win": [0.0], "loss": [1.0], "ids": []})
		var w: float = Balans._mean(d["win"])
		var l: float = Balans._mean(d["loss"])
		var doel: Dictionary = a["targets"][t]
		var wv: Array = doel["win"]
		check("tier %d (Dax lv %d solo): winst %d%% binnen %d-%d%% [%s]" % [t, int(a["tier_level"][t]), roundi(w * 100.0), roundi(wv[0] * 100.0), roundi(wv[1] * 100.0), ", ".join(d["ids"])],
				w >= float(wv[0]) and w <= float(wv[1]))
		if doel.has("loss"):
			var lv: Array = doel["loss"]
			check("tier %d: gemiddeld HP-verlies %d%% binnen %d-%d%%" % [t, roundi(l * 100.0), roundi(lv[0] * 100.0), roundi(lv[1] * 100.0)],
					l >= float(lv[0]) and l <= float(lv[1]))
		check("tier %d: niet makkelijker dan de vorige tier (%d%% <= %d%%)" % [t, roundi(w * 100.0), roundi(minf(vorige, 1.0) * 100.0)], w <= vorige + 0.02)
		vorige = w
	b.free()


func _laad(pad: String) -> Node:
	GameState.in_battle = false
	GameState.changing_map = false
	get_tree().change_scene_to_file(pad)
	for i in 180:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == pad and s.is_node_ready() and i > 4:
			return s
	return null


func _arena_en_classic() -> void:
	var tier := int(DR.room("archief_v1_gang").get("tier", 0))
	var oud := GameData.apply_archief_tier((GameData.ENEMIES["mosslijm"] as Dictionary).duplicate(true), tier) if tier > 0 \
			else (GameData.ENEMIES["mosslijm"] as Dictionary).duplicate(true)
	var nieuw := SomData.apply_action_area(oud, "archief_v1_gang", tier)
	# Action: de arena rekent met de gebiedsregels
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	var s := await _laad(GANG)
	var arena: Node = s.get("som") if s else null
	check("Action-arena in archief_v1_gang", arena != null)
	if arena:
		var p: Node = s.get_node("Objects/Player")
		var m: Node = s.add_monster({"id": "balans_m", "enemy": "mosslijm", "tile": [p.get_tile().x + 3, p.get_tile().y], "moves": false})
		await get_tree().process_frame
		var e: Dictionary = arena.enemies.get(m, {})
		check("arena: mosslijm HP %d (Classic %d), ATK %d (Classic %d)" % [int(e.get("max_hp", -1)), int(oud["max_hp"]), int(e.get("atk", -1)), int(oud["atk"])],
				int(e.get("max_hp", -1)) == int(nieuw["max_hp"]) and int(e.get("atk", -1)) == int(nieuw["atk"]))
		check("arena: vijandschade = ENEMY_DAMAGE_MULT x tier-atk (%.2f)" % SomData.enemy_damage_mult("archief_v1_gang", tier),
				is_equal_approx(SomData.enemy_damage_mult("archief_v1_gang", tier), SomData.ENEMY_DAMAGE_MULT * float(SomData.ACTION_AREAS["archief1"]["tiers"][tier]["atk"]))
				and is_equal_approx(SomData.enemy_damage_mult("woud_1"), SomData.ENEMY_DAMAGE_MULT))
		check("arena: vijand-cooldown uit de tierregels", is_equal_approx(SomData.attack_cooldown("archief_v1_gang", tier), SomData.ATTACK_COOLDOWN * float(SomData.ACTION_AREAS["archief1"]["tiers"][tier]["cooldown"])))
		await _shot("action_archief_v1_balans")
	# Classic: exact de oude stats
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	s = await _laad(GANG)
	check("Classic: geen arena", s != null and s.get("som") == null)
	if s == null:
		return
	var pl: Node = s.get_node("Objects/Player")
	GameState.start_battle(["mosslijm"], pl.get_tile(), pl.facing, "archief", false, tier, true)
	var bt: Node = null
	for i in 240:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs != null and cs.name == "Battle" and "enemies" in cs and not (cs.enemies as Array).is_empty():
			bt = cs
			break
	check("Classic: turn-based gevecht open", bt != null)
	if bt:
		var st: Dictionary = bt.enemies[0].get("s", {})
		check("Classic: mosslijm HP/ATK/DEF %d/%d/%d = oud %d/%d/%d" % [int(st.get("max_hp", -1)), int(st.get("atk", -1)), int(st.get("def", -1)), int(oud["max_hp"]), int(oud["atk"]), int(oud["def"])],
				int(st.get("max_hp", -1)) == int(oud["max_hp"]) and int(st.get("atk", -1)) == int(oud["atk"]) and int(st.get("def", -1)) == int(oud["def"]))
	GameState.in_battle = false


func _shot(naam: String) -> void:
	if shots == "":
		return
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join(naam + ".png"))
	print("INFO  screenshot: ", shots.path_join(naam + ".png"))
