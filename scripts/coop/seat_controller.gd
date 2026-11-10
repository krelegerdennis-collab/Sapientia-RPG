class_name SeatController
extends RefCounted
## Stoel-controller voor online co-op (M6, COMBAT_DESIGN §4 / D4, ONLINE_COOP §8–§9).
## local / remote / ai. AI draait alleen op de host en levert dezelfde virtuele input
## als een speler (stick + knoppen). Geen protocolwijziging: net_protocol.gd blijft v1.

const Codec := preload("res://scripts/net/net_codec.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const GameData := preload("res://scripts/data/game_data.gd")

## Tune-waarde. Start: 180 s (een paar minuten). Na afloop blijft de stoel AI tot het einde van de run.
const GRACE_SEC := 180.0
const SIM_HZ := 60
const GRACE_TICKS := 10800 # GRACE_SEC * SIM_HZ

const CTRL_LOCAL := "local"
const CTRL_REMOTE := "remote"
const CTRL_AI := "ai"
const HOST_LOST := "session_end"

## PLACEHOLDER: vaste AI-look = standaard held-sheet + grijs-cyaan tint. Geen paper-doll.
## Final art (RPG ART): lagen 24x32 lopen, zie ONLINE_COOP §5.3.
const AI_TINT := Color(0.62, 0.78, 0.80, 1.0)

## Nog geen gameplay: taunt, guard, revive, interrupt, debuff, buff.
## Revive zelf bouwt RPG COMBAT in M8; hier alleen de prioriteit-haak.
const STUB_ACTIONS: Array[String] = ["taunt", "guard", "revive", "interrupt", "debuff", "buff"]

const MAX_SEATS := 4

signal controller_changed(slot: int, controller: String)

var room_code := ""
var is_host := false
var local_slot := 0
var tick_i := 0
var seats: Array = []
var _claims: Array = []


func configure(room: String, host: bool, local: int) -> void:
	room_code = room
	is_host = host
	local_slot = local
	tick_i = 0
	_claims.clear()
	seats.clear()
	for i in MAX_SEATS:
		seats.append(_blank(i))


func runs_ai() -> bool:
	return is_host


static func role_of(hero_id: String) -> String:
	match hero_id:
		"dennis":
			return "tank"
		"lotte":
			return "heal"
		"noor":
			return "control"
		"kael", "orion":
			return "dps"
		_:
			return ""


## Lege stoelen: geen tank → Warrior, geen heal → Priest, dan Mage, dan Archer, dan Psytech.
static func fill_heroes(present: Array, empty_slots: int) -> Array[String]:
	var have := {}
	var has_tank := false
	var has_heal := false
	for id in present:
		var sid := str(id)
		have[sid] = true
		var role := role_of(sid)
		if role == "tank":
			has_tank = true
		elif role == "heal":
			has_heal = true
	var want: Array[String] = []
	if not has_tank:
		want.append("dennis")
	if not has_heal:
		want.append("lotte")
	want.append("noor")
	want.append("orion")
	want.append("kael")
	var out: Array[String] = []
	for id in want:
		if out.size() >= empty_slots:
			break
		if have.has(id):
			continue
		out.append(id)
		have[id] = true
	return out


## rows: slot, hero_id of character_id, controller, uid, hp, mp, x, y, room_code.
## Niet genoemde stoelen worden AI met de rol die ontbreekt.
func assign(rows: Array) -> void:
	for i in MAX_SEATS:
		seats[i] = _blank(i)
	var taken: Array[int] = []
	for raw in rows:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw
		var slot := int(row.get("slot", -1))
		if slot < 0 or slot >= MAX_SEATS or taken.has(slot):
			continue
		var hero := str(row.get("hero_id", row.get("character_id", "")))
		var ctrl := str(row.get("controller", ""))
		if hero == "" and ctrl != CTRL_AI:
			continue
		if ctrl == "":
			ctrl = CTRL_LOCAL if slot == local_slot else CTRL_REMOTE
		_write_seat(slot, hero, ctrl, str(row.get("uid", "")), row)
		taken.append(slot)
	var present: Array = []
	for slot in taken:
		var seat: Dictionary = seats[slot]
		if str(seat["controller"]) != CTRL_AI and str(seat["hero_id"]) != "":
			present.append(str(seat["hero_id"]))
	var empty: Array[int] = []
	for i in MAX_SEATS:
		if not taken.has(i):
			empty.append(i)
	var fill := fill_heroes(present, empty.size())
	for i in fill.size():
		var slot: int = empty[i]
		_write_seat(slot, fill[i], CTRL_AI, "", {})
	_renumber_ai()


func controller_of(slot: int) -> String:
	if slot < 0 or slot >= seats.size():
		return ""
	return str(seats[slot].get("controller", ""))


func hero_of(slot: int) -> String:
	if slot < 0 or slot >= seats.size():
		return ""
	return str(seats[slot].get("hero_id", ""))


func hp_of(slot: int) -> int:
	if slot < 0 or slot >= seats.size():
		return 0
	return int(seats[slot].get("hp", 0))


func mp_of(slot: int) -> int:
	if slot < 0 or slot >= seats.size():
		return 0
	return int(seats[slot].get("mp", 0))


func max_hp_of(slot: int) -> int:
	if slot < 0 or slot >= seats.size():
		return 1
	return maxi(1, int(seats[slot].get("max_hp", 1)))


func pos_of(slot: int) -> Vector2:
	if slot < 0 or slot >= seats.size():
		return Vector2.ZERO
	return Vector2(float(seats[slot].get("x", 0.0)), float(seats[slot].get("y", 0.0)))


func uid_of(slot: int) -> String:
	if slot < 0 or slot >= seats.size():
		return ""
	return str(seats[slot].get("uid", ""))


func reserved_uid(slot: int) -> String:
	if slot < 0 or slot >= seats.size():
		return ""
	return str(seats[slot].get("reserved_uid", ""))


func grace_ticks_of(slot: int) -> int:
	if slot < 0 or slot >= seats.size():
		return 0
	return int(seats[slot].get("grace_ticks", 0))


func drop_reason_of(slot: int) -> String:
	if slot < 0 or slot >= seats.size():
		return ""
	return str(seats[slot].get("drop_reason", ""))


func tracks(slot: int) -> bool:
	return slot >= 0 and slot < seats.size() and bool(seats[slot].get("occupied", false))


func holds(slot: int) -> bool:
	if not tracks(slot):
		return false
	if controller_of(slot) == CTRL_AI:
		return true
	return grace_ticks_of(slot) > 0


func occupied_slots() -> Array[int]:
	var out: Array[int] = []
	for i in seats.size():
		if bool(seats[i].get("occupied", false)):
			out.append(i)
	return out


func ai_slots() -> Array[int]:
	var out: Array[int] = []
	for i in seats.size():
		if bool(seats[i].get("occupied", false)) and controller_of(i) == CTRL_AI:
			out.append(i)
	return out


func human_slots() -> Array[int]:
	var out: Array[int] = []
	for i in seats.size():
		if not bool(seats[i].get("occupied", false)):
			continue
		var ctrl := controller_of(i)
		if ctrl == CTRL_LOCAL or ctrl == CTRL_REMOTE:
			out.append(i)
	return out


func hud_name(slot: int) -> String:
	if controller_of(slot) != CTRL_AI:
		return ""
	var n := 0
	for i in seats.size():
		if bool(seats[i].get("occupied", false)) and controller_of(i) == CTRL_AI:
			n += 1
			if i == slot:
				return "AI %d" % n
	return ""


func hud_rows() -> Array:
	var out: Array = []
	for i in seats.size():
		if not bool(seats[i].get("occupied", false)):
			continue
		var label := hud_name(i)
		if label == "":
			label = _hero_name(hero_of(i))
		out.append({
			"slot": i,
			"name": label,
			"hp": hp_of(i),
			"max_hp": max_hp_of(i),
			"hero_id": hero_of(i),
		})
	return out


func set_hp_mp(slot: int, hp: int, mp: int) -> void:
	if not tracks(slot):
		return
	seats[slot]["hp"] = hp
	seats[slot]["mp"] = mp


func remember_pos(slot: int, pos: Vector2) -> void:
	if not tracks(slot):
		return
	seats[slot]["x"] = pos.x
	seats[slot]["y"] = pos.y


## Gast weg (socket dicht of ping-timeout): dezelfde tick AI, HP/MP/positie blijven.
func guest_lost(slot: int, reason: String) -> bool:
	if not can_take_over(slot):
		return false
	var seat: Dictionary = seats[slot]
	if controller_of(slot) == CTRL_AI and str(seat.get("reserved_uid", "")) != "":
		seat["drop_reason"] = reason
		return true
	var uid := str(seat.get("uid", ""))
	seat["controller"] = CTRL_AI
	seat["reserved_uid"] = uid
	seat["grace_ticks"] = GRACE_TICKS
	seat["drop_reason"] = reason
	_renumber_ai()
	controller_changed.emit(slot, CTRL_AI)
	return true


func can_take_over(slot: int) -> bool:
	if not tracks(slot):
		return false
	var ctrl := controller_of(slot)
	if ctrl == CTRL_LOCAL:
		return false
	if ctrl == CTRL_AI:
		return reserved_uid(slot) != ""
	return ctrl == CTRL_REMOTE


## Zelfde uid + kamer binnen de grace: dezelfde stoel, geen sprong.
func try_rejoin(uid: String, room: String) -> int:
	if uid == "" or room != room_code:
		return -1
	for i in seats.size():
		if reserved_uid(i) != uid or grace_ticks_of(i) <= 0:
			continue
		if controller_of(i) != CTRL_AI:
			continue
		var seat: Dictionary = seats[i]
		seat["controller"] = CTRL_LOCAL if i == local_slot else CTRL_REMOTE
		seat["uid"] = uid
		seat["reserved_uid"] = ""
		seat["grace_ticks"] = 0
		_renumber_ai()
		controller_changed.emit(i, str(seat["controller"]))
		return i
	return -1


## Nieuwe gast pakt een vrije AI-stoel op de volgende tick (niet meteen).
func request_claim(uid: String, _hero_id: String) -> void:
	if uid == "":
		return
	_claims.append(uid)


func begin_tick(dt: float) -> void:
	var n := 1
	if dt <= 0.0:
		n = 0
	elif dt > (1.0 / float(SIM_HZ)) * 1.5:
		n = maxi(1, int(round(dt * float(SIM_HZ))))
	for _i in n:
		begin_tick_one()


func begin_tick_one() -> void:
	tick_i += 1
	for i in seats.size():
		var left := grace_ticks_of(i)
		if left <= 0:
			continue
		left -= 1
		seats[i]["grace_ticks"] = left
		if left == 0:
			seats[i]["reserved_uid"] = ""
	_apply_claims()


func advance_ticks(n: int) -> void:
	for _i in n:
		begin_tick_one()


func advance(seconds: float) -> void:
	advance_ticks(maxi(0, int(round(seconds * float(SIM_HZ)))))


## Host-wegval is het einde van de sessie. Geen stoel wordt AI.
func note_host_lost() -> String:
	return HOST_LOST


static func try_revive(_hp: int) -> bool:
	return false


static func try_role_hook(action: String) -> bool:
	if STUB_ACTIONS.has(action):
		return false
	return false


static func priority_list(role: String, senses: Dictionary) -> Array[String]:
	var has_enemy := bool(senses.get("has_enemy", false))
	var out: Array[String] = []
	match role:
		"tank":
			if bool(senses.get("non_tank_targeted", false)):
				out.append("taunt")
			if bool(senses.get("telegraph", false)):
				out.append("guard")
			out.append("attack" if has_enemy else "follow")
		"heal":
			if bool(senses.get("downed_ally", false)):
				out.append("revive")
			if bool(senses.get("ally_low", false)):
				out.append("heal")
			else:
				out.append("attack" if has_enemy else "follow")
		"control":
			if bool(senses.get("telegraph", false)):
				out.append("interrupt")
			if bool(senses.get("wants_debuff", false)):
				out.append("debuff")
			out.append("attack" if has_enemy else "follow")
		"dps":
			if bool(senses.get("chain_ready", false)):
				out.append("combo")
			elif has_enemy:
				out.append("attack")
			elif bool(senses.get("telegraph", false)):
				out.append("dodge")
			else:
				out.append("follow")
		_:
			out.append("follow")
	return out


## Virtuele speler-input. rng is de seeded arena-RNG; geen globale randf.
static func plan_input(role: String, senses: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var hook := ""
	var action := "follow"
	for step in priority_list(role, senses):
		if STUB_ACTIONS.has(step):
			if hook == "":
				hook = step
			if not try_role_hook(step):
				continue
		action = step
		break
	var self_pos: Vector2 = senses.get("self_pos", Vector2.ZERO)
	var aim := self_pos
	var buttons := 0
	var intent := action
	match action:
		"heal":
			aim = senses.get("heal_pos", senses.get("anchor_pos", self_pos))
		"dodge":
			buttons |= Codec.BTN_DODGE
			var enemy_pos: Vector2 = senses.get("enemy_pos", self_pos)
			var away := self_pos - enemy_pos
			if away.length_squared() < 0.01:
				away = Vector2.UP
			aim = self_pos + away.normalized() * 32.0
		"attack", "combo":
			if bool(senses.get("has_enemy", false)):
				aim = senses.get("enemy_pos", self_pos)
			var ready := bool(senses.get("charge_ready", false)) or action == "combo"
			if bool(senses.get("in_reach", false)) and ready:
				buttons |= Codec.BTN_ATTACK
			if action == "attack" and bool(senses.get("spell_ready", false)) and rng != null:
				if rng.randf() <= SomData.ALLY_DAMAGE_SPELL_CHANCE:
					intent = "damage_spell"
		_:
			var anchor: Vector2 = senses.get("anchor_pos", self_pos)
			var face: Vector2 = senses.get("anchor_facing", Vector2(0, 1))
			aim = formation_around(anchor, face, int(senses.get("slot", 0)))
	var stick := Vector2.ZERO
	var delta := aim - self_pos
	if delta.length() > SomData.ALLY_ARRIVE:
		stick = delta.normalized()
	if stick.length_squared() > 1.0:
		stick = stick.normalized()
	return {
		"stick": stick,
		"buttons": buttons,
		"lock_idx": int(senses.get("lock_idx", -1)),
		"intent": intent,
		"hook": hook,
	}


static func formation_around(anchor: Vector2, facing: Vector2, slot: int) -> Vector2:
	var face := facing
	if face.length_squared() < 0.01:
		face = Vector2(0, 1)
	else:
		face = face.normalized()
	var back := -face
	var side := Vector2(-back.y, back.x)
	var f: Vector2 = SomData.FORMATION[posmod(slot, SomData.FORMATION.size())]
	return anchor + side * f.x + back * f.y


func _apply_claims() -> void:
	if _claims.is_empty():
		return
	var pending: Array = _claims.duplicate()
	_claims.clear()
	for uid in pending:
		var sid := str(uid)
		if sid == "" or _uid_seated(sid):
			continue
		var slot := _open_ai_slot()
		if slot < 0:
			continue
		var seat: Dictionary = seats[slot]
		seat["controller"] = CTRL_LOCAL if slot == local_slot else CTRL_REMOTE
		seat["uid"] = sid
		seat["reserved_uid"] = ""
		seat["grace_ticks"] = 0
		_renumber_ai()
		controller_changed.emit(slot, str(seat["controller"]))


func _open_ai_slot() -> int:
	for i in seats.size():
		if controller_of(i) != CTRL_AI or not bool(seats[i].get("occupied", false)):
			continue
		if reserved_uid(i) != "":
			continue
		return i
	return -1


func _uid_seated(uid: String) -> bool:
	for i in seats.size():
		if uid_of(i) == uid and controller_of(i) != CTRL_AI:
			return true
	return false


func _write_seat(slot: int, hero: String, ctrl: String, uid: String, row: Dictionary) -> void:
	var vit := _base_vitals(hero)
	var hp := int(row.get("hp", -1))
	var mp := int(row.get("mp", -1))
	if hp < 0:
		hp = vit.x
	if mp < 0:
		mp = vit.y
	var placed := row.has("x") and row.has("y")
	var seat: Dictionary = seats[slot]
	seat["occupied"] = true
	seat["hero_id"] = hero
	seat["controller"] = ctrl
	seat["uid"] = uid
	seat["hp"] = hp
	seat["mp"] = mp
	seat["max_hp"] = int(row.get("max_hp", vit.x))
	seat["max_mp"] = int(row.get("max_mp", vit.y))
	seat["x"] = float(row.get("x", slot * 12.0)) if placed or row.has("x") else float(slot * 12)
	seat["y"] = float(row.get("y", 0.0)) if placed or row.has("y") else 0.0
	seat["reserved_uid"] = ""
	seat["grace_ticks"] = 0
	seat["drop_reason"] = ""


func _renumber_ai() -> void:
	var n := 0
	for i in seats.size():
		if bool(seats[i].get("occupied", false)) and controller_of(i) == CTRL_AI:
			n += 1
			seats[i]["ai_index"] = n
		else:
			seats[i]["ai_index"] = 0


func _blank(slot: int) -> Dictionary:
	return {
		"slot": slot,
		"occupied": false,
		"hero_id": "",
		"controller": "",
		"uid": "",
		"hp": 0,
		"mp": 0,
		"max_hp": 1,
		"max_mp": 0,
		"x": 0.0,
		"y": 0.0,
		"reserved_uid": "",
		"grace_ticks": 0,
		"drop_reason": "",
		"ai_index": 0,
	}


static func _base_vitals(hero_id: String) -> Vector2i:
	for h in GameData.HEROES:
		if str(h.get("id", "")) == hero_id:
			return Vector2i(int(h.get("max_hp", 1)), int(h.get("max_mp", 0)))
	return Vector2i(1, 0)


static func _hero_name(hero_id: String) -> String:
	for h in GameData.HEROES:
		if str(h.get("id", "")) == hero_id:
			return str(h.get("name", hero_id))
	return hero_id
