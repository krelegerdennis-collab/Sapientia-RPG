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
## --- Haak voor M1 (online profiel, PR #417, schema ongewijzigd) ---
## M1 bezit user://online_profile.json. Deze module schrijft dat bestand niet en
## voegt geen veld toe. Schema blijft: uid, name, class, look, profile_exp,
## unlocks, stats_seen, applied_grants. Geen sessie, tick, epoch of pending erin.
##
## Client (één instantie per proces; de runtime-set zit alleen in het geheugen):
##   var next := rewards.apply_bundle(profile, bundle)
##   # next = {status, grant_key, profile}; het invoerdict blijft onaangeroerd
##   # status "applied":  sla next.profile op, stuur daarna ACK(grant_key)
##   # status "duplicate": profiel ongewijzigd (0 extra), stuur óók ACK(grant_key)
##   # status "rejected": geen ACK (bundle ongeldig of geen slot)
## Apply telt als de sleutel niet in slot.applied_grants staat en niet in de
## runtime-set van deze instantie. Een andere session_id is geen weigering:
## na kill, crash of rejoin past een resend gewoon als de grant nieuw is.
## Nieuwe instantie = lege runtime-set. Staat de sleutel al in het opgeslagen
## profiel, dan is de resend duplicate en 0 extra.
##
## Grant-sleutel (max 8 in het profiel, FIFO, hash heeft geen volgorde):
##   "g" + 15 kleine hex van SHA256("session_id|host_tick|seat_uid") via HashingContext.
##   Geen Godot-hash(), geen "+". 16 tekens [a-z0-9], passend bij M1.
## De runtime-set vangt een replay in hetzelfde proces nadat FIFO de oudste
## van meer dan 8 runs uit applied_grants heeft gezet. Ze gaat niet mee naar schijf.
##
## profile_exp is een int 0..999999: int(round(verdiepingen × gewicht)), som geklemd.
## Normal × 1,5 rondt oneven verdiepingen af (1 → 2, 3 → 5, 7 → 11). Gewichten
## blijven het voorstel Easy 1 / Normal 1,5 / Hard 2. stats_seen.runs laat M1 zelf.
## stats_seen.best_floor = max(oud, bundle), geklemd op 0..100.
## Unlocks: [a-z0-9_]{1,16}, max 16, geen dubbelen. Een volle lijst neemt niets nieuws op.
##
## --- Host, wachtend op REWARD_ACK (bericht zelf: aparte PR bovenop #419) ---
## Deze module bouwt geen protocol en wijzigt NetProtocol.VERSION niet.
## De host houdt per stoel-uid een pending-lijst van onbevestigde bundles,
## hoogstens 8 (nooit meer dan M1's applied_grants). FIFO: de oudste valt weg.
##   host.note_pending(bundle)   # na verzenden; een al ACK'te sleutel wordt niet gezet
##   host.ack(uid, grant_key)    # haalt de bundle van die stoel; nooit opnieuw sturen
##   host.pending_for(uid)       # bij rejoin opnieuw sturen
## Pending en de ACK-set zijn runtime van de host-instantie, niet van het profiel.
## Gebruik voor de host een andere instantie dan voor de client.
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

## Zelfde plafonds als M1 (PR #417). Hier nagebootst; OnlineProfile wordt niet aangeroepen.
const MAX_PROFILE_EXP := 999999
const MAX_GRANTS := 8
const MAX_UNLOCKS := 16
const MAX_ID_LEN := 16
const MAX_BEST_FLOOR := 100

const STATUS_APPLIED := "applied"
const STATUS_DUPLICATE := "duplicate"
const STATUS_REJECTED := "rejected"

## Client: sleutels die dit proces al toepaste. Niet in het profiel.
var _live_grant_keys: Dictionary = {}
## Host: uid -> bundles die nog geen ACK hebben. Nooit meer dan MAX_GRANTS.
var _pending: Dictionary = {}
## Host: ACK'te sleutels. Die bundle gaat deze instantie niet opnieuw de deur uit.
var _acked: Dictionary = {}


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


## Verslagen verdiepingen × modusgewicht, afgerond naar int en geklemd op 0..999999.
## Onbekende modus (ook Classic) = 0. Normal × 1,5: oneven aantallen ronden af
## (round half van nul weg; 1,5 → 2).
static func profile_exp_for(floors_cleared: int, mode: String) -> int:
	if floors_cleared <= 0:
		return 0
	var raw := int(round(float(floors_cleared) * weight_for_mode(mode)))
	return clampi(raw, 0, MAX_PROFILE_EXP)


## 16 tekens [a-z0-9]: "g" + 15 hex van SHA256("session_id|host_tick|seat_uid").
## HashingContext, niet Godot hash() (dat verschilt per platform).
static func grant_key(session_id: String, host_tick: int, seat_uid: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(("%s|%d|%s" % [session_id, host_tick, seat_uid]).to_utf8_buffer())
	return "g" + ctx.finish().hex_encode().substr(0, 15)


static func grant_key_for_bundle(bundle: Dictionary) -> String:
	return grant_key(str(bundle.get("session_id", "")), int(bundle.get("host_tick", 0)), str(bundle.get("seat_uid", "")))


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
	# JSON levert een heel getal soms als float. In het profiel schrijven we int.
	if _exp_value(bundle["profile_exp"]) < 0:
		return false
	return true


## profile en bundle blijven onaangeroerd. Geen bestand, geen extra profielveld.
## {status, grant_key, profile}. status is applied, duplicate of rejected.
## applied en duplicate: de caller stuurt een ACK met grant_key (na het opslaan).
## Een andere session_id weigert niet; alleen de sleutel telt.
func apply_bundle(profile: Dictionary, bundle: Dictionary) -> Dictionary:
	var out := profile.duplicate(true)
	if not bundle_clean(bundle):
		return _verdict(out, STATUS_REJECTED, "")
	var key := grant_key_for_bundle(bundle)
	if _live_grant_keys.has(key):
		return _verdict(out, STATUS_DUPLICATE, key)
	var slots_v: Variant = out.get("slots", [])
	if not (slots_v is Array):
		return _verdict(out, STATUS_REJECTED, key)
	var slots: Array = slots_v
	var uid := str(bundle["seat_uid"])
	var idx := -1
	for i in slots.size():
		var raw: Variant = slots[i]
		if raw is Dictionary and str((raw as Dictionary).get("uid", "")) == uid:
			idx = i
			break
	if idx < 0:
		return _verdict(out, STATUS_REJECTED, key)
	var slot: Dictionary = slots[idx]
	var grants := _valid_ids(slot.get("applied_grants", []))
	if grants.has(key):
		_live_grant_keys[key] = true
		return _verdict(out, STATUS_DUPLICATE, key)
	var exp := _stored_int(slot.get("profile_exp", 0), 0, MAX_PROFILE_EXP)
	exp = mini(MAX_PROFILE_EXP, exp + _exp_value(bundle["profile_exp"]))
	slot["profile_exp"] = exp
	var seen_v: Variant = slot.get("stats_seen", {})
	var seen: Dictionary = (seen_v as Dictionary).duplicate(true) if seen_v is Dictionary else {}
	var floor_now := _stored_int(seen.get("best_floor", 0), 0, MAX_BEST_FLOOR)
	var floor_add := clampi(int(bundle["best_floor"]), 0, MAX_BEST_FLOOR)
	seen["best_floor"] = maxi(floor_now, floor_add)
	slot["stats_seen"] = seen
	var unlocks := _valid_ids(slot.get("unlocks", []))
	while unlocks.size() > MAX_UNLOCKS:
		unlocks.pop_back()
	for u in bundle["unlocks"]:
		var id := str(u)
		if unlocks.has(id) or unlocks.size() >= MAX_UNLOCKS:
			continue
		unlocks.append(id)
	slot["unlocks"] = unlocks
	while grants.size() >= MAX_GRANTS:
		grants.pop_front()
	grants.append(key)
	slot["applied_grants"] = grants
	_live_grant_keys[key] = true
	slots[idx] = slot
	out["slots"] = slots
	return _verdict(out, STATUS_APPLIED, key)


## Host zette deze bundle op de lijn en wacht op ACK. Al ACK'te sleutels blijven weg.
## Per uid hoogstens MAX_GRANTS; de oudste onbevestigde valt weg. Niet in het profiel.
func note_pending(bundle: Dictionary) -> bool:
	if not bundle_clean(bundle):
		return false
	var key := grant_key_for_bundle(bundle)
	if _acked.has(key):
		return false
	var uid := str(bundle["seat_uid"])
	var raw: Variant = _pending.get(uid, [])
	var list: Array = (raw as Array).duplicate(true) if raw is Array else []
	for existing in list:
		if existing is Dictionary and grant_key_for_bundle(existing) == key:
			return true
	list.append(bundle.duplicate(true))
	while list.size() > MAX_GRANTS:
		list.pop_front()
	_pending[uid] = list
	return true


## ACK binnen. Alleen als key op de pending-lijst van uid staat: weg en niet opnieuw verstuurd.
func ack(uid: String, key: String) -> bool:
	if key == "" or uid == "":
		return false
	var raw: Variant = _pending.get(uid, [])
	if not (raw is Array):
		return false
	var found := false
	for existing in raw:
		if existing is Dictionary and grant_key_for_bundle(existing) == key:
			found = true
			break
	if not found:
		return false
	_acked[key] = true
	var kept: Array = []
	for existing in raw:
		if not (existing is Dictionary):
			continue
		if grant_key_for_bundle(existing) != key:
			kept.append(existing)
	_pending[uid] = kept
	return true


## Bundles die deze host bij een rejoin opnieuw mag sturen. Kopie; de lijst zelf blijft hier.
func pending_for(uid: String) -> Array:
	var raw: Variant = _pending.get(uid, [])
	if not (raw is Array):
		return []
	return (raw as Array).duplicate(true)


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
		"profile_exp": int(bundle.get("profile_exp", 0)),
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


static func _verdict(profile: Dictionary, status: String, key: String) -> Dictionary:
	return {"profile": profile, "status": status, "grant_key": key}


## -1 als het geen heel getal in 0..MAX_PROFILE_EXP is. Bool telt niet.
static func _exp_value(v: Variant) -> int:
	if v is bool or typeof(v) == TYPE_BOOL:
		return -1
	var n := -1
	if v is int:
		n = int(v)
	elif v is float and v == floor(v):
		n = int(v)
	else:
		return -1
	if n < 0 or n > MAX_PROFILE_EXP:
		return -1
	return n


static func _stored_int(v: Variant, lo: int, hi: int) -> int:
	if v is bool or typeof(v) == TYPE_BOOL:
		return lo
	var n := lo
	if v is int:
		n = int(v)
	elif v is float and v == floor(v):
		n = int(v)
	else:
		return lo
	return clampi(n, lo, hi)


static func _valid_ids(raw: Variant) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	for item in raw:
		if typeof(item) != TYPE_STRING and typeof(item) != TYPE_STRING_NAME:
			continue
		var id := str(item)
		if _unlock_id_ok(id) and not out.has(id):
			out.append(id)
	return out


static func _unlock_id_ok(id: String) -> bool:
	if id.length() < 1 or id.length() > MAX_ID_LEN:
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
