extends RefCounted
## F6-T03: Hub-schermen (Warp, Party-select, Rustkamer-wissel) reageren op Android-terug.
## Zelfde pad als android_back_tests.gd: NOTIFICATION_WM_GO_BACK_REQUEST → AppLifecycle → cancel.

const WarpScene := preload("res://world_warper/warp/warp_view.tscn")
const WarpGd := preload("res://world_warper/warp/warp_view.gd")
const PartySelectScene := preload("res://world_warper/services/party_select.tscn")
const PartyWisselS := preload("res://world_warper/kamers/party_wissel.gd")
const Destinations := preload("res://world_warper/warp/destinations.gd")


func needs_game() -> bool:
	return false


func _go_back(t: Node) -> void:
	await t.pframes(1)
	t.get_tree().root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	if not t.get_tree().quit_on_go_back:
		t.get_tree().root.go_back_requested.emit()
	# AppLifecycle: cancel in _process; hub schermen vangen dat in hun eigen _process.
	await t.pframes(3)


func _test_warp(t: Node) -> void:
	var view: Control = WarpScene.instantiate()
	t.get_tree().root.add_child(view)
	await t.pframes(2)
	view.open()
	await t.pframes(2)
	t.check("F6-T03 warp: open na open()", view.visible)
	view.call("_on_world_pressed", Destinations.WM1)
	await t.pframes(3)
	t.check("F6-T03 warp: stap 2 (bestemmingen)", int(view.get("_step")) == WarpGd.STEP_PLACES)
	await _go_back(t)
	t.check("F6-T03 warp: terug naar stap 1", int(view.get("_step")) == WarpGd.STEP_WORLDS and view.visible)
	await _go_back(t)
	t.check("F6-T03 warp: dicht na cancel op stap 1", not view.visible)
	view.queue_free()
	await t.pframes(2)


func _test_party(t: Node) -> void:
	var ps: Control = PartySelectScene.instantiate()
	t.get_tree().root.add_child(ps)
	await t.pframes(2)
	ps.open()
	await t.pframes(2)
	t.check("F6-T03 party: open", ps.is_open())
	await _go_back(t)
	t.check("F6-T03 party: dicht na cancel", not ps.is_open())
	ps.queue_free()
	await t.pframes(2)


func _test_wissel(t: Node) -> void:
	var player := Node2D.new()
	player.set("input_locked", true)
	t.get_tree().root.add_child(player)
	var pw: CanvasLayer = PartyWisselS.new()
	pw.dicht.connect(func() -> void:
		if is_instance_valid(player) and "input_locked" in player:
			player.set("input_locked", false)
	)
	t.get_tree().root.add_child(pw)
	await t.pframes(4)
	t.check("F6-T03 wissel: scherm staat open", pw.is_inside_tree())
	await _go_back(t)
	t.check("F6-T03 wissel: node weg na cancel", not is_instance_valid(pw) or not pw.is_inside_tree())
	t.check("F6-T03 wissel: input_locked weer uit", not bool(player.get("input_locked")))
	player.queue_free()
	await t.pframes(2)


func run(t: Node) -> void:
	await _test_warp(t)
	await _test_party(t)
	await _test_wissel(t)