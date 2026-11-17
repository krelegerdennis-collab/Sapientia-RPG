extends Node
## UI-scenario's voor de WM1-schermen (veldmenu, winkel, Codex, lobby, gevecht, tekstvak, touch-HUD).
## Gedeeld door de screenshot-tool (ui_shots.gd) en de testsuite (scripts/tests/ui_polish_tests.gd).
## Geen eigen testlogica: een scenario opent een scherm en laat het open staan; sluiten doet close_all().
## Alles wat de speler ziet is Engels (komt uit de bestaande schermen).

const WORLD_TOWN := "res://scenes/maps/wilgendal.tscn"
const ShopScreen := preload("res://scripts/ui/shop_screen.gd")
const KoopmanScherm := preload("res://scripts/ui/koopman_winkel_scherm.gd")
const CoopLobbyScreen := preload("res://scripts/ui/coop_lobby_screen.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")
const GameData := preload("res://scripts/data/game_data.gd")

## Profielen: naam -> viewportgrootte in 384x216-eenheden (wat Godot met stretch 'expand' toont).
## 16:9 = 384x216; 19,5:9 (S25 Ultra: 2340x1080 / 3120x1440) = 468x216; 21:9 = 504x216; 4:3 'hoog' (tablet) = 384x288.
## 19_5x9_notch = 19,5:9 met een gesimuleerde punch-hole links + afgeronde hoeken/gebarenbalk (NOTCH_INSETS).
const PROFILES := {
	"16x9": Vector2i(384, 216),
	"19_5x9": Vector2i(468, 216),
	"19_5x9_notch": Vector2i(468, 216),
	"21x9": Vector2i(504, 216),
	"4x3_hoog": Vector2i(384, 288),
}
## Veilig gebied per profiel in eenheden: Vector4(links, boven, rechts, onder).
const PROFILE_INSETS := {"19_5x9_notch": Vector4(22, 4, 10, 6)}
const UI_TOUCH := "res://scripts/ui/ui_touch.gd"

## Veldscenario's (in de Wilgendal-kaart) en gevechtsscenario's, in vaste volgorde.
## Ook te openen met open(): "lobby_join_code" en "lobby_menu_online" (online co-op, alleen in de tests).
const FIELD_SCENARIOS: Array[String] = [
	"hud", "dialog_narrator", "dialog_choices",
	"menu_main", "menu_items", "menu_equipment", "menu_magic", "menu_status", "menu_codex",
	"menu_bestiary", "menu_party", "menu_quests", "menu_options", "menu_save",
	"shop_buy", "shop_sell", "shop_merchant", "lobby_menu", "lobby_host", "lobby_join",
]
const BATTLE_SCENARIOS: Array[String] = ["battle_cross", "battle_magic", "battle_target"]

var shots_dir := ""
var profile := "16x9"
var _lobby: Node = null
var _lobby_layer: CanvasLayer = null


func scene() -> Node:
	return get_tree().current_scene


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func seconds(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await pframes(2)
	Input.action_release(action)
	await pframes(2)


func wait_scene(scene_name: String, timeout := 20.0) -> bool:
	var t := 0.0
	while t < timeout:
		var s := scene()
		if s != null and s.name == scene_name and s.is_node_ready():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return false


## Vlag van world_warper/opening/flow.gd (FLAG_DRIFT_DONE). Lazy: geen preload, dezelfde
## reden als GameState (flow → drift → font breekt een import-keten als het te vroeg parst).
var _drift_flag := ""


func _drift_flag_name() -> String:
	if _drift_flag != "":
		return _drift_flag
	_drift_flag = "warper_drift_done"
	var flow: Script = load("res://world_warper/opening/flow.gd") as Script
	if flow != null:
		_drift_flag = str(flow.get_script_constant_map().get("FLAG_DRIFT_DONE", _drift_flag))
	return _drift_flag


## new_game() wist story_flags. start_new_game() (game_state.gd) roept daarna
## WorldWarperOpeningFlow.should_play aan. --uishots eindigt niet op "test", dus
## flow.gd:_mag_in_tests() laat de drift toe bij een lege user://. De CanvasLayer
## (drift.gd, laag 125, tekst "For now, you only drift.") blijft tot MAX_SECONDS
## over élk scherm; warper_drift_done wordt pas gezet als de hele opening klaar is
## (flow.gd, na Hal + echo). De tool loopt de profielen in dict-volgorde, dus de
## eerste profielen schieten de intro en een later profiel (op een trage machine
## de notch) niet meer. Daarom niet start_new_game(), maar dezelfde opzet met de
## vlag meteen ná new_game().
func _begin_without_drift(hero_name: String) -> void:
	GameState.new_game_starts += 1
	GameState.use_story_saves()
	GameState.new_game(hero_name)
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	GameState.changing_map = false
	GameState._autosave_request = ""
	_mark_drift_seen()
	_free_opening_nodes()


func _mark_drift_seen() -> void:
	GameState.story_flags[_drift_flag_name()] = true


func _is_opening_runner(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	var scr := n.get_script() as Script
	if scr == null:
		return false
	return scr.resource_path.ends_with("world_warper/opening/flow.gd") and n.has_method("_wacht_hal")


## Drift-laag en de opening-runner weg, vóór die alsnog naar de Hal wisselt.
func _free_opening_nodes() -> void:
	var root := get_tree().root
	var doomed: Array[Node] = []
	for child in root.get_children():
		if _is_opening_runner(child):
			doomed.append(child)
	var drift := root.find_child("OpeningDrift", true, false)
	if drift != null and is_instance_valid(drift):
		var host := drift.get_parent()
		if host == null or not doomed.has(host):
			doomed.append(drift)
	for n in doomed:
		if is_instance_valid(n):
			n.free()


func _on_town() -> bool:
	var s := scene()
	return s != null and s.name == "Wilgendal" and s.is_node_ready()


## De opening kan de kaart onder een scenario vandaan halen. Zonder Wilgendal is
## FieldMenu null en crasht open_bestiary() (race, ui_scenarios open()).
func _ensure_town() -> bool:
	if _on_town():
		return true
	var t := 0.0
	while not _on_town() and GameState.changing_map and t < 4.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	if _on_town():
		return true
	if GameState.in_battle:
		return false
	_free_opening_nodes()
	GameState.changing_map = false
	if not GameState.change_map(WORLD_TOWN, "start"):
		await pframes(2)
		GameState.changing_map = false
		GameState.change_map(WORLD_TOWN, "start")
	return await wait_scene("Wilgendal", 8.0)


## Zet de viewport op een profiel. KEEP + vaste basisgrootte geeft exact wat 'expand' op die verhouding toont,
## los van de (xvfb-)vensteromvang.
func set_profile(name: String) -> void:
	profile = name
	var win := get_window()
	var size: Vector2i = PROFILES[name]
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.content_scale_size = size
	win.size = size * 3
	# vóór de veilig-gebied-code bestond (before-run) is er geen UiTouch: dan geen override
	if ResourceLoader.exists(UI_TOUCH):
		var ut: Script = load(UI_TOUCH)
		ut.set("insets_override", PROFILE_INSETS.get(name, null))
	await pframes(4)


func viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func start_game() -> bool:
	# scanlines uit: tekst en randen zijn zo goed te beoordelen (en de PNG's blijven klein)
	Settings.set_value("crt", false)
	_begin_without_drift("Kees")
	var sd: Script = load("res://scripts/data/story_data.gd")
	GameState.set("story_step", int(sd.get_script_constant_map().get("KLAAR", 0)))
	_mark_drift_seen()
	await seconds(0.4)
	while GameState.changing_map:
		await get_tree().process_frame
	await seconds(0.4)
	_free_opening_nodes()
	GameState.change_map(WORLD_TOWN, "start")
	var ok := await wait_scene("Wilgendal")
	await seconds(0.6)
	GameState.encounter_multiplier = 0.0
	GameState.add_member("noor")
	GameState.add_member("lotte")
	GameState.gold = 123
	var kees: Dictionary = GameState.party[0]
	kees["spells"] = ["vuur", "genees"]
	kees["max_mp"] = 12
	kees["mp"] = 12
	GameState.codex_add("mosslijm", 3)
	GameState.codex_add("papiergeest", 2)
	GameState.codex_add("moskonijn", 1)
	return ok


func field_menu() -> Node:
	return scene().get_node_or_null("FieldMenu") if scene() != null else null


func open_field_menu() -> Node:
	if not await _ensure_town():
		return null
	# Een tik tijdens lopen, een fade of een net gewiste kaart opent niets.
	# Opnieuw proberen; nooit een methode op null aanroepen.
	for _i in 8:
		if field_menu() != null:
			return field_menu()
		await tap("menu")
		await pframes(3)
	return field_menu()


func _call_menu(method: String, arg: Variant = null) -> bool:
	var menu := await open_field_menu()
	if menu == null or not menu.has_method(method):
		return false
	if arg == null:
		menu.call(method)
	else:
		menu.call(method, arg)
	return true


func close_field_menu() -> void:
	var m := field_menu()
	if m != null and is_instance_valid(m):
		m.close()
	await pframes(3)


## Opent het scenario; geeft false als het niet kon.
func open(name: String) -> bool:
	# Vangnet: staat de drift er toch, haal hem weg vóór het scherm én vóór de PNG.
	_mark_drift_seen()
	_free_opening_nodes()
	if not await _ensure_town():
		return false
	match name:
		"hud":
			await pframes(2)
		"dialog_narrator":
			Dialog.chars_per_second = 1000.0
			Dialog.show_lines(["The old shelves hum quietly. Somewhere a page turns by itself, and the ink of the last line is still wet."])
			await pframes(6)
		"dialog_choices":
			Dialog.chars_per_second = 1000.0
			Dialog.ask("Do you want to rest at the inn for the night?", ["Yes, please", "No, thanks", "Tell me more"], "Aunt Mien")
			await pframes(8)
		"menu_main":
			if await open_field_menu() == null:
				return false
		"menu_items":
			if not await _call_menu("choose", "items"):
				return false
		"menu_equipment":
			if not await _call_menu("open_equipment", 0):
				return false
		"menu_magic":
			if not await _call_menu("choose", "magic"):
				return false
		"menu_status":
			if not await _call_menu("open_status", 0):
				return false
		"menu_codex":
			if not await _call_menu("open_codex"):
				return false
		"menu_bestiary":
			if not await _call_menu("open_bestiary"):
				return false
		"menu_party":
			if not await _call_menu("open_party"):
				return false
		"menu_quests":
			if not await _call_menu("open_quests"):
				return false
		"menu_options":
			if not await _call_menu("choose", "options"):
				return false
		"menu_save":
			if not await _call_menu("open_save"):
				return false
		"shop_buy", "shop_sell":
			var shop := ShopScreen.new()
			shop.name = "ShopScreen"
			shop.shop_id = "wilgendal_pantser"
			scene().add_child(shop)
			await pframes(3)
			if name == "shop_sell":
				GameState.set_item_count("drankje", 3)
				shop._show_verkoop()
		"shop_merchant":
			var k := KoopmanScherm.new()
			k.name = "ShopScreen"
			k.run_seed = 7
			k.bezoek = 1
			scene().add_child(k)
		"lobby_menu", "lobby_host", "lobby_join", "lobby_join_code", "lobby_menu_online":
			if name == "lobby_menu_online":
				OS.set_environment(Protocol.RELAY_URL_ENV, "wss://relay.example.test")
			_lobby_layer = CanvasLayer.new()
			_lobby_layer.layer = 30
			get_tree().root.add_child(_lobby_layer)
			_lobby = CoopLobbyScreen.new()
			_lobby.name = "CoopUi"
			_lobby_layer.add_child(_lobby)
			await pframes(2)
			# als scène-root vult de lobby de viewport; onder een CanvasLayer moet dat met de hand
			_lobby.position = Vector2.ZERO
			_lobby.size = viewport_size()
			await pframes(2)
			if name == "lobby_host":
				_lobby._show_host()
			elif name == "lobby_join":
				_lobby._show_join_listen()
			elif name == "lobby_join_code":
				_lobby._show_join_code()
		_:
			return false
	await pframes(6)
	return true


## Sluit wat een scenario opende, zodat het volgende vanaf de kaart begint.
func close_all() -> void:
	OS.unset_environment(Protocol.RELAY_URL_ENV)
	if _lobby != null and is_instance_valid(_lobby):
		_lobby_layer.queue_free()
		_lobby = null
	if Dialog.is_open:
		Dialog.close()
	var s := scene()
	if s != null:
		var shop := s.get_node_or_null("ShopScreen")
		if shop != null:
			shop.queue_free()
	var m := field_menu()
	if m != null and is_instance_valid(m):
		if m.sub != null and is_instance_valid(m.sub):
			m.sub.queue_free()
			m.sub = null
		m.close()
	await pframes(4)


## Start een gevecht (Classic) en wacht tot het commandokruis open is.
func start_battle() -> bool:
	GameState.start_battle(["mosslijm", "papiergeest"], Vector2i(10, 10), Vector2i.DOWN, "gras")
	if not await wait_scene("Battle"):
		return false
	var b := scene()
	for i in 600:
		if b.state == "command":
			break
		await get_tree().process_frame
	await pframes(10)
	return b.state == "command"


## Gevecht verlaten (vluchten) en wachten tot de kaart weer staat.
func end_battle() -> void:
	await GameState.end_battle("flee")
	await wait_scene("Wilgendal")
	await seconds(0.6)


func open_battle(name: String) -> bool:
	var b := scene()
	if b == null or b.name != "Battle":
		return false
	match name:
		"battle_cross":
			pass
		"battle_magic":
			await tap("move_up")
			await tap("interact")
		"battle_target":
			await tap("interact")
		_:
			return false
	await pframes(10)
	return true


## Terug naar het commandokruis (B, zo vaak als nodig).
func battle_back_to_cross() -> void:
	for i in 3:
		await tap("cancel")
	await pframes(4)


## Alleen als er een screenshotmap is (tests): zelfde als shot().
func shot_if(file_name: String) -> void:
	if shots_dir != "":
		await shot(file_name)


## Screenshot van de huidige viewport, ~936 px breed (gevecht: al 2x fijn; rest 2x vergroot) (scherpe pixels). Geeft het pad terug.
func shot(file_name: String) -> String:
	if shots_dir == "":
		return ""
	_mark_drift_seen()
	_free_opening_nodes()
	await pframes(3)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot mogelijk")
		return ""
	var factor := maxi(1, roundi(936.0 / float(img.get_width())))
	if factor > 1:
		img.resize(img.get_width() * factor, img.get_height() * factor, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(shots_dir)
	var path := shots_dir.path_join("%s_%s.png" % [file_name, profile])
	img.save_png(path)
	print("INFO  screenshot: ", path, " ", img.get_size())
	return path
