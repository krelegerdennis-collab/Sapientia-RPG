extends Node
## ALLEEN VOOR TESTEN - deel C van --savestresstest (scripts/tests/save_stress_tests.gd).
## Pauze/hervat zoals Android ze stuurt (PAUSED, FOCUS_OUT, FOCUS_IN, RESUMED via propagate_notification)
## midden in het veldmenu, een dialoog en een gevecht (ook op het overwinningsvenster):
## geen dubbele beloning, geen vastloper, geen verloren voortgang.
## Zit niet in de export (scripts/tests/*).

const StoryData := preload("res://scripts/data/story_data.gd")

const TOWN := "res://scenes/maps/wilgendal.tscn"
const BURSTS := 3
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up"}

## check(label, ok) van de suite.
var check_cb: Callable
var _fps_before := 0


func check(label: String, ok: bool) -> void:
	check_cb.call(label, ok)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# ---------------------------------------------------------------- hulpjes
func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_scene(scene_name: String, timeout := 15.0) -> bool:
	var t := 0.0
	while t < timeout:
		var s := get_tree().current_scene
		if s != null and s.name == scene_name and s.is_node_ready():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return false


func _battle() -> Node:
	var s := get_tree().current_scene
	if s != null and s.scene_file_path == GameState.BATTLE_SCENE and s.is_node_ready():
		return s
	return null


func _tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)


func _notify(what: int) -> void:
	get_tree().root.propagate_notification(what)


## Wat een telefoon stuurt als je de app wegdrukt en terughaalt, 'times' keer achter elkaar.
func _burst(times: int) -> void:
	for i in times:
		_notify(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		_notify(Node.NOTIFICATION_APPLICATION_PAUSED)
		await _frames(2)
		_notify(Node.NOTIFICATION_APPLICATION_RESUMED)
		_notify(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		await _frames(2)


## Na hervatten: niets blijft in 'achtergrond' hangen en de boom staat niet op pauze.
func _check_resumed(waar: String) -> void:
	check("%s: na hervatten geen achtergrondstand, framerate-cap terug (%d), boom niet gepauzeerd" % [waar, _fps_before],
			not AppLifecycle.is_background() and Engine.max_fps == _fps_before and not get_tree().paused)


func _autosave_path() -> String:
	GameState.sync_autosave_path()
	return GameState.autosave_path


func _remove(path: String) -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		var p: String = path + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


# ---------------------------------------------------------------- run
func run() -> void:
	var orig_mobile: bool = AppLifecycle.force_mobile
	AppLifecycle.force_mobile = true      # FOCUS_OUT telt dan als achtergrond, zoals op een telefoon
	_fps_before = Engine.max_fps
	GameState.new_game("Kees")
	GameState.story_step = StoryData.KLAAR
	GameState.change_map(TOWN, "start")
	var ok := await _wait_scene("Wilgendal")
	check("pauze-deel: Wilgendal geladen", ok)
	if ok:
		await _frames(20)
		var map: Node = get_tree().current_scene
		var player: Node = map.get_node_or_null("Objects/Player")
		check("pauze-deel: speler staat in de kaart", player != null)
		if player != null:
			await _menu_part(map)
			await _dialog_part()
			await _battle_part(player)
	AppLifecycle.force_mobile = orig_mobile
	_remove(_autosave_path())


# ---------------------------------------------------------------- menu
func _menu_part(map: Node) -> void:
	var auto := _autosave_path()
	_remove(auto)
	GameState.gold = 321
	GameState.set_item_count("drankje", 5)
	await _tap("menu")
	await _frames(3)
	var menu: Node = map.get_node_or_null("FieldMenu")
	check("menu: veldmenu is open", menu != null)
	if menu == null:
		return
	var count0 := GameState.autosave_count
	var inv_before := JSON.stringify(GameState.inventory, "", true)
	await _burst(BURSTS)
	_check_resumed("menu")
	check("menu: %dx pauze/hervat -> menu nog open en bruikbaar" % BURSTS,
			is_instance_valid(menu) and menu.is_inside_tree() and map.get_node_or_null("FieldMenu") == menu)
	check("menu: pauze-save(s) geschreven (%d), reden 'achtergrond'" % (GameState.autosave_count - count0),
			GameState.autosave_count > count0 and GameState.last_autosave_reason == "achtergrond")
	var a := GameState.read_save(auto)
	var inv_a: Dictionary = a.get("inventory", {}) if a.get("inventory") is Dictionary else {}
	check("menu: pauze-save bevat precies de huidige stand (321 goud, 5 drankjes)",
			int(a.get("gold", -1)) == 321 and int(inv_a.get("drankje", -1)) == 5)
	check("menu: goud en tas onveranderd door pauze/hervat",
			GameState.gold == 321 and JSON.stringify(GameState.inventory, "", true) == inv_before)
	if is_instance_valid(menu) and menu.has_method("close"):
		menu.close()
	await _frames(5)
	check("menu: na sluiten is het veld weer vrij (geen vastloper)", GameState.field_free())


# ---------------------------------------------------------------- dialoog
func _dialog_part() -> void:
	var auto := _autosave_path()
	_remove(auto)
	var count0 := GameState.autosave_count
	var gold0 := GameState.gold
	Dialog.show_lines(["Stress test line one.", "Stress test line two."])
	await _frames(3)
	check("dialoog: tekstvak open", Dialog.is_open)
	await _burst(BURSTS)
	_check_resumed("dialoog")
	check("dialoog: %dx pauze/hervat -> tekstvak nog open" % BURSTS, Dialog.is_open)
	check("dialoog: geen pauze-save midden in een dialoog", GameState.autosave_count == count0
			and not FileAccess.file_exists(auto))
	check("dialoog: goud onveranderd", GameState.gold == gold0)
	for i in 40:
		if not Dialog.is_open:
			break
		Dialog.advance()
		await _frames(3)
	await _frames(5)
	check("dialoog: na hervatten gewoon door te klikken en dicht (geen vastloper)",
			not Dialog.is_open and GameState.field_free())
	_notify(Node.NOTIFICATION_APPLICATION_PAUSED)
	_notify(Node.NOTIFICATION_APPLICATION_RESUMED)
	check("dialoog: na de dialoog werkt de pauze-save weer",
			GameState.autosave_count == count0 + 1 and FileAccess.file_exists(auto))
	await _frames(2)


# ---------------------------------------------------------------- gevecht
func _battle_part(player: Node) -> void:
	var auto := _autosave_path()
	_remove(auto)
	var lead: Dictionary = GameState.party[0]
	lead["hp"] = int(lead["max_hp"])
	var gold0 := GameState.gold
	var exp0 := int(lead["exp"])
	var count0 := GameState.autosave_count
	GameState.start_battle(["mosslijm"], player.get_tile(), player.facing, "archief", false, 0)
	var b: Node = null
	for i in 900:
		b = _battle()
		if b != null:
			break
		await get_tree().process_frame
	check("gevecht: gevechtsscène geladen", b != null)
	if b == null:
		return
	await _frames(5)
	for e in b.enemies:
		e["s"]["hp"] = 1      # één klap: de test gaat over pauzeren, niet over balans
	await _burst(BURSTS)
	_check_resumed("gevecht")
	check("gevecht: %dx pauze/hervat -> nog in het gevecht, geen pauze-save, goud onveranderd" % BURSTS,
			GameState.in_battle and _battle() == b and GameState.autosave_count == count0
			and not FileAccess.file_exists(auto) and GameState.gold == gold0)

	var reward_gold := -1
	var reward_exp := -1
	var victory_checked := false
	for guard in 3000:
		if _battle() != b or not is_instance_valid(b):
			break
		var st := str(b.state)
		if st == "command":
			var cross: Node = b.cross
			if not bool(cross.active):
				await _frames(1)
				continue
			var sel := int(cross.selected)
			if sel != 0:
				await _tap(str(CROSS_BACK[sel]))
			else:
				await _tap("interact")      # Aanval
		elif st == "target_enemy":
			await _tap("interact")
		elif st == "target_ally":
			await _tap("cancel")
		elif st == "message_wait":
			if bool(b.victory_panel.visible) and not victory_checked:
				victory_checked = true
				reward_gold = 0
				reward_exp = 0
				for e in b.enemies:
					if e.get("captured", false):
						continue
					reward_gold += int(e["s"]["gold"])
					reward_exp += int(e["s"]["exp"])
				var gold_at_panel := GameState.gold
				await _burst(BURSTS)
				_check_resumed("overwinningsvenster")
				check("overwinningsvenster: goud precies één keer erbij (%d + %d = %d), ook na %dx pauze/hervat"
						% [gold0, reward_gold, GameState.gold, BURSTS],
						gold_at_panel == gold0 + reward_gold and GameState.gold == gold0 + reward_gold)
				check("overwinningsvenster: wacht nog op de speler, geen pauze-save in het gevecht",
						_battle() == b and str(b.state) == "message_wait" and GameState.autosave_count == count0)
			await _tap("interact")
		else:
			await _frames(1)
	check("gevecht: overwinningsvenster gezien", victory_checked)
	var back := await _wait_scene("Wilgendal", 20.0)
	check("gevecht: terug in Wilgendal, uitslag 'win', niet meer in gevecht",
			back and GameState.last_battle_result == "win" and not GameState.in_battle)
	if not back or not victory_checked:
		return
	await _frames(20)
	check("gevecht: goud %d + %d precies één keer (nu %d)" % [gold0, reward_gold, GameState.gold],
			GameState.gold == gold0 + reward_gold)
	check("gevecht: EXP %d + %d precies één keer (nu %d)" % [exp0, reward_exp, int(GameState.party[0]["exp"])],
			int(GameState.party[0]["exp"]) == exp0 + reward_exp)
	var gold_after := GameState.gold
	var exp_after := int(GameState.party[0]["exp"])
	_notify(Node.NOTIFICATION_APPLICATION_PAUSED)
	_notify(Node.NOTIFICATION_APPLICATION_RESUMED)
	var a := GameState.read_save(auto)
	check("gevecht: pauze-save na het gevecht heeft de beloning (goud %d)" % gold_after,
			GameState.autosave_count > count0 and int(a.get("gold", -1)) == gold_after)
	GameState.new_game("Zed")
	check("gevecht: die pauze-save laden geeft dezelfde beloning, niet dubbel (goud %d, EXP %d)" % [gold_after, exp_after],
			GameState.load_game(auto) and GameState.gold == gold_after and int(GameState.party[0]["exp"]) == exp_after)
