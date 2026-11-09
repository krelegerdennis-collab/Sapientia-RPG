extends Node
## C-14: inventaris- en goud-API (add/remove, clamps, signaal, bronlint).
## Start: godot --path . -- --inventorytest

var failures := 0
var passes := 0
var _signal_log: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.inventory_changed.connect(_on_inventory_changed)
	_run.call_deferred()


func _on_inventory_changed(id: String, count: int) -> void:
	_signal_log.append([id, count])


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	_api_tests()
	_source_scan()
	print("INVENTORYTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


func _api_tests() -> void:
	GameState.inventory = {}
	GameState.gold = 0
	_signal_log.clear()
	GameState.add_item("drankje", 3)
	check("add_item: drankje = 3", GameState.item_count("drankje") == 3)
	check("signaal na add", _signal_log.size() == 1 and _signal_log[0][0] == "drankje" and _signal_log[0][1] == 3)
	var stack_room := GameState.MAX_ITEM_STACK - 5
	GameState.set_item_count("drankje", stack_room)
	_signal_log.clear()
	GameState.add_item("drankje", 10)
	check("add_item: clamp op MAX_ITEM_STACK", GameState.item_count("drankje") == GameState.MAX_ITEM_STACK)
	check("remove_item bij 0 voorraad = false", not GameState.remove_item("onbekend_item", 1))
	GameState.set_item_count("kruid", 2)
	check("remove_item: 2 -> 0", GameState.remove_item("kruid", 2) and GameState.item_count("kruid") == 0)
	check("remove_item tweede keer = false", not GameState.remove_item("kruid", 1))
	GameState.add_gold(100)
	GameState.add_gold(50)
	check("add_gold som", GameState.gold == 150)
	check("spend_gold lukt", GameState.spend_gold(40) and GameState.gold == 110)
	check("spend_gold te weinig = false", not GameState.spend_gold(9999) and GameState.gold == 110)
	GameState.gold = GameState.MAX_GOLD - 10
	GameState.add_gold(100)
	check("add_gold clamp MAX_GOLD", GameState.gold == GameState.MAX_GOLD)
	GameState.consume_item("drankje", GameState.item_count("drankje") + 5)
	check("consume_item: niet onder 0", GameState.item_count("drankje") == 0)


func _source_scan() -> void:
	var rx := RegEx.new()
	rx.compile("GameState\\.inventory" + "\\[")
	var dirs := ["res://scripts", "res://tools", "res://pvp"]
	var hits: Array[String] = []
	for dir_path in dirs:
		_scan_dir(dir_path, rx, hits)
	var pat_label: String = "GameState.inventory" + "["
	check("geen %s buiten game_state.gd (%s)" % [pat_label, str(hits)], hits.is_empty())


func _scan_dir(dir_path: String, rx: RegEx, hits: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name.begins_with("."):
			name = d.get_next()
			continue
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			_scan_dir(full, rx, hits)
		elif name.ends_with(".gd") and name != "game_state.gd" and name != "inventory_tests.gd":
			var f := FileAccess.open(full, FileAccess.READ)
			if f != null and rx.search(f.get_as_text()) != null:
				hits.append(full)
		name = d.get_next()
	d.list_dir_end()
