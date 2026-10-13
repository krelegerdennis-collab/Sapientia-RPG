extends Node
## ALLEEN VOOR TESTEN - DE KOOPMAN (H-5) + GROTKAMERS + HUB-RONDLOPERS (RPG ART batch 9 en 10).
## Start:  godot --path . -- --koopmantest [--shots=/pad/map]
##   Deel A: data: fases 1-3 / 4-7 / 8+ (CANON §12), token +10%, kamersoorten, plekken, valschade.
##   Deel B: save/load + nederlaag: bezoekteller en token blijven.
##   Deel C: echte scène: Koopman + kraam op een koopmanverdieping, gesprek, bezoek telt 1x per verdieping.
##   Deel D: valkamer (vallen zichtbaar/verborgen, stap = schade) en rustkamer (kampvuur-animatie).
##   Deel E: hub: rondlopers zijn AnimatedSprite2D met 16x24-frames uit de batch 9-sheets.
## Zit niet in de export (scripts/tests/*).

const Gen := preload("res://scripts/dungeon/dungeon100_generator.gd")
const K := preload("res://scripts/data/koopman_data.gd")
const GK := preload("res://scripts/data/grot_kamers.gd")
const SD := preload("res://scripts/data/story_data.gd")
const CodexData := preload("res://scripts/data/codex_data.gd")
const Wanderers := preload("res://world_warper/wander/wanderers.gd")
const HAL := "res://world_warper/maps/hal.tscn"
const DUNGEON := "res://scenes/maps/dungeon100.tscn"
const SEED := 4242
const BATCH9 := ["mosslijm", "moskonijn", "papiergeest", "glitchmot", "mech_wachter", "kennis_beest",
		"wortelkruiper", "mistuil", "sporenzwam", "inktwurm"]

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	seed(5005)
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func():
		check("waakhond: test klaar binnen 300 s", false)
		print("RESULT FOUT (waakhond)")
		get_tree().quit(1))
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	print("=== Deel A: data ===")
	_data_tests()
	print("=== Deel B: save/load ===")
	_save_tests()
	print("=== Deel C: Koopman in de Grot ===")
	await _koopman_scene()
	print("=== Deel D: val- en rustkamer ===")
	await _val_rust_scene()
	print("=== Deel E: hub-rondlopers ===")
	await _hub_scene()
	print("KOOPMANTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await pframes(10)
	get_tree().quit(1 if failures else 0)


# ================================================================ helpers
func scene() -> Node:
	return get_tree().current_scene


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_until(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func wait_fade() -> void:
	await wait_until(func(): return Transition._rect.color.a <= 0.01, 3.0)
	await pframes(2)


func wait_floor(n: int, timeout := 15.0) -> bool:
	var ok := await wait_until(func():
		var s := scene()
		return s != null and s.name == "Dungeon100" and s.is_node_ready() and not GameState.changing_map \
				and int(s.get("floor_no")) == n and GameState.dungeon100_floor == n, timeout)
	await wait_fade()
	return ok


func screenshot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(shots)
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(shots.path_join(name + ".png"))
	print("INFO  screenshot: ", shots.path_join(name + ".png"))


func close_dialog() -> void:
	var n := 0
	while Dialog.is_open and n < 40:
		Dialog.advance()
		await pframes(3)
		n += 1


func _floor_of(soort: String, from := 2) -> int:
	for f in range(from, 100):
		if GK.kamer_soort(SEED, f) == soort:
			return f
	return -1


# ================================================================ A
func _data_tests() -> void:
	var tiers := {1: 1, 2: 1, 3: 1, 4: 2, 5: 2, 7: 2, 8: 3, 9: 3, 20: 3}
	var ok := true
	for n in tiers:
		ok = ok and K.fase(n) == tiers[n]
	check("fases: bezoek 1-3 vaag, 4-7 fragmenten, 8+ waarheid", ok)
	check("na Archief 5: meteen fase 3", K.fase(1, true) == K.FASE_WAARHEID)
	var g1 := K.gesprek(1, false)
	var g8 := K.gesprek(8, false)
	var g9 := K.gesprek(9, true)
	check("fase 1: binnenkomstregel (canon) + vertrekregel", g1[0].begins_with("Well, well. A new candidate.") and g1[-1] == K.VERTREK)
	check("fase 1-2 geven geen token", not "\n".join(g1).contains("H-5's Token") and not "\n".join(K.gesprek(5, false)).contains("H-5's Token"))
	check("fase 3 zonder token: geeft H-5's Token", "\n".join(g8).contains("Received H-5's Token"))
	check("fase 3 met token: geen tweede token", not "\n".join(g9).contains("Received H-5's Token"))
	check("in-game naam Engels: 'the Merchant'", K.NAAM == "the Merchant")
	check("token: +10% tegen dienaren, niets zonder token of in oefening",
			is_equal_approx(K.token_factor(true, true), 1.1) and K.token_factor(false, true) == 1.0 and K.token_factor(true, false) == 1.0)
	var tex: Texture2D = K.SPRITE
	check("koopman_veld.png laadt (48x96)", tex != null and tex.get_size() == Vector2(48, 96))
	check("grot_kamers.png laadt (128x48)", GK.ATLAS != null and GK.ATLAS.get_size() == Vector2(128, 48))
	# kamersoorten
	var per_blok := true
	for b in 10:
		var n := 0
		for f in range(b * 10 + 1, b * 10 + 11):
			if GK.kamer_soort(SEED, f) == GK.SOORT_KOOPMAN:
				n += 1
		per_blok = per_blok and n == 1
	check("precies 1 koopmanverdieping per blok van 10", per_blok)
	var regels := true
	for s in [1, 7, SEED, 99999]:
		for f in range(1, 101):
			var k := GK.kamer_soort(s, f)
			if k == GK.SOORT_VAL and f < 4:
				regels = false
			if k == GK.SOORT_KOOPMAN and (f % 10 == 0 or f in [25, 50, 75, 99, 100] or f == 1):
				regels = false
			if (f % 10 == 0 and f < 100) != (k == GK.SOORT_RUST):
				regels = false
	check("val nooit op 1-3; koopman nooit op rust/baas/1/100; rust = elke 10e", regels)
	check("deterministisch per (seed, verdieping)", GK.kamer_soort(SEED, 37) == GK.kamer_soort(SEED, 37))
	var vals := 0
	for f in range(4, 100):
		if GK.kamer_soort(SEED, f) == GK.SOORT_VAL:
			vals += 1
	check("valkamers bestaan maar zijn zeldzaam (%d van 96)" % vals, vals >= 1 and vals <= 20)
	check("valschade spijker 5-10%, rune 10%, nooit dodelijk",
			GK.val_schade("spijker", 100, 100, 0.0) == 5 and GK.val_schade("spijker", 100, 100, 1.0) == 10
			and GK.val_schade("rune", 100, 100, 0.3) == 10 and GK.val_schade("rune", 100, 3, 0.5) == 2)
	var kf := _floor_of(GK.SOORT_KOOPMAN)
	var d: Dictionary = Gen.generate(SEED, kf)
	var plek := GK.koopman_plek(d["room"], d)
	check("koopmanplek gevonden op verdieping %d" % kf, not plek.is_empty())
	if not plek.is_empty():
		var reach := Gen.reachable_tiles(d["room"], d["spawn_up"])
		check("koopman en kraam staan op bereikbare vloer", reach.has(plek["koopman"]) and reach.has(plek["kraam"]))


# ================================================================ B
func _save_tests() -> void:
	GameState.new_game("Dennis")
	check("nieuw spel: 0 bezoeken, geen token", GameState.koopman_bezoeken == 0 and not GameState.koopman_token)
	check("bezoek telt", GameState.koopman_bezoek("1_5") == 1)
	check("zelfde verdieping telt niet opnieuw", GameState.koopman_bezoek("1_5") == 1)
	check("volgende verdieping telt", GameState.koopman_bezoek("1_15") == 2)
	GameState.koopman_token = true
	var data := GameState.state_data(Vector2i(3, 4), Vector2i.DOWN)
	check("save heeft blok 'koopman'", data.get("koopman", {}).get("bezoeken", -1) == 2 and data["koopman"]["token"] == true)
	GameState.new_game("Dennis")
	check("new_game wist de teller", GameState.koopman_bezoeken == 0)
	GameState.apply_state(data)
	check("load: teller 2 + token terug", GameState.koopman_bezoeken == 2 and GameState.koopman_token and GameState.koopman_laatste == "1_15")
	var oud := data.duplicate(true)
	oud.erase("koopman")
	GameState.apply_state(oud)
	check("oude save zonder blok: 0 bezoeken", GameState.koopman_bezoeken == 0 and not GameState.koopman_token)
	# nederlaag: checkpoint-respawn rolt de teller niet terug
	GameState.apply_state(data)
	GameState.set_checkpoint(GameState.current_map, Vector2i(3, 4), Vector2i.DOWN)
	GameState.koopman_bezoek("1_25")
	GameState.respawn_at_checkpoint()
	check("na respawn: teller blijft 3", GameState.koopman_bezoeken == 3)


# ================================================================ C
func _start_floor(f: int) -> Node:
	GameState.new_game("Dennis")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	GameState.dungeon100_seed = SEED
	GameState.dungeon100_floor = f
	GameState.change_map(DUNGEON, "omhoog")
	check("verdieping %d geladen" % f, await wait_floor(f))
	return scene()


func _koopman_scene() -> void:
	var kf := _floor_of(GK.SOORT_KOOPMAN)
	var r := await _start_floor(kf)
	check("kamersoort koopman", str(r.get("kamer_soort")) == GK.SOORT_KOOPMAN)
	var k = r.get("koopman")
	check("Koopman staat in de kamer", k != null and is_instance_valid(k))
	if k == null:
		return
	var sp: Sprite2D = k.get("sprite")
	check("sprite = koopman_veld.png, 3x4 frames van 16x24", sp.texture == K.SPRITE and sp.hframes == 3 and sp.vframes == 4)
	check("kraam: 4 tegels uit rij 2 van grot_kamers.png", k.get_parent().get_node("Kraam").get_child_count() == 5)
	var lines: Array = k.praat()
	check("eerste gesprek: bezoek 1, fase 1", GameState.koopman_bezoeken == 1 and int(k.get("last_fase")) == 1)
	k.praat()
	check("tweede gesprek op dezelfde verdieping: nog steeds 1 bezoek", GameState.koopman_bezoeken == 1)
	# echt via de speler: voor de Koopman zetten en A
	var pl = r.get_node("Objects/Player")
	var kt: Vector2i = k.get_tile()
	pl.place_at(kt + Vector2i.DOWN, Vector2i.UP)
	await pframes(3)
	k.interact(pl)
	await pframes(6)
	check("gesprek via interact opent het tekstvak", Dialog.is_open)
	await get_tree().create_timer(3.0).timeout
	await screenshot("koopman_grot_fase1")
	await close_dialog()
	# fase 2 en 3
	GameState.koopman_bezoeken = 4
	GameState.koopman_laatste = ""
	k.praat()
	check("bezoek 5: fase 2 (fragmenten)", int(k.get("last_fase")) == 2 and not GameState.koopman_token)
	GameState.koopman_bezoeken = 7
	GameState.koopman_laatste = ""
	k.interact(pl)
	await get_tree().create_timer(3.0).timeout
	check("bezoek 8: fase 3 + H-5's Token gekregen", int(k.get("last_fase")) == 3 and GameState.koopman_token)
	await screenshot("koopman_grot_fase3")
	for i in 4:     # door naar "Take this..." (regel 5 van fase 3)
		Dialog.advance()
		await pframes(4)
		Dialog.advance()
		await get_tree().create_timer(2.5).timeout
	await screenshot("koopman_grot_token")
	await close_dialog()
	await screenshot("koopman_kraam")
	check("lines niet leeg", not lines.is_empty())


# ================================================================ D
func _val_rust_scene() -> void:
	var vf := _floor_of(GK.SOORT_VAL, 4)
	var r := await _start_floor(vf)
	check("kamersoort val op verdieping %d" % vf, str(r.get("kamer_soort")) == GK.SOORT_VAL)
	var vallen: Dictionary = r.get("vallen")
	check("%d vallen geplaatst" % vallen.size(), vallen.size() >= GK.VAL_MIN)
	var alle_anim := true
	for v in vallen.values():
		var a: AnimatedSprite2D = v.get("anim")
		alle_anim = alle_anim and a != null and a.sprite_frames.has_animation("actief") \
				and str(a.animation) == ("verborgen" if v.verborgen else "zichtbaar")
	check("vallen tonen hidden/visible-tegel uit rij 0", alle_anim)
	var v0 = vallen.values()[0]
	var h: Dictionary = GameState.party[0]
	var hp0 := int(h["hp"])
	r.call("_on_val_stap", v0.get("tile"))
	await pframes(10)
	check("stap op val: schade (%d -> %d) en geactiveerd" % [hp0, int(h["hp"])], int(h["hp"]) < hp0 and v0.afgegaan
			and str(v0.get("anim").animation) == "actief")
	await close_dialog()
	var hp1 := int(h["hp"])
	r.call("_on_val_stap", v0.get("tile"))
	check("val gaat maar één keer af", int(h["hp"]) == hp1 and not Dialog.is_open)
	var pl = r.get_node("Objects/Player")
	pl.place_at(v0.get("tile") + Vector2i.DOWN, Vector2i.UP)
	await pframes(20)
	await screenshot("valkamer")
	# rustkamer
	r = await _start_floor(10)
	var rp: Node = r.get_node_or_null("Objects/Rustpunt")
	var vuur: AnimatedSprite2D = rp.get("vuur") if rp else null
	check("rustpunt heeft kampvuur (4 frames, speelt)", vuur != null and vuur.sprite_frames.get_frame_count("default") == 4 and vuur.is_playing())
	check("kampvuur-frames komen uit grot_kamers.png rij 1",
			vuur != null and (vuur.sprite_frames.get_frame_texture("default", 0) as AtlasTexture).region == Rect2(0, 16, 16, 16))
	pl = r.get_node("Objects/Player")
	var rt := Vector2i((rp.position / 16.0).floor())
	pl.place_at(rt + Vector2i.DOWN, Vector2i.UP)
	await pframes(20)
	await screenshot("rustkamer")


# ================================================================ E
func _hub_scene() -> void:
	GameState.new_game("Dennis")
	GameState.story_step = SD.NACHT
	for soort in ["mosslijm", "glitchmot", "mech_wachter", "inktwurm", "mistuil"]:
		GameState.codex_add(soort, 3)
	check("Codex heeft 5 pagina's", GameState.codex_pages.size() == 5)
	var alle := true
	for soort in BATCH9:
		var p := Wanderers._sheet_wezen(str(soort))
		var tex: Texture2D = load(p) if p != "" else null
		alle = alle and tex != null and tex.get_size() == Vector2(48, 96)
	check("alle 10 batch 9-soorten hebben een 48x96 hub-sheet", alle)
	GameState.story_flags["world_warper_intro_seen"] = true     # geen dreiging-cutscene
	GameState.change_map(HAL, "ingang")
	var ok := await wait_until(func(): return scene() != null and scene().scene_file_path == HAL \
			and scene().is_node_ready() and not GameState.changing_map, 15.0)
	await wait_fade()
	check("hub geladen", ok)
	await pframes(5)
	var w: Node = scene().find_child("Wanderers", true, false)
	check("Wanderers in de hub", w != null)
	if w == null:
		return
	w.call("refresh")
	await pframes(5)
	var lopers := w.get_children().filter(func(c): return str(c.name).begins_with("Loper_"))
	check("1 held + 5 wezens lopen rond (%d)" % lopers.size(), lopers.size() == 6)
	var anim_ok := true
	var geen_vlak := true
	for l in lopers:
		var a := l.get_node_or_null("Sprite") as AnimatedSprite2D
		anim_ok = anim_ok and a != null and a.sprite_frames.has_animation("loop_omlaag") \
				and a.sprite_frames.get_frame_count("loop_links") == 4 \
				and a.sprite_frames.get_frame_texture("stil_omlaag", 0).get_size() == Vector2(16, 24)
		for c in l.get_children():
			if c is ColorRect:
				geen_vlak = false
	check("alle lopers zijn AnimatedSprite2D met 16x24-frames", anim_ok)
	check("geen placeholder-vlakken meer", geen_vlak)
	var hp = scene().get_node_or_null("Objects/Player")
	if hp:
		hp.place_at(Vector2i(16, 12), Vector2i.UP)
	await pframes(90)
	var lopend := false
	for l in lopers:
		var a := l.get_node_or_null("Sprite") as AnimatedSprite2D
		if a and str(a.animation).begins_with("loop_"):
			lopend = true
	check("minstens één loper speelt een loopanimatie", lopend)
	await screenshot("hub_rondlopers")
