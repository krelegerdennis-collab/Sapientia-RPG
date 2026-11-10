extends Node
## M8b — buit per stoel, run-resultaat en reward-bundle.
## Start: godot --headless --path . -- --onlinerewardtest
## Puur: geen relay, geen wijziging van solo-saves of van NetProtocol.VERSION.

const OnlineLoot := preload("res://scripts/net/online_loot.gd")
const OnlineReward := preload("res://scripts/net/online_reward.gd")
const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")

const UIDS: Array[String] = ["a1b2c3d4", "b2c3d4e5", "c3d4e5f6", "d4e5f6a7"]

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
	var state_before := _capture_state()
	_write_story_sentinels()
	var files_before := _snap_user()
	_seed_tests()
	_stream_tests()
	_floor_tests()
	_claim_tests()
	_reward_tests()
	_epoch_tests()
	_payload_tests()
	_source_tests()
	_state_unchanged(state_before)
	_files_unchanged(files_before)
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


# ---------------------------------------------------------------- rng en rolls
func _seed_tests() -> void:
	var s0 := OnlineLoot.seat_seed(11, UIDS[0])
	check("seat-seed stabiel voor seed+uid", s0 == OnlineLoot.seat_seed(11, UIDS[0]) and s0 != 0)
	var seeds_differ := true
	var seen := {}
	for uid in UIDS:
		var s := OnlineLoot.seat_seed(11, uid)
		if seen.has(s):
			seeds_differ = false
		seen[s] = true
	check("vier stoelen, vier verschillende stromen", seeds_differ)
	check("andere run-seed, andere stroom", OnlineLoot.seat_seed(11, UIDS[0]) != OnlineLoot.seat_seed(12, UIDS[0]))
	check("zelfde seed+uid = zelfde kistreeks", _chest_seq(11, UIDS[0]) == _chest_seq(11, UIDS[0]))
	check("andere seed = andere kistreeks", _chest_seq(11, UIDS[0]) != _chest_seq(12, UIDS[0]))
	var seqs: Array = []
	var rolls_differ := true
	for uid in UIDS:
		var seq := _chest_seq(11, uid)
		for prev in seqs:
			if prev == seq:
				rolls_differ = false
		seqs.append(seq)
	check("vier stoelen, verschillende kist-rolls bij dezelfde seed", rolls_differ)


func _chest_seq(seed_value: int, uid: String) -> Array:
	var run := OnlineLoot.new()
	run.setup(seed_value, [uid])
	var seq: Array = []
	for i in 10:
		var drop: Dictionary = run.roll_chest_for(uid, {"id": "c%d" % i, "floor": 12 + i * 3})
		seq.append(drop["loot"])
	return seq


func _stream_tests() -> void:
	var multi := OnlineLoot.new()
	var solo := OnlineLoot.new()
	multi.setup(77, UIDS)
	solo.setup(77, [UIDS[2]])
	var same := true
	for i in 6:
		var many: Array = multi.roll_chest({"id": "c%d" % i, "floor": 20 + i})
		var one: Dictionary = solo.roll_chest_for(UIDS[2], {"id": "c%d" % i, "floor": 20 + i})
		same = same and _loot_of(many, UIDS[2]) == one["loot"]
	check("stoel-stroom gelijk met of zonder de andere drie", same)
	var plain := OnlineLoot.new()
	var extra := OnlineLoot.new()
	plain.setup(77, UIDS)
	extra.setup(77, UIDS)
	extra.roll_chest_for(UIDS[0], {"id": "extra", "floor": 40})
	extra.roll_chest_for(UIDS[0], {"id": "extra2", "floor": 41})
	extra.roll_monster_for(UIDS[0], {"id": "xm", "enemy": "papiergeest", "floor": 40})
	var b_plain: Dictionary = plain.roll_chest_for(UIDS[1], {"id": "shared", "floor": 33})
	var b_extra: Dictionary = extra.roll_chest_for(UIDS[1], {"id": "shared", "floor": 33})
	check("extra rolls van stoel A verschuiven stoel B niet", b_plain["loot"] == b_extra["loot"])
	var sim := RandomNumberGenerator.new()
	var twin := RandomNumberGenerator.new()
	sim.seed = 424242
	twin.seed = 424242
	for i in 5:
		sim.randi()
		twin.randi()
	var frozen := sim.state
	var noise := OnlineLoot.new()
	noise.setup(5, UIDS)
	for i in 12:
		noise.roll_chest({"id": "n%d" % i, "floor": 10 + i})
		noise.roll_monster({"id": "nm%d" % i, "enemy": "papiergeest", "floor": 10 + i, "boss": i == 3})
	check("loot-rolls laten de sim-RNG-state staan", sim.state == frozen)
	var got: Array = []
	var want: Array = []
	for i in 6:
		got.append(sim.randi())
		want.append(twin.randi())
	check("na loot-rolls blijft de sim-reeks gelijk", got == want)
	check("twee runs, zelfde seed, zelfde rapport", _scripted(42) == _scripted(42))
	check("twee runs, andere seed, ander rapport", _scripted(42) != _scripted(43))
	var reps: Array = _scripted(42)
	var loot_differs := true
	for i in reps.size():
		for j in range(i + 1, reps.size()):
			if (reps[i] as Dictionary)["loot"] == (reps[j] as Dictionary)["loot"]:
				loot_differs = false
				print("LOOT-GELIJK %s" % JSON.stringify(reps))
	check("vier stoelen, verschillende buit-samenvatting", loot_differs and reps.size() == 4)


func _loot_of(drops: Array, uid: String) -> Dictionary:
	for d in drops:
		if str(d.get("owner_uid", "")) == uid:
			return d["loot"]
	return {}


func _scripted(seed_value: int) -> Array:
	var run := OnlineLoot.new()
	run.setup(seed_value, UIDS)
	for i in 6:
		for d in run.roll_chest({"id": "c%d" % i, "floor": 8 + i * 4, "boss": i == 5}):
			run.claim(str(d["id"]), str(d["owner_uid"]))
		for d in run.roll_monster({"id": "m%d" % i, "enemy": "papiergeest", "floor": 8 + i * 4}):
			run.claim(str(d["id"]), str(d["owner_uid"]))
	for uid in UIDS:
		run.note_kill(uid, 3)
		run.note_revive(uid, 1)
		run.note_down(uid, 2)
		for f in 4:
			run.note_floor_cleared(uid, f + 1)
	return run.reports()


func _floor_tests() -> void:
	var saved := GameState.dungeon100_floor
	GameState.dungeon100_floor = 80
	check("floor-veld, niet de solo-verdieping", OnlineLoot.floor_of({"floor": 2}) == 2 and OnlineLoot.floor_of({}) == 0)
	var run := OnlineLoot.new()
	run.setup(3, ["u"])
	var low: Dictionary = run.roll_chest_for("u", {"id": "low", "floor": 2})
	var missing: Dictionary = run.roll_chest_for("u", {"id": "geen"})
	check("kist leest floor 2 (tier 1), niet floor 80", int(low["loot"]["tier"]) == Scaling.tier_for_floor(2) and int(low["loot"]["tier"]) != Scaling.tier_for_floor(80))
	check("zonder floor-veld blijft de kist leeg", int(missing["loot"]["gold"]) == 0 and (missing["loot"]["items"] as Array).is_empty())
	var boss: Dictionary = run.roll_chest_for("u", {"id": "baas", "floor": 20, "boss": true})
	check("baaskist gaat door chest_loot (boss)", bool(boss["loot"]["boss"]))
	var m1: Dictionary = run.roll_monster_for("u", {"id": "m1", "enemy": "papiergeest", "floor": 1})
	var m50: Dictionary = run.roll_monster_for("u", {"id": "m50", "enemy": "papiergeest", "floor": 50})
	var scaled: Dictionary = Scaling.battle_enemy(GameData.ENEMIES["papiergeest"], 50, false)
	check("drop-goud/EXP volgt battle_enemy op floor", int(m50["loot"]["gold"]) == int(scaled["gold"]) and int(m50["loot"]["exp"]) == int(scaled["exp"]))
	check("hogere floor, meer drop-goud", int(m50["loot"]["gold"]) > int(m1["loot"]["gold"]))
	check("vijandtabel niet beschreven", int(GameData.ENEMIES["papiergeest"]["gold"]) == 4)
	var capped := OnlineLoot.new()
	capped.setup(1, ["a", "a", "b", "c", "d", "e"])
	check("hoogstens vier stoelen, dubbele uid telt niet", capped.uids().size() == 4 and not capped.has_seat("e"))
	GameState.dungeon100_floor = saved


func _claim_tests() -> void:
	var run := OnlineLoot.new()
	run.setup(3, ["A", "B"])
	var drops: Array = run.roll_monster({"id": "slime", "enemy": "papiergeest", "floor": 12})
	var da: Dictionary = _drop_for(drops, "A")
	var db: Dictionary = _drop_for(drops, "B")
	check("B pakt de buit van A niet", run.claim(str(da["id"]), "B") == false)
	check("tas van B blijft leeg na een mislukte pak", int(run.bag("B")["gold"]) == 0 and int(run.bag("B")["exp"]) == 0 and (run.bag("B")["items"] as Dictionary).is_empty())
	check("A pakt de eigen buit", run.claim(str(da["id"]), "A"))
	check("run-goud en run-EXP van A komen uit de eigen roll", int(run.bag("A")["gold"]) == int(da["loot"]["gold"]) and int(run.bag("A")["exp"]) == int(da["loot"]["exp"]))
	check("tweede pak van A is een no-op", run.claim(str(da["id"]), "A") == false and int(run.bag("A")["gold"]) == int(da["loot"]["gold"]))
	var gold_a := int(run.bag("A")["gold"])
	check("A pakt de buit van B niet", run.claim(str(db["id"]), "A") == false and int(run.bag("A")["gold"]) == gold_a)
	check("B pakt daarna alsnog de eigen buit", run.claim(str(db["id"]), "B") and int(run.bag("B")["gold"]) == int(db["loot"]["gold"]))
	check("tas van A blijft de eigen roll", int(run.bag("A")["gold"]) == gold_a and int(run.bag("A")["exp"]) == int(da["loot"]["exp"]))


func _drop_for(drops: Array, uid: String) -> Dictionary:
	for d in drops:
		if str(d.get("owner_uid", "")) == uid:
			return d
	return {}


# ---------------------------------------------------------------- bundle
func _reward_tests() -> void:
	var seat := UIDS[0]
	check("gewicht Easy 1 (voorstel)", OnlineReward.profile_exp_for(7, "easy") == 7)
	check("Normal oneven verdiepingen ronden af (1→2, 3→5, 7→11)", OnlineReward.profile_exp_for(1, "normal") == 2 and OnlineReward.profile_exp_for(3, "normal") == 5 and OnlineReward.profile_exp_for(7, "normal") == 11)
	check("Normal even blijft heel (2→3)", OnlineReward.profile_exp_for(2, "normal") == 3)
	check("gewicht Hard 2 (voorstel)", OnlineReward.profile_exp_for(7, "hard") == 14)
	check("Classic / onbekende modus geeft 0", OnlineReward.profile_exp_for(10, "classic") == 0)
	var done := OnlineReward.make_bundle("sess", 1, "easy", {"seat_uid": seat, "floors": 10, "best_floor": 10})
	var partial := OnlineReward.make_bundle("sess", 1, "easy", {"seat_uid": seat, "floors": 9, "best_floor": 9})
	check("voltooide Easy: één placeholder-unlock", done["unlocks"] == [OnlineReward.UNLOCK_EASY])
	check("onvoltooide Easy: geen unlock", (partial["unlocks"] as Array).is_empty() and partial["profile_exp"] == 9)
	var normal := OnlineReward.make_bundle("sess", 2, "normal", {"seat_uid": seat, "floors": 50, "best_floor": 50})
	var hard := OnlineReward.make_bundle("sess", 3, "hard", {"seat_uid": seat, "floors": 100, "best_floor": 100})
	check("voltooide Normal en Hard: eigen placeholder", normal["unlocks"] == [OnlineReward.UNLOCK_NORMAL] and hard["unlocks"] == [OnlineReward.UNLOCK_HARD])
	check("profile_exp Normal 75 en Hard 200, allebei int", normal["profile_exp"] == 75 and hard["profile_exp"] == 200 and typeof(normal["profile_exp"]) == TYPE_INT)
	var key := OnlineReward.grant_key("sess", 1)
	check("grant-sleutel is g + 15 hex, stabiel, zonder plus", key.length() == 16 and key == OnlineReward.grant_key("sess", 1) and key != OnlineReward.grant_key("sess", 2) and key != OnlineReward.grant_key("andere", 1) and _id_chars(key) and not key.contains("+"))
	var rich := {
		"seat_uid": seat, "floors": 2, "best_floor": 2, "kills": 9,
		"loot": {"gold": 500, "exp": 800, "items": [{"item": "drankje", "n": 3}]},
	}
	var slim := OnlineReward.make_bundle("sess", 4, "easy", rich)
	var slim_json := JSON.stringify(slim)
	check("bundle heeft alleen rang en cosmetica", OnlineReward.bundle_clean(slim) and slim.size() == OnlineReward.BUNDLE_KEYS.size())
	check("geen items of stats in de bundle", not slim.has("items") and not slim.has("gold") and not slim.has("kills") and not slim_json.contains("drankje") and not slim_json.contains("\"atk\""))
	var rewards := OnlineReward.new()
	var profile := _profile(seat)
	var r1: Dictionary = rewards.apply_bundle(profile, done)
	var p1: Dictionary = r1["profile"]
	var r2: Dictionary = rewards.apply_bundle(p1, done)
	check("apply laat het invoer-profiel staan", int(profile["slots"][0]["profile_exp"]) == 0 and (profile["slots"][0]["applied_grants"] as Array).is_empty())
	check("eerste apply zet exp, verdieping en unlock", r1["status"] == OnlineReward.STATUS_APPLIED and r1["grant_key"] == key and p1["slots"][0]["profile_exp"] == 10 and typeof(p1["slots"][0]["profile_exp"]) == TYPE_INT and int(p1["slots"][0]["stats_seen"]["best_floor"]) == 10 and p1["slots"][0]["unlocks"] == [OnlineReward.UNLOCK_EASY])
	check("grant-sleutel staat in applied_grants", p1["slots"][0]["applied_grants"] == [key])
	check("tweede apply is duplicate en 0 extra", r2["status"] == OnlineReward.STATUS_DUPLICATE and r2["grant_key"] == key and p1 == r2["profile"])
	check("runs en inventaris van het slot blijven af", int(p1["slots"][0]["stats_seen"]["runs"]) == 0 and not p1["slots"][0].has("items") and not p1["slots"][0].has("gold") and not p1["slots"][0].has("accepted_session_id"))
	check("profiel na apply blijft M1-geldig", _m1_json_ok(p1))
	var other_session := OnlineReward.make_bundle("andere-run", 1, "easy", {"seat_uid": seat, "floors": 1, "best_floor": 1})
	var r_other: Dictionary = rewards.apply_bundle(p1, other_session)
	check("andere session_id telt als de grant nieuw is", r_other["status"] == OnlineReward.STATUS_APPLIED and r_other["profile"]["slots"][0]["profile_exp"] == 11)
	var again := done.duplicate(true)
	again["host_tick"] = 8
	var r3: Dictionary = rewards.apply_bundle(r_other["profile"], again)
	var p3: Dictionary = r3["profile"]
	check("andere tick telt wel, unlock niet verdubbeld", r3["status"] == OnlineReward.STATUS_APPLIED and p3["slots"][0]["profile_exp"] == 21 and p3["slots"][0]["unlocks"] == [OnlineReward.UNLOCK_EASY])
	var foreign := done.duplicate(true)
	foreign["host_tick"] = 3
	foreign["seat_uid"] = "iemand-anders"
	var r4: Dictionary = OnlineReward.new().apply_bundle(profile, foreign)
	check("bundle voor een andere uid is rejected", r4["status"] == OnlineReward.STATUS_REJECTED and int(r4["profile"]["slots"][0]["profile_exp"]) == 0)
	var smuggle := done.duplicate(true)
	smuggle["items"] = [{"item": "drankje", "n": 1}]
	check("bundle met items wordt geweigerd", not OnlineReward.bundle_clean(smuggle))
	var r5: Dictionary = rewards.apply_bundle(profile, smuggle)
	check("geweigerde bundle schrijft niets", r5["status"] == OnlineReward.STATUS_REJECTED and r5["grant_key"] == "" and (r5["profile"]["slots"][0]["applied_grants"] as Array).is_empty() and int(r5["profile"]["slots"][0]["profile_exp"]) == 0)
	var lore := done.duplicate(true)
	lore["unlocks"] = ["A fresh legend"]
	check("unlock moet een id zijn, geen tekst", not OnlineReward.bundle_clean(lore))
	var te_lang := done.duplicate(true)
	te_lang["unlocks"] = ["abcdefghijklmnopq"]
	check("unlock langer dan 16 wordt geweigerd", not OnlineReward.bundle_clean(te_lang))
	var mid: Dictionary = rewards.apply_bundle(profile, OnlineReward.make_bundle("sess", 5, "easy", {"seat_uid": seat, "floors": 4, "best_floor": 6}))
	var back: Dictionary = rewards.apply_bundle(mid["profile"], OnlineReward.make_bundle("sess", 6, "easy", {"seat_uid": seat, "floors": 1, "best_floor": 2}))
	check("best_floor gaat niet omlaag", int(back["profile"]["slots"][0]["stats_seen"]["best_floor"]) == 6)
	var reps: Array = _scripted(42)
	var result := OnlineReward.make_run_result("run-1", 1500, "easy", 42, reps)
	check("run-resultaat bevat per stoel verdiepingen, kills, revives, downs en buit", _result_fields(result))
	var bundles: Array = OnlineReward.bundles_for(result)
	var bundles_ok := bundles.size() == 4
	for b in bundles:
		var js := JSON.stringify(b)
		bundles_ok = bundles_ok and OnlineReward.bundle_clean(b) and not js.contains("drankje") and not b.has("items")
		bundles_ok = bundles_ok and b["profile_exp"] == 4
	check("bundles uit het resultaat: alleen rang, exp = verdiepingen x 1", bundles_ok)


func _result_fields(result: Dictionary) -> bool:
	var seats: Array = result["seats"]
	if seats.size() != 4:
		return false
	for s in seats:
		if int(s["floors"]) != 4 or int(s["kills"]) != 3 or int(s["revives"]) != 1 or int(s["downs"]) != 2:
			return false
		if not (s["loot"] is Dictionary):
			return false
	return true


func _profile(uid: String) -> Dictionary:
	return {
		"version": 1,
		"slots": [{
			"uid": uid,
			"name": "Dax",
			"class": "warrior",
			"look": {
				"body": 0, "skin": 0, "hair": 0, "hair_color": 0,
				"top": 0, "top_color": 0, "bottom": 0, "bottom_color": 0, "head": 0,
			},
			"profile_exp": 0,
			"unlocks": [],
			"stats_seen": {"best_floor": 0, "runs": 0},
			"applied_grants": [],
		}],
	}


# ---------------------------------------------------------------- ACK, FIFO, M1-vorm
func _epoch_tests() -> void:
	var seat := UIDS[0]
	var live := OnlineReward.new()
	var session := "marathon1"
	var cur := _profile(seat)
	var first: Dictionary = {}
	var applied_ok := true
	for i in 9:
		var bundle := OnlineReward.make_bundle(session, i + 1, "easy", {"seat_uid": seat, "floors": 1, "best_floor": 1})
		if i == 0:
			first = bundle
		var res: Dictionary = live.apply_bundle(cur, bundle)
		applied_ok = applied_ok and str(res["status"]) == OnlineReward.STATUS_APPLIED
		cur = res["profile"]
	var grants: Array = cur["slots"][0]["applied_grants"]
	var first_key := OnlineReward.grant_key(session, 1)
	check("negen bundles in één sessie toegepast", applied_ok and cur["slots"][0]["profile_exp"] == 9)
	check("FIFO houdt 8 grants en laat de eerste vallen", grants.size() == 8 and not grants.has(first_key) and grants.has(OnlineReward.grant_key(session, 9)))
	var replay: Dictionary = live.apply_bundle(cur, first)
	check("replay van de eerste na FIFO is duplicate", replay["status"] == OnlineReward.STATUS_DUPLICATE and replay["grant_key"] == first_key and replay["profile"]["slots"][0]["profile_exp"] == 9 and replay["profile"]["slots"][0]["applied_grants"] == grants)
	check("profiel na FIFO slaagt voor de M1-nabootsing", _m1_json_ok(replay["profile"]))
	var killed := OnlineReward.new()
	var lost_bundle := OnlineReward.make_bundle("beforekill", 1, "easy", {"seat_uid": seat, "floors": 10, "best_floor": 10})
	var unsaved := _profile(seat)
	var once: Dictionary = killed.apply_bundle(unsaved, lost_bundle)
	var restarted := OnlineReward.new()
	var resent: Dictionary = restarted.apply_bundle(unsaved, lost_bundle)
	check("kill zonder ACK, zelfde profiel, resend telt precies 1x", once["status"] == OnlineReward.STATUS_APPLIED and resent["status"] == OnlineReward.STATUS_APPLIED and resent["profile"]["slots"][0]["profile_exp"] == 10 and resent["profile"]["slots"][0]["unlocks"] == [OnlineReward.UNLOCK_EASY] and (resent["profile"]["slots"][0]["applied_grants"] as Array).size() == 1)
	var saved: Dictionary = once["profile"]
	var ack_lost := OnlineReward.new()
	var again: Dictionary = ack_lost.apply_bundle(saved, lost_bundle)
	check("profiel opgeslagen, ACK kwijt: resend is duplicate en 0 extra", again["status"] == OnlineReward.STATUS_DUPLICATE and again["grant_key"] == once["grant_key"] and again["profile"]["slots"][0]["profile_exp"] == 10 and again["profile"]["slots"][0]["unlocks"] == saved["slots"][0]["unlocks"] and _m1_json_ok(again["profile"]))
	var host := OnlineReward.new()
	var queued: Array = []
	var host_ok := true
	for i in 9:
		var outgoing := OnlineReward.make_bundle("hostpending", i + 1, "easy", {"seat_uid": seat, "floors": 1, "best_floor": 1})
		queued.append(outgoing)
		host_ok = host_ok and host.note_pending(outgoing)
	var pending: Array = host.pending_for(seat)
	var oldest := OnlineReward.grant_key("hostpending", 1)
	var newest := OnlineReward.grant_key("hostpending", 9)
	var pending_keys := _pending_keys(pending)
	check("pending komt niet boven 8", host_ok and pending.size() == 8 and pending.size() <= OnlineReward.MAX_GRANTS and not pending_keys.has(oldest) and pending_keys.has(newest))
	var other_seat := OnlineReward.make_bundle("hostpending", 1, "easy", {"seat_uid": UIDS[1], "floors": 1, "best_floor": 1})
	check("pending van een andere stoel telt apart", host.note_pending(other_seat) and host.pending_for(UIDS[1]).size() == 1 and host.pending_for(seat).size() == 8)
	var ack_key := newest
	host.ack(ack_key)
	var after_ack := _pending_keys(host.pending_for(seat))
	check("ACK haalt de bundle van de lijst", not after_ack.has(ack_key) and host.pending_for(seat).size() == 7)
	var acked_bundle: Dictionary = queued[8]
	check("ACK'te bundle wordt niet opnieuw gezet", not host.note_pending(acked_bundle) and not _pending_keys(host.pending_for(seat)).has(ack_key))
	var rejoin: Array = host.pending_for(seat)
	check("rejoin krijgt alleen de onbevestigde bundles", rejoin.size() == 7 and _m1_json_ok(saved))
	var clamped := OnlineReward.new()
	var fat := _profile(seat)
	fat["slots"][0]["profile_exp"] = 999990
	var big: Dictionary = clamped.apply_bundle(fat, OnlineReward.make_bundle("clamp1", 1, "hard", {"seat_uid": seat, "floors": 100, "best_floor": 100}))
	check("profile_exp klemt op 999999 en de grant telt", big["status"] == OnlineReward.STATUS_APPLIED and big["profile"]["slots"][0]["profile_exp"] == OnlineReward.MAX_PROFILE_EXP and (big["profile"]["slots"][0]["applied_grants"] as Array).size() == 1 and _m1_json_ok(big["profile"]))
	var capped := OnlineReward.new()
	var full := _profile(seat)
	var ids: Array = []
	for i in OnlineReward.MAX_UNLOCKS:
		ids.append("cos_ph_%02d" % i)
	full["slots"][0]["unlocks"] = ids
	var cap: Dictionary = capped.apply_bundle(full, OnlineReward.make_bundle("unlockcap", 1, "easy", {"seat_uid": seat, "floors": 10, "best_floor": 10}))
	var cap_unlocks: Array = cap["profile"]["slots"][0]["unlocks"]
	check("unlocks blijven op 16 zonder dubbelen", cap["status"] == OnlineReward.STATUS_APPLIED and cap_unlocks.size() == 16 and cap_unlocks == ids and cap["profile"]["slots"][0]["profile_exp"] == 10 and _m1_json_ok(cap["profile"]))


func _pending_keys(pending: Array) -> Array:
	var out: Array = []
	for bundle in pending:
		if bundle is Dictionary:
			out.append(OnlineReward.grant_key(str(bundle.get("session_id", "")), int(bundle.get("host_tick", 0))))
	return out


func _id_chars(id: String) -> bool:
	return _m1_id_ok(id, 16)


## Nabootst de slot-regels van M1 (PR #417) zonder OnlineProfile te laden.
func _m1_json_ok(profile: Dictionary) -> bool:
	var raw := JSON.stringify(profile)
	if raw.contains("accepted_session") or raw.contains("live_grant") or raw.contains("closed_session") or raw.contains("host_tick"):
		return false
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return false
	return _m1_document_ok(parsed)


func _m1_document_ok(doc: Dictionary) -> bool:
	if _m1_int(doc.get("version"), 1, 1) == null:
		return false
	var slots_v: Variant = doc.get("slots", null)
	if not (slots_v is Array):
		return false
	var slots: Array = slots_v
	if slots.size() > 3:
		return false
	var seen: Array = []
	for item in slots:
		if item == null:
			continue
		if not (item is Dictionary) or not _m1_slot_ok(item):
			return false
		var uid := str(item.get("uid", ""))
		if seen.has(uid):
			return false
		seen.append(uid)
	return true


func _m1_slot_ok(slot: Dictionary) -> bool:
	var allowed := ["uid", "name", "class", "look", "profile_exp", "unlocks", "stats_seen", "applied_grants"]
	if slot.size() != allowed.size():
		return false
	for k in slot.keys():
		if not allowed.has(str(k)):
			return false
	if not _m1_uid_ok(str(slot.get("uid", ""))):
		return false
	if not _m1_name_ok(str(slot.get("name", ""))):
		return false
	var classes := ["warrior", "mage", "priest", "psytech", "archer"]
	if not classes.has(str(slot.get("class", ""))):
		return false
	if not (slot.get("look") is Dictionary) or not _m1_look_ok(slot.get("look")):
		return false
	if _m1_int(slot.get("profile_exp"), 0, 999999) == null:
		return false
	if _m1_id_list(slot.get("unlocks"), 16, 16) == null:
		return false
	if _m1_id_list(slot.get("applied_grants"), 8, 16) == null:
		return false
	if not (slot.get("stats_seen") is Dictionary):
		return false
	var stats: Dictionary = slot.get("stats_seen")
	if stats.size() != 2 or not stats.has("best_floor") or not stats.has("runs"):
		return false
	if _m1_int(stats.get("best_floor"), 0, 100) == null or _m1_int(stats.get("runs"), 0, 9999) == null:
		return false
	return true


func _m1_look_ok(look: Dictionary) -> bool:
	var keys: Array[String] = ["body", "skin", "hair", "hair_color", "top", "top_color", "bottom", "bottom_color", "head"]
	var lim := {"body": 0, "skin": 3, "hair": 5, "hair_color": 7, "top": 3, "top_color": 5, "bottom": 2, "bottom_color": 5, "head": 2}
	if look.size() != keys.size():
		return false
	for k in keys:
		if not look.has(k) or _m1_int(look[k], 0, int(lim[k])) == null:
			return false
	return true


func _m1_uid_ok(uid: String) -> bool:
	if uid.length() != 8:
		return false
	for i in uid.length():
		var c := uid.unicode_at(i)
		if not ((c >= 48 and c <= 57) or (c >= 97 and c <= 102)):
			return false
	return true


func _m1_name_ok(naam: String) -> bool:
	if naam.length() < 1 or naam.length() > 5:
		return false
	for i in naam.length():
		var c := naam.unicode_at(i)
		if not ((c >= 65 and c <= 90) or (c >= 97 and c <= 122)):
			return false
	return true


func _m1_id_ok(id: String, max_len: int) -> bool:
	if id.length() < 1 or id.length() > max_len:
		return false
	for i in id.length():
		var c := id.unicode_at(i)
		if not ((c >= 48 and c <= 57) or (c >= 97 and c <= 122) or c == 95):
			return false
	return true


func _m1_id_list(raw: Variant, max_count: int, max_len: int) -> Variant:
	if not (raw is Array):
		return null
	var arr: Array = raw
	if arr.size() > max_count:
		return null
	var out: Array = []
	for item in arr:
		if not (item is String) or not _m1_id_ok(item, max_len) or out.has(item):
			return null
		out.append(item)
	return out


func _m1_int(v: Variant, lo: int, hi: int) -> Variant:
	if v is bool or typeof(v) == TYPE_BOOL:
		return null
	var n := 0
	if v is int:
		n = int(v)
	elif v is float and v == floor(v):
		n = int(v)
	else:
		return null
	if n < lo or n > hi:
		return null
	return n


# ---------------------------------------------------------------- payload
func _payload_tests() -> void:
	var result := OnlineReward.make_run_result("run-1", 1500, "easy", 42, _scripted(42))
	var raw := OnlineReward.encode_payload(OnlineReward.KIND_RUN_RESULT, result)
	var back := OnlineReward.decode_payload(raw)
	check("RUN_RESULT roundtrip", bool(back["ok"]) and str(back["kind"]) == OnlineReward.KIND_RUN_RESULT and back["body"] == result)
	check("RUN_RESULT past in het relay-plafond (%d bytes)" % raw.size(), raw.size() > 0 and raw.size() <= OnlineReward.RELAY_MAX_BYTES)
	var bundle := OnlineReward.make_bundle("run-1", 1500, "normal", {"seat_uid": UIDS[0], "floors": 3, "best_floor": 4})
	check("Normal oneven verdiepingen ronden de bundle-exp (3 → 5)", bundle["profile_exp"] == 5 and typeof(bundle["profile_exp"]) == TYPE_INT)
	var braw := OnlineReward.encode_payload(OnlineReward.KIND_REWARD_BUNDLE, bundle)
	var bback := OnlineReward.decode_payload(braw)
	check("REWARD_BUNDLE roundtrip", bool(bback["ok"]) and str(bback["kind"]) == OnlineReward.KIND_REWARD_BUNDLE and bback["body"] == OnlineReward.reward_bundle_body(bundle))
	check("REWARD_BUNDLE past in het relay-plafond (%d bytes)" % braw.size(), braw.size() > 0 and braw.size() <= OnlineReward.RELAY_MAX_BYTES)
	var v1 := Protocol.decode(raw)
	var v1b := Protocol.decode(braw)
	# v1: ontbrekende "v" is versie 0, dus ok maar niet compatible (lobby negeert dat).
	# Een pakket boven MAX_PACKET_BYTES is helemaal niet ok. Geen van beide is een v1-bericht.
	check("protocol v1 neemt RUN_RESULT en REWARD_BUNDLE niet aan", not bool(v1["compatible"]) and not bool(v1b["compatible"]))
	check("versie van het lobby-protocol blijft 1", Protocol.VERSION == 1)
	var heavy := _heavy_result()
	var packets: Array = OnlineReward.encode_run_results(heavy)
	var heavy_ok := packets.size() == 4
	var decoded: Array = []
	for raw_part in packets:
		var msg: Dictionary = OnlineReward.decode_payload(raw_part)
		heavy_ok = heavy_ok and bool(msg["ok"]) and (raw_part as PackedByteArray).size() <= OnlineReward.RELAY_MAX_BYTES
		decoded.append(msg["body"])
	var merged: Dictionary = OnlineReward.merge_run_results(decoded)
	check("zware buit: één RUN_RESULT per stoel, elk binnen 2048, samen gelijk", heavy_ok and merged == OnlineReward.run_result_body(heavy))
	var dirty := bundle.duplicate(true)
	dirty["gold"] = 10
	check("bundle met goud overleeft de decode niet", not bool(OnlineReward.decode_payload(OnlineReward.encode_payload(OnlineReward.KIND_REWARD_BUNDLE, dirty))["ok"]))


func _heavy_result() -> Dictionary:
	var items: Array = []
	var seen := {}
	for kind in Scaling.GEAR_KINDS:
		for tier in range(1, Scaling.MAX_TIER + 1):
			var id := str(Scaling.gear_id(kind, tier))
			if id != "" and not seen.has(id):
				seen[id] = true
				items.append({"item": id, "n": 1})
	for row in Scaling.POTIONS:
		for id in row:
			var sid := str(id)
			if not seen.has(sid):
				seen[sid] = true
				items.append({"item": sid, "n": 1})
	for id in Scaling.spell_scrolls_for_floor(Scaling.MAX_FLOOR):
		var sid := str(id)
		if not seen.has(sid):
			seen[sid] = true
			items.append({"item": sid, "n": 1})
	if not seen.has(Scaling.BOOK_ID):
		items.append({"item": Scaling.BOOK_ID, "n": 1})
	var seats: Array = []
	for uid in UIDS:
		seats.append({
			"seat_uid": uid, "floors": 10, "best_floor": 10,
			"kills": 40, "revives": 3, "downs": 2,
			"loot": {"gold": 5000, "exp": 8000, "items": items},
		})
	return OnlineReward.make_run_result("run-heavy", 9000, "easy", 7, seats)


func _source_tests() -> void:
	check("online_loot: geen globale rand en geen save", _source_clean("res://scripts/net/online_loot.gd"))
	check("online_reward: geen globale rand en geen save", _source_clean("res://scripts/net/online_reward.gd"))


func _source_clean(path: String) -> bool:
	var re := RegEx.new()
	re.compile("(?<![\\w.])(randf|randi|randf_range|randi_range|randfn|randomize)\\s*\\(")
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for line in lines:
		var code := line.get_slice("#", 0)
		if code.strip_edges() == "":
			continue
		if re.search(code) != null:
			return false
		if code.contains("FileAccess") or code.contains("GameState"):
			return false
	return true


# ---------------------------------------------------------------- solo-staat
func _capture_state() -> Dictionary:
	return {
		"gold": GameState.gold,
		"inventory": GameState.inventory.duplicate(true),
		"party": GameState.party.duplicate(true),
		"flags": GameState.story_flags.duplicate(true),
		"floor": GameState.dungeon100_floor,
	}


func _state_unchanged(before: Dictionary) -> void:
	check("solo-goud ongewijzigd", GameState.gold == int(before["gold"]))
	check("solo-inventaris ongewijzigd", GameState.inventory == before["inventory"])
	check("party en verhaalvlaggen ongewijzigd", GameState.party == before["party"] and GameState.story_flags == before["flags"])
	check("solo-verdieping teruggezet", GameState.dungeon100_floor == int(before["floor"]))


func _story_paths() -> Array:
	var out: Array = []
	for n in [1, 2, 3, 4]:
		out.append("user://save_%d.json" % n)
		out.append("user://autosave_%d.json" % n)
	out.append("user://autosave.json")
	out.append(GameState.save_path)
	out.append(GameState.autosave_path)
	return out


func _write_story_sentinels() -> void:
	var seen := {}
	var i := 0
	for path in _story_paths():
		var p := str(path)
		if p == "" or seen.has(p):
			continue
		seen[p] = true
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f == null:
			continue
		f.store_string("STORY-SENTINEL-%d" % i)
		f.close()
		i += 1


func _snap_user() -> Dictionary:
	var out := {}
	_snap_dir("user://", out)
	return out


func _snap_dir(path: String, out: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var child := path.path_join(name)
			if dir.current_is_dir():
				_snap_dir(child, out)
			else:
				out[child] = FileAccess.get_file_as_bytes(child)
		name = dir.get_next()
	dir.list_dir_end()


func _is_story_file(base: String) -> bool:
	return base.begins_with("save_") or base.contains("save_") or base.begins_with("autosave") or base.contains("autosave") or base == "online_profile.json"


func _files_unchanged(before: Dictionary) -> void:
	var after := _snap_user()
	var same := true
	var story_hit := 0
	for k in before.keys():
		var base := str(k).get_file()
		if not _is_story_file(base):
			continue
		story_hit += 1
		if not after.has(k) or (after[k] as PackedByteArray) != (before[k] as PackedByteArray):
			same = false
			print("STORY-DIFF %s" % k)
	for k in after.keys():
		var base := str(k).get_file()
		if not _is_story_file(base):
			continue
		if not before.has(k):
			same = false
			print("STORY-NEW %s" % k)
	check("verhaal-saves byte-gelijk na de run", same and story_hit >= 5)
