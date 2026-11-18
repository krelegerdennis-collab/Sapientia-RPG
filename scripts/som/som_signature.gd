class_name SomSignature
extends RefCounted
## F3 signature-logica (host-tick, deterministisch). Arena roept dunne hooks aan.

const SomSignatureData := preload("res://scripts/data/som_signature_data.gd")
const SomChainData := preload("res://scripts/data/som_chain_data.gd")
const SomFeelData := preload("res://scripts/data/som_feel_data.gd")
const TelegraphAttack := preload("res://scripts/som/telegraph_attack.gd")
const PartyActions := preload("res://scripts/party_actions.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")


static func backstab_hit(monster_facing: Vector2i, strike_dir: Vector2i) -> bool:
	if strike_dir == Vector2i.ZERO:
		return false
	var ef := Vector2(monster_facing)
	if ef.length_squared() < 0.01:
		return false
	var sd := Vector2(strike_dir)
	return ef.normalized().dot(sd.normalized()) > SomSignatureData.BACKSTAB_DOT


static func icd_ready(icd: Dictionary, hero_id: String) -> bool:
	return int(icd.get(hero_id, 0)) <= 0


static func dax_knockback_tiles(step: int, heavy: int) -> int:
	if heavy >= 2:
		return SomSignatureData.DAX_KNOCK_HEAVY2
	if heavy == 1:
		return SomSignatureData.DAX_KNOCK_HEAVY1
	if step >= 0 and SomChainData.is_finisher(step):
		return SomSignatureData.DAX_KNOCK_FIN
	return -1


static func dax_stagger_fill_mult(step: int, heavy: int) -> float:
	if heavy > 0 or (step >= 0 and SomChainData.is_finisher(step)):
		return SomSignatureData.DAX_STAGGER_MULT
	return 1.0


static func tick(arena) -> void:
	if not SomSignatureData.is_active():
		return
	if arena.coop_mode and not arena.coop_sim_host:
		return
	for hid in SomSignatureData.HERO_IDS:
		var left := int(arena._sig_icd.get(hid, 0))
		if left > 0:
			arena._sig_icd[hid] = left - 1
	for m in arena.enemies.keys():
		if not is_instance_valid(m) or not arena.enemies.has(m):
			continue
		var e: Dictionary = arena.enemies[m]
		var slow := int(e.get("sig_slow", 0))
		if slow > 0:
			e["sig_slow"] = slow - 1


static func aggro_target(arena, m: Node) -> String:
	if not SomSignatureData.is_active() or not arena.enemies.has(m):
		return ""
	var ag: Dictionary = arena.enemies[m].get("sig_aggro", {})
	if int(ag.get("until", 0)) > arena.sim_tick:
		var hid := str(ag.get("hero", ""))
		if hid != "" and arena.is_alive(hid):
			return hid
	return ""


static func chase_interval(base: float, e: Dictionary) -> float:
	if SomSignatureData.is_active() and int(e.get("sig_slow", 0)) > 0:
		return base / SomSignatureData.ORION_SLOW_MULT
	return base


static func on_telegraph_started(e: Dictionary) -> void:
	e["sig_orion_windup_done"] = false


## Vesper backstab via _land: lege dict = geen wijziging (geen alloc op de meeste hits).
static func adjust_melee_damage(arena, m: Node, raw: int, strike_dir: Vector2i) -> Dictionary:
	if not backstab_hit(m.facing, strike_dir):
		return {}
	arena.sig_backstab_hits += 1
	var out := {"dmg": maxi(1, roundi(float(raw) * SomSignatureData.CRIT_MULT))}
	if SomFeelData.ENABLED:
		out["color"] = SomFeelData.COL_FINISHER_NUMBER
		out["scale"] = SomFeelData.SCALE_FINISHER_NUMBER
	return out


static func after_melee_hit(arena, attacker_id: String, _m: Node, e: Dictionary, step: int, heavy: int) -> void:
	if not SomSignatureData.is_active():
		return
	var fin := step >= 0 and SomChainData.is_finisher(step)
	var heavy_hit := heavy > 0
	if attacker_id == "kael" and fin and icd_ready(arena._sig_icd, "kael"):
		e["sig_aggro"] = {"hero": "kael", "until": arena.sim_tick + SomSignatureData.KAEL_LOCK_TICKS}
		arena._sig_icd["kael"] = SomSignatureData.KAEL_ICD_TICKS
	if attacker_id == "orion" and (fin or heavy_hit) and not e.has("golem"):
		e["sig_slow"] = SomSignatureData.ORION_SLOW_TICKS
		if e.has("tg"):
			var tg: TelegraphAttack = e["tg"]
			if tg.in_windup() and not bool(e.get("sig_orion_windup_done", false)):
				tg.extend_windup(SomSignatureData.ORION_WINDUP_EXTRA_TICKS)
				e["sig_orion_windup_done"] = true
				if arena.has_method("_sync_telegraph_meters"):
					arena._sync_telegraph_meters(e, tg)


static func try_seren_heal(arena, caster_id: String, step: int, hits: int) -> void:
	if not SomSignatureData.is_active():
		return
	if caster_id != "lotte" or hits <= 0 or step < 0 or not SomChainData.is_finisher(step):
		return
	if not icd_ready(arena._sig_icd, "lotte"):
		return
	var from: Vector2 = arena.body_of(caster_id)
	var tgt := _lowest_ally_within(arena, from, SomSignatureData.SEREN_HEAL_RADIUS_PX)
	if tgt.is_empty():
		return
	var amt := maxi(1, roundi(float(tgt["max_hp"]) * SomSignatureData.SEREN_HEAL_PCT))
	var got := PartyActions.restore(tgt, amt, 0)
	if int(got.x) <= 0:
		return
	arena.last_sig_heal = int(got.x)
	arena.sig_heal_total += int(got.x)
	arena._sig_icd["lotte"] = SomSignatureData.SEREN_ICD_TICKS
	if arena.room != null and arena.has_method("heal_glow") and arena.room.has_node("Objects"):
		var tid := str(tgt.get("id", ""))
		SomFx.number(arena.room.get_node("Objects"), arena.body_of(tid) + Vector2(0, -22), "+%d" % got.x, Color(0.4, 1, 0.5))
		arena.heal_glow(tid)


static func _lowest_ally_within(arena, from: Vector2, radius: float) -> Dictionary:
	var best := {}
	var best_r := 2.0
	for hid in arena.party_ids():
		if not arena.is_alive(hid):
			continue
		if arena.body_of(hid).distance_to(from) > radius:
			continue
		var h: Dictionary = arena.member(hid)
		var r := float(h["hp"]) / maxf(1.0, float(h["max_hp"]))
		if r < best_r:
			best_r = r
			best = h
	return best