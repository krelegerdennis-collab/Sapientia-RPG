extends Node
## Down, revive en wipe in online co-op (M8a).
## Start: godot --path . -- --revivetest [--shots=/pad]

const Protocol := preload("res://scripts/net/net_protocol.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const Sim := preload("res://scripts/net/action_sandbox_sim.gd")
const Revive := preload("res://scripts/coop/coop_revive.gd")
const Seat := preload("res://scripts/coop/coop_seat.gd")
const Session := preload("res://scripts/net/action_coop_session.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const SomAlly := preload("res://scripts/som/som_ally.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const Ring := preload("res://scripts/coop/coop_revive_ring.gd")

## Dax in de SomAlly-test heeft een facing; de kale CharacterBody2D niet.
class _FaceBody extends CharacterBody2D:
	var facing := Vector2i.DOWN


var failures := 0
var passes := 0
var shots := ""
var _wipe_kinds: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.get_slice("=", 1)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	_constant_tests()
	_down_instead_of_wipe_tests()
	_channel_tick_tests()
	_break_and_phoenix_tests()
	_wipe_tests()
	_snapshot_tests()
	_input_tests()
	_ai_priority_tests()
	_revive_limit_tests()
	_solo_ko_tests()
	await _som_ally_tests()
	await _ring_tests()
	_session_signal_tests()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _roster() -> Array:
	return [
		{"slot": 0, "character_id": "dennis", "peer_id": 1},
		{"slot": 1, "character_id": "lotte", "peer_id": 2},
		{"slot": 2, "character_id": "noor", "peer_id": 3},
	]


func _sim() -> Sim:
	var sim := Sim.new()
	sim.reset(_roster(), 7)
	return sim


func _stand_together(sim: Sim, helper: int, target: int) -> void:
	sim.players[helper]["x"] = int(sim.players[target]["x"])
	sim.players[helper]["y"] = int(sim.players[target]["y"])


func _constant_tests() -> void:
	check("SIM_HZ 60, gelijk aan het protocol", Revive.SIM_HZ == 60 and Revive.SIM_HZ == Protocol.SIM_HZ)
	check("kanaal 2,0 s = 120 ticks", Revive.CHANNEL_TICKS == int(Revive.CHANNEL_SEC * Revive.SIM_HZ) and Revive.CHANNEL_TICKS == 120)
	check("Heal-kanaal 1,2 s = 72 ticks", Revive.CHANNEL_HEAL_TICKS == int(Revive.CHANNEL_HEAL_SEC * Revive.SIM_HZ) and Revive.CHANNEL_HEAL_TICKS == 72)
	check("30% van 100 HP = 30", Revive.revive_hp(100) == 30)
	check("bereik is 1 tegel (16 px)", Revive.RANGE_PX == 16)
	check("VOORSTEL: bleed af -> blijven liggen", Revive.BLEED_END_STAY_DOWN)
	check("VOORSTEL: andere AI alleen zonder Heal", Revive.AI_OTHERS_ONLY_WITHOUT_HEAL)
	check("bleed 15 s = 900 ticks", Revive.BLEED_TICKS == int(Revive.BLEED_SEC * Revive.SIM_HZ))


func _down_instead_of_wipe_tests() -> void:
	var sim := _sim()
	sim.players[0]["hp"] = 0
	sim.host_tick([])
	check("0 HP in co-op is down, geen wipe", bool(sim.players[0]["down"]) and not sim.wiped)
	check("down-vlag in de stoel", (int(sim.players[0]["flags"]) & Protocol.FLAG_DOWN) != 0)
	check("andere stoelen blijven staan", not bool(sim.players[1]["down"]) and int(sim.players[1]["hp"]) == Sim.PLAYER_HP)
	for _i in 30:
		sim.host_tick([])
	check("één staande stoel: nog geen wipe", not sim.wiped and bool(sim.players[0]["down"]))


func _channel_tick_tests() -> void:
	var sim := _sim()
	sim.players[0]["hp"] = 0
	_stand_together(sim, 1, 0)
	# Helper is lotte (Heal): 72 ticks.
	for _i in Revive.CHANNEL_HEAL_TICKS - 1:
		sim.host_tick([])
	check("Heal na 71 ticks nog down", bool(sim.players[0]["down"]) and int(sim.players[0]["hp"]) == 0)
	check("Heal-teller staat op 71", int(sim.players[1]["channel_ticks"]) == Revive.CHANNEL_HEAL_TICKS - 1)
	sim.host_tick([])
	check("Heal op tick 72: 30% HP en niet meer down",
			not bool(sim.players[0]["down"]) and int(sim.players[0]["hp"]) == 30)
	var slow := _sim()
	# De host is de helper. De sandbox-vijand jaagt op de host en zou het kanaal
	# anders breken; deze test meet alleen de tick-teller.
	slow.enemies.clear()
	slow.players[1]["hp"] = 0
	_stand_together(slow, 0, 1)
	for _i in Revive.CHANNEL_TICKS - 1:
		slow.host_tick([])
	check("niet-Heal na 119 ticks nog down", bool(slow.players[1]["down"]))
	check("niet-Heal-teller staat op 119", int(slow.players[0]["channel_ticks"]) == Revive.CHANNEL_TICKS - 1)
	slow.host_tick([])
	check("niet-Heal op tick 120: 30% HP", not bool(slow.players[1]["down"]) and int(slow.players[1]["hp"]) == 30)


func _break_and_phoenix_tests() -> void:
	var sim := _sim()
	sim.players[0]["hp"] = 0
	_stand_together(sim, 1, 0)
	for _i in 40:
		sim.host_tick([])
	check("kanaal loopt (40)", int(sim.players[1]["channel_ticks"]) == 40)
	sim.players[1]["x"] = int(sim.players[0]["x"]) + Revive.RANGE_PX + 8
	sim.host_tick([])
	check("wegstappen breekt het kanaal", int(sim.players[1]["channel_ticks"]) == 0 and bool(sim.players[0]["down"]))
	_stand_together(sim, 1, 0)
	for _i in 20:
		sim.host_tick([])
	var hp_before := int(sim.players[1]["hp"])
	sim.hurt_seat(1, 5)
	sim.host_tick([])
	check("treffer breekt het kanaal", int(sim.players[1]["channel_ticks"]) == 0 and int(sim.players[1]["hp"]) == hp_before - 5)
	check("doel blijft down na de treffer", bool(sim.players[0]["down"]))
	var feather := _sim()
	feather.players[0]["hp"] = 0
	feather.host_tick([])
	check("doel ligt voor de veer", bool(feather.players[0]["down"]))
	var ok := feather.use_phoenix(1, 0)
	check("Feniksveer is meteen (geen kanaal-ticks)", ok and not bool(feather.players[0]["down"]))
	check("Feniksveer gebruikt de bestaande 50%-fractie", int(feather.players[0]["hp"]) == 50)
	var guarded := int(feather.players[0]["hp"])
	feather.hurt_seat(0, 40)
	check("i-frames na de veer vangen de klap", int(feather.players[0]["hp"]) == guarded)
	feather.players[0]["iframes"] = 0
	feather.hurt_seat(0, 10)
	check("zonder i-frames komt de klap wel aan", int(feather.players[0]["hp"]) == guarded - 10)
	var bleed := _sim()
	bleed.players[0]["hp"] = 0
	bleed.host_tick([])
	bleed.players[0]["bleed_ticks"] = 1
	bleed.host_tick([])
	check("bleed af: blijft liggen, geen permadeath-wipe",
			bool(bleed.players[0]["down"]) and bool(bleed.players[0]["bleed_expired"]) and int(bleed.players[0]["hp"]) == 0 and not bleed.wiped)
	bleed.apply_rest()
	check("rustpunt haalt de down-stoel overeind op max HP",
			not bool(bleed.players[0]["down"]) and int(bleed.players[0]["hp"]) == Sim.PLAYER_HP)


func _wipe_tests() -> void:
	var sim := _sim()
	sim.players[0]["hp"] = 0
	sim.players[1]["hp"] = 0
	sim.players[2]["hp"] = 5
	var before := sim.tick
	sim.host_tick([])
	check("wipe nog niet zolang één stoel HP heeft", not sim.wiped and sim.wipe_tick == -1)
	check("de twee anderen liggen wel", bool(sim.players[0]["down"]) and bool(sim.players[1]["down"]))
	sim.players[2]["hp"] = 0
	sim.host_tick([])
	check("wipe op de tick dat de laatste down gaat", sim.wiped and sim.wipe_tick == sim.tick and sim.tick == before + 2)
	var later := sim.wipe_tick
	sim.host_tick([])
	check("wipe-tick blijft de eerste tick", sim.wipe_tick == later)


func _snapshot_tests() -> void:
	var sim := _sim()
	sim.players[0]["hp"] = 0
	_stand_together(sim, 1, 0)
	for _i in 36:
		sim.host_tick([])
	var raw := sim.encode_snapshot()
	var snap := Codec.unpack_snapshot(raw)
	var down_flags := -1
	var help_flags := -1
	for row in snap.get("players", []):
		if int(row.get("slot", -1)) == 0:
			down_flags = int(row.get("flags", 0))
		elif int(row.get("slot", -1)) == 1:
			help_flags = int(row.get("flags", 0))
	check("snapshot bevat FLAG_DOWN", (down_flags & Protocol.FLAG_DOWN) != 0)
	check("snapshot-voortgang is 50% (36/72)", Revive.flag_progress(down_flags) == 50)
	check("helper heeft FLAG_CHANNEL", (help_flags & Protocol.FLAG_CHANNEL) != 0)
	var guest := Sim.new()
	guest.reset(_roster(), 7)
	guest.apply_snapshot(snap)
	check("gast ziet down na apply", bool(guest.players[0]["down"]))
	check("gast ziet dezelfde voortgang", int(guest.players[0]["channel_pct"]) == 50)
	var again := guest.encode_snapshot()
	var back := Codec.unpack_snapshot(again)
	var flags2 := 0
	for row in back.get("players", []):
		if int(row.get("slot", -1)) == 0:
			flags2 = int(row.get("flags", 0))
	check("down-vlag overleeft een tweede roundtrip", (flags2 & Protocol.FLAG_DOWN) != 0)


func _input_tests() -> void:
	var sim := _sim()
	sim.players[0]["hp"] = 0
	sim.host_tick([])
	var x0 := int(sim.players[0]["x"])
	var x1 := int(sim.players[1]["x"])
	for _i in 15:
		sim.host_tick([
			{"slot": 0, "stick": Vector2(1, 0), "buttons": Codec.BTN_ATTACK, "lock_idx": -1},
			{"slot": 1, "stick": Vector2(1, 0), "buttons": 0, "lock_idx": -1},
		])
	check("input van een down-stoel wordt genegeerd", int(sim.players[0]["x"]) == x0)
	check("levende stoel beweegt nog", int(sim.players[1]["x"]) > x1)


func _ai_priority_tests() -> void:
	check("Heal-AI revivet altijd als er iemand ligt", Revive.ai_should_revive("lotte", true, true))
	check("Heal-AI revivet niet als niemand ligt", not Revive.ai_should_revive("lotte", true, false))
	check("andere AI revivet niet zolang Heal leeft", not Revive.ai_should_revive("dennis", true, true))
	check("andere AI revivet als er geen Heal leeft", Revive.ai_should_revive("noor", false, true))
	check("seat_controller.gd is er; SomAlly stopt de eigen haak", Revive.seat_controller_present())
	var sim := _sim()
	sim.enemies.clear()
	sim.players[0]["controller"] = Seat.CONTROLLER_AI
	sim.players[1]["controller"] = Seat.CONTROLLER_AI
	sim.players[2]["hp"] = 0
	sim.players[2]["x"] = 200
	sim.players[0]["x"] = 40
	sim.players[1]["x"] = 200
	sim.players[0]["y"] = 96
	sim.players[1]["y"] = 96
	sim.players[2]["y"] = 96
	sim.host_tick([])
	var far := Revive.query_revive(sim.players, sim.players[0])
	check("query buiten bereik is leeg", not bool(far.get("ok", false)) and int(far.get("slot", 0)) == -1)
	var heal_q := Revive.query_revive(sim.players, sim.players[1])
	check("Heal-AI ziet de down-stoel binnen bereik", bool(heal_q.get("ok", false)) and int(heal_q.get("slot", -1)) == 2)
	sim.players[0]["x"] = 200
	var blocked := Revive.query_revive(sim.players, sim.players[0])
	check("andere AI mag niet reviven zolang Heal leeft", not bool(blocked.get("ok", false)))
	check("begin_channel weigert die AI", not Revive.begin_channel(sim.players, sim.players[0], 2))
	sim.players[1]["hp"] = 0
	sim.players[1]["down"] = true
	sim.players[1]["x"] = 400
	var open := Revive.query_revive(sim.players, sim.players[0])
	check("zonder levende Heal wijst de query de down-stoel", bool(open.get("ok", false)) and int(open.get("slot", -1)) == 2)
	check("begin_channel start dat kanaal", Revive.begin_channel(sim.players, sim.players[0], 2))
	for _i in 10:
		sim.host_tick([])
	check("AI-kanaal loopt alleen na begin_channel", int(sim.players[0]["channel_ticks"]) == 10)
	Revive.end_channel(sim.players[0])
	check("end_channel zet de teller terug", int(sim.players[0]["channel_ticks"]) == 0 and int(sim.players[0]["channel_target"]) == -1)
	check("doel ligt nog na end_channel", bool(sim.players[2]["down"]))
	check("begin_channel hervat", Revive.begin_channel(sim.players, sim.players[0], 2))
	for _i in Revive.CHANNEL_TICKS - 1:
		sim.host_tick([])
	check("niet-Heal-AI staat op 119 na de herstart", int(sim.players[0]["channel_ticks"]) == Revive.CHANNEL_TICKS - 1)
	sim.host_tick([])
	check("niet-Heal-AI op tick 120: 30% HP", not bool(sim.players[2]["down"]) and int(sim.players[2]["hp"]) == 30)


func _revive_limit_tests() -> void:
	var sim := _sim()
	sim.enemies.clear()
	sim.players[0]["hp"] = 0
	_stand_together(sim, 1, 0)
	for _i in Revive.CHANNEL_HEAL_TICKS:
		sim.host_tick([])
	check("eerste revive van de stoel lukt",
			not bool(sim.players[0]["down"]) and int(sim.players[0]["hp"]) == 30 and int(sim.players[0]["revives"]) == 1)
	sim.players[0]["hp"] = 0
	sim.players[0]["iframes"] = 0
	_stand_together(sim, 1, 0)
	for _i in 40:
		sim.host_tick([])
	check("tweede revive van dezelfde speler wordt geweigerd",
			bool(sim.players[0]["down"]) and int(sim.players[0]["hp"]) == 0 and int(sim.players[1]["channel_ticks"]) == 0)
	check("ring start niet voor een geweigerde stoel",
			Revive.flag_progress(int(sim.players[0]["flags"])) == 0
			and (int(sim.players[1]["flags"]) & Protocol.FLAG_CHANNEL) == 0)
	sim.players[2]["hp"] = 0
	sim.players[2]["iframes"] = 0
	sim.players[2]["x"] = int(sim.players[1]["x"])
	sim.players[2]["y"] = int(sim.players[1]["y"])
	for _i in Revive.CHANNEL_HEAL_TICKS:
		sim.host_tick([])
	check("een andere speler kan nog gerevived worden",
			not bool(sim.players[2]["down"]) and int(sim.players[2]["hp"]) == 30
			and int(sim.players[2]["revives"]) == 1 and bool(sim.players[0]["down"]))
	sim.reset(_roster(), 7)
	sim.enemies.clear()
	check("teller staat op 0 na een nieuwe run",
			int(sim.players[0]["revives"]) == 0 and int(sim.players[1]["revives"]) == 0 and int(sim.players[2]["revives"]) == 0)
	sim.players[0]["hp"] = 0
	_stand_together(sim, 1, 0)
	for _i in Revive.CHANNEL_HEAL_TICKS:
		sim.host_tick([])
	check("na een nieuwe run mag dezelfde stoel weer",
			not bool(sim.players[0]["down"]) and int(sim.players[0]["hp"]) == 30 and int(sim.players[0]["revives"]) == 1)
	var ai := _sim()
	ai.enemies.clear()
	ai.players[1]["controller"] = Seat.CONTROLLER_AI
	ai.players[0]["x"] = 0
	ai.players[0]["y"] = 0
	ai.players[2]["hp"] = 0
	ai.players[2]["x"] = 200
	ai.players[2]["y"] = 96
	ai.players[1]["x"] = 200
	ai.players[1]["y"] = 96
	ai.host_tick([])
	check("AI begin_channel start de eerste revive", Revive.begin_channel(ai.players, ai.players[1], 2))
	for _i in Revive.CHANNEL_HEAL_TICKS - 1:
		ai.host_tick([])
	ai.host_tick([])
	check("AI-revive telt mee voor de limiet",
			not bool(ai.players[2]["down"]) and int(ai.players[2]["revives"]) == 1)
	ai.players[2]["hp"] = 0
	ai.players[2]["iframes"] = 0
	_stand_together(ai, 1, 2)
	ai.host_tick([])
	check("AI weigert de tweede revive van dezelfde stoel", not Revive.begin_channel(ai.players, ai.players[1], 2))
	for _i in 20:
		ai.host_tick([])
	check("AI-kanaal vult de ring niet na de limiet",
			bool(ai.players[2]["down"]) and int(ai.players[2]["hp"]) == 0
			and int(ai.players[1]["channel_ticks"]) == 0
			and Revive.flag_progress(int(ai.players[2]["flags"])) == 0)


func _solo_ko_tests() -> void:
	GameState.new_game("Dax")
	GameState.join_member("lotte")
	var arena := SomArena.new()
	arena.coop_mode = false
	var before_battle := GameState.in_battle
	GameState.member("dennis")["hp"] = 0
	arena.last_text = ""
	arena.on_member_hp_zero("dennis")
	check("solo: bestaande KO-tekst", arena.last_text == SomData.TXT_KO % str(GameState.member("dennis").get("name", "")))
	check("solo: geen co-op-wipe", not arena.coop_wiped and arena._coop_down.is_empty())
	check("solo: party nog niet game-over (Seren leeft)", not arena.down and GameState.in_battle == before_battle)
	check("solo: Dax blijft op 0 HP", int(GameState.member("dennis")["hp"]) == 0)
	arena.coop_mode = true
	arena.coop_sim_host = true
	arena._coop_slots[0] = "dennis"
	arena._coop_slots[1] = "lotte"
	GameState.member("dennis")["hp"] = 40
	GameState.member("lotte")["hp"] = int(GameState.member("lotte")["max_hp"])
	arena.last_text = ""
	var kinds: Array[String] = []
	arena.coop_run_result.connect(func(k: String) -> void: kinds.append(k))
	GameState.member("dennis")["hp"] = 0
	arena.on_member_hp_zero("dennis")
	check("co-op: geen solo-KO-tekst", arena.last_text == "")
	check("co-op: stoel is down, arena.down blijft uit",
			bool((arena._coop_down[0] as Dictionary).get("down", false)) and not arena.down)
	check("co-op: nog geen wipe met Seren overeind", kinds.is_empty() and not arena.coop_wiped)
	GameState.member("lotte")["hp"] = 0
	arena.on_member_hp_zero("lotte")
	check("co-op: wipe-signaal als iedereen down is", kinds.size() == 1 and kinds[0] == Revive.RESULT_WIPE)
	check("co-op-wipe roept geen end_battle", not arena.down and GameState.in_battle == before_battle)
	GameState.member("dennis")["hp"] = 0
	(arena._coop_down[0] as Dictionary)["down"] = true
	(arena._coop_down[0] as Dictionary)["hp"] = 0
	GameState.member("dennis")["hp"] = 16
	arena._coop_clear_down_hero("dennis")
	check("Feniksveer-pad wist down meteen", not bool((arena._coop_down[0] as Dictionary).get("down", false)))


func _som_ally_tests() -> void:
	GameState.new_game("Dax")
	GameState.join_member("lotte")
	var arena := SomArena.new()
	arena.coop_mode = true
	arena.coop_sim_host = true
	arena.allies_enabled = true
	var body := _FaceBody.new()
	body.position = Vector2(8, 0)
	arena.player = body
	var down := Seat.make(0, "dennis", Seat.CONTROLLER_HUMAN)
	down["x"] = 70
	down["y"] = 0
	down["hp"] = 0
	down["max_hp"] = 100
	down["down"] = true
	down["active"] = true
	arena._coop_down[0] = down
	arena._coop_slots[0] = "dennis"
	var ally: CharacterBody2D = SomAlly.new()
	add_child(arena)
	arena.add_child(body)
	arena.add_child(ally)
	arena.allies.append(ally)
	ally.setup(arena, "lotte", 0)
	var x0 := ally.position.x
	for _i in 12:
		ally.tick(1.0 / 60.0)
		await get_tree().physics_frame
	check("SomAlly loopt niet zelf nu seat_controller.gd er is", ally.position.x <= x0 + 4.0)
	check("SomAlly blijft in follow, geen extra state", ally.state == SomAlly.ST_FOLLOW)
	check("SomAlly slaat niet terwijl de haak bij M6 ligt", ally.attacks == 0)
	arena.queue_free()


func _ring_tests() -> void:
	var root := Node2D.new()
	add_child(root)
	var mod := CanvasModulate.new()
	mod.name = "WorldTint"
	root.add_child(mod)
	var ring: CanvasLayer = Ring.new()
	root.add_child(ring)
	await get_tree().process_frame
	var under_mod := false
	var cursor: Node = ring
	while cursor != null:
		if cursor is CanvasModulate:
			under_mod = true
		cursor = cursor.get_parent()
	check("ring is een CanvasLayer", ring is CanvasLayer)
	check("ring staat niet onder CanvasModulate", not under_mod and ring.get_parent() == root)
	check("ring-laag is 20", ring.layer == 20)
	var bar := ring.get_node_or_null("Ring") as TextureProgressBar
	check("ring is een TextureProgressBar", bar != null)
	var tex_under: Texture2D = bar.texture_under if bar != null else null
	var tex_ring: Texture2D = bar.texture_progress if bar != null else null
	check("textures geladen", tex_under != null and tex_ring != null)
	check("ring-art is 32x32",
			tex_under != null and tex_ring != null
			and tex_under.get_width() == 32 and tex_under.get_height() == 32
			and tex_ring.get_width() == 32 and tex_ring.get_height() == 32)
	check("fill_mode is 4", bar != null and bar.fill_mode == 4)
	check("range is 0-100", bar != null and bar.min_value == 0.0 and bar.max_value == 100.0)
	check("texture_filter is nearest", bar != null and bar.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	ring.show_channel(Vector2(48, 40), 0)
	await get_tree().process_frame
	check("ring verborgen bij 0%", bar != null and not bar.visible and ring.progress == 0 and not ring.shown)
	ring.show_channel(Vector2(48, 40), 60)
	await get_tree().process_frame
	await get_tree().process_frame
	check("ring zichtbaar boven 0%", bar != null and bar.visible and ring.progress == 60 and ring.shown and bar.value == 60.0)
	check("positie is world_pos min (16, 16)", bar != null and bar.position == Vector2(32, 24))
	await _shot_ring(ring)
	root.queue_free()


func _shot_ring(ring: CanvasLayer) -> void:
	# De ring hangt al als CanvasLayer in de hoofd-viewport. Een SubViewport met
	# UPDATE_ONCE pakte het frame vóór de boog en leverde alleen de achtergrond.
	await get_tree().process_frame
	await get_tree().process_frame
	var tex := get_viewport().get_texture()
	if tex == null:
		check("ring-screenshot", false)
		return
	var full := tex.get_image()
	var crop := full.get_region(Rect2i(0, 0, mini(96, full.get_width()), mini(72, full.get_height())))
	var drawn := false
	var bar := ring.get_node_or_null("Ring") as TextureProgressBar
	if bar != null:
		var origin := Vector2i(int(bar.position.x), int(bar.position.y))
		for y in 32:
			for x in 32:
				var px := origin.x + x
				var py := origin.y + y
				if px < 0 or py < 0 or px >= crop.get_width() or py >= crop.get_height():
					continue
				var c := crop.get_pixel(px, py)
				if c.a > 0.2 and (c.r > 0.15 or c.g > 0.15 or c.b > 0.15):
					drawn = true
					break
			if drawn:
				break
	check("ring-art staat in beeld", drawn)
	var out := "/opt/cursor/artifacts/revive_ring.png"
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	var err := crop.save_png(out)
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
		crop.save_png(shots.path_join("revive_ring.png"))
	check("ring-screenshot geschreven", err == OK and FileAccess.file_exists(out))


func _session_signal_tests() -> void:
	var sim := _sim()
	sim.players[0]["hp"] = 0
	sim.players[1]["hp"] = 0
	sim.players[2]["hp"] = 0
	sim.host_tick([])
	var sess := Session.new()
	sess.is_host = true
	sess.sim = sim
	var got: Array[String] = []
	sess.run_result.connect(func(k: String) -> void: got.append(k))
	sess.poll_result()
	sess.poll_result()
	check("sessie geeft één wipe-signaal", got.size() == 1 and got[0] == "wipe")
	sess.free()
