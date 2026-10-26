extends RefCounted
## WM1-bugfix: kaart-cast sheets na arena-setup (held joint later). Draait via --castjointest.

const SomData := preload("res://scripts/data/som_data.gd")

var t: Node


func _init(p_t: Node) -> void:
	t = p_t


func run() -> void:
	print("=== Cast sheets na late party join ===")
	await _late_join_map_cast()


func arena() -> Node:
	var r: Node = t.scene()
	return r.som if r != null and "som" in r else null


func _goto_archief() -> bool:
	GameState.in_battle = false
	GameState.som_mode = false
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	GameState.change_map(SomData.START_MAP, SomData.START_SPAWN)
	for i in 300:
		if t.map_name() == "ArchiefV1Gang" and not GameState.changing_map:
			break
		await t.frames(1)
	await t.frames(25)
	for i in 8:
		if Dialog.is_open:
			await t.tap("ui_accept")
			await t.frames(3)
		else:
			break
	return t.map_name() == "ArchiefV1Gang"


func _late_join_map_cast() -> void:
	var oude_stijl: int = int(Settings.get_value("battle_style"))
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	t.check("late join: archief laden (alleen Dax)", await _goto_archief())
	var a: Node = arena()
	if a == null:
		t.check("late join: arena aanwezig", false)
		Settings.set_value("battle_style", oude_stijl)
		return
	t.check("late join: Vesper cast nog niet geladen", not a.map_cast_texs.has("noor"))
	var ok := GameState.add_member("noor")
	t.check("late join: add_member Vesper", ok)
	t.check("late join: map_cast_texs Vesper na join", a.map_cast_texs.has("noor"))
	t.check("late join: cast_kind Vesper = map (geen cast6-terugval)", a.cast_kind("noor") == "map")
	t.check("late join: bondgenoot-node Vesper", a.ally_of("noor") != null)
	Settings.set_value("battle_style", oude_stijl)
