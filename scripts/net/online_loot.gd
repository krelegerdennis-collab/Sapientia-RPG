class_name OnlineLoot
extends RefCounted
## M8b — buit per stoel voor online co-op (design-doc §7.5, COMBAT D8).
##
## Puur en in geheugen. De host rolt per stoel op een eigen RandomNumberGenerator.
## De seed is hash(run-seed + stoel-uid), hetzelfde idee als dungeon_chest.gd
## (hash van een tekst). Die stroom is niet arena.rng: extra kist- of drop-rolls
## verschuiven de sim niet.
##
## Kisten gaan door Dungeon100Scaling.chest_loot. Monster-drops gebruiken de
## bestaande "drops"-tabel en de schaal via het "floor"-veld (battle_enemy).
## floor ontbreekt of is 0: geen terugval op GameState.dungeon100_floor.
##
## Run-tas, run-goud en run-EXP blijven op dit object. Geen FileAccess, geen
## schrijven naar een verhaal-save of naar solo-inventarissen. Oprapen gaat
## alleen via claim(); een andere stoel krijgt false en de tas blijft leeg.
##
## M1/M3 haken hier niet in. Het resultaat en de reward-bundle zitten in
## online_reward.gd.

const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const GameData := preload("res://scripts/data/game_data.gd")

## Zelfde plafond als NetProtocol.MAX_PLAYERS. Extra uid's worden genegeerd.
const SEAT_CAP := 4

var run_seed: int = 0

var _streams: Dictionary = {}
var _bags: Dictionary = {}
var _stats: Dictionary = {}
var _drops: Dictionary = {}
var _seq: int = 0


## Deterministische seed. Zelfde run-seed + uid = zelfde stroom. Geen globale rand.
static func seat_seed(run_seed_value: int, seat_uid: String) -> int:
	var s := hash("online-loot|%d|%s" % [run_seed_value, seat_uid])
	if s == 0:
		return 1
	return s


## Alleen het "floor"-veld van de kist of het monster. Geen solo-verdieping.
static func floor_of(entry: Dictionary) -> int:
	return int(entry.get("floor", 0))


func setup(run_seed_value: int, seat_uids: Array) -> void:
	run_seed = run_seed_value
	_streams.clear()
	_bags.clear()
	_stats.clear()
	_drops.clear()
	_seq = 0
	var seen := {}
	var n := 0
	for raw in seat_uids:
		if n >= SEAT_CAP:
			break
		var uid := str(raw).strip_edges()
		if uid == "" or seen.has(uid):
			continue
		seen[uid] = true
		n += 1
		var rng := RandomNumberGenerator.new()
		rng.seed = seat_seed(run_seed, uid)
		_streams[uid] = rng
		_bags[uid] = {"gold": 0, "exp": 0, "items": {}}
		_stats[uid] = {"floors": 0, "best_floor": 0, "kills": 0, "revives": 0, "downs": 0}


func has_seat(uid: String) -> bool:
	return _streams.has(uid)


func uids() -> Array:
	var out: Array = _streams.keys()
	out.sort()
	return out


## Eén kist, één stoel. Leeg dict als de stoel niet in deze run zit.
## chest: "id", "floor" (verplicht voor buit), optioneel "boss".
func roll_chest_for(uid: String, chest: Dictionary) -> Dictionary:
	if not _streams.has(uid):
		return {}
	var floor_nr := floor_of(chest)
	var rng: RandomNumberGenerator = _streams[uid]
	var loot: Dictionary = Scaling.chest_loot(floor_nr, rng, bool(chest.get("boss", false)))
	return _store(uid, str(chest.get("id", "chest")), "chest", floor_nr, loot)


## Zelfde kist voor elke stoel, elk met de eigen stroom. Volgorde = gesorteerde uid.
func roll_chest(chest: Dictionary) -> Array:
	var out: Array = []
	for uid in uids():
		out.append(roll_chest_for(str(uid), chest))
	return out


## Eén verslagen monster, één stoel.
## monster: "id", "enemy" (id uit GameData.ENEMIES), "floor", optioneel "boss".
func roll_monster_for(uid: String, monster: Dictionary) -> Dictionary:
	if not _streams.has(uid):
		return {}
	var floor_nr := floor_of(monster)
	var enemy_id := str(monster.get("enemy", ""))
	var rng: RandomNumberGenerator = _streams[uid]
	var loot := roll_monster_loot(rng, enemy_id, floor_nr, bool(monster.get("boss", false)))
	return _store(uid, str(monster.get("id", "drop")), "monster", floor_nr, loot)


func roll_monster(monster: Dictionary) -> Array:
	var out: Array = []
	for uid in uids():
		out.append(roll_monster_for(str(uid), monster))
	return out


## Bestaande droptabel + schaal. Vaste "n" gaat niet door de RNG (zoals fixed_drops).
## "chance" rolt alleen als het item in ITEMS staat, in dezelfde volgorde als som_arena.
static func roll_monster_loot(rng: RandomNumberGenerator, enemy_id: String, floor_nr: int, boss: bool) -> Dictionary:
	var empty := {
		"tier": 0, "items": [], "gold": 0, "exp": 0,
		"boss": false, "kind": "drop", "enemy": enemy_id, "floor": floor_nr,
	}
	if not GameData.ENEMIES.has(enemy_id):
		return empty
	var scaled: Dictionary = Scaling.battle_enemy(GameData.ENEMIES[enemy_id], floor_nr, boss)
	var items: Array = []
	var drops: Array = scaled.get("drops", [])
	for d in drops:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var id := str(d.get("item", ""))
		if id == "" or not GameData.ITEMS.has(id):
			continue
		var n := int(d.get("n", 0))
		if n > 0:
			items.append({"item": id, "n": n})
			continue
		if rng.randf() < float(d.get("chance", 0.0)):
			items.append({"item": id, "n": 1})
	return {
		"tier": Scaling.tier_for_floor(floor_nr) if floor_nr > 0 else 0,
		"items": items,
		"gold": int(scaled.get("gold", 0)),
		"exp": int(scaled.get("exp", 0)),
		"boss": boss,
		"kind": "drop",
		"enemy": enemy_id,
		"floor": floor_nr,
	}


## true alleen als claimer de eigenaar is en de buit nog niet gepakt is.
## Daarna staat de buit in de run-tas van die stoel. Een andere stoel verandert niets.
func claim(drop_id: String, claimer_uid: String) -> bool:
	if not _drops.has(drop_id) or not _bags.has(claimer_uid):
		return false
	var rec: Dictionary = _drops[drop_id]
	if str(rec["owner_uid"]) != claimer_uid or bool(rec["claimed"]):
		return false
	var loot: Dictionary = rec["loot"]
	var bag: Dictionary = _bags[claimer_uid]
	var gold := Scaling.grant_loot(loot, bag["items"])
	bag["gold"] = int(bag["gold"]) + gold
	bag["exp"] = int(bag["exp"]) + int(loot.get("exp", 0))
	rec["claimed"] = true
	return true


func bag(uid: String) -> Dictionary:
	if not _bags.has(uid):
		return {"gold": 0, "exp": 0, "items": {}}
	return (_bags[uid] as Dictionary).duplicate(true)


func loot_summary(uid: String) -> Dictionary:
	var b := bag(uid)
	var items: Array = []
	var ids: Array = (b["items"] as Dictionary).keys()
	ids.sort()
	for id in ids:
		items.append({"item": str(id), "n": int(b["items"][id])})
	return {"gold": int(b["gold"]), "exp": int(b["exp"]), "items": items}


func note_kill(uid: String, n: int = 1) -> void:
	_add_stat(uid, "kills", n)


func note_revive(uid: String, n: int = 1) -> void:
	_add_stat(uid, "revives", n)


func note_down(uid: String, n: int = 1) -> void:
	_add_stat(uid, "downs", n)


## Eén verslagen verdieping. best_floor = hoogste verdiepingsnummer, floors = aantal.
func note_floor_cleared(uid: String, floor_nr: int) -> void:
	if floor_nr <= 0 or not _stats.has(uid):
		return
	_stats[uid]["floors"] = int(_stats[uid]["floors"]) + 1
	_stats[uid]["best_floor"] = maxi(int(_stats[uid]["best_floor"]), floor_nr)


func seat_report(uid: String) -> Dictionary:
	if not _stats.has(uid):
		return {}
	var st: Dictionary = _stats[uid]
	return {
		"seat_uid": uid,
		"floors": int(st["floors"]),
		"best_floor": int(st["best_floor"]),
		"kills": int(st["kills"]),
		"revives": int(st["revives"]),
		"downs": int(st["downs"]),
		"loot": loot_summary(uid),
	}


func reports() -> Array:
	var out: Array = []
	for uid in uids():
		out.append(seat_report(str(uid)))
	return out


func _add_stat(uid: String, key: String, n: int) -> void:
	if n <= 0 or not _stats.has(uid):
		return
	_stats[uid][key] = int(_stats[uid][key]) + n


func _store(uid: String, source: String, kind: String, floor_nr: int, loot: Dictionary) -> Dictionary:
	_seq += 1
	var id := "%s#%s#%d" % [source, uid, _seq]
	var rec := {
		"id": id,
		"owner_uid": uid,
		"source": source,
		"kind": kind,
		"floor": floor_nr,
		"loot": loot,
		"claimed": false,
	}
	_drops[id] = rec
	return rec.duplicate(true)
