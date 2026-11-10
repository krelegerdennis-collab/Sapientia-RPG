class_name OnlineReward
extends RefCounted
## M8b — run-resultaat en reward-bundle (design-doc §5.1, §7.5, §9).
##
## Puur: geen bestand, geen NetProtocol.VERSION, geen solo-save.
## Na een online run blijft alleen rang + cosmetica (DECISION). De bundle heeft
## geen stats en geen items. Run-goud en run-EXP zitten in RUN_RESULT (tijdelijk)
## en gaan niet mee naar het profiel.
##
## Gewichten zijn een balans-VOORSTEL (§7.0): Easy 1, Normal 1,5, Hard 2.
## Geen akkoord van Dennis; niet gebruikt door de solo-DLS.
##
## --- Haak voor M1 (online profiel, nog niet op coop/easy) ---
## M1 bezit user://online_profile.json (laden, schrijven, export). Deze module
## schrijft dat bestand niet. Na een ontvangen bundle:
##   var next := OnlineReward.apply_bundle(profile, bundle)
##   # next is een nieuw dict; profile blijft onaangeroerd
##   # schrijf next alleen als de grant-sleutel nieuw was
## Sleutel in slot.applied_grants: grant_key(session_id, host_tick)
##   formaat "<session_id>+<host_tick>"  (stoel zit er niet in; het profiel is van één speler)
## Slotkeuze: slot.uid == bundle.seat_uid. Geen slot = no-op.
## Tweede apply met dezelfde sleutel = no-op (het dict is gelijk aan de eerste uitkomst).
## profile_exp is een float (Normal × 1,5). M1 moet het getal niet naar int afronden.
## stats_seen.best_floor = max(oud, bundle.best_floor). stats_seen.runs laat M1 zelf.
##
## --- Haak voor M3 (protocol v2, nog niet op coop/easy) ---
## VERSION blijft 1 tot M3 hem zelf verhoogt. Nieuwe kinds horen in NetProtocol.Kind:
##   RUN_RESULT, REWARD_BUNDLE
## Body (Dictionary, geen extra sleutels):
##   run_result_body(result)     — zie make_run_result
##   reward_bundle_body(bundle)  — zie make_bundle
## Verzenden pas als VERSION 2 bestaat:
##   NetProtocol.encode(Kind.RUN_RESULT, OnlineReward.run_result_body(result))
## Tot die tijd is encode_payload / decode_payload een los kanaal ("online-reward").
## NetProtocol.decode weigert dat pakket (kind is een string, v1 kent de kinds niet).
## Relay-plafond: 2048 bytes (relay/src/config.js maxMessageBytes).
## encode_run_results stuurt één pakket als het past, anders één RUN_RESULT per stoel.
## M3 verstuurt die array op volgorde; merge_run_results zet ze terug. De body-vorm
## blijft hetzelfde. Dit wijzigt NetProtocol.VERSION niet.

const GAME_ID := "sapientia-coop"
const CHANNEL := "online-reward"
const KIND_RUN_RESULT := "RUN_RESULT"
const KIND_REWARD_BUNDLE := "REWARD_BUNDLE"
## FACT relay/src/config.js DEFAULTS.maxMessageBytes.
const RELAY_MAX_BYTES := 2048

## DECISION §7.0: lengte van de modus. Geen solo-curve.
const FLOORS_EASY := 10
const FLOORS_NORMAL := 50
const FLOORS_HARD := 100

## PROPOSAL §7.0 / §7.5. Balans, nog niet goedgekeurd.
const WEIGHT_EASY := 1.0
const WEIGHT_NORMAL := 1.5
const WEIGHT_HARD := 2.0

## Alleen ids. Geen weergavenaam en geen lore (RPG ART en Dennis leveren die).
const UNLOCK_EASY := "cos_ph_easy"
const UNLOCK_NORMAL := "cos_ph_normal"
const UNLOCK_HARD := "cos_ph_hard"

const MODE_EASY := "easy"
const MODE_NORMAL := "normal"
const MODE_HARD := "hard"

const BUNDLE_KEYS: Array[String] = [
	"session_id", "host_tick", "seat_uid", "profile_exp", "best_floor", "unlocks",
]
const RESULT_KEYS: Array[String] = ["session_id", "host_tick", "mode", "seed", "seats"]
const SEAT_KEYS: Array[String] = [
	"seat_uid", "floors", "best_floor", "kills", "revives", "downs", "loot",
]
const LOOT_KEYS: Array[String] = ["gold", "exp", "items"]


static func floors_for_mode(mode: String) -> int:
	match mode:
		MODE_EASY:
			return FLOORS_EASY
		MODE_NORMAL:
			return FLOORS_NORMAL
		MODE_HARD:
			return FLOORS_HARD
		_:
			return 0


static func weight_for_mode(mode: String) -> float:
	match mode:
		MODE_EASY:
			return WEIGHT_EASY
		MODE_NORMAL:
			return WEIGHT_NORMAL
		MODE_HARD:
			return WEIGHT_HARD
		_:
			return 0.0


## Eén placeholder-id bij een voltooide modus, anders "".
static func unlock_for_mode(mode: String) -> String:
	match mode:
		MODE_EASY:
			return UNLOCK_EASY
		MODE_NORMAL:
			return UNLOCK_NORMAL
		MODE_HARD:
			return UNLOCK_HARD
		_:
			return ""


## Verslagen verdiepingen × modusgewicht. Onbekende modus (ook Classic) = 0.
static func profile_exp_for(floors_cleared: int, mode: String) -> float:
	if floors_cleared <= 0:
		return 0.0
	return float(floors_cleared) * weight_for_mode(mode)


static func grant_key(session_id: String, host_tick: int) -> String:
	return "%s+%d" % [session_id, host_tick]


## seats: rapporten uit OnlineLoot.reports() (of hetzelfde dict-formaat).
static func make_run_result(session_id: String, host_tick: int, mode: String, seed_value: int, seats: Array) -> Dictionary:
	var norm: Array = []
	for s in seats:
		if s is Dictionary:
			norm.append(_norm_seat(s))
	norm.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["seat_uid"]) < str(b["seat_uid"]))
	return {
		"session_id": session_id,
		"host_tick": host_tick,
		"mode": mode,
		"seed": seed_value,
		"seats": norm,
	}


static func make_bundle(session_id: String, host_tick: int, mode: String, seat: Dictionary) -> Dictionary:
	var floors := int(seat.get("floors", 0))
	var best := int(seat.get("best_floor", floors))
	var unlocks: Array = []
	var need := floors_for_mode(mode)
	var unlock := unlock_for_mode(mode)
	if need > 0 and floors >= need and unlock != "":
		unlocks.append(unlock)
	return {
		"session_id": session_id,
		"host_tick": host_tick,
		"seat_uid": str(seat.get("seat_uid", "")),
		"profile_exp": profile_exp_for(floors, mode),
		"best_floor": best,
		"unlocks": unlocks,
	}


static func bundles_for(result: Dictionary) -> Array:
	var out: Array = []
	var seats_v: Variant = result.get("seats", [])
	if not (seats_v is Array):
		return out
	for seat in seats_v:
		if seat is Dictionary:
			out.append(make_bundle(
				str(result.get("session_id", "")),
				int(result.get("host_tick", 0)),
				str(result.get("mode", "")),
				seat,
			))
	return out


## Alleen de zes beloningsvelden. Een item, een stat of een losse sleutel = false.
static func bundle_clean(bundle: Dictionary) -> bool:
	for k in bundle.keys():
		if not BUNDLE_KEYS.has(str(k)):
			return false
	for key in BUNDLE_KEYS:
		if not bundle.has(key):
			return false
	if typeof(bundle["unlocks"]) != TYPE_ARRAY:
		return false
	for u in bundle["unlocks"]:
		if typeof(u) != TYPE_STRING and typeof(u) != TYPE_STRING_NAME:
			return false
		if not _unlock_id_ok(str(u)):
			return false
	if str(bundle["session_id"]) == "" or str(bundle["seat_uid"]) == "":
		return false
	if int(bundle["host_tick"]) < 0 or int(bundle["best_floor"]) < 0:
		return false
	if float(bundle["profile_exp"]) < 0.0:
		return false
	return true


## Pure apply. profile en bundle blijven onaangeroerd. Geen bestand.
## Tweede keer met dezelfde grant-sleutel: zelfde inhoud als de eerste uitkomst.
static func apply_bundle(profile: Dictionary, bundle: Dictionary) -> Dictionary:
	var out := profile.duplicate(true)
	if not bundle_clean(bundle):
		return out
	var slots_v: Variant = out.get("slots", [])
	if not (slots_v is Array):
		return out
	var slots: Array = slots_v
	var uid := str(bundle["seat_uid"])
	var idx := -1
	for i in slots.size():
		var raw: Variant = slots[i]
		if raw is Dictionary and str((raw as Dictionary).get("uid", "")) == uid:
			idx = i
			break
	if idx < 0:
		return out
	var slot: Dictionary = slots[idx]
	var key := grant_key(str(bundle["session_id"]), int(bundle["host_tick"]))
	var grants_v: Variant = slot.get("applied_grants", [])
	var grants: Array = (grants_v as Array).duplicate() if grants_v is Array else []
	if grants.has(key):
		return out
	slot["profile_exp"] = float(slot.get("profile_exp", 0)) + float(bundle["profile_exp"])
	var seen_v: Variant = slot.get("stats_seen", {})
	var seen: Dictionary = (seen_v as Dictionary).duplicate(true) if seen_v is Dictionary else {}
	seen["best_floor"] = maxi(int(seen.get("best_floor", 0)), int(bundle["best_floor"]))
	slot["stats_seen"] = seen
	var un_v: Variant = slot.get("unlocks", [])
	var unlocks: Array = (un_v as Array).duplicate() if un_v is Array else []
	for u in bundle["unlocks"]:
		var id := str(u)
		if not unlocks.has(id):
			unlocks.append(id)
	slot["unlocks"] = unlocks
	grants.append(key)
	slot["applied_grants"] = grants
	slots[idx] = slot
	out["slots"] = slots
	return out


static func run_result_body(result: Dictionary) -> Dictionary:
	var seats_v: Variant = result.get("seats", [])
	var seats: Array = seats_v if seats_v is Array else []
	return make_run_result(
		str(result.get("session_id", "")),
		int(result.get("host_tick", 0)),
		str(result.get("mode", "")),
		int(result.get("seed", 0)),
		seats,
	)


static func reward_bundle_body(bundle: Dictionary) -> Dictionary:
	return {
		"session_id": str(bundle.get("session_id", "")),
		"host_tick": int(bundle.get("host_tick", 0)),
		"seat_uid": str(bundle.get("seat_uid", "")),
		"profile_exp": float(bundle.get("profile_exp", 0.0)),
		"best_floor": int(bundle.get("best_floor", 0)),
		"unlocks": _norm_unlocks(bundle.get("unlocks", [])),
	}


static func encode_payload(kind: String, body: Dictionary) -> PackedByteArray:
	return JSON.stringify({
		"game": GAME_ID,
		"channel": CHANNEL,
		"kind": kind,
		"body": body,
	}).to_utf8_buffer()


## Eén pakket als het geheel onder het relay-plafond past. Anders één RUN_RESULT per stoel
## (zelfde velden, seats heeft dan lengte 1). M3 stuurt ze op volgorde; merge_run_results
## zet ze weer aan elkaar. Een losse stoel met de hele kist-tabel blijft onder 2048.
static func encode_run_results(result: Dictionary) -> Array:
	var body := run_result_body(result)
	var whole := encode_payload(KIND_RUN_RESULT, body)
	if whole.size() <= RELAY_MAX_BYTES:
		return [whole]
	var out: Array = []
	var seats: Array = body["seats"]
	for seat in seats:
		var part := make_run_result(
			str(body["session_id"]), int(body["host_tick"]), str(body["mode"]), int(body["seed"]), [seat])
		out.append(encode_payload(KIND_RUN_RESULT, part))
	return out


## Gedecodeerde RUN_RESULT-bodies (één of per stoel) terug naar één resultaat.
static func merge_run_results(parts: Array) -> Dictionary:
	var session_id := ""
	var host_tick := 0
	var mode := ""
	var seed_value := 0
	var seats: Array = []
	for part in parts:
		if not (part is Dictionary):
			continue
		session_id = str(part.get("session_id", session_id))
		host_tick = int(part.get("host_tick", host_tick))
		mode = str(part.get("mode", mode))
		seed_value = int(part.get("seed", seed_value))
		var seats_v: Variant = part.get("seats", [])
		if seats_v is Array:
			for seat in seats_v:
				if seat is Dictionary:
					seats.append(seat)
	return make_run_result(session_id, host_tick, mode, seed_value, seats)


## {ok, kind, body}. Te groot voor de relay, of een vreemd kanaal: ok = false.
static func decode_payload(raw: PackedByteArray) -> Dictionary:
	var fail := {"ok": false, "kind": "", "body": {}}
	if raw.is_empty() or raw.size() > RELAY_MAX_BYTES:
		return fail
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not (parsed is Dictionary):
		return fail
	var data: Dictionary = parsed
	if str(data.get("game", "")) != GAME_ID or str(data.get("channel", "")) != CHANNEL:
		return fail
	var kind := str(data.get("kind", ""))
	var body_v: Variant = data.get("body", {})
	if not (body_v is Dictionary):
		return fail
	var body: Dictionary = body_v
	if kind == KIND_RUN_RESULT:
		if not _result_shape_ok(body):
			return fail
		return {"ok": true, "kind": kind, "body": run_result_body(body)}
	if kind == KIND_REWARD_BUNDLE:
		if not bundle_clean(body):
			return fail
		return {"ok": true, "kind": kind, "body": reward_bundle_body(body)}
	return fail


static func _norm_seat(seat: Dictionary) -> Dictionary:
	var loot_v: Variant = seat.get("loot", {})
	var loot: Dictionary = loot_v if loot_v is Dictionary else {}
	return {
		"seat_uid": str(seat.get("seat_uid", "")),
		"floors": int(seat.get("floors", 0)),
		"best_floor": int(seat.get("best_floor", 0)),
		"kills": int(seat.get("kills", 0)),
		"revives": int(seat.get("revives", 0)),
		"downs": int(seat.get("downs", 0)),
		"loot": {
			"gold": int(loot.get("gold", 0)),
			"exp": int(loot.get("exp", 0)),
			"items": _norm_items(loot.get("items", [])),
		},
	}


static func _norm_items(items: Variant) -> Array:
	var out: Array = []
	if not (items is Array):
		return out
	for it in items:
		if not (it is Dictionary):
			continue
		var id := str(it.get("item", ""))
		if id == "":
			continue
		out.append({"item": id, "n": int(it.get("n", 1))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["item"]) < str(b["item"]))
	return out


static func _norm_unlocks(raw: Variant) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	for u in raw:
		if typeof(u) != TYPE_STRING and typeof(u) != TYPE_STRING_NAME:
			continue
		var id := str(u)
		if _unlock_id_ok(id) and not out.has(id):
			out.append(id)
	return out


static func _unlock_id_ok(id: String) -> bool:
	if id == "" or id.length() > 32:
		return false
	for i in id.length():
		var c := id.unicode_at(i)
		var ok := (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95
		if not ok:
			return false
	return true


static func _keys_exact(data: Dictionary, allowed: Array) -> bool:
	if data.size() != allowed.size():
		return false
	for k in data.keys():
		if not allowed.has(str(k)):
			return false
	return true


static func _result_shape_ok(body: Dictionary) -> bool:
	if not _keys_exact(body, RESULT_KEYS):
		return false
	var seats_v: Variant = body["seats"]
	if not (seats_v is Array):
		return false
	for seat in seats_v:
		if not (seat is Dictionary):
			return false
		if not _keys_exact(seat, SEAT_KEYS):
			return false
		var loot_v: Variant = seat["loot"]
		if not (loot_v is Dictionary) or not _keys_exact(loot_v, LOOT_KEYS):
			return false
		if not (loot_v["items"] is Array):
			return false
	return true
