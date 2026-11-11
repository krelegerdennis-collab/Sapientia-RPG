class_name OnlineDlsFloor
extends RefCounted
## Online-only verdieping van de DLS. Roept generate(seed, eff) aan en past daarna
## de modustabel toe op een kopie. De generator-cache (solo) wordt niet beschreven.
## Koopman, puzzels en blauwe kisten uit. Baas-slot leeg tot M9 (Page Warden).

const ONLINE_SCENE := "res://scenes/online/online_dls_room.tscn"
const NOTITIE_PROP := "grot_notitie"

const Gen := preload("res://scripts/dungeon/dungeon100_generator.gd")
const Content := preload("res://scripts/dungeon/dungeon100_content.gd")
const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const Blue := preload("res://scripts/data/dungeon100_blue.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const CoopRevive := preload("res://scripts/coop/coop_revive.gd")
const CoopSeat := preload("res://scripts/coop/coop_seat.gd")

static var _heals: Dictionary = {}


static func build(mode: String, seed: int, mode_floor: int) -> Dictionary:
	var eff := OnlineDlsModes.eff_floor(mode, mode_floor)
	if eff <= 0:
		return {}
	var raw := Gen.generate(seed, eff)
	if raw.is_empty():
		return {}
	var data: Dictionary = raw.duplicate(true)
	var room: Dictionary = data.get("room", {})
	var cap := OnlineDlsModes.enemy_cap()
	var mons: Array = Content.monsters(data)
	if mons.size() > cap:
		mons = mons.slice(0, cap)
	for m in mons:
		m["floor"] = eff
		m["boss"] = false
		m.erase("guard")
		m.erase("puzzel_duw")
		var eid := str(m.get("enemy", ""))
		m["group"] = [eid]
	room["monsters"] = mons
	var chests: Array = []
	for c in Content.chests(data):
		if _is_blue(c):
			continue
		c["floor"] = eff
		var loot: Dictionary = scale_heal_loot(mode, c.get("loot", {}))
		c["loot"] = loot
		var items: Array = loot.get("items", [])
		if not items.is_empty():
			c["item"] = items[0].get("item", c.get("item", ""))
			c["n"] = int(items[0].get("n", c.get("n", 1)))
		chests.append(c)
	room["chests"] = chests
	for key in ["puzzel", "puzzel_massief", "puzzel_duw", "signs", "notitie"]:
		room.erase(key)
	if room.has("props"):
		var props: Array = []
		for p in room["props"]:
			if str(p.get("type", "")) == NOTITIE_PROP:
				continue
			props.append(p)
		room["props"] = props
	var bkey := OnlineDlsModes.boss_key(mode, mode_floor)
	var total := OnlineDlsModes.floors(mode)
	data["boss_key"] = bkey
	data["boss_closed"] = bkey > 0
	data["online_mode"] = mode
	data["online_mode_floor"] = mode_floor
	data["online_eff"] = eff
	if OnlineDlsModes.is_rest(mode, mode_floor):
		var rs: Vector2i = data.get("rest_slot", Vector2i(-1, -1))
		if rs.x >= 0:
			room["rustpunt"] = [rs.x, rs.y]
		# De prop is alleen de plek. Herstel en CoopRevive.apply_rest zitten in apply_easy_entry.
	else:
		room.erase("rustpunt")
	var spawns: Dictionary = room.get("spawns", {}).duplicate(true)
	if mode_floor == 1:
		var ws: Vector2i = data.get("warper_slot", Vector2i(-1, -1))
		if ws.x >= 0:
			room["warper"] = [ws.x, ws.y]
		else:
			room.erase("warper")
	else:
		room.erase("warper")
		spawns.erase(Gen.SPAWN_WARPER)
	room["spawns"] = spawns
	var exits := {}
	if mode_floor > 1:
		exits["h"] = {"map": ONLINE_SCENE, "spawn": Gen.SPAWN_FROM_BELOW}
	else:
		exits["h"] = {"map": "", "spawn": "hal"}
	if bool(data.get("has_stairs_down", false)):
		if mode_floor < total:
			exits["v"] = {"map": ONLINE_SCENE, "spawn": Gen.SPAWN_FROM_ABOVE}
		else:
			exits["v"] = {"map": "", "spawn": "uitgang"}
	room["exits"] = exits
	room["online_dls"] = true
	room["online_mode"] = mode
	room["online_mode_floor"] = mode_floor
	room["online_eff"] = eff
	room["name"] = "Verdieping %d/%d" % [mode_floor, total]
	room["dungeon100_floor"] = eff
	data["room"] = room
	return data


## Easy-vloer > 1, vóór het gevecht. Levenden krijgen COOP_EASY_FLOOR_HEAL_PCT van max HP en max MP.
## Wie op 0 staat blijft liggen. Rustvloer vult levenden daarna vol en laat CoopRevive.apply_rest
## de liggende stoelen op volle HP zetten. De revive-teller blijft staan. Andere modi doen niets.
static func apply_easy_entry(mode: String, floor_no: int, heroes: Array, rows: Array) -> bool:
	if mode != "easy" or floor_no <= 1:
		return false
	heal_living(heroes, SomData.COOP_EASY_FLOOR_HEAL_PCT)
	if not OnlineDlsModes.is_rest(mode, floor_no):
		return true
	heal_living(heroes, 100)
	var use: Array = rows
	if use.is_empty():
		use = _down_rows(heroes)
	else:
		_copy_hp_to_rows(heroes, use)
	CoopRevive.apply_rest(use)
	_copy_hp_from_rows(use, heroes)
	return true


## Procent van max HP en max MP erbij, alleen hp > 0. 0 doet niets. 100 vult een levende vol.
static func heal_living(heroes: Array, pct: int) -> void:
	var p := clampi(pct, 0, 100)
	if p <= 0:
		return
	for h in heroes:
		if typeof(h) != TYPE_DICTIONARY:
			continue
		var hero: Dictionary = h
		if int(hero.get("hp", 0)) <= 0:
			continue
		var max_hp := maxi(1, int(hero.get("max_hp", 1)))
		var add_hp := int(round(float(max_hp) * float(p) / 100.0))
		hero["hp"] = mini(max_hp, int(hero.get("hp", 0)) + add_hp)
		if hero.has("mp") or hero.has("max_mp"):
			var max_mp := maxi(0, int(hero.get("max_mp", 0)))
			var add_mp := int(round(float(max_mp) * float(p) / 100.0))
			hero["mp"] = mini(max_mp, int(hero.get("mp", 0)) + add_mp)


static func _down_rows(heroes: Array) -> Array:
	var out: Array = []
	var i := 0
	for h in heroes:
		if typeof(h) != TYPE_DICTIONARY:
			continue
		var hero: Dictionary = h
		if int(hero.get("hp", 0)) > 0:
			i += 1
			continue
		var row := CoopSeat.make(i, str(hero.get("id", "")), CoopSeat.CONTROLLER_HUMAN)
		row["hp"] = 0
		row["max_hp"] = maxi(1, int(hero.get("max_hp", 1)))
		row["down"] = true
		row["active"] = true
		row["participate"] = true
		out.append(row)
		i += 1
	return out


static func _copy_hp_to_rows(heroes: Array, rows: Array) -> void:
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var hero := _hero_named(heroes, CoopRevive.hero_of(row))
		if hero.is_empty():
			continue
		row["max_hp"] = maxi(1, int(hero.get("max_hp", row.get("max_hp", 1))))
		row["hp"] = int(hero.get("hp", 0))
		if int(row["hp"]) <= 0 and CoopRevive.row_active(row) and not CoopRevive.row_down(row):
			CoopRevive.enter_down(row)


static func _copy_hp_from_rows(rows: Array, heroes: Array) -> void:
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var hero := _hero_named(heroes, CoopRevive.hero_of(row))
		if hero.is_empty():
			continue
		hero["hp"] = int(row.get("hp", hero.get("hp", 0)))


static func _hero_named(heroes: Array, id: String) -> Dictionary:
	if id == "":
		return {}
	for h in heroes:
		if typeof(h) == TYPE_DICTIONARY and str((h as Dictionary).get("id", "")) == id:
			return h
	return {}


static func scale_heal_loot(mode: String, loot: Dictionary) -> Dictionary:
	var out: Dictionary = loot.duplicate(true)
	var factor := OnlineDlsModes.mode_exp_factor(mode)
	if factor == 1:
		return out
	var heal := _heal_ids()
	var items: Array = []
	for it in out.get("items", []):
		var row: Dictionary = (it as Dictionary).duplicate()
		if heal.has(str(row.get("item", ""))):
			row["n"] = maxi(1, int(row.get("n", 1)) * factor)
		items.append(row)
	out["items"] = items
	return out


static func apply_mode_exp(mode: String, stats: Dictionary) -> Dictionary:
	var out := stats.duplicate(true)
	var factor := OnlineDlsModes.mode_exp_factor(mode)
	out["exp"] = GameData.round_half_even(float(out.get("exp", 0)) * float(factor))
	out["online_exp_factor"] = factor
	return out


static func monster_preview(mode: String, enemy_id: String, eff: int) -> Dictionary:
	var base: Dictionary = GameData.ENEMIES.get(enemy_id, {})
	if base.is_empty():
		return {}
	var scaled: Dictionary = Scaling.monster_stats(base, eff)
	var n := 1
	var scale := SomData.boss_party_scale(n)
	if not is_equal_approx(scale, 1.0):
		for k in ["max_hp", "atk", "def", "mag", "mdef"]:
			if scaled.has(k):
				scaled[k] = maxi(1, GameData.round_half_even(float(scaled[k]) * scale))
	return apply_mode_exp(mode, scaled)


## Baas-stats uit de modus-sleutel (niet uit eff). M7 spawnt de baas nog niet.
static func boss_preview(mode: String, mode_floor: int) -> Dictionary:
	var key := OnlineDlsModes.boss_key(mode, mode_floor)
	if key <= 0 or not Scaling.BOSSES.has(key):
		return {}
	var enemy := str(Scaling.BOSSES[key].get("enemy", ""))
	var base: Dictionary = GameData.ENEMIES.get(enemy, {})
	if base.is_empty():
		return {}
	var stats: Dictionary = Scaling.boss_stats(base, key)
	var scale := SomData.boss_party_scale(1)
	if not is_equal_approx(scale, 1.0):
		for k in ["max_hp", "atk", "def", "mag", "mdef"]:
			if stats.has(k):
				stats[k] = maxi(1, GameData.round_half_even(float(stats[k]) * scale))
	stats["boss_key"] = key
	stats["name"] = str(Scaling.BOSSES[key].get("name", stats.get("name", "")))
	return apply_mode_exp(mode, stats)


## Action-stats voor SomArena. Alleen als de kamer online_dls is en coop_mode aan staat.
static func action_stats(m: Node, _arena: Node) -> Dictionary:
	var mode := ""
	var mode_floor := 0
	var host: Node = m.room
	if host != null and host.get("room") is Dictionary:
		var rd: Dictionary = host.get("room")
		mode = str(rd.get("online_mode", ""))
		mode_floor = int(rd.get("online_mode_floor", 0))
	if bool(m.boss):
		return boss_preview(mode, mode_floor)
	return monster_preview(mode, str(m.enemy_id), int(m.floor_nr))


static func map_hash(built: Dictionary) -> String:
	var room: Dictionary = built.get("room", {})
	var parts: PackedStringArray = []
	parts.append("mode=%s" % str(built.get("online_mode", "")))
	parts.append("f=%s" % str(built.get("online_mode_floor", 0)))
	parts.append("eff=%s" % str(built.get("online_eff", 0)))
	parts.append("bk=%s" % str(built.get("boss_key", 0)))
	parts.append("bc=%s" % str(built.get("boss_closed", false)))
	for row in room.get("layout", []):
		parts.append(str(row))
	for m in room.get("monsters", []):
		var tile: Array = m.get("tile", [0, 0])
		parts.append("m:%s:%s:%s:%s:%s" % [m.get("id", ""), m.get("enemy", ""), tile[0], tile[1], m.get("floor", 0)])
	for c in room.get("chests", []):
		var tile: Array = c.get("tile", [0, 0])
		parts.append("c:%s:%s:%s:%s:%s" % [c.get("id", ""), tile[0], tile[1], c.get("floor", 0), c.get("kind", "")])
	parts.append("rest:%s" % SoloD100Fingerprint.canon(room.get("rustpunt", [])))
	parts.append("warp:%s" % SoloD100Fingerprint.canon(room.get("warper", [])))
	parts.append("ex:%s" % SoloD100Fingerprint.canon(room.get("exits", {})))
	return SoloD100Fingerprint.djb2("|".join(parts))


static func has_boss_monster(built: Dictionary) -> bool:
	for m in built.get("room", {}).get("monsters", []):
		if bool(m.get("boss", false)):
			return true
	return false


static func has_blue_chest(built: Dictionary) -> bool:
	for c in built.get("room", {}).get("chests", []):
		if _is_blue(c):
			return true
	return false


static func exit_reachable(built: Dictionary) -> bool:
	var room: Dictionary = built.get("room", {})
	var spawn: Vector2i = built.get("spawn_up", Vector2i(-1, -1))
	var stairs: Vector2i = built.get("stairs_down", Vector2i(-1, -1))
	if spawn.x < 0 or stairs.x < 0:
		return false
	var seen: Dictionary = Gen.reachable_tiles(room, spawn)
	if not seen.has(stairs):
		return false
	if int(built.get("boss_key", 0)) > 0:
		var slot: Vector2i = built.get("boss_slot", Vector2i(-1, -1))
		if slot.x < 0 or not seen.has(slot):
			return false
	return true


static func _is_blue(chest: Dictionary) -> bool:
	if str(chest.get("kind", "")) == Blue.KIND_BLUE:
		return true
	var loot = chest.get("loot", {})
	return loot is Dictionary and bool(loot.get("blue", false))


static func _heal_ids() -> Dictionary:
	if not _heals.is_empty():
		return _heals
	for row in Scaling.POTIONS:
		for id in row:
			_heals[str(id)] = true
	return _heals
