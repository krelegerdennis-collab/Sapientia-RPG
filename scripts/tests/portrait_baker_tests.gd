extends Node
## Portretbakker (online co-op look -> 32x32 borstbeeld). Start: godot --path . -- --portraitbakertest
## Tijdgrens per portret: 5 ms lokaal, 25 ms als CI of GITHUB_ACTIONS gezet is.

const Slot := preload("res://scripts/ui/lobby_portrait_slot.gd")
const Roles := preload("res://scripts/coop/seat_controller.gd")
const Profile := preload("res://scripts/online/online_profile.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")

const LIMIT_LOCAL_MS := 5.0
const LIMIT_CI_MS := 25.0
## Lagen met een eigen portretbestand (recolor_v2.json: geen schaduw, onder of wapen).
const PORTRAIT_LAYERS: PackedStringArray = ["lichaam", "boven", "cape", "haar_achter", "gezicht", "haar_voor", "hoofd"]
const EMPTY_LAYERS: PackedStringArray = ["schaduw", "onder", "wapen"]

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
	PortraitBaker.release_cache()
	PortraitBaker.reset_stats()
	_layers()
	_determinism()
	_all_combinations()
	_fallback()
	_timing()
	_cache_release()
	await _slot()
	await _lobby_rows()
	_shots()
	PortraitBaker.release_cache()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _look(over: Dictionary = {}) -> Dictionary:
	var look := Profile.default_look()
	for k in over:
		look[k] = over[k]
	return look


func _layers() -> void:
	var order := PaperDollBaker.layer_order()
	check("laagvolgorde komt van de paper-doll baker (%d lagen)" % order.size(), order.size() == 10)
	var opts := {
		"hair": Profile.LOOK_MAX["hair"], "top": Profile.LOOK_MAX["top"], "head": Profile.LOOK_MAX["head"],
	}
	var missing := PackedStringArray()
	for hair in int(opts["hair"]) + 1:
		for top in int(opts["top"]) + 1:
			for head in int(opts["head"]) + 1:
				var look := _look({"hair": hair, "top": top, "head": head})
				for layer in ["lichaam", "boven", "haar_achter", "gezicht", "haar_voor"]:
					if PortraitBaker.layer_path(look, layer) == "":
						missing.append("%s h%d t%d" % [layer, hair, top])
				if head > 0 and PortraitBaker.layer_path(look, "hoofd") == "":
					missing.append("hoofd %d" % head)
	check("elke optie heeft een portretlaag in assets/ui/portret/ (mist: %s)" % ", ".join(missing), missing.is_empty())
	var base := _look()
	for layer in EMPTY_LAYERS:
		check("laag %s heeft geen portret (blijft leeg)" % layer, PortraitBaker.layer_path(base, layer) == "")
	check("head 0 = geen hoofddeksel", PortraitBaker.layer_path(base, "hoofd") == "")
	check("cape zit niet in de look: geen cape", PortraitBaker.layer_path(base, "cape") == "")


func _determinism() -> void:
	var look := _look({"skin": 2, "hair": 4, "hair_color": 3, "top": 2, "top_color": 1, "head": 2})
	var a := PortraitBaker.image_for(look)
	var b := PortraitBaker.image_for(look.duplicate())
	check("portret is 32x32 RGBA8", a != null and a.get_width() == 32 and a.get_height() == 32 and a.get_format() == Image.FORMAT_RGBA8)
	var ha := PortraitBaker.image_hash(a)
	check("zelfde look = zelfde hash (%s)" % ha.substr(0, 12), ha != "" and ha == PortraitBaker.image_hash(b))
	var with_class := look.duplicate()
	with_class["class"] = "mage"
	var blob := AvatarBlob.encode(with_class)
	check("AvatarBlob (seat-data) geeft dezelfde hash", PortraitBaker.image_hash(PortraitBaker.image_for(blob)) == ha)
	var bytes := Profile.encode_look(look)
	check("profiel-look-bytes geven dezelfde hash", PortraitBaker.image_hash(PortraitBaker.image_for(bytes)) == ha)
	var json_look: Variant = JSON.parse_string(JSON.stringify(look))
	check("look uit JSON (floats) geeft dezelfde hash", PortraitBaker.image_hash(PortraitBaker.image_for(json_look)) == ha)
	PortraitBaker.release_cache()
	check("na vrijgeven opnieuw gebakken: zelfde hash", PortraitBaker.image_hash(PortraitBaker.image_for(look)) == ha)
	var t1 := PortraitBaker.bake(look)
	var hits := PortraitBaker.cache_hits
	var t2 := PortraitBaker.bake(look)
	check("tweede bake: zelfde texture uit de cache", t1 != null and t1 == t2 and PortraitBaker.cache_hits == hits + 1)
	check("texture-pixels = image-pixels", t1 != null and PortraitBaker.image_hash(t1.get_image()) == ha)
	var other := look.duplicate()
	other["bottom"] = 2
	other["bottom_color"] = 5
	check("onderkant valt buiten het borstbeeld: zelfde pixels", PortraitBaker.image_hash(PortraitBaker.image_for(other)) == ha)
	for key in ["skin", "hair", "hair_color", "top", "top_color", "head"]:
		var diff := look.duplicate()
		diff[key] = (int(look[key]) + 1) % (int(Profile.LOOK_MAX[key]) + 1)
		check("andere %s = ander portret" % key, PortraitBaker.image_hash(PortraitBaker.image_for(diff)) != ha)
	var outline := PaperDollBaker.outline_color()
	var has_edge := false
	for y in 32:
		for x in 32:
			if a.get_pixel(x, y) == outline:
				has_edge = true
	check("buitenrand #3a4058 zoals de paper-doll baker", has_edge)
	var off_palette := 0
	for y in 32:
		for x in 32:
			var c := a.get_pixel(x, y)
			if c.a8 != 0 and c.a8 != 255:
				off_palette += 1
			elif not PaperDollBaker.palette_has(c):
				off_palette += 1
	check("alle pixels heel ondoorzichtig of leeg, en in het masterpalet (%d fout)" % off_palette, off_palette == 0)


func _all_combinations() -> void:
	var m: Dictionary = Profile.LOOK_MAX
	var total := 0
	var bad := 0
	var empty := 0
	var t0 := Time.get_ticks_msec()
	# Alle waarden van de lagen in het portret; onder/onderkleur lopen mee (geen eigen pixels).
	for body in int(m["body"]) + 1:
		for skin in int(m["skin"]) + 1:
			for hair in int(m["hair"]) + 1:
				for hc in int(m["hair_color"]) + 1:
					for top in int(m["top"]) + 1:
						for tc in int(m["top_color"]) + 1:
							for head in int(m["head"]) + 1:
								var look := {
									"body": body, "skin": skin, "hair": hair, "hair_color": hc,
									"top": top, "top_color": tc, "head": head,
									"bottom": total % (int(m["bottom"]) + 1),
									"bottom_color": total % (int(m["bottom_color"]) + 1),
								}
								var img := PortraitBaker.image_for(look)
								total += 1
								if img == null or img.get_width() != 32 or img.get_height() != 32:
									bad += 1
								elif img.is_invisible():
									empty += 1
	var ms := Time.get_ticks_msec() - t0
	check("alle %d portret-combinaties binnen LOOK_MAX bakken zonder fout (%d ms)" % [total, ms], total == 13824 and bad == 0)
	check("geen enkel combinatie-portret is leeg", empty == 0)


func _fallback() -> void:
	var fallback: Texture2D = load("res://assets/ui/lobby/portret_noor.png")
	var broken_blob := AvatarBlob.encode(_look({"class": "warrior"}))
	broken_blob[10] = 99
	var bad_sum := Profile.encode_look(_look())
	bad_sum[15] = (int(bad_sum[15]) + 1) % 256
	var cases := {
		"lege dictionary": {},
		"null": null,
		"tekst": "kapot",
		"getal": 7,
		"skin te hoog": _look({"skin": 99}),
		"hair negatief": _look({"hair": -1}),
		"hair_color 1.5": _look({"hair_color": 1.5}),
		"head als tekst": _look({"head": "hoed"}),
		"top als bool": _look({"top": true}),
		"sleutel mist": {"body": 0, "skin": 0},
		"bytes te kort": PackedByteArray([1, 2, 3]),
		"blob met kapotte klasse": broken_blob,
		"profielbytes met foute checksum": bad_sum,
		"onbekende look-versie": PackedByteArray([9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
	}
	PortraitBaker.reset_stats()
	for label in cases:
		var raw: Variant = cases[label]
		var tex := PortraitBaker.texture_or(raw, fallback)
		check("terugval bij %s: vast portret" % label, tex == fallback and PortraitBaker.bake(raw) == null)
	check("kapotte looks komen niet in de cache", PortraitBaker.bakes == 0)
	check("terugval zonder vast portret: null, geen crash", PortraitBaker.texture_or({}, null) == null)


func _timing() -> void:
	var ci := OS.get_environment("CI") != "" or OS.get_environment("GITHUB_ACTIONS") != ""
	var limit := LIMIT_CI_MS if ci else LIMIT_LOCAL_MS
	PortraitBaker.release_cache()
	PortraitBaker.reset_stats()
	var count := 0
	var total_us := 0
	var max_us := 0
	for i in 60:
		# 60 verschillende looks: i*229 als getal in gemengde basis (4*6*8*4*6*3 = 13824).
		var n := (i * 229) % 13824
		var look := _look({
			"skin": n % 4, "hair": (n / 4) % 6, "hair_color": (n / 24) % 8,
			"top": (n / 192) % 4, "top_color": (n / 768) % 6, "head": (n / 4608) % 3,
		})
		var t0 := Time.get_ticks_usec()
		var tex := PortraitBaker.bake(look)
		var us := int(Time.get_ticks_usec() - t0)
		if tex == null:
			continue
		count += 1
		total_us += us
		max_us = maxi(max_us, us)
	var avg_ms := float(total_us) / maxf(1.0, float(count)) / 1000.0
	print("INFO  portret bakken: gem. %.3f ms, max %.3f ms (koud, inclusief laden), grens %.0f ms%s" % [
		avg_ms, float(max_us) / 1000.0, limit, " (CI)" if ci else ""])
	check("60 portretten gebakken (%d nieuw in de cache)" % PortraitBaker.bakes, count == 60 and PortraitBaker.bakes == 60)
	check("bakken < %.0f ms per portret (gem. %.3f ms)" % [limit, avg_ms], avg_ms < limit)


func _cache_release() -> void:
	PortraitBaker.bake(_look({"skin": 1}))
	check("cache gevuld (%d portretten, %d lagen warm)" % [PortraitBaker.cache_size(), PortraitBaker.warm_size()],
		PortraitBaker.cache_size() > 0 and PortraitBaker.warm_size() > 0)
	PaperDollBaker.release_warm_cache()
	check("PaperDollBaker.release_warm_cache() geeft ook de portretcache vrij",
		PortraitBaker.cache_size() == 0 and PortraitBaker.warm_size() == 0)
	PortraitBaker.bake(_look({"skin": 2}))
	PortraitBaker.release_cache()
	check("PortraitBaker.release_cache() leegt alles", PortraitBaker.cache_size() == 0 and PortraitBaker.warm_size() == 0)


func _slot() -> void:
	var slot := Slot.new()
	add_child(slot)
	await get_tree().process_frame
	var look := _look({"skin": 3, "hair": 1, "hair_color": 5, "top": 1, "top_color": 4, "head": 1})
	slot.set_seat("dennis", Roles.role_of("dennis"))
	await get_tree().process_frame
	check("zonder look: vast heldenportret van #454", slot.portrait_source() == "hero"
		and slot.portrait_texture() != null and slot.portrait_texture().get_path().ends_with("portret_dennis.png"))
	slot.set_look(look)
	await get_tree().process_frame
	var face := slot.portrait_texture()
	check("met look: gebakken portret", slot.portrait_source() == "baked" and face is ImageTexture)
	check("gebakken portret = bakker-pixels", face != null
		and PortraitBaker.image_hash(face.get_image()) == PortraitBaker.image_hash(PortraitBaker.image_for(look)))
	var rect: TextureRect = null
	for child in slot.get_children():
		if child is TextureRect and (child as TextureRect).texture == face:
			rect = child
	check("pixel-perfect: NEAREST, 32x32 op 32x32 (schaal 1)", rect != null
		and rect.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and rect.stretch_mode == TextureRect.STRETCH_KEEP
		and rect.size == Vector2(32, 32) and face.get_size() == Vector2(32, 32))
	check("rol-lijst blijft staan", slot.frame_back_texture() != null and slot.frame_front_texture() != null)
	slot.set_look({"skin": 42})
	await get_tree().process_frame
	check("kapotte look: terug naar het vaste portret", slot.portrait_source() == "hero"
		and slot.portrait_texture().get_path().ends_with("portret_dennis.png"))
	slot.set_look(null)
	await get_tree().process_frame
	check("look weg: vast portret", slot.portrait_source() == "hero")
	slot.set_seat("", "tank")
	slot.set_look(look)
	await get_tree().process_frame
	check("lege stoel met look: geen portret, geen crash", slot.portrait_texture() == null and slot.portrait_source() == "")
	slot.queue_free()
	await get_tree().process_frame


func _lobby_rows() -> void:
	var screen := CoopLobbyScreen.new()
	add_child(screen)
	await get_tree().process_frame
	var own := _look({"skin": 1, "hair": 3, "hair_color": 2, "top": 3, "top_color": 0, "head": 0})
	var other := _look({"skin": 0, "hair": 5, "hair_color": 6, "top": 0, "top_color": 5, "head": 2})
	var own_blob := own.duplicate()
	own_blob["class"] = "warrior"
	var other_blob := other.duplicate()
	other_blob["class"] = "mage"
	var lobby: LanLobby = screen.lobby
	var rows: Array[Dictionary] = [
		{"slot": 0, "seat": 0, "character_id": "dennis", "look": AvatarBlob.encode(own_blob)},
		{"slot": 1, "seat": 1, "character_id": "noor", "look": AvatarBlob.encode(other_blob)},
		{"slot": 2, "seat": 2, "character_id": "lotte", "look": PackedByteArray()},
		{"slot": 3, "seat": 3, "character_id": "kael"},
	]
	lobby.slots = rows
	lobby.local_slot = 0
	screen._clear_box()
	screen._add_roster_rows(true)
	await get_tree().process_frame
	var p0 := screen.find_child("SeatPortrait0", true, false) as LobbyPortraitSlot
	var p1 := screen.find_child("SeatPortrait1", true, false) as LobbyPortraitSlot
	var p2 := screen.find_child("SeatPortrait2", true, false) as LobbyPortraitSlot
	var p3 := screen.find_child("SeatPortrait3", true, false) as LobbyPortraitSlot
	check("lobby: eigen stoel toont het gebakken portret", p0 != null and p0.portrait_source() == "baked"
		and PortraitBaker.image_hash(p0.portrait_texture().get_image()) == PortraitBaker.image_hash(PortraitBaker.image_for(own)))
	check("lobby: andere speler met look: gebakken portret", p1 != null and p1.portrait_source() == "baked"
		and PortraitBaker.image_hash(p1.portrait_texture().get_image()) == PortraitBaker.image_hash(PortraitBaker.image_for(other)))
	check("lobby: stoel zonder look (lege bytes): vast portret", p2 != null and p2.portrait_source() == "hero")
	check("lobby: stoel zonder look-veld (LAN): vast portret", p3 != null and p3.portrait_source() == "hero")
	# Eigen stoel zonder look in de seat-data: het hal-profiel.
	lobby.slots = [{"slot": 2, "seat": 2, "character_id": "lotte"}] as Array[Dictionary]
	lobby.local_slot = 2
	screen.hall_profile = {"uid": "0123abcd", "name": "Dax", "class": "priest", "look": own.duplicate()}
	screen._clear_box()
	screen._add_roster_rows(false)
	await get_tree().process_frame
	var own_row := screen.find_child("SeatPortrait2", true, false) as LobbyPortraitSlot
	check("lobby: eigen stoel zonder seat-look gebruikt het profiel", own_row != null and own_row.portrait_source() == "baked")
	screen.hall_profile = {"look": {"skin": "kapot"}}
	screen._clear_box()
	screen._add_roster_rows(false)
	await get_tree().process_frame
	own_row = screen.find_child("SeatPortrait2", true, false) as LobbyPortraitSlot
	check("lobby: kapot profiel: vast portret, geen crash", own_row != null and own_row.portrait_source() == "hero")
	lobby.slots = [] as Array[Dictionary]
	lobby.local_slot = Protocol.NO_SLOT
	screen.hall_profile = {}
	screen.queue_free()
	await get_tree().process_frame



## Met --shots=/pad: een strook voorbeeldportretten (4x, nearest) om te bekijken.
func _shots() -> void:
	var dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			dir = arg.substr(8)
	if dir == "":
		return
	DirAccess.make_dir_recursive_absolute(dir)
	var looks: Array = [
		_look(),
		_look({"skin": 1, "hair": 0, "hair_color": 0, "top": 2, "top_color": 0}),
		_look({"skin": 0, "hair": 2, "hair_color": 2, "top": 3, "top_color": 4}),
		_look({"skin": 2, "hair": 5, "hair_color": 0, "top": 1, "top_color": 5, "head": 2}),
		_look({"skin": 3, "hair": 4, "hair_color": 4, "top": 0, "top_color": 2, "head": 1}),
		_look({"skin": 1, "hair": 3, "hair_color": 3, "top": 0, "top_color": 3}),
	]
	var strip := Image.create(32 * looks.size(), 32, false, Image.FORMAT_RGBA8)
	strip.fill(Color8(40, 36, 52))
	for i in looks.size():
		var img := PortraitBaker.image_for(looks[i])
		if img != null:
			strip.blend_rect(img, Rect2i(0, 0, 32, 32), Vector2i(i * 32, 0))
	strip.resize(strip.get_width() * 4, strip.get_height() * 4, Image.INTERPOLATE_NEAREST)
	strip.save_png(dir.path_join("portretbakker_voorbeelden.png"))
