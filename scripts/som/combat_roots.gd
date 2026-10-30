class_name CombatRoots
extends RefCounted
## Wortelgreep-status (Combat T6). Host-tick op 60 Hz; gast spiegelt snapshot-trailer.
## rooted[id] = ticks (max 60, niet stapelbaar = max), daarna immune[id] = 90 ticks.

const MAX_ROOT_TICKS := 60
const IMMUNITY_TICKS := 90

var _rooted: Dictionary = {}
var _immune: Dictionary = {}


func clear_all() -> void:
	_rooted.clear()
	immune_clear()


func immune_clear() -> void:
	_immune.clear()


func clear_member(id: String) -> void:
	if id == "":
		return
	_rooted.erase(id)
	_immune.erase(id)


func ticks_rooted(id: String) -> int:
	return int(_rooted.get(id, 0))


func ticks_immune(id: String) -> int:
	return int(_immune.get(id, 0))


func is_rooted(id: String) -> bool:
	return ticks_rooted(id) > 0


func blocks_movement(id: String) -> bool:
	return is_rooted(id)


## Alleen na een echte klap (geen iframes); false bij immuniteit of lege id.
func try_apply_root(id: String, ticks: int = MAX_ROOT_TICKS) -> bool:
	if id == "":
		return false
	if ticks_immune(id) > 0:
		return false
	var want := clampi(ticks, 1, MAX_ROOT_TICKS)
	var cur := ticks_rooted(id)
	if cur >= want:
		return cur > 0
	_rooted[id] = maxi(cur, want)
	return true


## Dodge-hook (stap 5): beëindigt root en start immuniteit.
func break_root(id: String) -> void:
	if id == "" or not is_rooted(id):
		return
	_rooted.erase(id)
	_immune[id] = IMMUNITY_TICKS


func tick() -> void:
	var ended: Array = []
	for id in _rooted.keys():
		var left := int(_rooted[id]) - 1
		if left <= 0:
			_rooted.erase(id)
			ended.append(id)
		else:
			_rooted[id] = left
	for id in _immune.keys():
		var left := int(_immune[id]) - 1
		if left <= 0:
			_immune.erase(id)
		else:
			_immune[id] = left
	for id in ended:
		_immune[id] = IMMUNITY_TICKS


func rooted_ids() -> Array:
	return _rooted.keys()


func wire_rows(slots: Dictionary) -> Array:
	var out: Array = []
	for slot in slots.keys():
		var hid := str(slots[slot])
		if hid == "":
			continue
		var r := ticks_rooted(hid)
		var im := ticks_immune(hid)
		if r <= 0 and im <= 0:
			continue
		out.append({
			"slot": int(slot),
			"root_ticks": clampi(r, 0, 255),
			"immune_ticks": clampi(im, 0, 255),
		})
	return out


func apply_wire_rows(rows: Array, slots: Dictionary) -> void:
	_rooted.clear()
	_immune.clear()
	for row in rows:
		var slot := int(row.get("slot", Protocol.NO_SLOT))
		if slot < 0:
			continue
		var hid := str(slots.get(slot, ""))
		if hid == "":
			continue
		var r := int(row.get("root_ticks", 0))
		var im := int(row.get("immune_ticks", 0))
		if r > 0:
			_rooted[hid] = clampi(r, 1, MAX_ROOT_TICKS)
		if im > 0:
			_immune[hid] = clampi(im, 1, IMMUNITY_TICKS)


const Protocol := preload("res://scripts/net/net_protocol.gd")
