extends Node
## Modustabel van de online DLS (Easy/Normal/Hard). Geen solo-balans.
## Start: godot --path . -- --onlinedlsmodetest

const Modes := preload("res://scripts/online/online_dls_modes.gd")
const Floor := preload("res://scripts/online/online_dls_floor.gd")
const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const Rules := preload("res://scripts/dungeon/dungeon100_rules.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const Run := preload("res://scripts/online/online_dls_run.gd")
const Rust := preload("res://scripts/dungeon/dungeon100_rustpunt.gd")
const Revive := preload("res://scripts/coop/coop_revive.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const SeatCtrl := preload("res://scripts/coop/seat_controller.gd")
const CoopAvatar := preload("res://scripts/coop/coop_avatar.gd")

const EASY := {1: 1, 2: 12, 3: 23, 4: 34, 5: 45, 6: 55, 7: 66, 8: 77, 9: 88, 10: 99}
const CANON := [25, 50, 75, 99]
const NORMAL_REST := [10, 20, 30, 40]

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
	_data()
	_eff()
	_bosses()
	_rest()
	_exp_and_canon()
	_heals()
	await _online_rest_checks()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _data() -> void:
	var sim := Modes.sim()
	check("sim id dls", str(sim.get("id", "")) == "dls")
	check("vijand-cap 8", Modes.enemy_cap() == 8 and int(sim.get("enemy_cap", 0)) == 8)
	check("verdiepingen easy/normal/hard", Modes.floors("easy") == 10 and Modes.floors("normal") == 50 and Modes.floors("hard") == 100)
	check("PROPOSAL-teller is 100", Modes.PROPOSAL_MODE_EXP_NUMERATOR == 100)
	check("exp-factor 10/2/1", Modes.mode_exp_factor("easy") == 10 and Modes.mode_exp_factor("normal") == 2 and Modes.mode_exp_factor("hard") == 1)
	check("onbekende modus blijft leeg", Modes.floors("nope") == 0 and Modes.eff_floor("nope", 1) == 0 and Modes.boss_key("nope", 1) == 0 and not Modes.is_rest("nope", 1) and Modes.mode_exp_factor("nope") == 1)


func _eff() -> void:
	var easy_ok := true
	for f in EASY:
		if Modes.eff_floor("easy", int(f)) != int(EASY[f]):
			easy_ok = false
	check("easy eff 1→1, 2→12 … 10→99", easy_ok)
	var normal_ok := true
	for f in range(1, 51):
		if Modes.eff_floor("normal", f) != 2 * f - 1:
			normal_ok = false
	check("normal eff = 2f-1 (1→1, 5→9, 13→25, 25→49, 38→75, 50→99)", normal_ok
			and Modes.eff_floor("normal", 1) == 1 and Modes.eff_floor("normal", 5) == 9
			and Modes.eff_floor("normal", 13) == 25 and Modes.eff_floor("normal", 25) == 49
			and Modes.eff_floor("normal", 38) == 75 and Modes.eff_floor("normal", 50) == 99)
	var hard_ok := true
	for f in range(1, 101):
		if Modes.eff_floor("hard", f) != f:
			hard_ok = false
	check("hard eff = f (1..100)", hard_ok)


func _bosses() -> void:
	var easy_only := Modes.boss_key("easy", 10) == 10
	for f in range(1, 11):
		if f != 10 and Modes.boss_key("easy", f) != 0:
			easy_only = false
	check("easy: alleen verdieping 10 → sleutel 10", easy_only)
	check("easy sleutel 10 is Page Warden", str(Scaling.BOSSES[10]["name"]) == "Page Warden")
	var normal_ok := true
	var seen := {}
	for key in Scaling.boss_floors():
		@warning_ignore("integer_division")
		var f := (int(key) + 1) / 2
		seen[f] = true
		if Modes.boss_key("normal", f) != int(key):
			normal_ok = false
	for f in range(1, 51):
		if not seen.has(f) and Modes.boss_key("normal", f) != 0:
			normal_ok = false
	check("normal: f = (sleutel+1) div 2 voor alle 12 bazen", normal_ok and seen.size() == 12
			and Modes.boss_key("normal", 5) == 10 and Modes.boss_key("normal", 13) == 25
			and Modes.boss_key("normal", 25) == 50 and Modes.boss_key("normal", 38) == 75
			and Modes.boss_key("normal", 50) == 99)
	var hard_ok := true
	for f in range(1, 101):
		var want := f if Scaling.is_boss_floor(f) else 0
		if Modes.boss_key("hard", f) != want:
			hard_ok = false
	check("hard: bazen zoals solo", hard_ok and Scaling.boss_floors().size() == 12)


func _rest() -> void:
	var easy_ok := true
	for f in range(1, 11):
		if Modes.is_rest("easy", f) != (f == 5):
			easy_ok = false
	check("easy rust alleen op 5", easy_ok)
	var normal_ok := true
	for f in range(1, 51):
		if Modes.is_rest("normal", f) != (f in NORMAL_REST):
			normal_ok = false
	check("normal rust op 10/20/30/40", normal_ok)
	var hard_ok := true
	for f in range(1, 101):
		if Modes.is_rest("hard", f) != Rules.is_rest_floor(f):
			hard_ok = false
	check("hard rust zoals solo", hard_ok)


func _exp_and_canon() -> void:
	var base: Dictionary = GameData.ENEMIES["mosslijm"]
	for mode in ["easy", "normal", "hard"]:
		var eff := 12 if mode != "hard" else 12
		var preview: Dictionary = Floor.monster_preview(mode, "mosslijm", eff)
		var raw: Dictionary = Scaling.monster_stats(base, eff)
		var factor := Modes.mode_exp_factor(mode)
		var want := GameData.round_half_even(float(raw["exp"]) * float(factor))
		check("%s: exp-factor ×%d op mosslijm eff %d" % [mode, factor, eff],
				int(preview.get("online_exp_factor", 0)) == factor and int(preview["exp"]) == want
				and int(preview["max_hp"]) == int(raw["max_hp"]))
	for key in CANON:
		@warning_ignore("integer_division")
		var nf := (int(key) + 1) / 2
		var enemy := str(Scaling.BOSSES[key]["enemy"])
		var solo: Dictionary = Scaling.boss_stats(GameData.ENEMIES[enemy], int(key))
		var normal: Dictionary = Floor.boss_preview("normal", nf)
		var hard: Dictionary = Floor.boss_preview("hard", int(key))
		var same := _canon_same(normal, solo) and _canon_same(hard, solo) and _canon_same(normal, hard)
		check("canon-stats sleutel %d gelijk in normal (f %d) en hard" % [key, nf], same)
		var eff_normal := Modes.eff_floor("normal", nf)
		var via_eff: Dictionary = Scaling.boss_stats(GameData.ENEMIES[enemy], eff_normal)
		var uses_key := int(normal["max_hp"]) == int(solo["max_hp"])
		if eff_normal != int(key):
			uses_key = uses_key and int(normal["max_hp"]) != int(via_eff["max_hp"])
		check("sleutel %d volgt de baas-sleutel (eff %d)" % [key, eff_normal], uses_key)
		check("exp-factor op canon-baas %d (HP blijft canon)" % key,
				int(normal["exp"]) == GameData.round_half_even(float(solo["exp"]) * 2.0)
				and int(hard["exp"]) == int(solo["exp"])
				and int(normal["max_hp"]) == int(solo["max_hp"]))
	var warden: Dictionary = Floor.boss_preview("easy", 10)
	var solo10: Dictionary = Scaling.boss_stats(GameData.ENEMIES[str(Scaling.BOSSES[10]["enemy"])], 10)
	var voice: Dictionary = Scaling.boss_stats(GameData.ENEMIES[str(Scaling.BOSSES[99]["enemy"])], 99)
	check("easy 10 is Page Warden, niet The Voice (eff 99)",
			str(warden.get("name", "")) == "Page Warden" and int(warden["max_hp"]) == int(solo10["max_hp"])
			and int(warden["max_hp"]) != int(voice["max_hp"])
			and int(warden["exp"]) == GameData.round_half_even(float(solo10["exp"]) * 10.0))


func _heals() -> void:
	var loot := {"items": [{"item": "drankje", "n": 2}, {"item": "kort_zwaard", "n": 1}], "gold": 10}
	var easy: Dictionary = Floor.scale_heal_loot("easy", loot)
	var hard: Dictionary = Floor.scale_heal_loot("hard", loot)
	check("genees-items × exp-factor (easy ×10), uitrusting niet",
			int(easy["items"][0]["n"]) == 20 and int(easy["items"][1]["n"]) == 1 and int(easy["gold"]) == 10)
	check("hard laat het aantal genees-items staan", int(hard["items"][0]["n"]) == 2)
	check("bron-buit blijft staan", int(loot["items"][0]["n"]) == 2)


func _online_rest_checks() -> void:
	GameState.dungeon100_snapshot = {}
	GameState.coop_role = ""
	GameState.new_game("Dax")
	GameState.join_member("kael")
	Run.start("easy", 11)
	Run.floor_no = 5
	var packed := load(Run.SCENE) as PackedScene
	var node := packed.instantiate() as OnlineDlsRoom
	add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	node.set_process(false)
	if node.som != null:
		node.som.set_process(false)
	var rp := node.get_node_or_null("Objects/Rustpunt")
	check("easy 5 zet een Dungeon100Rustpunt", rp is Dungeon100Rustpunt)
	if rp == null:
		rp = Rust.create(Vector2i(2, 2))
		node.get_node("Objects").add_child(rp)
		await get_tree().process_frame
	var som: SomArena = node.som
	som.coop_mode = true
	som.coop_sim_host = true
	som.coop_local_slot = 0
	som.allies_enabled = false
	var sc := SeatCtrl.new()
	sc.configure("KAMER", true, 0)
	var dmax := int(GameState.member("dennis")["max_hp"])
	var kmax := int(GameState.member("kael")["max_hp"])
	var kmp := int(GameState.member("kael")["max_mp"])
	sc.assign([
		{"slot": 0, "uid": "host", "hero_id": "dennis", "controller": "local", "hp": 5, "mp": 0, "max_hp": dmax, "max_mp": 0},
		{"slot": 1, "uid": "guest", "hero_id": "kael", "controller": "remote", "hp": 0, "mp": 2, "max_hp": kmax, "max_mp": kmp},
	])
	som.seat_controller = sc
	som._coop_slots[0] = "dennis"
	som._coop_slots[1] = "kael"
	GameState.member("dennis")["hp"] = 5
	GameState.member("kael")["hp"] = 0
	GameState.member("kael")["mp"] = 2
	som._coop_sync_down_rows()
	var down: Dictionary = som._coop_down[1]
	down["down"] = true
	down["hp"] = 0
	down["revives"] = 1
	down["active"] = true
	down["participate"] = true
	sc.set_hp_mp(0, 5, 0)
	sc.set_hp_mp(1, 0, 2)
	var av := CoopAvatar.new()
	av.facing = Vector2i.DOWN
	av.position = Vector2(48, 48)
	node.add_child(av)
	som._coop_avatars[1] = av
	var hud := GameState.get_node_or_null("Dungeon100Hud")
	if hud != null:
		hud.set_process(false)
	GameState.dungeon100_floor = 50
	GameState.dungeon100_checkpoint = 30
	GameState.dungeon100_best = 44
	var saves := [0]
	GameState.game_saved.connect(func(_p, _ok): saves[0] += 1)
	var save_path := GameState.save_path
	var save_before := FileAccess.get_modified_time(save_path) if FileAccess.file_exists(save_path) else -1
	rp.interact(node.player)
	await get_tree().process_frame
	var living: Dictionary = som._coop_down[0]
	check("online rustpunt geneest de levende stoel tot vol HP",
			int(living.get("hp", 0)) == dmax and int(sc.hp_of(0)) == dmax and int(GameState.member("dennis")["hp"]) == dmax)
	check("online rustpunt vult MP van een stoel die MP heeft",
			int(GameState.member("kael")["mp"]) == kmp and int(sc.mp_of(1)) == kmp)
	check("online rustpunt laat de down-stoel opstaan",
			not bool(down.get("down", true)) and int(down.get("hp", 0)) == kmax and int(GameState.member("kael")["hp"]) == kmax)
	var snap := Codec.unpack_snapshot(som.coop_encode_snapshot(4))
	var wire_ok := true
	var seen := 0
	for row in snap.get("players", []):
		var slot := int(row.get("slot", -1))
		if slot != 0 and slot != 1:
			continue
		seen += 1
		var want := dmax if slot == 0 else kmax
		if int(row.get("hp", 0)) != want or Revive.flag_is_down(int(row.get("flags", 0))):
			wire_ok = false
	check("snapshot na rust: volle HP en geen down-vlag", wire_ok and seen == 2)
	GameState.member("kael")["hp"] = 1
	var guest := SomArena.new()
	guest.coop_mode = true
	guest.coop_sim_host = false
	guest._coop_slots[1] = "kael"
	var gbody := CoopAvatar.new()
	gbody.facing = Vector2i.DOWN
	gbody.position = Vector2(12, 12)
	add_child(guest)
	guest.add_child(gbody)
	guest._coop_avatars[1] = gbody
	guest.apply_coop_snapshot(snap)
	var grew: Dictionary = guest._coop_down[1] if guest._coop_down.has(1) else {}
	check("gast leest de snapshot: HP vol en niet down",
			int(GameState.member("kael")["hp"]) == kmax and not bool(grew.get("down", true)))
	check("online rustpunt laat dungeon100_checkpoint staan", GameState.dungeon100_checkpoint == 30)
	check("online rustpunt laat dungeon100_best staan", GameState.dungeon100_best == 44)
	var save_after := FileAccess.get_modified_time(save_path) if FileAccess.file_exists(save_path) else -1
	check("online rustpunt stelt geen solo-savevraag en schrijft niets",
			str(rp.last_result) == "online_rest" and not rp.last_activated and not Dialog.is_open
			and saves[0] == 0 and save_after == save_before)
	check("revive-teller blijft staan na een rustpunt", int(down.get("revives", -1)) == 1)
	if hud != null:
		hud.set_process(true)
	await _shut_dialog()
	node.queue_free()
	guest.queue_free()
	Run.stop()
	await _solo_rest_still()


func _solo_rest_still() -> void:
	Run.stop()
	GameState.coop_role = ""
	GameState.dungeon100_snapshot = {}
	GameState.new_game("Dax")
	GameState.join_member("lotte")
	GameState.dungeon100_floor = 20
	GameState.dungeon100_checkpoint = 10
	GameState.dungeon100_best = 10
	GameState.party[0]["hp"] = 1
	GameState.member("lotte")["hp"] = 3
	GameState.member("lotte")["mp"] = 1
	var rp: Node2D = Rust.create(Vector2i(3, 3))
	add_child(rp)
	await get_tree().process_frame
	var pl := Node2D.new()
	add_child(pl)
	var saves := [0]
	GameState.game_saved.connect(func(_p, _ok): saves[0] += 1)
	rp.interact(pl)
	var lmax := int(GameState.member("lotte")["max_hp"])
	var lmp := int(GameState.member("lotte")["max_mp"])
	check("solo rustpunt geneest nog en verhoogt het checkpoint",
			not Run.active and GameState.dungeon100_checkpoint == 20 and GameState.dungeon100_best == 20
			and int(GameState.party[0]["hp"]) == int(GameState.party[0]["max_hp"])
			and int(GameState.member("lotte")["hp"]) == lmax and int(GameState.member("lotte")["mp"]) == lmp
			and rp.last_activated)
	var saw := false
	for _i in 20:
		if Dialog.has_choices():
			saw = true
			break
		if not Dialog.is_open:
			break
		Dialog.advance()
		await get_tree().process_frame
	check("solo rustpunt vraagt nog om op te slaan", saw and Dialog.choices.size() == 2)
	if Dialog.has_choices():
		Dialog.choose(Dialog.choices.size() - 1)
	await get_tree().process_frame
	check("solo Nee slaat niet op", str(rp.last_result) == "declined" and saves[0] == 0
			and GameState.dungeon100_checkpoint == 20)
	await _shut_dialog()
	rp.queue_free()
	pl.queue_free()


func _shut_dialog() -> void:
	for _i in 12:
		if not Dialog.is_open:
			return
		if Dialog.has_choices():
			Dialog.choose(Dialog.choices.size() - 1)
		else:
			Dialog.advance()
		await get_tree().process_frame


func _canon_same(a: Dictionary, b: Dictionary) -> bool:
	if int(a.get("max_hp", -1)) != int(b.get("max_hp", -2)):
		return false
	if int(a.get("atk", -1)) != int(b.get("atk", -2)):
		return false
	if int(a.get("def", -1)) != int(b.get("def", -2)):
		return false
	return str(a.get("weak", [])) == str(b.get("weak", []))
