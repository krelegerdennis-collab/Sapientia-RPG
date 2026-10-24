extends Node
## WM1 geheugenmeting (geen test, geen gameplay). Reproduceerbaar en headless.
##
## Start (via de driver tools/geheugen/wm1_meting.sh, of met de hand):
##   godot --rendering-driver opengl3 --path . res://tools/geheugen/wm1_meting.tscn -- <modus> [opties]
## Modi:
##   --lijst                  druk de WM1-kaartlijst af (een pad per regel)
##   --start                  alleen de opstart (autoloads + achtergrond-preload), geen kaart
##   --scene=res://...tscn    een kaart in een verse proces: voor/na laden/na vrijgeven
##   --sessie                 alle WM1-kaarten achter elkaar in een proces (lekken, piek)
##   --battle=<terrein>       een WM1-gevecht (gras, bos, zand, boss, ...) zoals start_battle het klaarzet
##   --pixels                 beeld van elke WM1-kaart op meerdere camerastanden en schermbreedtes (SHA-256 + png's met
##                            --pngdir=map): bewijst dat een geheugenwijziging het beeld niet verandert. Start Godot met
##                            --fixed-fps 60 en vergelijk met tools/geheugen/beeldcheck.py (dungeon100 is willekeurig)
##   --texaudit               elke png in assets/, art/, world_warper/: echte GPU-kosten, formaat, alpha, hash
## Opties: --out=pad.json (resultaat als JSON, anders stdout), --frames=N (wachtframes, standaard 12),
##   --met-cutscene (laat de wereldkaart-intro meespelen), --only=naam,naam (alleen deze kaarten, bij --sessie/--pixels)
## De Performance-monitors vragen een echte renderer (gl_compatibility, opengl3): op Linux via xvfb-run.
## Meting zit niet in de export (tools/).

const MAPS_DIR := "res://scenes/maps/"
const START_MAP := "res://scenes/maps/wilgendal.tscn"
const SPELER := "Dax"

var _out := ""
var _frames := 12
## Standaard staat de eenmalige wereldkaart-intro (video) uit: we meten de kaart, niet het filmpje.
var _cutscene := false
var _pngdir := ""
var _only: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var modus := ""
	var scene := ""
	for arg in OS.get_cmdline_user_args():
		if arg == "--lijst" or arg == "--start" or arg == "--sessie" or arg == "--texaudit" or arg == "--pixels":
			modus = arg.trim_prefix("--")
		elif arg.begins_with("--scene="):
			modus = "scene"
			scene = arg.get_slice("=", 1)
		elif arg.begins_with("--battle="):
			modus = "battle"
			scene = arg.get_slice("=", 1)
		elif arg.begins_with("--only="):
			_only = arg.get_slice("=", 1).split(",")
		elif arg.begins_with("--pngdir="):
			_pngdir = arg.get_slice("=", 1)
		elif arg == "--met-cutscene":
			_cutscene = true
		elif arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--frames="):
			_frames = int(arg.get_slice("=", 1))
	_run.call_deferred(modus, scene)


## Alle WM1-kaarten (scenes/maps/*.tscn), gesorteerd zodat de lijst stabiel is.
static func kaarten() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(MAPS_DIR):
		if f.ends_with(".tscn"):
			out.append(MAPS_DIR + f)
	out.sort()
	return out


func _run(modus: String, scene: String) -> void:
	if modus == "lijst":
		for p in kaarten():
			print(p)
		get_tree().quit(0)
		return
	await _opstart_klaar()
	var res := {"modus": modus, "godot": Engine.get_version_info()["string"],
			"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile")),
			"adapter": RenderingServer.get_video_adapter_name()}
	match modus:
		"start":
			res["start"] = _monsters()
			res["preload"] = _preload_overzicht()
		"scene":
			res["kaart"] = await _meet_kaart(scene)
		"sessie":
			var rij: Array = []
			for p in kaarten():
				if not _only.is_empty() and not _only.has(p.get_file().get_basename()):
					continue
				rij.append(await _meet_kaart(p, true))
			res["kaarten"] = rij
			await _frames_wachten(3)
			res["eind"] = _monsters()
		"pixels":
			var px: Dictionary = {}
			# Vaste framestand (met --fixed-fps): tegelanimaties (TIME) lopen dan gelijk in voor en na.
			while Engine.get_frames_drawn() < 600:
				await get_tree().process_frame
			for p in kaarten():
				if not _only.is_empty() and not _only.has(p.get_file().get_basename()):
					continue
				px[p] = await _pixels(p)
			res["pixels"] = px
		"battle":
			res["gevecht"] = await _meet_gevecht(scene)
		"texaudit":
			res["texturen"] = await _tex_audit()
		_:
			printerr("Geef --lijst, --start, --scene=<pad>, --sessie of --texaudit.")
			get_tree().quit(2)
			return
	var json := JSON.stringify(res, "\t")
	if _out != "":
		var f := FileAccess.open(_out, FileAccess.WRITE)
		f.store_string(json)
		f.close()
	else:
		print(json)
	get_tree().quit(0)


## Wacht tot de achtergrond-preload van GameState klaar is: zo meten we een stabiele beginstand.
func _opstart_klaar() -> void:
	var tel := 0
	while not GameState._preloading.is_empty() and tel < 1800:
		await get_tree().process_frame
		tel += 1
	await _frames_wachten(5)


## Laadt elke png uit de WM1-assetmappen los (zonder cache) en meet de echte GPU-kosten als verschil
## van RENDER_TEXTURE_MEM_USED. Dat is de waarheid voor "wat kost dit bestand in VRAM?".
func _tex_audit() -> Array:
	var pngs: Array[String] = []
	for dir in ["res://assets", "res://art", "res://world_warper"]:
		_zoek_png(dir, pngs)
	pngs.sort()
	var rij: Array = []
	for p in pngs:
		var voor := int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
		var t := ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		if t == null:
			continue
		var na := int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
		var img := t.get_image()
		var fmt := -1
		var alpha := -1
		var h := 0
		var mips := -1
		if img != null:
			mips = img.get_mipmap_count()
			fmt = img.get_format()
			alpha = img.detect_alpha()
			h = hash(img.get_data())
		rij.append({"pad": p, "w": t.get_width(), "h": t.get_height(), "vram": na - voor,
				"formaat": fmt, "alpha": alpha, "mips": mips, "hash": h})
		t = null
	return rij


func _zoek_png(dir: String, uit: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png"):
			uit.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_zoek_png(dir.path_join(d), uit)


## Wat GameState na de opstart vasthoudt (`_loaded`): per pad klasse en textuurgrootte (b*h*4).
func _preload_overzicht() -> Dictionary:
	var rij: Array = []
	var totaal := 0
	for p in GameState._loaded:
		var r: Resource = GameState._loaded[p]
		var b := 0
		if r is Texture2D:
			b = (r as Texture2D).get_width() * (r as Texture2D).get_height() * 4
		totaal += b
		rij.append({"pad": p, "klasse": r.get_class() if r != null else "null", "bytes": b})
	rij.sort_custom(func(a, c): return a["bytes"] > c["bytes"])
	return {"aantal": rij.size(), "bytes_rgba8": totaal, "items": rij}


func _frames_wachten(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Een kaart zoals het spel hem opent (nieuw spel, kaart instantiëren als huidige scène),
## wacht een paar frames en meet. Daarna vrijgeven en nogmaals meten (lekcontrole).
func _meet_kaart(pad: String, sessie := false) -> Dictionary:
	_nieuw_spel()
	var voor := _monsters()
	var t0 := Time.get_ticks_usec()
	var packed := GameState.get_resource(pad) as PackedScene
	var kaart := packed.instantiate()
	var oud := get_tree().current_scene
	get_tree().root.add_child(kaart)
	get_tree().current_scene = kaart
	if oud != null and oud != self:
		oud.queue_free()
	await _frames_wachten(_frames)
	var laadtijd_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var na := _monsters()
	var tex := _texturen(kaart)
	tex["atlassen"] = _atlassen(kaart)
	var knopen := _tel_knopen(kaart)
	get_tree().current_scene = null
	kaart.queue_free()
	await _frames_wachten(3)
	var vrij := _monsters()
	return {"pad": pad, "voor": voor, "na": na, "vrijgegeven": vrij, "texturen": tex,
			"knopen": knopen, "laadtijd_ms": snappedf(laadtijd_ms, 0.1)}


## Beeld-hashes van een kaart: standaardbreedte (16:9) en breed (19.5:9, zoals een S25 Ultra), elk op de
## spawn en op twee gebroken (sub-pixel) positionen van de speler. De camera volgt de speler.
func _pixels(pad: String) -> Array:
	var uit: Array = []
	_nieuw_spel()
	Crt.set_enabled(false)      # scanlines/glitch zijn tijdgestuurd
	var packed := GameState.get_resource(pad) as PackedScene
	var kaart := packed.instantiate()
	get_tree().root.add_child(kaart)
	get_tree().current_scene = kaart
	var speler := kaart.get_node_or_null("Objects/Player") as Node2D
	var start := speler.position if speler != null else Vector2.ZERO
	var stappen := [Vector2.ZERO, Vector2(37.37, 21.61), Vector2(-23.5, 40.25)]
	for breedte in [1152, 1404]:
		get_window().size = Vector2i(breedte, 648)
		for i in stappen.size():
			if speler != null:
				speler.position = start + stappen[i]
			await _frames_wachten(25)
			get_tree().paused = true      # bevries animaties/wandelaars voor een reproduceerbaar beeld
			await _frames_wachten(3)
			var img := get_viewport().get_texture().get_image()
			get_tree().paused = false
			var ctx := HashingContext.new()
			ctx.start(HashingContext.HASH_SHA256)
			ctx.update(img.get_data())
			var h := ctx.finish().hex_encode()
			uit.append({"breedte": breedte, "stand": i, "w": img.get_width(), "h": img.get_height(), "sha": h})
			if _pngdir != "":
				DirAccess.make_dir_recursive_absolute(_pngdir)
				img.save_png("%s/%s_%d_%d.png" % [_pngdir, pad.get_file().get_basename(), breedte, i])
	get_tree().current_scene = null
	kaart.queue_free()
	await _frames_wachten(3)
	return uit


func _nieuw_spel() -> void:
	GameState.new_game(SPELER)
	GameState.dungeon100_seed = 20261024      # vaste run-seed: dungeon100 is anders elke keer anders
	if not _cutscene:
		GameState.story_flags["cutscene_wereldkaart_gezien"] = true


## Een gevecht zoals start_battle het klaarzet (zonder kaart/overgang): prepare_battle kiest de
## achtergrond bij het terrein; daarna de gevechtsscène laden, tonen en meten.
func _meet_gevecht(terrein: String) -> Dictionary:
	_nieuw_spel()
	var boss := terrein == "boss"
	var voor := _monsters()
	var t0 := Time.get_ticks_usec()
	GameState.prepare_battle(["mosslijm", "moskonijn"] if not boss else ["wortelkoning"], "" if boss else terrein, boss)
	var packed := GameState.get_resource(GameState.BATTLE_SCENE) as PackedScene
	var b := packed.instantiate()
	var oud := get_tree().current_scene
	get_tree().root.add_child(b)
	get_tree().current_scene = b
	if oud != null and oud != self:
		oud.queue_free()
	await _frames_wachten(_frames)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var na := _monsters()
	var tex := _texturen(b)
	get_tree().current_scene = null
	b.queue_free()
	GameState.in_battle = false
	await _frames_wachten(3)
	return {"terrein": terrein, "achtergrond": GameState.pending_backdrop, "voor": voor, "na": na,
			"vrijgegeven": _monsters(), "texturen": tex, "laadtijd_ms": snappedf(ms, 0.1)}


func _monsters() -> Dictionary:
	var rss := _proc_status()
	return {
		"statisch": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"statisch_piek": int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)),
		"textuur_mem": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"buffer_mem": int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
		"video_mem": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"objecten": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"knopen": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"wees_knopen": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"drawcalls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"rss": rss.get("VmRSS", 0),
		"rss_piek": rss.get("VmHWM", 0),
	}


## VmRSS/VmHWM in bytes (Linux). Elders 0. (/proc meldt lengte 0: daarom regel voor regel lezen.)
func _proc_status() -> Dictionary:
	var out := {}
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line()
		for k in ["VmRSS", "VmHWM"]:
			if line.begins_with(k + ":"):
				out[k] = int(line.get_slice(":", 1).strip_edges().get_slice(" ", 0)) * 1024
	return out


## Tegelatlassen onder de kaart: aantal bronnen en hoeveel er nog `use_texture_padding` hebben
## (dat is een tweede, opgevulde kopie van de atlas in het geheugen).
func _atlassen(wortel: Node) -> Dictionary:
	var gezien := {}
	var bronnen := 0
	var padded := 0
	var padded_px := 0
	var stapel: Array[Node] = [wortel]
	while not stapel.is_empty():
		var n: Node = stapel.pop_back()
		stapel.append_array(n.get_children())
		if not (n is TileMapLayer):
			continue
		var ts := (n as TileMapLayer).tile_set
		if ts == null or gezien.has(ts.get_instance_id()):
			continue
		gezien[ts.get_instance_id()] = true
		for i in ts.get_source_count():
			var src := ts.get_source(ts.get_source_id(i))
			if src is TileSetAtlasSource:
				bronnen += 1
				var tex := (src as TileSetAtlasSource).texture
				if (src as TileSetAtlasSource).use_texture_padding and tex != null:
					padded += 1
					padded_px += tex.get_width() * tex.get_height()
	return {"bronnen": bronnen, "met_padding": padded, "padding_bytes_rgba8": padded_px * 4}


func _tel_knopen(wortel: Node) -> int:
	var n := 1
	for c in wortel.get_children():
		n += _tel_knopen(c)
	return n


## Loopt de scène af en verzamelt elke Texture2D die een node of een onderliggende resource
## (TileSet, SpriteFrames, materiaal, ...) vasthoudt. Per unieke textuur: pad, afmeting, klasse
## en de onbewerkte RGBA8-grootte (b*h*4). `verborgen` = alleen vastgehouden door onzichtbare nodes.
func _texturen(wortel: Node) -> Dictionary:
	var gezien := {}      # instance_id -> {"tex": Texture2D, "zichtbaar": bool}
	var bezocht := {}     # instance_id van resources die al doorlopen zijn
	_verzamel(wortel, gezien, bezocht)
	var rij: Array = []
	var totaal := 0
	var runtime := 0
	var runtime_n := 0
	var verborgen := 0
	var per_hash := {}
	var dubbel_bytes := 0
	for item in gezien.values():
		var t: Texture2D = item["tex"]
		var b := t.get_width() * t.get_height() * 4
		totaal += b
		if not item["zichtbaar"]:
			verborgen += b
		var pad := t.resource_path
		if not pad.begins_with("res://"):
			runtime += b
			runtime_n += 1
		var h := _hash(t)
		if per_hash.has(h) and per_hash[h] != pad:
			dubbel_bytes += b
		per_hash[h] = pad
		rij.append({"pad": pad, "w": t.get_width(), "h": t.get_height(), "klasse": t.get_class(),
				"bytes": b, "zichtbaar": item["zichtbaar"]})
	rij.sort_custom(func(a, c): return a["bytes"] > c["bytes"])
	return {"uniek": gezien.size(), "bytes_rgba8": totaal, "verborgen_bytes": verborgen,
			"runtime_aantal": runtime_n, "runtime_bytes": runtime, "dubbel_bytes": dubbel_bytes,
			"top": rij.slice(0, 15), "alle": rij}


func _hash(t: Texture2D) -> int:
	var img := t.get_image()
	if img == null:
		return 0
	return hash(img.get_data())


func _verzamel(n: Node, gezien: Dictionary, bezocht: Dictionary) -> void:
	var zichtbaar := true
	if n is CanvasItem:
		zichtbaar = (n as CanvasItem).is_visible_in_tree()
	for prop in n.get_property_list():
		var tp := int(prop["type"])
		if tp == TYPE_OBJECT or tp == TYPE_NIL or tp == TYPE_ARRAY or tp == TYPE_DICTIONARY:
			_waarde(n.get(prop["name"]), zichtbaar, gezien, bezocht, 0)
	for c in n.get_children():
		_verzamel(c, gezien, bezocht)


## Een eigenschapswaarde: resource, of (genest) array/dictionary met resources (scriptvariabelen).
func _waarde(v: Variant, zichtbaar: bool, gezien: Dictionary, bezocht: Dictionary, diepte: int) -> void:
	if diepte > 4:
		return
	if v is Resource:
		_verzamel_res(v as Resource, zichtbaar, gezien, bezocht)
	elif v is Array:
		for x in v:
			_waarde(x, zichtbaar, gezien, bezocht, diepte + 1)
	elif v is Dictionary:
		for x in (v as Dictionary).values():
			_waarde(x, zichtbaar, gezien, bezocht, diepte + 1)


func _verzamel_res(r: Resource, zichtbaar: bool, gezien: Dictionary, bezocht: Dictionary) -> void:
	if r is AtlasTexture:
		var at := (r as AtlasTexture).atlas
		if at != null:
			_verzamel_res(at, zichtbaar, gezien, bezocht)
		return
	if r is Texture2D:
		var id := r.get_instance_id()
		if gezien.has(id):
			gezien[id]["zichtbaar"] = gezien[id]["zichtbaar"] or zichtbaar
		elif (r as Texture2D).get_width() > 0:
			gezien[id] = {"tex": r, "zichtbaar": zichtbaar}
		return
	var rid := r.get_instance_id()
	if bezocht.has(rid):
		return
	bezocht[rid] = true
	if r is Script or r is Shader or r is Mesh or r is Font or r is AudioStream:
		return
	for prop in r.get_property_list():
		var tp := int(prop["type"])
		if tp == TYPE_OBJECT or tp == TYPE_NIL or tp == TYPE_ARRAY or tp == TYPE_DICTIONARY:
			_waarde(r.get(prop["name"]), zichtbaar, gezien, bezocht, 0)
	if r is TileSet:
		var ts := r as TileSet
		for i in ts.get_source_count():
			var src := ts.get_source(ts.get_source_id(i))
			if src is TileSetAtlasSource:
				_verzamel_res((src as TileSetAtlasSource).texture, zichtbaar, gezien, bezocht)
	elif r is SpriteFrames:
		var sf := r as SpriteFrames
		for a in sf.get_animation_names():
			for i in sf.get_frame_count(a):
				var ft := sf.get_frame_texture(a, i)
				if ft != null:
					_verzamel_res(ft, zichtbaar, gezien, bezocht)
