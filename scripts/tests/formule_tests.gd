extends Node
## ALLEEN VOOR TESTEN - schade- en EXP-formules van WM1.
## Start:  godot --path . -- --formuletest
##   Deel A: fysieke schade (battle.gd physical_base / _physical_damage):
##           ATK x mult - DEF/2, +/- 15% geluk, minimaal 1, verdedigen = helft, schild = DEF x guard_mult.
##   Deel B: EXP-curve (GameData.exp_for_level = 15 x (level-1)^2) en PartyActions.exp_to_next.
##   Deel C: level-ups via GameState.give_exp (drempels, meerdere levels in een keer, groei).
## Vaste getallen met de hand uitgerekend: een fout in de formule geeft hier direct FAIL.
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const PartyActions := preload("res://scripts/party_actions.gd")
const BATTLE_SCRIPT := "res://scripts/battle/battle.gd"

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
	print("=== Deel A: fysieke schade ===")
	_damage_tests()
	print("=== Deel B: EXP-curve ===")
	_exp_curve_tests()
	print("=== Deel C: level-ups ===")
	_level_up_tests()
	print("FORMULETEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	for i in 10:
		await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


## Strijder zoals battle.gd hem gebruikt (alleen de velden die de formule leest).
func _fighter(atk: int, def: int) -> Dictionary:
	return {"s": {"atk": atk, "def": def, "hp": 10}, "is_hero": false, "defending": false, "buffs": []}


# ================================================================ deel A
func _damage_tests() -> void:
	# Script los instantiëren (niet in de boom): _ready draait niet, de formules zijn puur.
	var b: Object = (load(BATTLE_SCRIPT) as GDScript).new()
	var a := _fighter(20, 0)
	var t := _fighter(0, 10)
	check("physical_base: ATK 20, DEF 10 -> 20 - 10/2 = 15", is_equal_approx(b.physical_base(a, t, 1.0), 15.0))
	check("physical_base: oneven DEF 7 -> 20 - 3.5 = 16.5", is_equal_approx(b.physical_base(a, _fighter(0, 7), 1.0), 16.5))
	check("physical_base: mult 1.5 -> 20 x 1.5 - 5 = 25", is_equal_approx(b.physical_base(a, t, 1.5), 25.0))
	check("physical_base: geen DEF -> ATK", is_equal_approx(b.physical_base(a, _fighter(0, 0), 1.0), 20.0))
	check("physical_base: DEF > 2xATK -> negatief (min 1 komt later)", b.physical_base(_fighter(5, 0), _fighter(0, 20), 1.0) < 0.0)

	var buffed := _fighter(20, 0)
	buffed["buffs"] = [{"stat": "atk", "pct": 0.5, "turns": 2}]
	check("ATK-buff +50% -> 30 - 5 = 25", is_equal_approx(b.physical_base(buffed, t, 1.0), 25.0))
	var verlopen := _fighter(20, 0)
	verlopen["buffs"] = [{"stat": "atk", "pct": 0.5, "turns": 0}]
	check("verlopen buff (turns 0) telt niet", is_equal_approx(b.physical_base(verlopen, t, 1.0), 15.0))
	var guard := _fighter(0, 10)
	guard["guard"] = 2
	guard["guard_mult"] = 2.0
	check("schild omhoog: DEF x 2 -> 20 - 10 = 10", is_equal_approx(b.physical_base(a, guard, 1.0), 10.0))

	# Geluksmarge: 15 x [0.85, 1.15] = [12.75, 17.25] -> afgerond 13..17
	var lo := 999
	var hi := -999
	seed(12345)
	for i in 500:
		var d: int = b._physical_damage(a, t, 1.0)
		lo = mini(lo, d)
		hi = maxi(hi, d)
	check("_physical_damage blijft binnen 13..17 (15 +/- 15%%), kreeg %d..%d" % [lo, hi], lo >= 13 and hi <= 17)
	check("_physical_damage varieert (geluk zit erin)", hi > lo)

	seed(99)
	var d1: int = b._physical_damage(a, t, 1.0)
	seed(99)
	var d2 := maxi(1, roundi(15.0 * randf_range(0.85, 1.15)))
	check("_physical_damage = roundi(base x randf_range(0.85, 1.15))", d1 == d2)

	var zwak := _fighter(5, 0)
	var tank := _fighter(0, 50)
	var min_ok := true
	for i in 50:
		min_ok = min_ok and b._physical_damage(zwak, tank, 1.0) == 1
	check("minimaal 1 schade, ook als DEF de aanval opslokt", min_ok)

	var def_t := _fighter(0, 10)
	def_t["defending"] = true
	var ok_half := true
	for s in [1, 2, 3, 4, 5, 6, 7, 8]:
		seed(s)
		var normaal: int = b._physical_damage(a, t, 1.0)
		seed(s)
		var half: int = b._physical_damage(a, def_t, 1.0)
		ok_half = ok_half and half == maxi(1, int(normaal / 2.0))
	check("verdedigen = halve schade (afgerond naar beneden)", ok_half)
	b.free()


# ================================================================ deel B
func _exp_curve_tests() -> void:
	var expected := {1: 0, 2: 15, 3: 60, 4: 135, 5: 240, 10: 1215, 20: 5415, 50: 36015, 100: 147015}
	for lvl: int in expected:
		check("exp_for_level(%d) = %d" % [lvl, expected[lvl]], GD.exp_for_level(lvl) == int(expected[lvl]))
	var stijgend := true
	var groeit := true
	for lvl in range(2, 100):
		stijgend = stijgend and GD.exp_for_level(lvl + 1) > GD.exp_for_level(lvl)
		var stap := GD.exp_for_level(lvl + 1) - GD.exp_for_level(lvl)
		groeit = groeit and stap == 15 * (2 * lvl - 1)
	check("EXP-curve strikt stijgend t/m level 100", stijgend)
	check("stap per level = 15 x (2 x level - 1) (kwadratische curve)", groeit)

	check("exp_to_next: level 1, 0 EXP -> 15", PartyActions.exp_to_next({"level": 1, "exp": 0}) == 15)
	check("exp_to_next: level 1, 9 EXP -> 6", PartyActions.exp_to_next({"level": 1, "exp": 9}) == 6)
	check("exp_to_next: level 3, 100 EXP -> 35", PartyActions.exp_to_next({"level": 3, "exp": 100}) == 35)
	check("exp_to_next nooit negatief", PartyActions.exp_to_next({"level": 2, "exp": 999}) == 0)


# ================================================================ deel C
func _level_up_tests() -> void:
	var h: Dictionary = GameState.hero_template("dennis")
	check("held 'dennis' bestaat", not h.is_empty())
	if h.is_empty():
		return
	var g: Dictionary = h["growth"]
	var hp0 := int(h["max_hp"])
	check("start: level 1, 0 EXP", int(h["level"]) == 1 and int(h["exp"]) == 0)
	var msgs: Array[String] = GameState.give_exp(h, 14)
	check("14 EXP: nog level 1 (drempel is 15)", int(h["level"]) == 1 and msgs.is_empty())
	msgs = GameState.give_exp(h, 1)
	check("15 EXP: precies level 2", int(h["level"]) == 2 and msgs.size() == 1)
	check("level-up: max_hp + growth", int(h["max_hp"]) == hp0 + int(g["max_hp"]))
	msgs = GameState.give_exp(h, 120)   # 135 = drempel level 4
	check("135 EXP: twee levels tegelijk -> level 4", int(h["level"]) == 4 and msgs.size() == 2)
	check("EXP blijft opgeteld (135)", int(h["exp"]) == 135)
	check("3 level-ups: max_hp = start + 3 x growth", int(h["max_hp"]) == hp0 + 3 * int(g["max_hp"]))
	GameState.give_exp(h, 104)          # 239: net onder level 5 (240)
	check("239 EXP: nog level 4", int(h["level"]) == 4)
	check("exp_to_next na 239 EXP = 1", PartyActions.exp_to_next(h) == 1)
