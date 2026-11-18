extends RefCounted
## F6-T01: systeem-terug (Android back) sluit de save-slotlijst op titel en in het veldmenu.
## Zelfde _go_back() als android_back_tests.gd (melding + go_back_requested).

const StoryData := preload("res://scripts/data/story_data.gd")
const TOWN := "res://scenes/maps/wilgendal.tscn"


func needs_game() -> bool:
	return false


func _go_back(t: Node) -> void:
	await t.pframes(1)
	t.get_tree().root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	if not t.get_tree().quit_on_go_back:
		t.get_tree().root.go_back_requested.emit()
	await t.pframes(2)


func _prep_title_save() -> void:
	GameState.active_slot = 1
	GameState.new_game("BackTest")
	GameState.current_map = TOWN
	GameState.save_game(Vector2i(1, 1), Vector2i.DOWN)


func _on_title(t: Node) -> Node:
	if t.sc.scene() == null or t.sc.scene().name != "Title":
		GameState.go_to_title(true)
	if not await t.sc.wait_scene("Title", 15.0):
		t.check("F6-T01: titelscherm", false)
		return null
	await t.pframes(10)
	return t.sc.scene()


func run(t: Node) -> void:
	_prep_title_save()
	var titel: Node = await _on_title(t)
	if titel == null:
		return
	titel.refresh()
	await t.pframes(4)
	var starts_load := GameState.new_game_starts
	titel._on_load()
	await t.pframes(6)
	var list_load: Node = titel.get_node_or_null("SaveSlotList")
	t.check("F6-T01 titel>Load: slotlijst open", list_load != null)
	if list_load == null:
		return
	await _go_back(t)
	t.check("F6-T01 titel>Load: lijst weg na terug", titel.get_node_or_null("SaveSlotList") == null)
	t.check("F6-T01 titel>Load: titel blijft staan, geen extra reactie", t.sc.scene() == titel and titel.name == "Title"
			and titel.is_inside_tree() and titel.visible)
	t.check("F6-T01 titel>Load: start_new_game niet aangeroepen", GameState.new_game_starts == starts_load)

	var starts_new := GameState.new_game_starts
	titel._on_new()
	await t.pframes(6)
	var list_new: Node = titel.get_node_or_null("SaveSlotList")
	t.check("F6-T01 titel>Nieuw: slotlijst open (mode new)", list_new != null and list_new.mode == list_new.MODE_NEW)
	if list_new == null:
		return
	await _go_back(t)
	t.check("F6-T01 titel>Nieuw: lijst weg na terug", titel.get_node_or_null("SaveSlotList") == null)
	t.check("F6-T01 titel>Nieuw: blijft op titel", t.sc.scene() == titel and titel.name == "Title")
	t.check("F6-T01 titel>Nieuw: start_new_game niet aangeroepen", GameState.new_game_starts == starts_new)

	var game_ok: bool = await t.sc.start_game()
	t.check("F6-T01 veld: spel in Wilgendal", game_ok)
	if not game_ok:
		return
	await t._skip_opening()
	var map: Node = t.sc.scene()
	if map == null:
		t.check("F6-T01 veld: kaart", false)
		return
	var saved: bool = GameState.save_game(map.get_node("Objects/Player").get_tile(), map.get_node("Objects/Player").facing)
	var m: Node = await t.sc.open_field_menu()
	t.check("F6-T01 veld: veldmenu open", m != null)
	if m == null:
		return
	m.open_load()
	await t.pframes(6)
	var ls: Node = m.sub
	t.check("F6-T01 veld>Load: laadscherm met lijst", saved and ls != null and ls.name == "Load" and ls.list != null)
	if ls == null or ls.list == null:
		return
	await _go_back(t)
	var fm: Node = t.sc.field_menu()
	t.check("F6-T01 veld>Load: één terug sluit alleen lijst, veldmenu blijft", m.sub == null and fm != null
			and fm == m and is_instance_valid(m) and t.sc.scene() != null and t.sc.scene().name == "Wilgendal")
	if m.sub != null:
		return
	m.open_load()
	await t.pframes(6)
	ls = m.sub
	if ls == null or ls.list == null:
		t.check("F6-T01 veld>Load: lijst opnieuw open voor prompt", false)
		return
	ls.list.slot_buttons[0].pressed.emit()
	await t.pframes(6)
	t.check("F6-T01 veld>Load: bevestiging open", ls.prompt != null and ls.prompt.question.begins_with("Load slot"))
	if ls.prompt == null:
		return
	await _go_back(t)
	t.check("F6-T01 veld>Load: eerste terug sluit alleen prompt", ls.prompt == null and is_instance_valid(ls) and m.sub == ls)
	await _go_back(t)
	t.check("F6-T01 veld>Load: tweede terug sluit lijst", m.sub == null)
