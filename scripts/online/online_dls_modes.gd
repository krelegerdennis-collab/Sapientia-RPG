class_name OnlineDlsModes
extends RefCounted
## Online DLS-modi (Easy/Normal/Hard). Alleen de online-run leest dit.
## Solo-DLS (Classic) blijft dungeon100_scaling / dungeon100_rules. Zie ONLINE_COOP_DESIGN §7.0 en §11.
##
## PROPOSAL — RPG FORGE, geen canon. Dennis keurt de balans.
## Startwaarde van mode_exp_factor: Easy ×EASY_EXP_FACTOR (7), anders 100/N (Normal ×2, Hard ×1).
## Niet in dungeon100_scaling.gd. De battlesim mag dit later bijstellen.

const SIM_PATH := "res://data/online/sims/dls.json"
## PROPOSAL_MODE_EXP_NUMERATOR: teller van 100/N. Geen canon-balansgetal.
const PROPOSAL_MODE_EXP_NUMERATOR := 100
const EASY_EXP_FACTOR := 7

const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const Rules := preload("res://scripts/dungeon/dungeon100_rules.gd")

static var _sim: Dictionary = {}


static func sim() -> Dictionary:
	if not _sim.is_empty():
		return _sim
	var txt := FileAccess.get_file_as_string(SIM_PATH)
	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary:
		_sim = parsed
	return _sim


static func mode_ids() -> Array:
	var modes: Dictionary = sim().get("modes", {})
	var out: Array = []
	for k in modes.keys():
		out.append(str(k))
	return out


static func mode_def(mode: String) -> Dictionary:
	var modes: Dictionary = sim().get("modes", {})
	var raw = modes.get(mode, {})
	return raw if raw is Dictionary else {}


static func floors(mode: String) -> int:
	return int(mode_def(mode).get("floors", 0))


static func enemy_cap() -> int:
	return maxi(1, int(sim().get("enemy_cap", 8)))


## Effectieve solo-verdieping voor monsterstats, EXP, goud en buit.
## Easy/Normal: round(1 + (f-1) * 98 / (N-1)). Hard: f.
static func eff_floor(mode: String, f: int) -> int:
	var n := floors(mode)
	if n <= 0:
		return 0
	var ff := clampi(f, 1, n)
	var spec := str(mode_def(mode).get("eff", ""))
	if spec == "identity":
		return ff
	if spec == "compressed_98":
		if n <= 1:
			return 1
		return int(round(1.0 + float(ff - 1) * 98.0 / float(n - 1)))
	return 0


## Baas-sleutel in Scaling.BOSSES, of 0 als deze modus-verdieping geen baas heeft.
## De stats komen uit de sleutel, niet uit eff. Canon-bazen houden zo hun vaste stats.
static func boss_key(mode: String, f: int) -> int:
	var bosses = mode_def(mode).get("bosses", null)
	if bosses is Dictionary:
		var key := str(f)
		if bosses.has(key):
			return int(bosses[key])
		return 0
	var tag := str(bosses)
	if tag == "half_keys":
		for k in Scaling.boss_floors():
			@warning_ignore("integer_division")
			if (int(k) + 1) / 2 == f:
				return int(k)
		return 0
	if tag == "solo":
		return f if Scaling.is_boss_floor(f) else 0
	return 0


static func is_rest(mode: String, f: int) -> bool:
	var rest = mode_def(mode).get("rest", null)
	if rest is Array:
		for x in rest:
			if int(x) == f:
				return true
		return false
	if str(rest) == "solo":
		return Rules.is_rest_floor(f)
	return false


## PROPOSAL. Easy: EASY_EXP_FACTOR. Normal/Hard: PROPOSAL_MODE_EXP_NUMERATOR / floors (2 / 1).
static func mode_exp_factor(mode: String) -> int:
	if mode == "easy":
		return EASY_EXP_FACTOR
	var n := floors(mode)
	if n <= 0:
		return 1
	@warning_ignore("integer_division")
	return PROPOSAL_MODE_EXP_NUMERATOR / n
