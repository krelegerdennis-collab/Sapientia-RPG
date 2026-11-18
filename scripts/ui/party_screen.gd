extends "res://scripts/ui/menu_screen.gd"
## v0.22 Partylimiet: veldmenu > Party. Wie vecht er mee (max 4 helden + 1 monster) en wie
## staat in de reserve. Alleen buiten een gevecht (in een gevecht opent dit scherm niet en
## blokkeert PartyLimiet elke wissel).
##   links : de actieve groep, 4 heldenplekken + 1 monsterplek (groen, het Codex-monster)
##   rechts: de reserve: helden (GameState.party_bench) en monsters (niet-actieve Codex-pagina's)
## Wisselen: tik/A op een actieve held (die wordt gemarkeerd) en daarna op een reserve-held = ruilen.
## Nogmaals op de gemarkeerde held = naar de reserve. Reserve-held zonder markering = erbij (als
## er plek is). Reserve-monster = wordt het actieve monster; de monsterplek = monster naar de reserve.
## Regels: scripts/party_limiet.gd.

const PartyLimiet := preload("res://scripts/party_limiet.gd")
const HeroStatusBox := preload("res://scripts/battle/hero_status_box.gd")
const COL_W := 172
const HINT := "Tap someone in Active, then someone in Reserve to swap. Back to close."

var actief_lijst: VBoxContainer
var reserve_lijst: VBoxContainer
var actief_knoppen: Array[Button] = []
var monster_knop: Button
var reserve_held_knoppen: Array[Button] = []
var reserve_monster_knoppen: Array[Button] = []
## Gemarkeerde actieve held (-1 = geen)
var gekozen := -1
## Laatste uitkomst (voor de partytest)
var laatste_tekst := ""
var _hint_band: Control


## Onderste hintregel: wrap binnen de inhoudsbreedte (lange F6.3-tekst).
func _layout_party_hint() -> void:
	if hint == null or not is_instance_valid(root) or not root.is_inside_tree():
		return
	var vp := root.get_viewport().get_visible_rect().size
	var safe := UiTouchC.safe_rect(vp, root.get_viewport())
	var inhoud_b := maxf(8.0, safe.size.x - (PAD_X * 2.0))
	if _outer.size.x > 1.0:
		inhoud_b = minf(inhoud_b, _outer.size.x)
	var font := hint.get_theme_font("font")
	var fs := hint.get_theme_font_size("font_size")
	var regels := _hint_regels(HINT, inhoud_b, fs, font)
	var rij_h := float(fs + 3)
	var hoog := maxf(float(ROW_H), rij_h * float(regels.size()))
	_hint_band.custom_minimum_size = Vector2(inhoud_b, hoog)
	_hint_band.size = Vector2(inhoud_b, hoog)


static func _hint_regels(tekst: String, breedte: float, fs: int, font: Font) -> PackedStringArray:
	var words := tekst.split(" ")
	var regels: PackedStringArray = []
	var cur := ""
	for w in words:
		var probe := (cur + " " + w).strip_edges()
		if font.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > breedte and cur != "":
			regels.append(cur)
			cur = w
		else:
			cur = probe
	if cur != "":
		regels.append(cur)
	return regels


func _build() -> void:
	header.text = "Party  (in battle: %d heroes + %d monster)" % [PartyLimiet.MAX_HELDEN, PartyLimiet.MAX_MONSTERS]
	set_hint(HINT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.clip_text = false
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_band = Control.new()
	_hint_band.name = "HintBand"
	_hint_band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_outer.remove_child(hint)
	_hint_band.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_outer.add_child(_hint_band)
	if not root.resized.is_connected(_layout_party_hint):
		root.resized.connect(_layout_party_hint)
	_layout_party_hint.call_deferred()
	PartyLimiet.normaliseer()
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	content.add_child(body)
	actief_lijst = _kolom(body, "Active")
	reserve_lijst = _kolom(body, "Reserve")
	_vul()


func _kolom(ouder: Node, titel: String) -> VBoxContainer:
	var doos := VBoxContainer.new()
	doos.custom_minimum_size = Vector2(COL_W, 0)
	doos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doos.add_theme_constant_override("separation", 0)
	ouder.add_child(doos)
	doos.add_child(UiMenu.label(titel, MenuColors.TEXT_DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	doos.add_child(scroll)
	var lijst := VBoxContainer.new()
	lijst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lijst.add_theme_constant_override("separation", 0)
	scroll.add_child(lijst)
	return lijst


func _knop(tekst: String, actie: Callable, ouder: Node) -> Button:
	var b := touch_row(UiMenu.button(tekst))
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.clip_text = true
	b.pressed.connect(actie)
	lock_horizontal_focus(b)
	ouder.add_child(b)
	return b


static func _held_regel(h: Dictionary) -> String:
	return "%s  Lv%d  %d/%d" % [str(h.get("name", "")), int(h.get("level", 1)), int(h.get("hp", 0)), int(h.get("max_hp", 0))]


func _vul() -> void:
	var focus_naam := ""
	var f := root.get_viewport().gui_get_focus_owner() if root.is_inside_tree() else null
	if f is Button:
		focus_naam = str(f.name)
	for c in actief_lijst.get_children() + reserve_lijst.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	actief_knoppen.clear()
	reserve_held_knoppen.clear()
	reserve_monster_knoppen.clear()
	for i in PartyLimiet.MAX_HELDEN:
		var b: Button
		if i < GameState.party.size():
			var h: Dictionary = GameState.party[i]
			var merk := "* " if i == gekozen else ""
			b = _knop(merk + _held_regel(h), kies_actief.bind(i), actief_lijst)
			if i == gekozen:
				_set_button_color(b, MenuColors.ACCENT_SOFT)
		else:
			b = _knop("- empty -", func() -> void: _zeg("A free spot: pick someone from the reserve."), actief_lijst)
			_grey(b)
		b.name = "Actief%d" % i
		actief_knoppen.append(b)
	var page: Dictionary = GameState.codex_active_page()
	var mt := "Monster: %s  Lv%d" % [str(page["name"]), int(page.get("level", 1))] if not page.is_empty() else "Monster: none"
	monster_knop = _knop(mt, kies_monster_vak, actief_lijst)
	monster_knop.name = "Monster"
	_monster_stijl(monster_knop)
	for i in GameState.party_bench.size():
		var b := _knop(_held_regel(GameState.party_bench[i]), kies_reserve_held.bind(i), reserve_lijst)
		b.name = "ReserveHeld%d" % i
		reserve_held_knoppen.append(b)
	var mons: Array = PartyLimiet.reserve_monsters()
	for i in mons.size():
		var p: Dictionary = mons[i]
		var b := _knop("%s  Lv%d%s" % [str(p["name"]), int(p.get("level", 1)), "  KO" if int(p.get("hp", 0)) <= 0 else ""],
				kies_reserve_monster.bind(i), reserve_lijst)
		b.name = "ReserveMonster%d" % i
		_monster_stijl(b)
		reserve_monster_knoppen.append(b)
	if reserve_held_knoppen.is_empty() and reserve_monster_knoppen.is_empty():
		reserve_lijst.add_child(UiMenu.label("Nobody in the reserve.", MenuColors.TEXT_DIM))
	# focus terug op dezelfde plek (of de eerste regel)
	var alle: Array = actief_knoppen + [monster_knop] + reserve_held_knoppen + reserve_monster_knoppen
	var doel: Button = alle[0]
	for b in alle:
		if str(b.name) == focus_naam:
			doel = b
	doel.grab_focus.call_deferred()


## Monsterregels: groene tekst en een groen kader (zelfde kleur als het monstervak in het gevecht).
func _monster_stijl(b: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = HeroStatusBox.MONSTER_VAK
	sb.border_color = HeroStatusBox.MONSTER_RAND
	sb.set_border_width_all(1)
	sb.set_content_margin_all(1)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_color_override("font_color", HeroStatusBox.MONSTER_RAND)


func _zeg(t: String) -> void:
	laatste_tekst = t
	if t != "":
		show_message(t)


# ---------------------------------------------------------------- acties (ook voor de test)
func kies_actief(i: int) -> void:
	if gekozen == i:
		gekozen = -1
		_zeg(PartyLimiet.naar_reserve(i))
	else:
		gekozen = i
		_zeg("Pick who swaps in for %s (or pick again: to reserve)." % str(GameState.party[i].get("name", "")))
	_vul()


func kies_reserve_held(i: int) -> void:
	if gekozen >= 0:
		_zeg(PartyLimiet.wissel(gekozen, i))
		gekozen = -1
	else:
		_zeg(PartyLimiet.naar_groep(i))
	_vul()


func kies_reserve_monster(i: int) -> void:
	var mons: Array = PartyLimiet.reserve_monsters()
	if i >= 0 and i < mons.size():
		_zeg(PartyLimiet.kies_monster(str(mons[i]["uid"])))
	_vul()


func kies_monster_vak() -> void:
	if GameState.codex_active == "":
		_zeg("Pick a monster from the reserve.")
	else:
		_zeg(PartyLimiet.kies_monster(""))
	_vul()


func back() -> void:
	if gekozen >= 0:
		gekozen = -1
		_vul()
		return
	close()
