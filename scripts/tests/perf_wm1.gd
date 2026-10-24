extends Node
## PROFILEER-MODUS voor WM1 (geen gameplay-test): laadt elke WM1-scène (Wilgendal, wereldkaart,
## Eerste Archief, Donker Woud, gevechten) en meet laadtijd, frametijd, draw calls, nodes en textuurgeheugen.
## Start:  godot --path . -- --perftest [--perf-frames=N] [--perf-only=id,id] [--csv=/pad.csv] [--md=/pad.md]
## Of:     GODOT=... .github/scripts/run_suite.sh perftest
## De vlag eindigt op "test" zodat de wereldkaart-cutscene en de tests-haken zich als in de andere suites gedragen.
## Zonder scherm: draait onder xvfb met software-GL (llvmpipe). Draw calls, nodes en textuurgeheugen zijn
## deterministisch; frametijd en laadtijd zijn alleen onderling vergelijkbaar (zelfde machine, zelfde run).
## Schrijft PASS/FAIL-regels (sanity) en 'RESULT OK'. Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")

## Een regel per scène: [groep, id, pad]. Volgorde = ongeveer de speelvolgorde.
const MAPS := [
	["Willowdale", "huis_wilgendal", "res://scenes/maps/huis_wilgendal.tscn"],
	["Willowdale", "wilgendal", "res://scenes/maps/wilgendal.tscn"],
	["Willowdale", "dorp_wilgendal", "res://scenes/maps/dorp_wilgendal.tscn"],
	["Willowdale", "wilgendal_binnen", "res://scenes/maps/wilgendal_binnen.tscn"],
	["World map 1", "wereldkaart", "res://scenes/maps/wereldkaart.tscn"],
	["First Archive", "archief_ingang", "res://scenes/maps/archief_ingang.tscn"],
	["First Archive", "archief_v1_gang", "res://scenes/maps/archief_v1_gang.tscn"],
	["First Archive", "archief_v2_trapzaal", "res://scenes/maps/archief_v2_trapzaal.tscn"],
	["First Archive", "archief_v2_leeszaal", "res://scenes/maps/archief_v2_leeszaal.tscn"],
	["First Archive", "archief_v2_kastenzaal", "res://scenes/maps/archief_v2_kastenzaal.tscn"],
	["First Archive", "archief_puzzel", "res://scenes/maps/archief_puzzel.tscn"],
	["First Archive", "archief_v3_gang", "res://scenes/maps/archief_v3_gang.tscn"],
	["First Archive", "archief_v3_zuilenhal", "res://scenes/maps/archief_v3_zuilenhal.tscn"],
	["First Archive", "archief_v4_voorhal", "res://scenes/maps/archief_v4_voorhal.tscn"],
	["First Archive", "archief_v4_wachtersgang", "res://scenes/maps/archief_v4_wachtersgang.tscn"],
	["First Archive", "archief_bibliotheek", "res://scenes/maps/archief_bibliotheek.tscn"],
	["First Archive", "archief_golemhal", "res://scenes/maps/archief_golemhal.tscn"],
	["Dark Wood", "esdoorn", "res://scenes/maps/esdoorn.tscn"],
	["Dark Wood", "esdoorn_herberg", "res://scenes/maps/esdoorn_herberg.tscn"],
	["Dark Wood", "esdoorn_huis_noor", "res://scenes/maps/esdoorn_huis_noor.tscn"],
	["Dark Wood", "woud_rand", "res://scenes/maps/woud_rand.tscn"],
	["Dark Wood", "woud_pad", "res://scenes/maps/woud_pad.tscn"],
	["Dark Wood", "woud_mistpoel", "res://scenes/maps/woud_mistpoel.tscn"],
	["Dark Wood", "woud_sporenkring", "res://scenes/maps/woud_sporenkring.tscn"],
	["Dark Wood", "woud_open_plek", "res://scenes/maps/woud_open_plek.tscn"],
]

## Gevechten: [id, vijanden, terrein, baas, tier, archief]
const BATTLES := [
	["battle_gras", ["mosslijm", "mosslijm"], "gras", false, 0, false],
	["battle_zand", ["moskonijn", "mosslijm"], "zand", false, 0, false],
	["battle_archief", ["papiergeest", "glitchmot", "papiergeest"], "archief", false, 2, true],
	["battle_woud", ["wortelgeest", "rankje", "sporekop"], "woud", false, 2, true],
	["battle_baas_golem", ["kennis_beest"], "archief", true, 0, false],
	["battle_kas", ["papiergeest", "glitchmot"], "kas", false, 3, true],
	["battle_diepe_grot", ["glitchmot", "glitchmot"], "dungeon100", false, 0, false],
]

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const SETTLE_FRAMES := 90
const DEFAULT_FRAMES := 180
## Een textuur breder of hoger dan dit telt als 'groot' in het rapport (gl_compatibility op goedkope telefoons).
const BIG_TEX := 1024

var failures := 0
var passes := 0
var frames := DEFAULT_FRAMES
var only: PackedStringArray = []
var csv_path := ""
var md_path := ""
var verbose := false
## Wat-als: verberg nodes met deze namen (scène of autoload) vóór het meten, om hun draw calls te isoleren.
var hide_names: PackedStringArray = []
var rows: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-frames="):
			frames = maxi(int(arg.get_slice("=", 1)), 10)
		elif arg.begins_with("--perf-only="):
			only = arg.get_slice("=", 1).split(",", false)
		elif arg.begins_with("--csv="):
			csv_path = arg.get_slice("=", 1)
		elif arg.begins_with("--perf-hide="):
			hide_names = arg.get_slice("=", 1).split(",", false)
		elif arg == "--perf-verbose":
			verbose = true
		elif arg.begins_with("--md="):
			md_path = arg.get_slice("=", 1)
	get_tree().create_timer(1500.0, true, false, true).timeout.connect(func():
		check("waakhond: profiel klaar binnen 1500 s", false)
		print("RESULT FOUT (waakhond)")
		get_tree().quit(1))
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _wanted(id: String) -> bool:
	return only.is_empty() or id in only


func _run() -> void:
	# Zonder 60 fps-begrenzing en zonder vsync meet de frametijd het echte werk, niet de wachttijd.
	var cap := Engine.max_fps
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _leeg()
	var basis := _rendering_baseline()
	print("PERF baseline: tex_mem_mb=%.2f nodes=%d" % [basis["tex_mem"] / 1048576.0, int(basis["nodes"])])
	if only.is_empty() or "boot_preload" in only:
		_registreer(_meet_boot(basis))
	for m in MAPS:
		if _wanted(m[1]):
			var r := await _meet_map(m[0], m[1], m[2], basis)
			_registreer(r)
	for b in BATTLES:
		if _wanted(b[0]):
			var r := await _meet_gevecht(b, basis)
			_registreer(r)
	Engine.max_fps = cap
	_rapport()
	print("PERFTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


func _registreer(r: Dictionary) -> void:
	rows.append(r)
	check("%s: geladen, %d nodes, %d draw calls, %.1f ms/frame" % [r["id"], r["nodes"], int(r["draw_calls"]), r["frame_ms"]],
			bool(r["ok"]))
	print("PERF %s" % JSON.stringify(r))


## Ruimt de huidige scène op en wacht tot alles weg is, zodat de volgende laadtijd 'koud' is.
func _leeg() -> void:
	var cs := get_tree().current_scene
	if cs != null:
		get_tree().current_scene = null
		cs.queue_free()
	for i in 4:
		await get_tree().process_frame
	GameState.changing_map = false
	GameState.in_battle = false
	GameState.pending_spawn = ""
	GameState.has_return_point = false


func _rendering_baseline() -> Dictionary:
	return {
		"tex_mem": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),
		"nodes": get_tree().get_node_count(),
	}


## Wat GameState bij het opstarten vooraf laadt (_preload_paths): hoeveel resources en hoeveel textuurgeheugen
## er staan voordat er een scène is geladen. Dit is geheugen dat op een telefoon de hele sessie bezet blijft.
func _meet_boot(basis: Dictionary) -> Dictionary:
	var geladen: Dictionary = GameState._loaded
	var tex := 0
	var n_tex := 0
	var grootste: Array = []
	for p in geladen:
		var t := geladen[p] as Texture2D
		if t != null:
			n_tex += 1
			tex += t.get_width() * t.get_height() * 4
			grootste.append([str(p).get_file(), t.get_width() * t.get_height() * 4, t.get_width(), t.get_height()])
	grootste.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	var top: Array[String] = []
	for i in mini(3, grootste.size()):
		top.append("%s %dx%d" % [grootste[i][0], grootste[i][2], grootste[i][3]])
	return {"group": "Boot", "id": "boot_preload", "kind": "boot", "ok": n_tex > 0,
			"nodes": get_tree().get_node_count(), "tex_mem_mb": basis["tex_mem"] / 1048576.0,
			"tex_unique": n_tex, "tex_ref_mb": tex / 1048576.0, "frame_ms": 0.0, "draw_calls": 0.0,
			"preloaded": geladen.size(), "objects": Performance.get_monitor(Performance.OBJECT_COUNT),
			"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), "tex_top": "; ".join(top)}


func _meet_map(groep: String, id: String, path: String, basis: Dictionary) -> Dictionary:
	await _leeg()
	var r := {"group": groep, "id": id, "kind": "map", "ok": false}
	var tex_voor: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	var t0 := Time.get_ticks_usec()
	var packed := load(path) as PackedScene
	r["load_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	if packed == null:
		return r
	r["tex_load_mb"] = (RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) - tex_voor) / 1048576.0
	var t1 := Time.get_ticks_usec()
	get_tree().change_scene_to_packed(packed)
	while get_tree().current_scene == null or str(get_tree().current_scene.scene_file_path) != path:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	r["enter_ms"] = (Time.get_ticks_usec() - t1) / 1000.0
	return await _sample(r, tex_voor, basis, path)


func _meet_gevecht(b: Array, basis: Dictionary) -> Dictionary:
	await _leeg()
	var r := {"group": "Battle", "id": b[0], "kind": "battle", "ok": false}
	var tex_voor: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	GameState.prepare_battle(b[1], b[2], b[3], b[4], b[5], false)
	GameState.in_battle = true
	var t0 := Time.get_ticks_usec()
	var packed := load(BATTLE_SCENE) as PackedScene
	r["load_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	var t1 := Time.get_ticks_usec()
	get_tree().change_scene_to_packed(packed)
	while get_tree().current_scene == null or str(get_tree().current_scene.scene_file_path) != BATTLE_SCENE:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	r["enter_ms"] = (Time.get_ticks_usec() - t1) / 1000.0
	r = await _sample(r, tex_voor, basis, BATTLE_SCENE)
	var bd: TextureRect = null
	if get_tree().current_scene != null:
		bd = get_tree().current_scene.get_node_or_null("Backdrop") as TextureRect
	r["ok"] = bool(r["ok"]) and bd != null and bd.texture != null and bd.texture.resource_path == GameState.pending_backdrop
	return r


## Laat de scène 'rusten' (fades, autosave, eerste animaties) en meet dan `frames` frames.
func _sample(r: Dictionary, tex_voor: int, basis: Dictionary, path: String) -> Dictionary:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	var cs := get_tree().current_scene
	if cs == null:
		return r
	for hn in hide_names:
		for root in [cs, get_tree().root]:
			for n in root.find_children(hn, "", true, false):
				if n is CanvasItem or n is CanvasLayer:
					n.visible = false
	if not hide_names.is_empty():
		for i in 3:
			await get_tree().process_frame
	var scan := _scan_scene(cs)
	var tex_na: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	var obj0 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var mem0 := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var dt: Array[float] = []
	var phys: Array[float] = []
	var dc_sum := 0.0
	var dc_max := 0
	var prim_sum := 0.0
	var last := Time.get_ticks_usec()
	for i in frames:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		dt.append((now - last) / 1000.0)
		last = now
		phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		var dc: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		dc_sum += dc
		dc_max = maxi(dc_max, dc)
		prim_sum += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var obj1 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var mem1 := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var sorted := dt.duplicate()
	sorted.sort()
	r["frame_ms"] = _avg(dt)
	r["frame_p95_ms"] = sorted[mini(int(sorted.size() * 0.95), sorted.size() - 1)]
	r["frame_max_ms"] = sorted[sorted.size() - 1]
	r["physics_ms"] = _avg(phys)
	r["draw_calls"] = dc_sum / frames
	r["draw_calls_max"] = dc_max
	r["primitives"] = prim_sum / frames
	r["nodes"] = scan["nodes"]
	r["nodes_total"] = get_tree().get_node_count()
	r["processing_nodes"] = scan["processing"]
	r["physics_nodes"] = scan["physics"]
	r["tex_mem_mb"] = tex_na / 1048576.0
	r["tex_mem_delta_mb"] = (tex_na - tex_voor) / 1048576.0
	r["tex_unique"] = scan["tex_count"]
	r["tex_ref_mb"] = scan["tex_bytes"] / 1048576.0
	r["tex_big"] = scan["tex_big"]
	r["tex_top"] = scan["tex_top"]
	if verbose:
		for t in scan["tex_list"]:
			print("PERFTEX %s %s %dx%d %.3f MB" % [r["id"], t["path"], int(t["w"]), int(t["h"]), int(t["bytes"]) / 1048576.0])
	r["classes_top"] = scan["classes_top"]
	var hot := _script_kosten(cs)
	r["script_us"] = hot["totaal_us"]
	r["script_top"] = hot["top"]
	r["objects"] = obj1
	r["resources"] = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	r["obj_growth"] = obj1 - obj0
	r["static_mem_growth_kb"] = (mem1 - mem0) / 1024.0
	r["ok"] = scan["nodes"] > 0 and dt.size() == frames and str(cs.scene_file_path) == path
	return r


## Kosten van de _process-scripts: elke node (scène + autoloads) die per frame draait, 200x _process(0.0)
## aanroepen en de tijd per aanroep sommeren per script. delta 0 laat timers en beweging stilstaan, dus de scène
## verandert niet; je meet de controles die elk frame draaien (polling, get_node, array's maken).
func _script_kosten(cs: Node) -> Dictionary:
	var knopen: Array[Node] = []
	_verzamel_proces(cs, knopen)
	for c in get_tree().root.get_children():
		if c != cs and c != self:
			_verzamel_proces(c, knopen)
	var per_script := {}
	for n in knopen:
		var t0 := Time.get_ticks_usec()
		for i in 200:
			n._process(0.0)
		var us := (Time.get_ticks_usec() - t0) / 200.0
		var naam := str(n.get_script().resource_path).get_file()
		per_script[naam] = float(per_script.get(naam, 0.0)) + us
	var lijst: Array = []
	var totaal := 0.0
	for k in per_script:
		lijst.append([k, per_script[k]])
		totaal += per_script[k]
	lijst.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	var top: Array[String] = []
	for i in mini(3, lijst.size()):
		top.append("%s %.1fus" % [lijst[i][0], lijst[i][1]])
	return {"totaal_us": totaal, "top": "; ".join(top)}


func _verzamel_proces(n: Node, uit: Array[Node]) -> void:
	var sc: Script = n.get_script()
	if sc != null and n.is_processing() and n.has_method("_process"):
		uit.append(n)
	for c in n.get_children():
		_verzamel_proces(c, uit)


func _avg(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += float(v)
	return s / a.size()


## Telt nodes per klasse, nodes die per frame draaien en de unieke textures die de scène gebruikt.
func _scan_scene(root: Node) -> Dictionary:
	var st := {"nodes": 0, "processing": 0, "physics": 0, "classes": {}, "tex": {}, "seen": {}}
	_scan_node(root, st)
	var tex_bytes := 0
	var big := 0
	var list: Array = []
	for k in st["tex"]:
		var t: Dictionary = st["tex"][k]
		tex_bytes += int(t["bytes"])
		if maxi(int(t["w"]), int(t["h"])) >= BIG_TEX:
			big += 1
		list.append(t)
	list.sort_custom(func(a, b): return int(a["bytes"]) > int(b["bytes"]))
	var top: Array[String] = []
	for i in mini(3, list.size()):
		top.append("%s %dx%d" % [str(list[i]["path"]).get_file(), int(list[i]["w"]), int(list[i]["h"])])
	var cls: Array = []
	for c in st["classes"]:
		cls.append([c, st["classes"][c]])
	cls.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	var ctop: Array[String] = []
	for i in mini(3, cls.size()):
		ctop.append("%s x%d" % [cls[i][0], cls[i][1]])
	return {"nodes": st["nodes"], "processing": st["processing"], "physics": st["physics"],
			"tex_count": st["tex"].size(), "tex_bytes": tex_bytes, "tex_big": big,
			"tex_top": "; ".join(top), "classes_top": "; ".join(ctop), "tex_list": list}


func _scan_node(n: Node, st: Dictionary) -> void:
	st["nodes"] += 1
	var cname := n.get_class()
	var sc: Script = n.get_script()
	if sc != null and sc.resource_path != "":
		cname = sc.resource_path.get_file()
	st["classes"][cname] = int(st["classes"].get(cname, 0)) + 1
	if n.is_processing():
		st["processing"] += 1
	if n.is_physics_processing():
		st["physics"] += 1
	_scan_object(n, st, 0)
	for c in n.get_children():
		_scan_node(c, st)


func _scan_object(o: Object, st: Dictionary, depth: int) -> void:
	for p in o.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_STORAGE):
			continue
		if int(p["type"]) != TYPE_OBJECT:
			continue
		var v: Variant = o.get(p["name"])
		if v is Resource and not (v is Script):
			_scan_resource(v, st, depth + 1)


func _scan_resource(res: Resource, st: Dictionary, depth: int) -> void:
	var key: int = res.get_instance_id()
	if st["seen"].has(key) or depth > 5:
		return
	st["seen"][key] = true
	if res is AtlasTexture:
		var at := res as AtlasTexture
		if at.atlas != null:
			_scan_resource(at.atlas, st, depth + 1)
		return
	if res is CanvasTexture:
		var ct := res as CanvasTexture
		for t in [ct.diffuse_texture, ct.normal_texture, ct.specular_texture]:
			if t != null:
				_scan_resource(t, st, depth + 1)
		return
	if res is Texture2D:
		if res is ViewportTexture or res is PlaceholderTexture2D:
			return
		var tex := res as Texture2D
		var w: int = tex.get_width()
		var h: int = tex.get_height()
		var path := res.resource_path if res.resource_path != "" else "<%s %d>" % [res.get_class(), key]
		st["tex"][path] = {"path": path, "w": w, "h": h, "bytes": w * h * 4}
		return
	if res is SpriteFrames:
		var sf := res as SpriteFrames
		for a in sf.get_animation_names():
			for i in sf.get_frame_count(a):
				var ft: Texture2D = sf.get_frame_texture(a, i)
				if ft != null:
					_scan_resource(ft, st, depth + 1)
		return
	if res is TileSet:
		var ts := res as TileSet
		for i in ts.get_source_count():
			var src: TileSetSource = ts.get_source(ts.get_source_id(i))
			if src is TileSetAtlasSource and (src as TileSetAtlasSource).texture != null:
				_scan_resource((src as TileSetAtlasSource).texture, st, depth + 1)
		return
	_scan_object(res, st, depth)


func _rapport() -> void:
	var cols := ["group", "id", "kind", "load_ms", "enter_ms", "frame_ms", "frame_p95_ms", "frame_max_ms",
			"physics_ms", "draw_calls", "draw_calls_max", "primitives", "nodes", "nodes_total", "processing_nodes",
			"physics_nodes", "tex_mem_mb", "tex_mem_delta_mb", "tex_unique", "tex_ref_mb", "tex_big", "tex_top",
			"classes_top", "script_us", "script_top", "objects", "resources", "preloaded", "obj_growth", "static_mem_growth_kb"]
	var csv := ",".join(cols) + "\n"
	for r in rows:
		var cells: Array[String] = []
		for c in cols:
			var v: Variant = r.get(c, "")
			cells.append(("%.3f" % float(v)) if (v is float) else ('"%s"' % str(v) if (v is String and "," in v) else str(v)))
		csv += ",".join(cells) + "\n"
	var cp := csv_path if csv_path != "" else "user://perf_wm1.csv"
	var f := FileAccess.open(cp, FileAccess.WRITE)
	if f != null:
		f.store_string(csv)
		f.close()
		print("PERF csv: %s" % ProjectSettings.globalize_path(cp))
	if md_path != "":
		var mf := FileAccess.open(md_path, FileAccess.WRITE)
		if mf != null:
			mf.store_string(_markdown())
			mf.close()
	print(_markdown())


func _markdown() -> String:
	var s := "| Groep | Scène | load ms | enter ms | frame ms | p95 ms | draw calls | nodes | tick-nodes | tex ref MB | tex mem Δ MB | grootste textures |\n"
	s += "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|\n"
	for r in rows:
		s += "| %s | `%s` | %.1f | %.1f | %.2f | %.2f | %.0f | %d | %d | %.2f | %.2f | %s |\n" % [r["group"], r["id"],
				r.get("load_ms", 0.0), r.get("enter_ms", 0.0), r.get("frame_ms", 0.0), r.get("frame_p95_ms", 0.0),
				r.get("draw_calls", 0.0), int(r.get("nodes", 0)), int(r.get("processing_nodes", 0)),
				r.get("tex_ref_mb", 0.0), r.get("tex_mem_delta_mb", 0.0), r.get("tex_top", "")]
	return s
