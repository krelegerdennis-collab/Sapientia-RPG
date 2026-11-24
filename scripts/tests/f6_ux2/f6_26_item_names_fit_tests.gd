extends RefCounted
## Post-RC: itemnamen in de inventarislijst worden niet meer hard afgeknipt ('Leather Greav').
## Zet de langste lijstnamen uit alle itemdata (game_data ITEMS/EQUIPMENT/KEY_ITEMS, grade_gear, arena)
## in de tas, opent het Items-scherm op 16:9 (384x216) en 19,5:9 (468x216) en controleert per regel:
## volle naam (of de 'short' uit game_data), tekst + icoon passen in de knop, knop binnen de lijst,
## detailkolom blijft bruikbaar. Registratie: scripts/tests/f6_ux2_tests.gd (map-scan).

const ItemsScreen := preload("res://scripts/ui/items_screen.gd")
const PartyActions := preload("res://scripts/party_actions.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const GradeGear := preload("res://scripts/data/grade_gear.gd")
const ArenaGear := preload("res://scripts/data/arena_shop_data.gd")
const ReleaseFlags := preload("res://scripts/data/release_flags.gd")

const PROFILES := {"16x9": Vector2i(384, 216), "19_5x9": Vector2i(468, 216)}
const LONGEST_N := 8


func needs_game() -> bool:
	return true


func _all_ids() -> Array:
	var ids: Array = []
	for d in [GameData.ITEMS, GameData.EQUIPMENT, GradeGear.ITEMS, ArenaGear.GEAR]:
		for id in d:
			if not ids.has(str(id)):
				ids.append(str(id))
	var keys: Dictionary = PartyActions.data_const("KEY_ITEMS")
	for id in keys:
		if not ids.has(str(id)):
			ids.append(str(id))
	return ids


func run(t: Node) -> void:
	var arena_before := ReleaseFlags.arena_enabled_override
	ReleaseFlags.arena_enabled_override = 1   # arena-uitrusting telt als uitrusting (Equipment.is_equipment)
	var probe: Node = ItemsScreen.new()
	# langste lijstnamen (zoals het scherm ze toont) over alle data
	var rows: Array = []
	for id in _all_ids():
		rows.append([probe.list_name(id).length(), id])
	probe.free()
	rows.sort_custom(func(a, b): return a[0] > b[0] if a[0] != b[0] else str(a[1]) < str(b[1]))
	var longest: Array = []
	for i in mini(LONGEST_N, rows.size()):
		longest.append(rows[i][1])
	var names: Array = []
	for id in longest:
		names.append("%s=%d" % [PartyActions.item_name(id), rows[longest.find(id)][0]])
	print("INFO  langste lijstnamen: ", names)

	# zonder 'short' geen knip meer: list_name == volle naam
	var knip: Array = []
	for id in _all_ids():
		var it := PartyActions.item_data(id)
		var probe2: Node = ItemsScreen.new()
		var ln: String = probe2.list_name(id)
		probe2.free()
		if not it.has("short") and ln != PartyActions.item_name(id):
			knip.append(id)
	t.check("item-namen: geen harde knip zonder 'short' %s" % [knip], knip.is_empty())

	var inv_before: Dictionary = GameState.inventory.duplicate(true)
	for k in GameState.inventory.keys():
		GameState.set_item_count(str(k), 0)
	for id in longest:
		GameState.set_item_count(id, 99)
	GameState.set_item_count("drankje", 3)
	var win := t.get_window()
	var mode_b := win.content_scale_mode
	var aspect_b := win.content_scale_aspect
	var size_b := win.content_scale_size
	for p in PROFILES:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		win.content_scale_size = PROFILES[p]
		await t.pframes(3)
		var s: Node = ItemsScreen.new()
		t.get_tree().root.add_child(s)
		await t.pframes(8)
		var fout: Array = []
		var vis: Rect2 = s.scroll.get_global_rect()
		var bar: Control = s.scroll.get_v_scroll_bar()
		var bar_w: float = bar.size.x if bar != null and bar.visible else 0.0
		for i in s.entries.size():
			var b: Button = s.entries[i]
			var id: String = str(s.ids[i])
			var font := b.get_theme_font("font")
			var fs := b.get_theme_font_size("font_size")
			var tw := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var iw := (b.icon.get_width() + b.get_theme_constant("h_separation")) if b.icon != null else 0
			var pad := b.get_theme_stylebox("normal").get_minimum_size().x
			var r := b.get_global_rect()
			var ok := tw + iw + pad <= b.size.x + 0.5 and r.end.x <= vis.end.x - bar_w + 0.5 \
					and str(b.get_meta("label", "")).begins_with(str(s.list_name(id)))
			if not ok:
				fout.append("%s '%s' %.0f+%d+%.0f > %.0f (rij %.0f, lijst %.0f-%.0f)" % [id, b.text, tw, iw, pad,
						b.size.x, r.end.x, vis.end.x, bar_w])
		t.check("item-namen %s: %d langste namen passen volledig in de lijst %s" % [p, longest.size(), fout],
				s.entries.size() == longest.size() + 1 and fout.is_empty())
		# x-kolom: alle regels even lang (naamkolom = langste naam)
		var lens := {}
		for i in s.entries.size():
			lens[str(s.entries[i].get_meta("label", "")).length() - str(GameState.item_count(str(s.ids[i]))).length()] = true
		t.check("item-namen %s: aantal 'xN' in één kolom" % p, lens.size() == 1)
		t.check("item-namen %s: detailkolom blijft bruikbaar (%.0f px)" % [p, s.desc_label.size.x],
				s.desc_label.size.x >= 150.0 and s.name_label.get_global_rect().end.x <= t.get_viewport().get_visible_rect().size.x)
		s.queue_free()
		await t.pframes(3)
	# kleine tas: precies de oude maat (menutest: 'Potion        x3')
	for k in GameState.inventory.keys():
		GameState.set_item_count(str(k), 0)
	GameState.set_item_count("drankje", 3)
	var s2: Node = ItemsScreen.new()
	t.get_tree().root.add_child(s2)
	await t.pframes(6)
	t.check("item-namen: korte lijst ongewijzigd ('%s', lijst %.0f)" % [s2.entry_text(0), s2.scroll.custom_minimum_size.x],
			s2.entry_text(0) == "Potion        x3" and s2.scroll.custom_minimum_size.x == ItemsScreen.LIST_W)
	s2.queue_free()
	await t.pframes(3)
	win.content_scale_mode = mode_b
	win.content_scale_aspect = aspect_b
	win.content_scale_size = size_b
	GameState.inventory = inv_before
	ReleaseFlags.arena_enabled_override = arena_before
	await t.pframes(3)
