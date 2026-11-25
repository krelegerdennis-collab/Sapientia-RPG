extends Node
## Perf-bewijs (post-RC): vaste-tijd-captures van kaarten per lichtpreset, voor een pixelvergelijking
## voor/na. Niet geregistreerd: zet tijdelijk (niet committen) in scripts/game_state.gd naast --wm1budgettest:
##   ["--capfixed", "res://tools/perf/capture_fixed.gd", "CapFixed", "capfixed"],
## Start: godot --rendering-driver opengl3 --fixed-fps 60 --path . -- --capfixed
##   --out=/pad --tag=before [--only=map:preset,...]
## Bevriest: vaste fps + vaste frametelling, globale seed, licht-flikker uit, tegelanimaties op frame 0,
## daarna boom gepauzeerd en time_scale 0. Alles gelijk aan beide kanten; verder niets uitgezet.

const Wm1FrametimeScript := preload("res://scripts/perf/wm1_frametime.gd")
const MapLightingC := preload("res://scripts/map_lighting.gd")
const StoryData := preload("res://scripts/data/story_data.gd")

const CASES := [
	["woud_beek", "day"], ["woud_beek", "night"],
	["dorp_wilgendal", "day"], ["dorp_wilgendal", "night"],
	["huis_wilgendal", "day"], ["huis_wilgendal", "night"],
	["leven_ingang", "day"],
	# puzzelkamers (botsing 'Muren' samengevoegd): beeld moet gelijk blijven
	["archief_puzzel", "day"], ["berggrot_geheim", "day"], ["berggrot_grendel", "day"],
	["leven_v1_plaat", "day"], ["leven_v2_leeszaal", "day"], ["leven_v3_combi", "day"],
	# dorp: speler (en camera) bij de bosrand en de beek, zodat bomen en beekrand in beeld zijn
	["dorp_wilgendal", "day", Vector2i(4, 4)], ["dorp_wilgendal", "day", Vector2i(85, 51)],
	["dorp_wilgendal", "night", Vector2i(4, 24)], ["dorp_wilgendal", "day", Vector2i(60, 24)],
]

var sampler := Wm1FrametimeScript.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _arg(k: String, d := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % k):
			return a.get_slice("=", 1)
	return d


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	var out := _arg("out", "/tmp/capfixed")
	var tag := _arg("tag", "x")
	var only := _arg("only").split(",", false)
	DirAccess.make_dir_recursive_absolute(out)
	var rooms := {}
	for r in Wm1FrametimeScript.rooms():
		rooms[r["id"]] = r
	for c in CASES:
		var spot: Vector2i = c[2] if c.size() > 2 else Vector2i(-1, -1)
		var key := "%s:%s" % [c[0], c[1]]
		var naam := str(c[0]) if spot.x < 0 else "%s_at%d_%d" % [c[0], spot.x, spot.y]
		if not only.is_empty() and not (key in only):
			continue
		get_tree().paused = false
		Engine.time_scale = 1.0
		seed(1234)
		# boven StoryData.KLAAR stuurt Story de fase niet meer; dan geldt time_of_day bij setup (volle preset)
		GameState.story_step = maxi(int(GameState.story_step), int(StoryData.KLAAR))
		GameState.time_of_day = c[1]
		var ok := await sampler.enter_room(get_tree(), rooms[c[0]])
		if not ok:
			print("CAPFIXED %s LOADFAIL" % key)
			continue
		var cs := get_tree().current_scene
		if spot.x >= 0:
			var pl := cs.get_node_or_null("Objects/Player") as Node2D
			if pl:
				pl.position = Vector2(spot) * 16.0 + Vector2(8, 8)
			for cam in cs.find_children("*", "Camera2D", true, false):
				(cam as Camera2D).reset_smoothing()
		await _frames(30)
		var rig := cs.get_node_or_null("MapLightingRig")
		var phase := str(rig.get("_phase")) if rig else "-"
		if rig:
			var p: Dictionary = (rig.get("_preset") as Dictionary).duplicate()
			p["flicker"] = {}
			rig.set("_preset", p)
		for n in cs.find_children("*", "TileMapLayer", true, false):
			var ts := (n as TileMapLayer).tile_set
			if ts == null:
				continue
			for i in ts.get_source_count():
				var src := ts.get_source(ts.get_source_id(i)) as TileSetAtlasSource
				if src == null:
					continue
				for t in src.get_tiles_count():
					var ac := src.get_tile_id(t)
					if src.get_tile_animation_frames_count(ac) > 1:
						src.set_tile_animation_frames_count(ac, 1)
		await _frames(10)
		get_tree().paused = true
		Engine.time_scale = 0.0
		await _frames(5)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var f := "%s/%s__%s__%s.png" % [out, naam, c[1], tag]
		img.save_png(f)
		var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var split_n := cs.find_children("*_R*", "TileMapLayer", true, false).size()
		print("CAPFIXED %s phase=%s draw=%d split_layers=%d -> %s" % [key, phase, dc, split_n, f])
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().quit()
