extends Control
class_name PvpBattleView

signal action_chosen(action: String, target_uid: String, extra: Dictionary)

var _banner: Label
var _sides: HBoxContainer
var _log: Label
var _actions: VBoxContainer
var _state: PvpBattleState
var _can: bool = false
var _pending: String = ""
var _spell_id: String = ""
var _item_id: String = ""


func _ready() -> void:
	PvpStyle.fill(self)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 4.0
	root.offset_top = 2.0
	root.offset_right = -4.0
	root.offset_bottom = -2.0
	root.add_theme_constant_override("separation", 2)
	add_child(root)
	_banner = PvpStyle.label("", 8)
	root.add_child(_banner)
	_sides = HBoxContainer.new()
	_sides.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sides.add_theme_constant_override("separation", 6)
	root.add_child(_sides)
	_log = PvpStyle.label("", 8)
	root.add_child(_log)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 2)
	root.add_child(_actions)


func present(state: PvpBattleState, can_act: bool, banner: String) -> void:
	_state = state
	_can = can_act
	_pending = ""
	_spell_id = ""
	_item_id = ""
	_banner.text = banner
	if state != null and not state.log.is_empty():
		_log.text = str(state.log.back())
	_rebuild()


func set_log(text: String) -> void:
	if _log != null:
		_log.text = text


func _rebuild() -> void:
	if _sides == null:
		return
	for child in _sides.get_children():
		child.queue_free()
	for child in _actions.get_children():
		child.queue_free()
	if _state == null:
		return
	_sides.add_child(_side_column("host", "Speler 1"))
	_sides.add_child(_side_column("guest", "Speler 2"))
	if not _can:
		_actions.add_child(PvpStyle.label("Wachten op de andere speler…", 8))
		return
	if _pending == "":
		_add_action("Aanval", "attack")
		var actor := _current()
		if not actor.is_empty() and not (actor["spells"] as Array).is_empty():
			_add_action("Magie", "spell")
		_add_action("Verdedigen", "defend")
		if _has_item(actor):
			_add_action("Item", "item")
		return
	if _pending == "attack":
		_add_targets(false)
	elif _pending == "spell" and _spell_id == "":
		_add_spells()
	elif _pending == "spell":
		_add_spell_targets()
	elif _pending == "item" and _item_id == "":
		_add_items()
	elif _pending == "item":
		_add_targets(true)
	var back := PvpStyle.button("Terug")
	back.pressed.connect(_clear_pending)
	_actions.add_child(back)


func _side_column(seat: String, title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	col.add_child(PvpStyle.label(title, 8))
	var current := ""
	if _state != null:
		current = _state.current_uid()
	for raw in _state.fighters:
		var row: Dictionary = raw
		if str(row["seat"]) != seat:
			continue
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 3)
		line.add_child(PvpStyle.portrait(str(row["character_id"])))
		var text := "%s\n%d/%d HP" % [str(row["display"]), int(row["hp"]), int(row["max_hp"])]
		if int(row["max_mp"]) > 0:
			text += "  %d MP" % int(row["mp"])
		var caption := PvpStyle.label(text, 8)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if str(row["uid"]) == current and int(row["hp"]) > 0:
			caption.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		line.add_child(caption)
		col.add_child(line)
	return col


func _current() -> Dictionary:
	if _state == null:
		return {}
	return _state.fighter(_state.current_uid())


func _has_item(actor: Dictionary) -> bool:
	if actor.is_empty():
		return false
	var bag: Dictionary = actor["items"]
	for key in bag.keys():
		if int(bag[key]) > 0:
			return true
	return false


func _add_action(text: String, action: String) -> void:
	var btn := PvpStyle.button(text)
	btn.pressed.connect(_begin.bind(action))
	_actions.add_child(btn)


func _begin(action: String) -> void:
	if action == "defend":
		action_chosen.emit("defend", "", {})
		return
	_pending = action
	_spell_id = ""
	_item_id = ""
	_rebuild()


func _clear_pending() -> void:
	_pending = ""
	_spell_id = ""
	_item_id = ""
	_rebuild()


func _add_targets(allies: bool) -> void:
	var actor := _current()
	if actor.is_empty():
		return
	for raw in _state.fighters:
		var row: Dictionary = raw
		if int(row["hp"]) <= 0:
			continue
		var same := str(row["seat"]) == str(actor["seat"])
		if allies != same:
			continue
		var btn := PvpStyle.button("%s %d" % [str(row["display"]), int(row["hp"])])
		btn.pressed.connect(_pick_target.bind(str(row["uid"])))
		_actions.add_child(btn)


func _pick_target(uid: String) -> void:
	if _pending == "attack":
		action_chosen.emit("attack", uid, {})
	elif _pending == "spell":
		action_chosen.emit("spell", uid, {"spell": _spell_id})
	elif _pending == "item":
		action_chosen.emit("item", uid, {"item": _item_id})


func _add_spells() -> void:
	var actor := _current()
	if actor.is_empty():
		return
	for raw in actor["spells"]:
		var id := str(raw)
		var spell := PvpSpells.get_spell(id)
		if spell.is_empty():
			continue
		var btn := PvpStyle.button("%s (%d MP)" % [str(spell["name"]), int(spell["mp"])])
		btn.disabled = int(actor["mp"]) < int(spell["mp"])
		btn.pressed.connect(_pick_spell.bind(id))
		_actions.add_child(btn)


func _pick_spell(id: String) -> void:
	_spell_id = id
	var spell := PvpSpells.get_spell(id)
	if str(spell.get("target", "")) == "all_enemies":
		action_chosen.emit("spell", "", {"spell": id})
		return
	_rebuild()


func _add_spell_targets() -> void:
	var spell := PvpSpells.get_spell(_spell_id)
	_add_targets(str(spell.get("type", "")) == "heal")


func _add_items() -> void:
	var actor := _current()
	if actor.is_empty():
		return
	var bag: Dictionary = actor["items"]
	for key in bag.keys():
		var id := str(key)
		var count := int(bag[key])
		if count <= 0:
			continue
		var btn := PvpStyle.button("%s ×%d" % [PvpItems.display_name(id), count])
		btn.pressed.connect(_pick_item.bind(id))
		_actions.add_child(btn)


func _pick_item(id: String) -> void:
	_item_id = id
	_rebuild()
