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
	check("gewicht Easy 1 (voorstel)", is_equal_approx(OnlineReward.profile_exp_for(7, "easy"), 7.0))
	check("gewicht Normal 1,5 (voorstel)", is_equal_approx(OnlineReward.profile_exp_for(7, "normal"), 10.5))
	check("gewicht Hard 2 (voorstel)", is_equal_approx(OnlineReward.profile_exp_for(7, "hard"), 14.0))
	check("Classic / onbekende modus geeft 0", is_equal_approx(OnlineReward.profile_exp_for(10, "classic"), 0.0))
	var done := OnlineReward.make_bundle("sess", 1, "easy", {"seat_uid": "u", "floors": 10, "best_floor": 10})
	var partial := OnlineReward.make_bundle("sess", 1, "easy", {"seat_uid": "u", "floors": 9, "best_floor": 9})
	check("voltooide Easy: één placeholder-unlock", done["unlocks"] == [OnlineReward.UNLOCK_EASY])
	check("onvoltooide Easy: geen unlock", (partial["unlocks"] as Array).is_empty() and is_equal_approx(partial["profile_exp"], 9.0))
	var normal := OnlineReward.make_bundle("sess", 2, "normal", {"seat_uid": "u", "floors": 50, "best_floor": 50})
	var hard := OnlineReward.make_bundle("sess", 3, "hard", {"seat_uid": "u", "floors": 100, "best_floor": 100})
	check("voltooide Normal en Hard: eigen placeholder", normal["unlocks"] == [OnlineReward.UNLOCK_NORMAL] and hard["unlocks"] == [OnlineReward.UNLOCK_HARD])
	check("profile_exp Normal 75 en Hard 200", is_equal_approx(normal["profile_exp"], 75.0) and is_equal_approx(hard["profile_exp"], 200.0))
	var rich := {
		"seat_uid": "u", "floors": 2, "best_floor": 2, "kills": 9,
		"loot": {"gold": 500, "exp": 800, "items": [{"item": "drankje", "n": 3}]},
	}
	var slim := OnlineReward.make_bundle("sess", 4, "easy", rich)
	var slim_json := JSON.stringify(slim)
	check("bundle heeft alleen rang en cosmetica", OnlineReward.bundle_clean(slim) and slim.size() == OnlineReward.BUNDLE_KEYS.size())
	check("geen items of stats in de bundle", not slim.has("items") and not slim.has("gold") and not slim.has("kills") and not slim_json.contains("drankje") and not slim_json.contains("\"atk\""))
	var profile := _profile("u")
	var p1: Dictionary = OnlineReward.apply_bundle(profile, done)
	var p2: Dictionary = OnlineReward.apply_bundle(p1, done)
	check("apply laat het invoer-profiel staan", int(profile["slots"][0]["profile_exp"]) == 0 and (profile["slots"][0]["applied_grants"] as Array).is_empty())
	check("eerste apply zet exp, verdieping en unlock", is_equal_approx(p1["slots"][0]["profile_exp"], 10.0) and int(p1["slots"][0]["stats_seen"]["best_floor"]) == 10 and p1["slots"][0]["unlocks"] == [OnlineReward.UNLOCK_EASY])
	check("grant-sleutel is session+tick", p1["slots"][0]["applied_grants"] == [OnlineReward.grant_key("sess", 1)])
	check("tweede apply is een no-op", p1 == p2)
	check("runs en inventaris van het slot blijven af", int(p1["slots"][0]["stats_seen"]["runs"]) == 0 and not p1["slots"][0].has("items") and not p1["slots"][0].has("gold"))
	var again := done.duplicate(true)
	again["host_tick"] = 8
	var p3: Dictionary = OnlineReward.apply_bundle(p1, again)
	check("andere tick telt wel, unlock niet verdubbeld", is_equal_approx(p3["slots"][0]["profile_exp"], 20.0) and p3["slots"][0]["unlocks"] == [OnlineReward.UNLOCK_EASY])
	var foreign := done.duplicate(true)
	foreign["seat_uid"] = "iemand-anders"
	var p4: Dictionary = OnlineReward.apply_bundle(profile, foreign)
	check("bundle voor een andere uid is een no-op", int(p4["slots"][0]["profile_exp"]) == 0)
	var smuggle := done.duplicate(true)
	smuggle["items"] = [{"item": "drankje", "n": 1}]
	check("bundle met items wordt geweigerd", not OnlineReward.bundle_clean(smuggle))
	var p5: Dictionary = OnlineReward.apply_bundle(profile, smuggle)
	check("geweigerde bundle schrijft niets", (p5["slots"][0]["applied_grants"] as Array).is_empty() and int(p5["slots"][0]["profile_exp"]) == 0)
	var lore := done.duplicate(true)
	lore["unlocks"] = ["A fresh legend"]
	check("unlock moet een id zijn, geen tekst", not OnlineReward.bundle_clean(lore))
	var mid: Dictionary = OnlineReward.apply_bundle(profile, OnlineReward.make_bundle("sess", 5, "easy", {"seat_uid": "u", "floors": 4, "best_floor": 6}))
	var back: Dictionary = OnlineReward.apply_bundle(mid, OnlineReward.make_bundle("sess", 6, "easy", {"seat_uid": "u", "floors": 1, "best_floor": 2}))
	check("best_floor gaat niet omlaag", int(back["slots"][0]["stats_seen"]["best_floor"]) == 6)
	var reps: Array = _scripted(42)
	var result := OnlineReward.make_run_result("run-1", 1500, "easy", 42, reps)
	check("run-resultaat bevat per stoel verdiepingen, kills, revives, downs en buit", _result_fields(result))
	var bundles: Array = OnlineReward.bundles_for(result)
	var bundles_ok := bundles.size() == 4
	for b in bundles:
		var js := JSON.stringify(b)
		bundles_ok = bundles_ok and OnlineReward.bundle_clean(b) and not js.contains("drankje") and not b.has("items")
		bundles_ok = bundles_ok and is_equal_approx(float(b["profile_exp"]), 4.0)
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
			"look": {},
			"profile_exp": 0,
			"unlocks": [],
			"stats_seen": {"best_floor": 0, "runs": 0},
			"applied_grants": [],
		}],
	}


# ---------------------------------------------------------------- payload
func _payload_tests() -> void:
	var result := OnlineReward.make_run_result("run-1", 1500, "easy", 42, _scripted(42))
	var raw := OnlineReward.encode_payload(OnlineReward.KIND_RUN_RESULT, result)
	var back := OnlineReward.decode_payload(raw)
	check("RUN_RESULT roundtrip", bool(back["ok"]) and str(back["kind"]) == OnlineReward.KIND_RUN_RESULT and back["body"] == result)
	check("RUN_RESULT past in het relay-plafond (%d bytes)" % raw.size(), raw.size() > 0 and raw.size() <= OnlineReward.RELAY_MAX_BYTES)
	var bundle := OnlineReward.make_bundle("run-1", 1500, "normal", {"seat_uid": UIDS[0], "floors": 3, "best_floor": 4})
	check("Normal-bundle bewaart de halve exp", is_equal_approx(bundle["profile_exp"], 4.5))
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
