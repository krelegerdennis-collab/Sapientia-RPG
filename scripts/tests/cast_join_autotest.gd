extends RefCounted
## WM1-bugfix: kaart-cast sheets na arena-setup (held joint later). Draait via --castjointest.

const SomData := preload("res://scripts/data/som_data.gd")

var t: Node


func _init(p_t: Node) -> void:
	t = p_t


func run() -> void:
	print("=== Cast sheets na late party join ===")
	await _late_join_active()
	await _late_join_bench()


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


func _late_join_active() -> void:
	var oude_stijl: int = int(Settings.get_value("battle_style"))
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	t.check("late join actief: archief laden (alleen Dax)", await _goto_archief())
	var a: Node = arena()
	if a == null:
		t.check("late join actief: arena aanwezig", false)
		Settings.set_value("battle_style", oude_stijl)
		return
	t.check("late join actief: Vesper cast nog niet geladen", not a.map_cast_texs.has("noor"))
	var ok := GameState.add_member("noor")
	t.check("late join actief: add_member Vesper", ok)
	t.check("late join actief: map_cast_texs Vesper na join", a.map_cast_texs.has("noor"))
	t.check("late join actief: cast_kind Vesper = map (geen cast6-terugval)", a.cast_kind("noor") == "map")
	t.check("late join actief: bondgenoot-node Vesper", a.ally_of("noor") != null)
	Settings.set_value("battle_style", oude_stijl)


func _late_join_bench() -> void:
	var oude_stijl: int = int(Settings.get_value("battle_style"))
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	for id in ["noor", "kael", "orion"]:
		GameState.add_member(id)
	t.check("late join reserve: archief laden (party vol)", await _goto_archief())
	var a: Node = arena()
	if a == null:
		t.check("late join reserve: arena aanwezig", false)
		Settings.set_value("battle_style", oude_stijl)
		return
	t.check("late join reserve: party heeft 4 helden", GameState.party.size() == 4)
	t.check("late join reserve: Seren cast nog niet geladen", not a.map_cast_texs.has("lotte"))
	var ok := GameState.add_member("lotte")
	t.check("late join reserve: Seren naar de bank", ok and GameState.party_bench.size() == 1
			and str(GameState.party_bench[0].get("id", "")) == "lotte")
	t.check("late join reserve: map_cast_texs Seren na join", a.map_cast_texs.has("lotte"))
	t.check("late join reserve: geen SomAlly voor Seren op de bank", a.ally_of("lotte") == null)
	Settings.set_value("battle_style", oude_stijl)
