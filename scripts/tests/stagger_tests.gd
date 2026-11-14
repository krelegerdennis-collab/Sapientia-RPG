extends Node
## F2 stagger-meter (Action). Start: godot --headless --path . -- --staggertest

const SomStagger := preload("res://scripts/som/som_stagger.gd")
const SomStaggerData := preload("res://scripts/data/som_stagger_data.gd")
const SomFeelData := preload("res://scripts/data/som_feel_data.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")

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
	_data_tests()
	_fill_tests()
	_decay_tests()
	_wankel_tests()
	_immunity_tests()
	_golem_excluded_tests()
	_determinism_tests()
	_codec_tests()
	_sim_metrics()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _blank_entry(max_hp: int = 40, unique := false) -> Dictionary:
	var d := {"max_hp": max_hp, "def": 2, "unique": unique}
	var e := {"hp": max_hp, "data": d, "golem": null}
	SomStagger.init_entry(e)
	return e


func _data_tests() -> void:
	check("data: hit1 fill", SomStaggerData.fill_for_kind(SomStaggerData.KIND_HIT1) == 8)
	check("data: hit2 fill", SomStaggerData.fill_for_kind(SomStaggerData.KIND_HIT2) == 10)
	check("data: finisher fill", SomStaggerData.fill_for_kind(SomStaggerData.KIND_FINISHER) == 22)
	check("data: heavy L1/L2", SomStaggerData.fill_for_kind(SomStaggerData.KIND_HEAVY_L1) == 30
			and SomStaggerData.fill_for_kind(SomStaggerData.KIND_HEAVY_L2) == 45)
	check("data: spreuk fill", SomStaggerData.fill_for_kind(SomStaggerData.KIND_SPELL) == 5)
	check("data: perfect-counter klaar", SomStaggerData.FILL_PERFECT_COUNTER == 20)
	check("data: wankel #FF8A3D", SomFeelData.COL_FINISHER.is_equal_approx(Color("#FF8A3D")))
	check("data: max normaal/baas", SomStaggerData.max_meter({}, null) == 100)


func _fill_tests() -> void:
	var e := _blank_entry()
	if SomStagger.apply_hit(e, null, e["data"], SomStaggerData.KIND_HIT1):
		check("fill: hit1 triggert niet meteen wankel", false)
	else:
		check("fill: hit1 +8", int(e["stg"]) == 8)
	e["stg"] = 78
	var entered := SomStagger.apply_hit(e, null, e["data"], SomStaggerData.KIND_FINISHER)
	check("fill: finisher naar wankel drempel", entered)
	if entered:
		SomStagger.enter_wankel(e)
	check("fill: wankel ticks", int(e["stg_wankel"]) == SomStaggerData.WANKEL_TICKS)


func _decay_tests() -> void:
	var e := _blank_entry()
	e["stg"] = 40
	e["stg_idle"] = 60
	SomStagger.tick_entry(e, false)
	check("decay: geen verval op tick 60", int(e["stg"]) == 40)
	SomStagger.tick_entry(e, false)
	check("decay: -1 na 62 idle ticks", int(e["stg"]) == 39)


func _wankel_tests() -> void:
	var e := _blank_entry()
	SomStagger.enter_wankel(e)
	var left := SomStaggerData.WANKEL_TICKS
	var ticks := 0
	while int(e.get("stg_wankel", 0)) > 0:
		SomStagger.tick_entry(e, false)
		ticks += 1
	check("wankel: duur 90 ticks", ticks == left)
	check("wankel: schade x1.3", absf(SomStagger.damage_multiplier(e) - 1.0) < 0.001 or SomStaggerData.in_wankel(e))
	e["stg_wankel"] = 10
	check("wankel: multiplier actief", absf(SomStagger.damage_multiplier(e) - SomStaggerData.WANKEL_DAMAGE_MULT) < 0.001)


func _immunity_tests() -> void:
	var e := _blank_entry()
	SomStagger.enter_wankel(e)
	while int(e.get("stg_wankel", 0)) > 0:
		SomStagger.tick_entry(e, false)
	check("immuniteit: meter na wankel 0", int(e["stg"]) == 0)
	check("immuniteit: start 180 ticks", int(e["stg_immune"]) == SomStaggerData.IMMUNE_TICKS)
	var before := int(e["stg"])
	SomStagger.apply_hit(e, null, e["data"], SomStaggerData.KIND_FINISHER)
	check("immuniteit: geen vulling", int(e["stg"]) == before)


func _golem_excluded_tests() -> void:
	var e := _blank_entry()
	e["golem"] = true
	var before := int(e["stg"])
	SomStagger.tick_entry(e, true)
	SomStagger.apply_hit(e, null, e["data"], SomStaggerData.KIND_HEAVY_L2)
	check("Golem: geen tick/ fill", int(e["stg"]) == before and not e.has("stg_wankel") or int(e.get("stg_wankel", 0)) == 0)


func _determinism_tests() -> void:
	var logs: Array = []
	for _run in 2:
		var e := _blank_entry()
		var seq: PackedStringArray = []
		for _i in 13:
			SomStagger.apply_hit(e, null, e["data"], SomStaggerData.KIND_HIT1)
			SomStagger.tick_entry(e, false)
			seq.append("%d,%d,%d" % [int(e.get("stg", 0)), int(e.get("stg_wankel", 0)), int(e.get("stg_immune", 0))])
		logs.append("|".join(seq))
	check("determinisme: zelfde seed → zelfde ticks", logs.size() == 2 and logs[0] == logs[1])


func _codec_tests() -> void:
	var row: Dictionary = {"idx": 0, "x": 0, "y": 0, "hp": 50, "pose": 0, "target_slot": 0,
			"atk_id": 0, "phase": 0, "t": 0, "ox": 0, "oy": 0, "dir_x": 0, "dir_y": 0,
			"stg": 77, "stg_wankel": 12, "stg_immune": 0}
	var raw: PackedByteArray = Codec.pack_snapshot(9, [], [row])
	var snap: Dictionary = Codec.unpack_snapshot(raw)
	check("codec v2 version", int(snap.get("codec_version", -1)) == Protocol.SNAPSHOT_CODEC_VERSION)
	var er: Dictionary = (snap.get("enemies", []) as Array)[0]
	check("codec stg velden", int(er.get("stg", -1)) == 77 and int(er.get("stg_wankel", -1)) == 12)


func _sim_metrics() -> void:
	## Lichtgewicht keten-microsim (SomStagger zelf, geen volledige action_sim-kamer).
	var e := _blank_entry()
	var wankels := 0
	var dmg_total := 0
	var dmg_wankel := 0
	var room_ticks := 0
	var kinds: Array = [SomStaggerData.KIND_HIT1, SomStaggerData.KIND_HIT2, SomStaggerData.KIND_FINISHER]
	for _round in 12:
		if SomStaggerData.immune(e):
			SomStagger.tick_entry(e, false)
			room_ticks += 1
			continue
		var kind: int = kinds[_round % kinds.size()]
		var in_w := SomStaggerData.in_wankel(e)
		var dmg := 10
		if in_w:
			dmg = roundi(float(dmg) * SomStaggerData.WANKEL_DAMAGE_MULT)
			dmg_wankel += dmg
		dmg_total += dmg
		if not in_w and not SomStaggerData.immune(e):
			if SomStagger.apply_hit(e, null, e["data"], kind):
				SomStagger.enter_wankel(e)
				wankels += 1
		SomStagger.tick_entry(e, false)
		room_ticks += 1
	var share := float(dmg_wankel) / float(maxi(1, dmg_total))
	print("METRIC wankels_per_room=%.2f damage_wankel_share=%.1f%% room_ticks=%d" % [float(wankels), share * 100.0, room_ticks])
	check("metrics: minstens 1 wankel in micro-sim", wankels >= 1)