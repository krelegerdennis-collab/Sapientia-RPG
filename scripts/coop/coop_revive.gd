class_name CoopRevive
extends RefCounted
## Down, revive en wipe voor online co-op (design §7.4, COMBAT_DESIGN D6).
## Alleen de host tikt dit, op SIM_HZ. Geen wandklok, geen globale rand.
## Solo/Classic roept deze klasse niet aan.
##
## VOORSTEL (open punten §7.4, nog geen akkoord van Dennis):
## - BLEED_END_STAY_DOWN: bleed op 0 laat de stoel liggen tot wipe of rustpunt.
##   Geen permadeath midden in de run.
## - Elke levende menselijke stoel mag reviven door binnen RANGE_PX te blijven.
## - AI: Heal (base_hero "lotte") heeft revive als prioriteit 1.
##   Andere AI-rollen reviven alleen als er geen levende Heal-stoel is.
##
## Kanaal breekt (keuze, bewust): voortgang valt terug naar 0, niet op pauze,
## als de helper verder dan 1 tegel staat, zelf down gaat, of geraakt wordt
## (hit_seq omhoog). Een ander doel kiest de teller ook opnieuw. Stilstaan is
## niet verplicht: binnen 1 tegel blijven telt, ook als de stick nog beweegt.
## De Feniksveer gaat via phoenix() meteen, met de bestaande item-fractie.
##
## Eén revive per stoel per run (besluit Dennis). Het getal `revives` staat
## alleen op het stoel-record dat de host tikt. Geen tweede lijst, niet in de
## snapshot. begin_run() zet het terug op 0. Een stoel die al een keer is
## opgestaan en weer valt, blijft liggen: query_revive wijst haar niet aan,
## dus het kanaal en de ring starten niet. AI gebruikt dezelfde query.
##
## Haak voor M6 (seat_controller.gd). Die file bouwt deze klasse niet.
## De controller vraagt query_revive (welke down-stoel ligt binnen bereik en
## mag ik die reviven) en roept daarna begin_channel of end_channel.
## De host telt het kanaal in step(). Mensen starten vanzelf door nabijheid.
## Een AI-stoel start niet vanzelf: zonder begin_channel blijft de teller 0.
## Zolang seat_controller.gd ontbreekt, doet SomAlly die twee calls zelf
## (alleen als allies_enabled aan staat). Zodra het bestand er is, stopt SomAlly.

const Protocol := preload("res://scripts/net/net_protocol.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const PartyActions := preload("res://scripts/party_actions.gd")
const Seat := preload("res://scripts/coop/coop_seat.gd")

const HEAL_HERO := "lotte"
const RESULT_WIPE := "wipe"

## Zelfde klok als NetProtocol.SIM_HZ. De test eist dat die 60 blijft.
const SIM_HZ := 60
const CHANNEL_SEC := 2.0
const CHANNEL_HEAL_SEC := 1.2
const CHANNEL_TICKS := 120
const CHANNEL_HEAL_TICKS := 72
const HP_PERCENT := 30
const RANGE_PX := 16
const BLEED_SEC := 15.0
const BLEED_TICKS := 900
## D6: 1 s i-frames na een kanaal-revive. Niet de solo PLAYER_IFRAMES.
const IFRAME_TICKS := 60
## Eén geslaagde revive (kanaal of Feniksveer) per stoel per run.
const REVIVES_PER_RUN := 1

## VOORSTEL: bleed afgelopen -> blijven liggen.
const BLEED_END_STAY_DOWN := true
## VOORSTEL: andere AI revivet alleen zonder levende Heal.
const AI_OTHERS_ONLY_WITHOUT_HEAL := true

## Eenmalig, hergebruikt door write_flags en query_revive (geen allocatie per tick).
static var _incoming: Array = [0, 0, 0, 0]
static var _query: Dictionary = {"ok": false, "slot": -1, "x": 0, "y": 0, "ticks_need": 0}
static var _seat_hook: int = -1


static func channel_ticks_for(hero_id: String) -> int:
	return CHANNEL_HEAL_TICKS if hero_id == HEAL_HERO else CHANNEL_TICKS


static func revive_hp(max_hp: int) -> int:
	return maxi(1, roundi(float(maxi(1, max_hp)) * (float(HP_PERCENT) / 100.0)))


static func revives_used(row: Dictionary) -> int:
	return int(row.get("revives", 0))


static func can_be_revived(row: Dictionary) -> bool:
	return revives_used(row) < REVIVES_PER_RUN


## Nieuwe run: de enige plek die de teller wist. De host roept dit aan bij reset.
static func begin_run(rows: Array) -> void:
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		row["revives"] = 0


static func _spend_revive(row: Dictionary) -> bool:
	if not can_be_revived(row):
		return false
	row["revives"] = revives_used(row) + 1
	return true


static func hero_of(row: Dictionary) -> String:
	var base := str(row.get("base_hero", ""))
	if base != "":
		return base
	var cid := str(row.get("character_id", ""))
	if cid != "":
		return cid
	return str(row.get("hero_id", ""))


static func is_heal_hero(hero_id: String) -> bool:
	return hero_id == HEAL_HERO


static func row_active(row: Dictionary) -> bool:
	return bool(row.get("active", false)) and bool(row.get("participate", true))


static func row_down(row: Dictionary) -> bool:
	return bool(row.get("down", false))


static func row_alive(row: Dictionary) -> bool:
	return row_active(row) and not row_down(row) and int(row.get("hp", 0)) > 0


static func heal_seat_alive(rows: Array) -> bool:
	for row in rows:
		if row_alive(row) and is_heal_hero(hero_of(row)):
			return true
	return false


static func any_down(rows: Array) -> bool:
	for row in rows:
		if row_active(row) and row_down(row):
			return true
	return false


static func ai_should_revive(hero_id: String, heal_alive: bool, someone_down: bool) -> bool:
	if not someone_down:
		return false
	if is_heal_hero(hero_id):
		return true
	if AI_OTHERS_ONLY_WITHOUT_HEAL:
		return not heal_alive
	return true


## True zodra M6 scripts/coop/seat_controller.gd heeft toegevoegd.
## SomAlly doet de haak zelf tot dat bestand er is, en stopt dan.
static func seat_controller_present() -> bool:
	if _seat_hook < 0:
		_seat_hook = 1 if ResourceLoader.exists("res://scripts/coop/seat_controller.gd") else 0
	return _seat_hook == 1


## Welke down-stoel ligt binnen bereik en mag deze helper reviven?
## Het teruggegeven record wordt hergebruikt; meteen uitlezen.
## ok=false en slot=-1 als het niet mag of niemand binnen 1 tegel ligt.
static func query_revive(rows: Array, helper: Dictionary) -> Dictionary:
	_query["ok"] = false
	_query["slot"] = -1
	_query["x"] = 0
	_query["y"] = 0
	_query["ticks_need"] = channel_ticks_for(hero_of(helper))
	if not row_alive(helper):
		return _query
	var down := any_down(rows)
	if not down or not _may_channel(helper, heal_seat_alive(rows), down):
		return _query
	var target := _nearest_in_range(rows, int(helper.get("slot", -1)), int(helper.get("x", 0)), int(helper.get("y", 0)))
	if target.is_empty():
		return _query
	_query["ok"] = true
	_query["slot"] = int(target.get("slot", -1))
	_query["x"] = int(target.get("x", 0))
	_query["y"] = int(target.get("y", 0))
	return _query


## Start of herneem een kanaal op target_slot. Alleen als query_revive dat doel wijst.
static func begin_channel(rows: Array, helper: Dictionary, target_slot: int) -> bool:
	var q := query_revive(rows, helper)
	if not bool(q.get("ok", false)) or int(q.get("slot", -1)) != target_slot:
		return false
	if int(helper.get("channel_target", -1)) != target_slot:
		helper["channel_ticks"] = 0
		helper["channel_target"] = target_slot
		helper["channel_seen"] = int(helper.get("hit_seq", 0))
	return true


static func end_channel(helper: Dictionary) -> void:
	helper["channel_ticks"] = 0
	helper["channel_target"] = -1


static func in_range(ax: int, ay: int, bx: int, by: int) -> bool:
	var dx := ax - bx
	var dy := ay - by
	return dx * dx + dy * dy <= RANGE_PX * RANGE_PX


static func nearest_down_row(rows: Array, from: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d := 0x7FFFFFFF
	var best_slot := 999
	var fx := int(round(from.x))
	var fy := int(round(from.y))
	for row in rows:
		if not row_active(row) or not row_down(row) or not can_be_revived(row):
			continue
		var dx := fx - int(row.get("x", 0))
		var dy := fy - int(row.get("y", 0))
		var d := dx * dx + dy * dy
		var slot := int(row.get("slot", 0))
		if d < best_d or (d == best_d and slot < best_slot):
			best_d = d
			best_slot = slot
			best = row
	return best


static func enter_down(row: Dictionary) -> void:
	row["down"] = true
	row["hp"] = 0
	row["bleed_ticks"] = BLEED_TICKS
	row["bleed_expired"] = false
	row["channel_ticks"] = 0
	row["channel_target"] = -1
	row["iframes"] = 0


static func clear_down(row: Dictionary) -> void:
	row["down"] = false
	row["bleed_ticks"] = 0
	row["bleed_expired"] = false
	row["channel_ticks"] = 0
	row["channel_target"] = -1


## Eén host-tick. Geeft true zolang elke meewerkende stoel down is.
## already_wiped: de run is al voorbij; er wordt niet meer gerevived.
static func step(rows: Array, already_wiped: bool) -> bool:
	for row in rows:
		if not row_active(row):
			continue
		var ifr := int(row.get("iframes", 0))
		if ifr > 0:
			row["iframes"] = ifr - 1
		if int(row.get("hp", 0)) <= 0 and not row_down(row):
			enter_down(row)
		elif row_down(row) and int(row.get("hp", 0)) > 0:
			clear_down(row)
		if row_down(row):
			var bleed := int(row.get("bleed_ticks", 0))
			if bleed > 0:
				bleed -= 1
				row["bleed_ticks"] = bleed
			if bleed <= 0 and not bool(row.get("bleed_expired", false)):
				row["bleed_expired"] = true
				if not BLEED_END_STAY_DOWN:
					row["hp"] = 0
	if not already_wiped:
		_channel(rows)
	return everyone_down(rows)


static func everyone_down(rows: Array) -> bool:
	var any := false
	for row in rows:
		if not row_active(row):
			continue
		any = true
		if not row_down(row):
			return false
	return any


static func _channel(rows: Array) -> void:
	for row in rows:
		if not row_alive(row):
			end_channel(row)
			continue
		var q := query_revive(rows, row)
		var ok := bool(q.get("ok", false))
		var slot := int(q.get("slot", -1))
		if is_ai_controller(row):
			# AI start niet zelf. seat_controller (M6) of SomAlly riep begin_channel.
			var open := int(row.get("channel_target", -1))
			if open < 0 or not ok or slot != open:
				end_channel(row)
				continue
		else:
			if not ok:
				end_channel(row)
				continue
			if int(row.get("channel_target", -1)) != slot:
				row["channel_ticks"] = 0
				row["channel_target"] = slot
				row["channel_seen"] = int(row.get("hit_seq", 0))
		if int(row.get("hit_seq", 0)) != int(row.get("channel_seen", 0)):
			row["channel_ticks"] = 0
			row["channel_seen"] = int(row.get("hit_seq", 0))
			continue
		var ticks := int(row.get("channel_ticks", 0)) + 1
		row["channel_ticks"] = ticks
		if ticks >= channel_ticks_for(hero_of(row)):
			var target := _by_slot(rows, int(row.get("channel_target", -1)))
			if not target.is_empty():
				_finish_channel(row, target)


static func is_ai_controller(row: Dictionary) -> bool:
	var c := str(row.get("controller", Seat.CONTROLLER_HUMAN))
	return c == Seat.CONTROLLER_AI or c == Seat.CONTROLLER_ALLY


static func _may_channel(row: Dictionary, heal_alive: bool, someone_down: bool) -> bool:
	if not is_ai_controller(row):
		return true
	return ai_should_revive(hero_of(row), heal_alive, someone_down)


static func _nearest_in_range(rows: Array, helper_slot: int, hx: int, hy: int) -> Dictionary:
	var best: Dictionary = {}
	var best_d := RANGE_PX * RANGE_PX + 1
	var best_slot := 999
	for row in rows:
		if int(row.get("slot", -2)) == helper_slot or not row_active(row) or not row_down(row):
			continue
		if not can_be_revived(row):
			continue
		var dx := hx - int(row.get("x", 0))
		var dy := hy - int(row.get("y", 0))
		var d := dx * dx + dy * dy
		if d > RANGE_PX * RANGE_PX:
			continue
		var slot := int(row.get("slot", 0))
		if d < best_d or (d == best_d and slot < best_slot):
			best_d = d
			best_slot = slot
			best = row
	return best


static func _finish_channel(helper: Dictionary, target: Dictionary) -> void:
	helper["channel_ticks"] = 0
	helper["channel_target"] = -1
	if not row_down(target) or not _spend_revive(target):
		return
	target["hp"] = revive_hp(int(target.get("max_hp", 1)))
	target["iframes"] = IFRAME_TICKS
	clear_down(target)


## Feniksveer: meteen, fractie uit game_data (nu 0.5). Geen kanaal.
static func phoenix(rows: Array, helper_slot: int, target_slot: int) -> bool:
	var helper := _by_slot(rows, helper_slot)
	var target := _by_slot(rows, target_slot)
	if helper.is_empty() or target.is_empty():
		return false
	if not row_alive(helper) or not row_down(target) or not can_be_revived(target):
		return false
	var frac := float(GameData.ITEMS.get("feniksveer", {}).get("revive", 0.0))
	if frac <= 0.0:
		return false
	var hero := {"max_hp": int(target.get("max_hp", 1)), "hp": 0, "name": "Ally"}
	if not _spend_revive(target):
		return false
	var hp := PartyActions.revive(hero, frac)
	target["hp"] = hp
	target["iframes"] = IFRAME_TICKS
	clear_down(target)
	return true


## Rustpunt: down-stoelen staan op, volle HP. Levende stoelen blijven zoals ze zijn.
static func apply_rest(rows: Array) -> void:
	for row in rows:
		if not row_active(row) or not row_down(row):
			continue
		row["hp"] = maxi(1, int(row.get("max_hp", 1)))
		clear_down(row)


static func _by_slot(rows: Array, slot: int) -> Dictionary:
	for row in rows:
		if int(row.get("slot", -2)) == slot:
			return row
	return {}


static func progress_pct(ticks: int, need: int) -> int:
	if need <= 0 or ticks <= 0:
		return 0
	return clampi((ticks * 100) / need, 0, 100)


## Lage byte: ring/attack blijven staan. DOWN, CHANNEL en BLEED_DONE worden gezet.
## Hoge byte: voortgang 0..100 op de liggende stoel, zodat een gast de boog tekent.
static func write_flags(rows: Array) -> void:
	_incoming[0] = 0
	_incoming[1] = 0
	_incoming[2] = 0
	_incoming[3] = 0
	for row in rows:
		if not row_active(row) or row_down(row):
			continue
		var tgt := int(row.get("channel_target", -1))
		if tgt < 0 or tgt > 3:
			continue
		var pct := progress_pct(int(row.get("channel_ticks", 0)), channel_ticks_for(hero_of(row)))
		if pct > int(_incoming[tgt]):
			_incoming[tgt] = pct
	for row in rows:
		var low := int(row.get("flags", 0)) & 0xFF
		low &= ~(Protocol.FLAG_DOWN | Protocol.FLAG_CHANNEL | Protocol.FLAG_BLEED_DONE)
		if row_down(row):
			low |= Protocol.FLAG_DOWN
		if int(row.get("channel_ticks", 0)) > 0 and not row_down(row):
			low |= Protocol.FLAG_CHANNEL
		if bool(row.get("bleed_expired", false)):
			low |= Protocol.FLAG_BLEED_DONE
		var slot := int(row.get("slot", 0))
		var pct := 0
		if row_down(row) and slot >= 0 and slot < 4:
			pct = int(_incoming[slot])
		row["flags"] = low | ((pct & 0xFF) << 8)


static func flag_is_down(flags: int) -> bool:
	return (flags & Protocol.FLAG_DOWN) != 0


static func flag_progress(flags: int) -> int:
	return (flags >> 8) & 0xFF
