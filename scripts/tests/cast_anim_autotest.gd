extends RefCounted
## Seren/Vesper kaart-cast (ringmenu + SomData.MAP_CAST), binnen --autotest.
## Alleen dit blok: godot --path . -- --autotest --test-cast-anim [--shots=/pad]
## Zonder de vlag draait het blok aan het eind van de volledige --autotest mee.

const SomData := preload("res://scripts/data/som_data.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
const GameData := preload("res://scripts/data/game_data.gd")

var t: Node
var shots := ""


func _init(p_t: Node) -> void:
	t = p_t
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cast-anim-shots="):
			shots = arg.get_slice("=", 1)
		elif arg.begins_with("--shots=") and shots == "":
			shots = arg.get_slice("=", 1)
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)


func run() -> void:
	print("=== Cast-animaties Seren/Vesper (ringmenu, MAP_CAST) ===")
	_art_checks()
	await _ring_cast_action()
	await _ring_cast_classic_som_mode()


func _art_checks() -> void:
	t.check("MAP_CAST: Seren en Vesper", SomData.MAP_CAST.has("lotte") and SomData.MAP_CAST.has("noor"))
	t.check("MAP_CAST_MS = 150/170/130/170", SomData.MAP_CAST_MS == [150, 170, 130, 170])
	t.check("MAP_CAST_RELEASE = frame 2 (loslaten)", SomData.MAP_CAST_RELEASE == 2)
	for pair in [["lotte", "seren"], ["noor", "vesper"]]:
		var hid: String = pair[0]
		var prefix: String = pair[1]
		var mc: Dictionary = SomData.MAP_CAST[hid]
		var cast: Texture2D = SomFx.tex(str(mc["sheet"]))
		var fx: Texture2D = SomFx.tex(str(mc.get("fx", "")))
		var cw := int(SomData.MAP_CAST_CELL[0])
		var ch := int(SomData.MAP_CAST_CELL[1])
		t.check("%s_cast sheet 96x128 (4x24x32 x 4 richtingen)" % prefix,
				cast != null and cast.get_size() == Vector2(cw * 4, ch * 4))
		var fcw := int(SomData.MAP_CAST_FX_CELL[0])
		t.check("%s_castfx 96x24 (4 x 24x24)" % prefix,
				fx != null and fx.get_size() == Vector2(fcw * 4, int(SomData.MAP_CAST_FX_CELL[1])))
		t.check("%s: cast_kind = map (data)" % prefix, _cast_kind_for(hid) == "map")


func _cast_kind_for(hero_id: String) -> String:
	var mc: Dictionary = SomData.MAP_CAST.get(hero_id, {})
	if SomFx.tex(str(mc.get("sheet", ""))) == null:
		return "direct"
	return "map"


func arena() -> Node:
	var r := t.scene()
	return r.som if r != null and "som" in r else null


func _goto_archief(action_battles: bool, som_mode: bool) -> bool:
	GameState.in_battle = false
	GameState.som_mode = som_mode
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION if action_battles else Settings.BATTLE_STYLE_CLASSIC)
	GameState.change_map(SomData.START_MAP, SomData.START_SPAWN)
	var ok := false
	for i in 300:
		if t.map_name() == "ArchiefV1Gang" and not GameState.changing_map:
			ok = true
			break
		await t.frames(1)
	await t.frames(25)
	await _close_dialogs()
	return ok


func _close_dialogs() -> void:
	for i in 8:
		if Dialog.is_open():
			await t.tap("ui_accept")
			await t.frames(3)
		else:
			break


func _ring_cast_action() -> void:
	var oude_stijl: int = int(Settings.get_value("battle_style"))
	var oude_som: bool = GameState.som_mode
	GameState.new_game("Dax")
	GameState.add_member("noor")
	GameState.add_member("lotte")
	GameState.encounter_multiplier = 0.0
	t.check("Action: archief laden", await _goto_archief(true, false))
	var a: Node = arena()
	if a == null:
		t.check("Action: arena aanwezig", false)
		Settings.set_value("battle_style", oude_stijl)
		GameState.som_mode = oude_som
		return
	t.check("Action: map_cast_texs voor Vesper en Seren",
			a.map_cast_texs.has("noor") and a.map_cast_texs.has("lotte"))
	await _ring_fire(a, "noor", "vuur")
	await _ring_heal(a, "lotte")
	Settings.set_value("battle_style", oude_stijl)
	GameState.som_mode = oude_som


func _ring_cast_classic_som_mode() -> void:
	var oude_stijl: int = int(Settings.get_value("battle_style"))
	var oude_som: bool = GameState.som_mode
	GameState.new_game("Dax")
	GameState.add_member("noor")
	GameState.add_member("lotte")
	GameState.encounter_multiplier = 0.0
	t.check("Classic + som_mode: archief laden", await _goto_archief(false, true))
	var a: Node = arena()
	t.check("Classic + som_mode: arena actief (ringmenu)", a != null and SomData.room_enabled("archief_v1_gang", true))
	if a == null:
		Settings.set_value("battle_style", oude_stijl)
		GameState.som_mode = oude_som
		return
	t.check("Classic: cast_kind Vesper = map", a.cast_kind("noor") == "map")
	await _ring_fire(a, "noor", "vuur")
	Settings.set_value("battle_style", oude_stijl)
	GameState.som_mode = oude_som


func _ring_fire(a: Node, caster_id: String, spell_id: String) -> void:
	a.switch_hero(caster_id)
	await t.frames(4)
	var m: Node = _first_enemy(a)
	if m == null:
		t.check("ring cast %s: testmonster" % caster_id, false)
		return
	a.enemies[m]["hp"] = 999
	a.member(caster_id)["mp"] = a.member(caster_id)["max_mp"]
	a.open_ring()
	await t.frames(3)
	a.ring.set_tab("magic")
	var si := -1
	for i in a.ring.entries.size():
		if str(a.ring.entries[i].get("id", "")) == spell_id:
			si = i
	if si < 0:
		t.check("ring cast %s: spreuk %s in de ring" % [caster_id, spell_id], false)
		a.ring.close({})
		return
	a.ring.choose(si)
	await t.frames(2)
	if a.ring.is_open and a.ring.tab == "target":
		var ti := -1
		for i in a.ring.entries.size():
			if a.ring.entries[i].get("target") == m:
				ti = i
				break
		if ti < 0:
			t.check("ring cast %s: doel in de ring" % caster_id, false)
			a.ring.close({})
			return
		a.ring.choose(ti)
	await _wait_cast_anim(a, caster_id)
	var n: Node2D = a.node_of(caster_id)
	var anim: Node = n.get_node_or_null("SomCastAnim") if n else null
	t.check("ring cast %s (%s): SomCastAnim speelt (4x24x32)" % [caster_id, spell_id],
			anim != null and int(anim.hframes) == 4 and int(anim.vframes) == 4
			and anim.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	await _wait_released(a)
	if anim != null and is_instance_valid(anim):
		t.check("ring cast %s: hit op loslaten-frame %d" % [caster_id, int(anim.hit_index)],
				int(anim.hit_index) == SomData.MAP_CAST_RELEASE)
	var fx: Node = n.get_node_or_null("SomCastFx") if n else null
	t.check("ring cast %s: castfx na loslaten" % caster_id, fx != null)
	await t.frames(20)


func _ring_heal(a: Node, caster_id: String) -> void:
	a.switch_hero(caster_id)
	await t.frames(4)
	var dax: Dictionary = a.member("dennis")
	dax["hp"] = int(dax["max_hp"]) / 2
	a.member(caster_id)["mp"] = a.member(caster_id)["max_mp"]
	a.open_ring()
	await t.frames(3)
	a.ring.set_tab("magic")
	var si := -1
	for i in a.ring.entries.size():
		var sp: Dictionary = GameData.SPELLS.get(str(a.ring.entries[i].get("id", "")), {})
		if str(sp.get("type", "")) == "heal":
			si = i
			break
	if si < 0:
		t.check("ring heal %s: genees-spreuk in de ring" % caster_id, false)
		a.ring.close({})
		return
	a.ring.choose(si)
	await t.frames(2)
	if a.ring.is_open and a.ring.tab == "target":
		var ti := -1
		for i in a.ring.entries.size():
			if str(a.ring.entries[i].get("target", "")) == "dennis":
				ti = i
				break
		if ti < 0:
			t.check("ring heal %s: Dax als doel" % caster_id, false)
			a.ring.close({})
			return
		a.ring.choose(ti)
	await _wait_cast_anim(a, caster_id)
	var n: Node2D = a.node_of(caster_id)
	var anim: Node = n.get_node_or_null("SomCastAnim") if n else null
	var path_ok := anim != null and anim.texture != null and str(anim.texture.resource_path).ends_with("seren_cast.png")
	t.check("ring heal Seren: seren_cast.png", path_ok)
	await _wait_released(a)
	await t.frames(15)


func _first_enemy(a: Node) -> Node:
	for m in a.enemies.keys():
		if is_instance_valid(m):
			return m
	return null


func _wait_cast_anim(a: Node, caster_id: String) -> void:
	var n := 0
	while n < 90:
		var node: Node2D = a.node_of(caster_id)
		if node != null and node.get_node_or_null("SomCastAnim") != null:
			return
		await t.frames(1)
		n += 1


func _wait_released(a: Node) -> void:
	var got := [false]
	var cb := func(_s: String, _c: String) -> void:
		got[0] = true
	a.spell_released.connect(cb)
	var n := 0
	while not got[0] and n < 120:
		await t.frames(1)
		n += 1
	a.spell_released.disconnect(cb)
