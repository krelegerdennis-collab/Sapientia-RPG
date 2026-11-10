extends Node
## M9b: de Easy-run-sim is deterministisch, laat solo/Classic met rust en schrijft geen save.
## Start: godot --path . -- --d100modesimtest
## Niet in CI (tests.yml) en niet in debug_autotest.gd. Vraag aan Dennis staat in de PR.

const Sim := preload("res://tools/battlesim/d100_mode_sim.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const Modes := preload("res://scripts/online/online_dls_modes.gd")
const Floor := preload("res://scripts/online/online_dls_floor.gd")
const Finger := preload("res://scripts/online/solo_d100_fingerprint.gd")
const PageWardenBoss := preload("res://scripts/som/page_warden_boss.gd")
const SomData := preload("res://scripts/data/som_data.gd")

const SENTINEL := "M9B-SENTINEL-DO-NOT-SAVE\n"
const SAVE_PATHS: Array[String] = [
	"user://save_1.json",
	"user://autosave.json",
	"user://som_save_1.json",
	"user://coop_guest_session.json",
	"user://coop_guest_autosave.json",
	"user://online_profile.json",
	"user://d100modesimtest_save_1.json",
	"user://d100modesimtest_autosave.json",
	"user://d100modesim_save_1.json",
]
const MUST_STAY_ABSENT := "user://online_runs.json"

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
	_factor_stays()
	_boss_voorstel_blijft()
	_chain()
	_seeds()
	_param_determinisme()
	var solo_before := _solo_sig()
	var party_before := _party_sig()
	var gold_before := int(GameState.gold)
	var floor_before := int(GameState.dungeon100_floor)
	var inv_before := _inv_sig()
	var planted := _plant_saves()
	var runs_was_absent := not FileAccess.file_exists(MUST_STAY_ABSENT)
	_determinisme()
	_geen_saves(planted, runs_was_absent)
	check("solo-vingerafdruk ongewijzigd", _solo_sig() == solo_before and solo_before != "")
	check("partij-exp ongewijzigd", _party_sig() == party_before)
	check("goud ongewijzigd", int(GameState.gold) == gold_before)
	check("inventaris ongewijzigd", _inv_sig() == inv_before)
	check("dungeon100_floor ongewijzigd", int(GameState.dungeon100_floor) == floor_before)
	check("exp-factor blijft 10 na de sim", Modes.mode_exp_factor("easy") == 10)
	_cleanup(planted)
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _factor_stays() -> void:
	var applied: Dictionary = Floor.apply_mode_exp("easy", {"exp": 37})
	check("scaled_exp(37, 10) = apply_mode_exp easy", Sim.scaled_exp(37, 10) == int(applied["exp"]))
	check("scaled_exp(37, 25) wijkt af van de spelwaarde", Sim.scaled_exp(37, 25) != int(applied["exp"]))
	check("spelwaarde easy is 10", Modes.mode_exp_factor("easy") == 10)
	check("PROPOSAL-teller blijft 100", Modes.PROPOSAL_MODE_EXP_NUMERATOR == 100)
	check("normal/hard-factor blijft 2/1", Modes.mode_exp_factor("normal") == 2 and Modes.mode_exp_factor("hard") == 1)


func _boss_voorstel_blijft() -> void:
	check("ACTION_HP_MULT blijft 3.8", is_equal_approx(PageWardenBoss.ACTION_HP_MULT, 3.8))
	check("ACTION_ATK_MULT blijft 2.6", is_equal_approx(PageWardenBoss.ACTION_ATK_MULT, 2.6))
	check("SEAT_HP blijft de tabel uit #420", _close(PageWardenBoss.SEAT_HP, [0.0, 1.0, 2.6, 2.95, 3.35]))
	check("SEAT_ATK blijft de tabel uit #420", _close(PageWardenBoss.SEAT_ATK, [0.0, 1.0, 1.42, 1.43, 1.45]))
	check("boss_key blijft 10", PageWardenBoss.BOSS_KEY == 10)


func _chain() -> void:
	var swings := Sim.chain_swing_count(300)
	check("keten slaat minstens 4 keer in 5 s (%d)" % swings, swings >= 4)
	check("keten blijft onder 12 slagen in 5 s", swings < 12)


func _param_determinisme() -> void:
	check("spel-mult blijft 2.2", is_equal_approx(SomData.ENEMY_DAMAGE_MULT, 2.2))
	var base := {
		"mode": "easy",
		"runs": 1,
		"floors": 3,
		"factors": [10],
		"seats": [1],
		"hypothetical": false,
		"base_seed": 20261110,
		"verbose": false,
		"enemy_dmg": 2.2,
		"floor_heal": 0,
	}
	var a := Sim.run_cfg(base)
	var b := Sim.run_cfg(base)
	check("zelfde dmg en herstel, zelfde handtekening", Sim.signature(a) == Sim.signature(b) and Sim.signature(a) != "")
	var plain: Dictionary = base.duplicate(true)
	plain.erase("enemy_dmg")
	plain.erase("floor_heal")
	check("default is dmg 2.2 en herstel 0", Sim.signature(Sim.run_cfg(plain)) == Sim.signature(a))
	var low: Dictionary = base.duplicate(true)
	low["enemy_dmg"] = 1.2
	var healed: Dictionary = base.duplicate(true)
	healed["floor_heal"] = 50
	var c := Sim.run_cfg(low)
	var d := Sim.run_cfg(healed)
	check("easy_enemy_dmg 1.2 twee keer gelijk", Sim.signature(c) == Sim.signature(Sim.run_cfg(low)))
	check("floor_heal 50 twee keer gelijk", Sim.signature(d) == Sim.signature(Sim.run_cfg(healed)))
	check("lagere easy_enemy_dmg wijzigt de handtekening", Sim.signature(c) != Sim.signature(a))
	check("floor_heal wijzigt de handtekening", Sim.signature(d) != Sim.signature(a))
	var hero := {"hp": 10, "max_hp": 40, "mp": 4, "max_mp": 10}
	var down := {"hp": 0, "max_hp": 40, "mp": 0, "max_mp": 10}
	var party: Array = [hero, down]
	Sim.floor_heal_living(party, 0)
	check("herstel 0 laat HP staan", int(hero["hp"]) == 10 and int(down["hp"]) == 0)
	Sim.floor_heal_living(party, 50)
	check("herstel 50 is de helft van max, neer blijft liggen", int(hero["hp"]) == 30 and int(hero["mp"]) == 9 and int(down["hp"]) == 0)
	Sim.floor_heal_living(party, 100)
	check("herstel 100 vult de levende, niet de neergegane", int(hero["hp"]) == 40 and int(hero["mp"]) == 10 and int(down["hp"]) == 0 and int(down["mp"]) == 0)


func _seeds() -> void:
	check("run_seed index 0", Sim.run_seed_for(20261110, 0) == 20261110)
	check("run_seed stap 10007", Sim.run_seed_for(20261110, 1) == ((20261110 + 10007) & 0x7FFFFFFF))
	check("run_seed 0 wordt 1", Sim.run_seed_for(0, 0) == 1)


func _determinisme() -> void:
	var cheap := {
		"mode": "easy",
		"runs": 1,
		"floors": 2,
		"factors": [10],
		"seats": [1],
		"hypothetical": false,
		"base_seed": 20261110,
		"verbose": false,
	}
	var other: Dictionary = cheap.duplicate(true)
	other["base_seed"] = 7
	var a := Sim.run_cfg(cheap)
	var b := Sim.run_cfg(cheap)
	var c := Sim.run_cfg(other)
	check("zelfde seed, twee keer, zelfde handtekening", Sim.signature(a) == Sim.signature(b) and Sim.signature(a) != "")
	check("andere seed, andere kaart", int(a["map_fp"]) != int(c["map_fp"]))
	check("andere seed, andere handtekening", Sim.signature(a) != Sim.signature(c))
	var full := {
		"mode": "easy",
		"runs": 1,
		"floors": 10,
		"factors": [10, 25],
		"seats": [1, 4],
		"hypothetical": true,
		"base_seed": 20261110,
		"verbose": false,
	}
	var d := Sim.run_cfg(full)
	var e := Sim.run_cfg(full)
	check("volle easy-run, zelfde seed, zelfde handtekening", Sim.signature(d) == Sim.signature(e) and Sim.signature(d) != "")
	var rows: Array = d["rows"]
	check("vier cellen (2 factoren × 2 stoelen)", rows.size() == 4)
	var floors_ok := true
	var hypo_ok := true
	for row in rows:
		var fls: Array = row["floors"]
		if fls.size() != 10:
			floors_ok = false
		if int(row["hypo_n"]) != 1:
			hypo_ok = false
	check("tien vloeren per cel, inclusief boss_key 10", floors_ok)
	check("hypo-baas één keer per cel", hypo_ok)
	var causes_ok := true
	for row in rows:
		for fl in row["floors"]:
			var summed := int(fl["cause_wipe"]) + int(fl["cause_timeout"]) + int(fl["cause_soft"]) + int(fl["cause_other"])
			if summed != int(fl["losses"]):
				causes_ok = false
	check("elke verlies heeft één oorzaak", causes_ok)


func _plant_saves() -> Dictionary:
	var before := {}
	for path in SAVE_PATHS:
		before[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			check("sentinel schrijven %s" % path, false)
			continue
		f.store_string(SENTINEL)
		f.close()
	return before


func _geen_saves(planted: Dictionary, runs_was_absent: bool) -> void:
	for path in SAVE_PATHS:
		var now := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		check("sim laat %s met rust" % path, now == SENTINEL)
	check("sim maakt online_runs.json niet", runs_was_absent and not FileAccess.file_exists(MUST_STAY_ABSENT))
	check("suite-save is het omgeleide pad", GameState.save_path == "user://d100modesimtest_save_1.json")
	# planted bewaart de oude inhoud; de suite wist die zelf weer (zie _cleanup).
	check("sentinels geplant", planted.size() == SAVE_PATHS.size())


func _cleanup(planted: Dictionary) -> void:
	for path in SAVE_PATHS:
		var now := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		if now != SENTINEL:
			continue
		var old := str(planted.get(path, ""))
		if old == "":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f != null:
				f.store_string(old)
				f.close()


func _close(got: Array, want: Array) -> bool:
	if got.size() != want.size():
		return false
	for i in want.size():
		if not is_equal_approx(float(got[i]), float(want[i])):
			return false
	return true


func _solo_sig() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for f in [1, 10, 50, 99]:
		parts.append("m%d=%s" % [f, Finger.monster_hash(f)])
		parts.append("b%d=%s" % [f, Finger.boss_hash(f)])
		parts.append("c%d=%s" % [f, Finger.chest_hash(f)])
		for seed in [1, 42]:
			parts.append("g%d.%d=%s" % [f, seed, Finger.generate_hash(seed, f)])
	return "|".join(parts)


func _party_sig() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for h in GameState.party:
		parts.append("%s:%d:%d:%d" % [str(h["id"]), int(h["exp"]), int(h["level"]), int(h["hp"])])
	return "|".join(parts)


## Tas via de publieke item_count, over de catalogus.
func _inv_sig() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for bag in [GameData.ITEMS, GameData.KEY_ITEMS, GameData.EQUIPMENT]:
		var keys: Array = bag.keys()
		keys.sort()
		for k in keys:
			var n := GameState.item_count(str(k))
			if n > 0:
				parts.append("%s=%d" % [str(k), n])
	return "|".join(parts)
