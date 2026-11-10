extends Node
## Modustabel van de online DLS (Easy/Normal/Hard). Geen solo-balans.
## Start: godot --path . -- --onlinedlsmodetest

const Modes := preload("res://scripts/online/online_dls_modes.gd")
const Floor := preload("res://scripts/online/online_dls_floor.gd")
const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const Rules := preload("res://scripts/dungeon/dungeon100_rules.gd")
const GameData := preload("res://scripts/data/game_data.gd")

const EASY := {1: 1, 2: 12, 3: 23, 4: 34, 5: 45, 6: 55, 7: 66, 8: 77, 9: 88, 10: 99}
const CANON := [25, 50, 75, 99]
const NORMAL_REST := [10, 20, 30, 40]

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
	_data()
	_eff()
	_bosses()
	_rest()
	_exp_and_canon()
	_heals()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _data() -> void:
	var sim := Modes.sim()
	check("sim id dls", str(sim.get("id", "")) == "dls")
	check("vijand-cap 8", Modes.enemy_cap() == 8 and int(sim.get("enemy_cap", 0)) == 8)
	check("verdiepingen easy/normal/hard", Modes.floors("easy") == 10 and Modes.floors("normal") == 50 and Modes.floors("hard") == 100)
	check("PROPOSAL-teller is 100", Modes.PROPOSAL_MODE_EXP_NUMERATOR == 100)
	check("exp-factor 10/2/1", Modes.mode_exp_factor("easy") == 10 and Modes.mode_exp_factor("normal") == 2 and Modes.mode_exp_factor("hard") == 1)
	check("onbekende modus blijft leeg", Modes.floors("nope") == 0 and Modes.eff_floor("nope", 1) == 0 and Modes.boss_key("nope", 1) == 0 and not Modes.is_rest("nope", 1) and Modes.mode_exp_factor("nope") == 1)


func _eff() -> void:
	var easy_ok := true
	for f in EASY:
		if Modes.eff_floor("easy", int(f)) != int(EASY[f]):
			easy_ok = false
	check("easy eff 1→1, 2→12 … 10→99", easy_ok)
	var normal_ok := true
	for f in range(1, 51):
		if Modes.eff_floor("normal", f) != 2 * f - 1:
			normal_ok = false
	check("normal eff = 2f-1 (1→1, 5→9, 13→25, 25→49, 38→75, 50→99)", normal_ok
			and Modes.eff_floor("normal", 1) == 1 and Modes.eff_floor("normal", 5) == 9
			and Modes.eff_floor("normal", 13) == 25 and Modes.eff_floor("normal", 25) == 49
			and Modes.eff_floor("normal", 38) == 75 and Modes.eff_floor("normal", 50) == 99)
	var hard_ok := true
	for f in range(1, 101):
		if Modes.eff_floor("hard", f) != f:
			hard_ok = false
	check("hard eff = f (1..100)", hard_ok)


func _bosses() -> void:
	var easy_only := Modes.boss_key("easy", 10) == 10
	for f in range(1, 11):
		if f != 10 and Modes.boss_key("easy", f) != 0:
			easy_only = false
	check("easy: alleen verdieping 10 → sleutel 10", easy_only)
	check("easy sleutel 10 is Page Warden", str(Scaling.BOSSES[10]["name"]) == "Page Warden")
	var normal_ok := true
	var seen := {}
	for key in Scaling.boss_floors():
		@warning_ignore("integer_division")
		var f := (int(key) + 1) / 2
		seen[f] = true
		if Modes.boss_key("normal", f) != int(key):
			normal_ok = false
	for f in range(1, 51):
		if not seen.has(f) and Modes.boss_key("normal", f) != 0:
			normal_ok = false
	check("normal: f = (sleutel+1) div 2 voor alle 12 bazen", normal_ok and seen.size() == 12
			and Modes.boss_key("normal", 5) == 10 and Modes.boss_key("normal", 13) == 25
			and Modes.boss_key("normal", 25) == 50 and Modes.boss_key("normal", 38) == 75
			and Modes.boss_key("normal", 50) == 99)
	var hard_ok := true
	for f in range(1, 101):
		var want := f if Scaling.is_boss_floor(f) else 0
		if Modes.boss_key("hard", f) != want:
			hard_ok = false
	check("hard: bazen zoals solo", hard_ok and Scaling.boss_floors().size() == 12)


func _rest() -> void:
	var easy_ok := true
	for f in range(1, 11):
		if Modes.is_rest("easy", f) != (f == 5):
			easy_ok = false
	check("easy rust alleen op 5", easy_ok)
	var normal_ok := true
	for f in range(1, 51):
		if Modes.is_rest("normal", f) != (f in NORMAL_REST):
			normal_ok = false
	check("normal rust op 10/20/30/40", normal_ok)
	var hard_ok := true
	for f in range(1, 101):
		if Modes.is_rest("hard", f) != Rules.is_rest_floor(f):
			hard_ok = false
	check("hard rust zoals solo", hard_ok)


func _exp_and_canon() -> void:
	var base: Dictionary = GameData.ENEMIES["mosslijm"]
	for mode in ["easy", "normal", "hard"]:
		var eff := 12 if mode != "hard" else 12
		var preview: Dictionary = Floor.monster_preview(mode, "mosslijm", eff)
		var raw: Dictionary = Scaling.monster_stats(base, eff)
		var factor := Modes.mode_exp_factor(mode)
		var want := GameData.round_half_even(float(raw["exp"]) * float(factor))
		check("%s: exp-factor ×%d op mosslijm eff %d" % [mode, factor, eff],
				int(preview.get("online_exp_factor", 0)) == factor and int(preview["exp"]) == want
				and int(preview["max_hp"]) == int(raw["max_hp"]))
	for key in CANON:
		@warning_ignore("integer_division")
		var nf := (int(key) + 1) / 2
		var enemy := str(Scaling.BOSSES[key]["enemy"])
		var solo: Dictionary = Scaling.boss_stats(GameData.ENEMIES[enemy], int(key))
		var normal: Dictionary = Floor.boss_preview("normal", nf)
		var hard: Dictionary = Floor.boss_preview("hard", int(key))
		var same := _canon_same(normal, solo) and _canon_same(hard, solo) and _canon_same(normal, hard)
		check("canon-stats sleutel %d gelijk in normal (f %d) en hard" % [key, nf], same)
		var eff_normal := Modes.eff_floor("normal", nf)
		var via_eff: Dictionary = Scaling.boss_stats(GameData.ENEMIES[enemy], eff_normal)
		var uses_key := int(normal["max_hp"]) == int(solo["max_hp"])
		if eff_normal != int(key):
			uses_key = uses_key and int(normal["max_hp"]) != int(via_eff["max_hp"])
		check("sleutel %d volgt de baas-sleutel (eff %d)" % [key, eff_normal], uses_key)
		check("exp-factor op canon-baas %d (HP blijft canon)" % key,
				int(normal["exp"]) == GameData.round_half_even(float(solo["exp"]) * 2.0)
				and int(hard["exp"]) == int(solo["exp"])
				and int(normal["max_hp"]) == int(solo["max_hp"]))
	var warden: Dictionary = Floor.boss_preview("easy", 10)
	var solo10: Dictionary = Scaling.boss_stats(GameData.ENEMIES[str(Scaling.BOSSES[10]["enemy"])], 10)
	var voice: Dictionary = Scaling.boss_stats(GameData.ENEMIES[str(Scaling.BOSSES[99]["enemy"])], 99)
	check("easy 10 is Page Warden, niet The Voice (eff 99)",
			str(warden.get("name", "")) == "Page Warden" and int(warden["max_hp"]) == int(solo10["max_hp"])
			and int(warden["max_hp"]) != int(voice["max_hp"])
			and int(warden["exp"]) == GameData.round_half_even(float(solo10["exp"]) * 10.0))


func _heals() -> void:
	var loot := {"items": [{"item": "drankje", "n": 2}, {"item": "kort_zwaard", "n": 1}], "gold": 10}
	var easy: Dictionary = Floor.scale_heal_loot("easy", loot)
	var hard: Dictionary = Floor.scale_heal_loot("hard", loot)
	check("genees-items × exp-factor (easy ×10), uitrusting niet",
			int(easy["items"][0]["n"]) == 20 and int(easy["items"][1]["n"]) == 1 and int(easy["gold"]) == 10)
	check("hard laat het aantal genees-items staan", int(hard["items"][0]["n"]) == 2)
	check("bron-buit blijft staan", int(loot["items"][0]["n"]) == 2)


func _canon_same(a: Dictionary, b: Dictionary) -> bool:
	if int(a.get("max_hp", -1)) != int(b.get("max_hp", -2)):
		return false
	if int(a.get("atk", -1)) != int(b.get("atk", -2)):
		return false
	if int(a.get("def", -1)) != int(b.get("def", -2)):
		return false
	return str(a.get("weak", [])) == str(b.get("weak", []))
