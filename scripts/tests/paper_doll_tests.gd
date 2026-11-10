extends Node
## Paper-doll-bakker (online co-op M2), RPG ART paper-doll v2 (5-kolom kaart).
## Start: godot --path . -- --paperdolltest

const Baker := preload("res://scripts/online/paper_doll_baker.gd")

const FULL := {
	"skin": 2, "hair": 3, "hair_color": 5,
	"top": 1, "top_color": 0, "bottom": 2, "bottom_color": 4,
	"head": 1, "head_color": 1, "class": "priest",
}

const BARE := {
	"skin": "licht", "hair": -1, "top": -1, "bottom": -1, "head": -1, "class": "",
}

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--shots="):
			shots = str(arg).get_slice("=", 1)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	_data_tests()
	_order_tests()
	_recolor_unit()
	_bake_tests()
	_save_previews()
	print("PAPERDOLL %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _data_tests() -> void:
	check("recolor-bestand staat in assets/sprites/paperdoll", FileAccess.file_exists(Baker.RECOLOR_PATH))
	var raw := FileAccess.get_file_as_string(Baker.RECOLOR_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	var doc_ok := parsed is Dictionary
	var tone_ok := false
	var edge_ok := false
	if doc_ok:
		var doc: Dictionary = parsed
		var tones: Variant = doc.get("tone_order", [])
		tone_ok = tones is Array and (tones as Array).size() == 5
		var edge: Variant = doc.get("buitenrand_na_bakken", {})
		edge_ok = edge is Dictionary and str((edge as Dictionary).get("kleur", "")) == "#3a4058"
	check("vijf sleuteltonen en contour #3a4058 in de json", doc_ok and tone_ok and edge_ok)
	var problems := Baker.validate()
	check("manifest, rampen en bestanden (%d opmerkingen)" % problems.size(), problems.is_empty())
	if not problems.is_empty():
		for p in problems:
			print("  - ", p)
	check("masterpalet 73 kleuren", Baker.palette_count() == 73)
	check("huid 4 / haar 8 / kleding 6",
		Baker.color_names("huid").size() == 4 and Baker.color_names("haar").size() == 8
		and Baker.color_names("kleding").size() == 6)
	check("lichaam 1, haar 6, top 4, onder 3, kap 2, wapen 5, cape 1",
		Baker.option_count("lichaam") == 1 and Baker.option_count("haar_achter") == 6
		and Baker.option_count("haar_voor") == 6 and Baker.option_count("boven") == 4
		and Baker.option_count("onder") == 3 and Baker.option_count("hoofd") == 2
		and Baker.option_count("wapen") == 5 and Baker.option_count("cape") == 1
		and Baker.option_count("gezicht") == 1 and Baker.option_count("schaduw") == 1)
	var layers := FileAccess.get_file_as_string("res://data/online/paper_doll_layers.json")
	var manifest: Variant = JSON.parse_string(layers)
	var sheets_ok := manifest is Dictionary
	if sheets_ok:
		var man: Dictionary = manifest
		var sheets: Dictionary = man.get("sheets", {})
		for sid in Baker.SHEET_LIST:
			var want := Baker.sheet_size(sid)
			var got: Dictionary = sheets.get(sid, {})
			if int(got.get("w", -1)) != want.x or int(got.get("h", -1)) != want.y:
				sheets_ok = false
	check("json-sheetmaten = baker", sheets_ok)
	var files_ok := true
	var indexed_ok := true
	var rgba_ok := true
	var path_ok := true
	var seen := 0
	if manifest is Dictionary:
		var man2: Dictionary = manifest
		var layer_doc: Dictionary = man2.get("layers", {})
		for layer in layer_doc:
			var meta: Dictionary = layer_doc[layer]
			var recolor := str(meta.get("recolor", ""))
			var opts: Dictionary = meta.get("options", {})
			for id in opts:
				var per: Dictionary = opts[id]
				for sid in Baker.ART_SHEETS:
					var path := str(per.get(sid, ""))
					seen += 1
					if not path.begins_with("res://assets/sprites/paperdoll/"):
						path_ok = false
					if not FileAccess.file_exists(path):
						files_ok = false
						continue
					var png := FileAccess.get_file_as_bytes(path)
					var kind := int(png[25]) if png.size() > 25 else -1
					if recolor == "":
						if kind == 3:
							rgba_ok = false
					elif kind != 6:
						indexed_ok = false
					var img := Image.new()
					if img.load_png_from_buffer(png) != OK:
						files_ok = false
						continue
					var want := Baker.sheet_size(sid)
					if img.get_width() != want.x or img.get_height() != want.y:
						files_ok = false
	check("alle laag-png's bestaan en hebben de sheetmaat (%d)" % seen, files_ok and seen == 60)
	check("bestanden staan onder assets/sprites/paperdoll", path_ok)
	check("herschikbare lagen zijn RGBA8 (v2)", indexed_ok)
	check("schaduw en wapen zijn RGBA", rgba_ok)


func _order_tests() -> void:
	var order := Baker.layer_order()
	var text := ",".join(order)
	var expect := "schaduw,lichaam,onder,boven,cape,haar_achter,gezicht,haar_voor,hoofd,wapen"
	check("laagvolgorde onder naar boven", text == expect)
	check("wapen bovenop, schaduw onderaan in de lijst", order[0] == "schaduw" and order[order.size() - 1] == "wapen")
	var layers := FileAccess.get_file_as_string("res://data/online/paper_doll_layers.json")
	var manifest: Variant = JSON.parse_string(layers)
	var listed_ok := false
	if manifest is Dictionary:
		var listed: Array = (manifest as Dictionary).get("draw_order", [])
		listed_ok = listed.size() == order.size()
		for i in order.size():
			if i >= listed.size() or str(listed[i]) != order[i]:
				listed_ok = false
		listed_ok = listed_ok and (manifest as Dictionary).get("mirrors_right", true) == false
	check("manifest-volgorde = bakker, rechts wordt niet gespiegeld", listed_ok)


func _recolor_unit() -> void:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	var keys := Baker.key_colors("huid")
	img.set_pixel(0, 0, keys[0])
	img.set_pixel(1, 0, keys[4])
	img.set_pixel(0, 1, Color(0, 0, 0, 0))
	img.set_pixel(1, 1, Color8(10, 10, 18, 255))
	var ramp := Baker.ramp_colors("huid", 3)
	var out := Baker.recolor_image(img, keys, ramp)
	check("RGBA-pad: toon rand → donkere huid", _same(out.get_pixel(0, 0), ramp[0]))
	check("RGBA-pad: toon licht → donkere huid", _same(out.get_pixel(1, 0), ramp[4]))
	check("RGBA-pad: transparant blijft", out.get_pixel(0, 1).a8 == 0)
	check("RGBA-pad: vaste kleur blijft", out.get_pixel(1, 1).r8 == 10 and out.get_pixel(1, 1).a8 == 255)
	check("bronbeeld ongemoeid", _same(img.get_pixel(0, 0), keys[0]))


func _bake_tests() -> void:
	var tiny := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	tiny.set_pixel(1, 1, Baker.key_colors("kleding")[2])
	Baker.recolor_image(tiny, Baker.key_colors("kleding"), Baker.ramp_colors("haar", 0))
	Baker.clear_cache()
	Baker.reset_stats()
	var t0 := Time.get_ticks_usec()
	var baked: Variant = Baker.bake(FULL)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	print("PAPERDOLL bake_ms=%.3f" % ms)
	var first: Dictionary = baked
	check("bakken < 50 ms (%.2f ms)" % ms, ms < 50.0 and first.size() == 5)
	var walk_tex: Texture2D = first["walk"]
	var attack_tex: Texture2D = first["attack"]
	var hurt_tex: Texture2D = first["hurt"]
	var dodge_tex: Texture2D = first["dodge"]
	var ko_tex: Texture2D = first["ko"]
	check("walk 120x128 (5 kolommen)", walk_tex.get_width() == 120 and walk_tex.get_height() == 128)
	check("attack 288x192", attack_tex.get_width() == 288 and attack_tex.get_height() == 192)
	check("hurt 192x48", hurt_tex.get_width() == 192 and hurt_tex.get_height() == 48)
	check("dodge 192x48", dodge_tex.get_width() == 192 and dodge_tex.get_height() == 48)
	check("ko 48x48", ko_tex.get_width() == 48 and ko_tex.get_height() == 48)
	var walk := Baker.image_for(FULL, "walk")
	var attack := Baker.image_for(FULL, "attack")
	check("hoek van de loopsheet is transparant", walk.get_pixel(0, 0).a8 == 0)
	var hash_walk := Baker.image_hash(walk)
	var hash_atk := Baker.image_hash(attack)
	check("hash niet leeg", hash_walk != "" and hash_atk != "" and hash_walk != hash_atk)
	check("walk-pixels in het masterpalet of transparant", _palette_ok(walk))
	check("attack-pixels in het masterpalet of transparant", _palette_ok(attack))
	check("hurt-pixels in het masterpalet of transparant", _palette_ok(Baker.image_for(FULL, "hurt")))
	check("dodge-pixels in het masterpalet of transparant", _palette_ok(Baker.image_for(FULL, "dodge")))
	check("ko-pixels in het masterpalet of transparant", _palette_ok(Baker.image_for(FULL, "ko")))
	check("avatar heeft dekking", _opaque_count(walk) > 80)
	var again: Dictionary = Baker.bake(FULL)
	var again_walk: Texture2D = again["walk"]
	var again_attack: Texture2D = again["attack"]
	check("zelfde look → zelfde texture", again_walk == walk_tex and again_attack == attack_tex)
	check("tweede bak is een cache-hit", Baker.cache_hits == 1 and Baker.bakes == 1)
	var png_a := walk.save_png_to_buffer()
	Baker.clear_cache()
	var rebuilt := Baker.image_for(FULL, "walk")
	check("zelfde look → byte-gelijke png", png_a == rebuilt.save_png_to_buffer() and Baker.image_hash(rebuilt) == hash_walk)
	var skin := FULL.duplicate()
	skin["skin"] = 0
	check("andere huid → andere hash", Baker.image_hash(Baker.image_for(skin, "walk")) != hash_walk)
	var hair := FULL.duplicate()
	hair["hair_color"] = 0
	check("andere haarkleur → andere hash", Baker.image_hash(Baker.image_for(hair, "walk")) != hash_walk)
	var top := FULL.duplicate()
	top["top_color"] = 2
	check("andere bovenkleur → andere hash", Baker.image_hash(Baker.image_for(top, "walk")) != hash_walk)
	var bottom := FULL.duplicate()
	bottom["bottom_color"] = 1
	check("andere broekkleur → andere hash", Baker.image_hash(Baker.image_for(bottom, "walk")) != hash_walk)
	var hat := FULL.duplicate()
	hat["head_color"] = 3
	check("andere kapkleur → andere hash", Baker.image_hash(Baker.image_for(hat, "walk")) != hash_walk)
	var bare_head := FULL.duplicate()
	bare_head["head"] = 0
	var bare_neg := FULL.duplicate()
	bare_neg["head"] = -1
	var no_hat := Baker.image_hash(Baker.image_for(bare_head, "walk"))
	check("head 0 is geen kap", no_hat != hash_walk)
	check("head 0 en head -1 zijn dezelfde look", no_hat == Baker.image_hash(Baker.image_for(bare_neg, "walk")))
	var by_name := {
		"skin": "midden", "hair": "staart", "hair_color": "blauw",
		"top": "harnas", "top_color": "nacht", "bottom": "broek", "bottom_color": "leer",
		"head": "kap", "head_color": "mos", "class": "lotte",
	}
	var by_index := {
		"skin": 1, "hair": 2, "hair_color": 5,
		"top": 2, "top_color": 0, "bottom": 0, "bottom_color": 3,
		"head": 1, "head_color": 2, "class": "priest",
	}
	check("naam en index delen dezelfde hash",
		Baker.image_hash(Baker.image_for(by_name, "walk")) == Baker.image_hash(Baker.image_for(by_index, "walk")))
	var warrior := FULL.duplicate()
	warrior["class"] = "warrior"
	var mage := FULL.duplicate()
	mage["class"] = "mage"
	var as_dennis := FULL.duplicate()
	as_dennis["class"] = "dennis"
	var w_hash := Baker.image_hash(Baker.image_for(warrior, "walk"))
	check("andere klasse → ander wapen", w_hash != Baker.image_hash(Baker.image_for(mage, "walk")))
	check("dennis en warrior delen het zwaard", w_hash == Baker.image_hash(Baker.image_for(as_dennis, "walk")))
	check("warrior-pixels in het palet", _palette_ok(Baker.image_for(warrior, "walk")))
	_art_pixels()
	var missing := {"hair": 99, "top": -3, "head": 80, "class": "nope", "body": 5, "bottom": 9}
	var miss: Dictionary = Baker.bake(missing)
	var miss_ok := miss.size() == 5
	for sid in Baker.SHEET_LIST:
		var want := Baker.sheet_size(sid)
		var tex: Texture2D = miss[sid]
		if tex == null or tex.get_width() != want.x or tex.get_height() != want.y:
			miss_ok = false
		if not _palette_ok(Baker.image_for(missing, sid)):
			miss_ok = false
	check("ontbrekende laag crasht niet en houdt de maat", miss_ok)
	var empty: Dictionary = Baker.bake({})
	var empty_walk: Texture2D = empty["walk"]
	check("lege look geeft een loopsheet", empty_walk.get_width() == 120 and _palette_ok(Baker.image_for({}, "walk")))
	var m1 := {
		"body": 0, "skin": 0, "hair": 0, "hair_color": 0,
		"top": 0, "top_color": 0, "bottom": 0, "bottom_color": 0, "head": 0,
	}
	var m1_img := Baker.image_for(m1, "walk")
	check("M1-look (head 0, zonder klasse) bakt", m1_img.get_width() == 120 and _palette_ok(m1_img) and m1_img.get_pixel(12, 16).a8 == 255)
	var voorbeeld := {
		"skin": "getint", "hair": "krul", "hair_color": "zwart",
		"top": "mantel", "top_color": "paars", "bottom": "korte_broek", "bottom_color": "nacht",
		"head": "hoed", "head_color": "leer", "cape": "nacht", "class": "mage",
	}
	check("voorbeeld_c bakt", _palette_ok(Baker.image_for(voorbeeld, "walk")))
	var sprite := Sprite2D.new()
	add_child(sprite)
	sprite.texture = walk_tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	Baker.apply_nearest(sprite)
	check("nearest filtering op de sprite", sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	# ProjectSettings telt 0 = Nearest. Dat is een andere enum dan CanvasItem.TEXTURE_FILTER_*.
	var project_filter := int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"))
	check("project staat op nearest", project_filter == 0)
	sprite.queue_free()


func _art_pixels() -> void:
	var licht := Baker.image_for(BARE, "walk")
	var donker_look := BARE.duplicate()
	donker_look["skin"] = "donker"
	var donker := Baker.image_for(donker_look, "walk")
	var hi := licht.get_pixel(7, 5)
	var edge := licht.get_pixel(11, 30)
	var shade := licht.get_pixel(12, 31)
	check("lichte huid houdt toon licht (#f8e0c0)", hi.r8 == 248 and hi.g8 == 224 and hi.b8 == 192 and hi.a8 == 255)
	check("donkere huid vervangt de lichte toon", donker.get_pixel(7, 5).r8 == 176 and donker.get_pixel(7, 5).g8 == 104 and donker.get_pixel(7, 5).b8 == 62)
	check("donkere huid bevat geen #f8e0c0", not _has_rgb(donker, 248, 224, 192))
	check("donkere buitencontour wordt #3a4058", edge.r8 == 58 and edge.g8 == 64 and edge.b8 == 88)
	check("schaduw ligt onder de figuur en blijft #0a0a12", shade.r8 == 10 and shade.g8 == 10 and shade.b8 == 18 and shade.a8 == 255)
	var armed := Baker.image_for(FULL, "walk")
	var left := armed.get_pixel(10, 37)
	var right := armed.get_pixel(82, 69)
	check("walk-sheet is 120 breed (5 kolommen)", licht.get_width() == 120)
	check("links-rij en rechts-rij zijn beide zichtbaar", left.a8 == 255 and right.a8 == 255)
	check("rechts-rij wijkt af van links (gebakken spiegel, geen runtime-flip)", not _same(left, right))


func _palette_ok(img: Image) -> bool:
	if img == null:
		return false
	var data := img.get_data()
	var n := data.size()
	var i := 0
	while i < n:
		var a := int(data[i + 3])
		if a != 0:
			if a != 255:
				return false
			if not Baker.palette_has(Color8(int(data[i]), int(data[i + 1]), int(data[i + 2]))):
				return false
		i += 4
	return true


func _has_rgb(img: Image, r: int, g: int, b: int) -> bool:
	var data := img.get_data()
	var i := 0
	while i < data.size():
		if int(data[i + 3]) == 255 and int(data[i]) == r and int(data[i + 1]) == g and int(data[i + 2]) == b:
			return true
		i += 4
	return false


func _opaque_count(img: Image) -> int:
	var data := img.get_data()
	var n := 0
	var i := 3
	while i < data.size():
		if data[i] == 255:
			n += 1
		i += 4
	return n


func _same(a: Color, b: Color) -> bool:
	return a.r8 == b.r8 and a.g8 == b.g8 and a.b8 == b.b8 and a.a8 == b.a8


func _save_previews() -> void:
	var walk := Baker.image_for(FULL, "walk")
	var attack := Baker.image_for(FULL, "attack")
	if walk == null or attack == null:
		return
	var front := Image.create(24, 32, false, Image.FORMAT_RGBA8)
	front.blit_rect(walk, Rect2i(0, 0, 24, 32), Vector2i.ZERO)
	_write_zoom(front, "/opt/cursor/artifacts/paperdoll_front_x8.png", 8)
	_write_zoom(walk, "/opt/cursor/artifacts/paperdoll_walk_x4.png", 4)
	_write_zoom(attack, "/opt/cursor/artifacts/paperdoll_attack_x2.png", 2)
	_write_zoom(Baker.image_for(FULL, "hurt"), "/opt/cursor/artifacts/paperdoll_hurt_x4.png", 4)
	_write_zoom(Baker.image_for(FULL, "dodge"), "/opt/cursor/artifacts/paperdoll_dodge_x4.png", 4)
	_write_zoom(Baker.image_for(FULL, "ko"), "/opt/cursor/artifacts/paperdoll_ko_x4.png", 4)
	var alt := FULL.duplicate()
	alt["skin"] = 0
	alt["hair"] = 5
	alt["hair_color"] = 7
	alt["top_color"] = 1
	alt["bottom_color"] = 2
	alt["head"] = 2
	alt["head_color"] = 2
	alt["class"] = "archer"
	var alt_front := Image.create(24, 32, false, Image.FORMAT_RGBA8)
	alt_front.blit_rect(Baker.image_for(alt, "walk"), Rect2i(0, 0, 24, 32), Vector2i.ZERO)
	_write_zoom(alt_front, "/opt/cursor/artifacts/paperdoll_front_alt_x8.png", 8)
	var bare := Baker.image_for(BARE, "walk")
	var bare_front := Image.create(24, 32, false, Image.FORMAT_RGBA8)
	bare_front.blit_rect(bare, Rect2i(0, 0, 24, 32), Vector2i.ZERO)
	_write_zoom(bare_front, "/opt/cursor/artifacts/paperdoll_bare_x8.png", 8)
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
		walk.save_png(shots.path_join("paperdoll_walk.png"))
		attack.save_png(shots.path_join("paperdoll_attack.png"))


func _write_zoom(img: Image, path: String, scale: int) -> void:
	if img == null:
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var big := img.duplicate()
	big.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	big.save_png(path)
