extends "res://scripts/ui/menu_screen.gd"
## v0.11 Veldmenu > Status: één held tegelijk.
##   links : portret + klasse. v0.14: via hero_portrait.gd (portret van RPG ART
##           assets/ui/portrait_<id>.png, anders het VOORAANZICHT uit de loop-sheet; nooit
##           meer het rugaanzicht uit het gevecht)
##   rechts: naam/Lv/HP/MP (PartyCard), EXP en EXP tot het volgende level (formule
##           GameData.exp_for_level), v0.14: ATK/DEF/MAG/MDEF/SPD (effectief, met de bonus
##           van de uitrusting erachter: '17 (+3)'), het wapen en de spreuken
## Links/rechts (D-pad of de '<' '>' knoppen bovenin) = andere held, als de party >1 is.

const GameData := preload("res://scripts/data/game_data.gd")
const PartyActions := preload("res://scripts/party_actions.gd")
const Equipment := preload("res://scripts/equipment.gd")
const KernData := preload("res://scripts/data/kern_data.gd")   # v0.15
const HeroPortrait := preload("res://scripts/ui/hero_portrait.gd")

## v0.14: vak voor het portret (RPG ART levert 64x80).
const PORTRAIT_SIZE := Vector2(64, 80)
## Gevechtssprites: strook met frames van FRAME_PX x FRAME_PX, frame 0 = 'stil'.
const FRAME_PX := HeroPortrait.FRAME_PX
const CARD_W := 196
const KEY_W := 72              # breedte van de kolom met namen ('EXP', 'Volgend Lv', ...)
const STAT_KEY_W := 30         # 'MDEF'
const STAT_VAL_W := 60         # '17 (+3)'
const TEXT_INDENT := 4         # zelfde inspringing als de tekst in de PartyCard

var index := 0
var prev_button: Button
var next_button: Button
var page_label: Label
var portrait: TextureRect
var portrait_view: CenterContainer
var class_label: Label
var card: PartyCard
var exp_label: Label
var next_label: Label
var atk_label: Label
var def_label: Label
var agi_label: Label
var mag_label: Label
var mdef_label: Label
var weapon_label: Label
var spells_label: Label
var kern_label: Label     # v0.15
var kern_key: Label


func _build() -> void:
	header.text = "Status"
	prev_button = arrow_button("<")
	prev_button.pressed.connect(switch.bind(-1))
	page_label = UiMenu.label("", MenuColors.TEXT_DIM)
	next_button = arrow_button(">")
	next_button.pressed.connect(switch.bind(1))
	for c in [prev_button, page_label, next_button]:
		header_row.add_child(c)
		header_row.move_child(c, header_row.get_child_count() - 2)   # vóór 'Terug'
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	content.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	body.add_child(left)
	var frame := PanelContainer.new()
	var fs := UiMenu.inner_style()
	fs.set_content_margin_all(1)
	frame.add_theme_stylebox_override("panel", fs)
	left.add_child(frame)
	portrait_view = HeroPortrait.make_view(PORTRAIT_SIZE)
	portrait = HeroPortrait.view_rect(portrait_view)
	frame.add_child(portrait_view)
	class_label = UiMenu.label("", MenuColors.TEXT_DIM)
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(class_label)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 3)
	body.add_child(right)
	card = PartyCard.new()
	card.show_class = false
	card.custom_minimum_size = Vector2(CARD_W, PartyCard.HEIGHT)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right.add_child(card)
	# tabel: naam (grijs) | waarde (licht)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", TEXT_INDENT)
	right.add_child(pad)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	pad.add_child(grid)
	exp_label = _row(grid, "EXP")
	next_label = _row(grid, "Next Lv")
	# v0.14: stats in twee kolommen (ATK/DEF/SPD links, MAG/MDEF rechts)
	var pad2 := MarginContainer.new()
	pad2.add_theme_constant_override("margin_left", TEXT_INDENT)
	right.add_child(pad2)
	var sg := GridContainer.new()
	sg.columns = 4
	sg.add_theme_constant_override("h_separation", 2)
	sg.add_theme_constant_override("v_separation", 0)
	pad2.add_child(sg)
	atk_label = _stat_cell(sg, "atk")
	mag_label = _stat_cell(sg, "mag")
	def_label = _stat_cell(sg, "def")
	mdef_label = _stat_cell(sg, "mdef")
	agi_label = _stat_cell(sg, "agi")
	var pad3 := MarginContainer.new()
	pad3.add_theme_constant_override("margin_left", TEXT_INDENT)
	right.add_child(pad3)
	var grid2 := GridContainer.new()
	grid2.columns = 2
	grid2.add_theme_constant_override("h_separation", 0)
	grid2.add_theme_constant_override("v_separation", 0)
	pad3.add_child(grid2)
	weapon_label = _row(grid2, "Weapon")
	spells_label = _row(grid2, "Spells")
	spells_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spells_label.custom_minimum_size = Vector2(CARD_W - KEY_W, 0)
	# v0.15: kernfragmenten (alleen zichtbaar bij de hoofdheld als hij er een heeft)
	kern_label = _row(grid2, "Cores")
	kern_key = grid2.get_child(grid2.get_child_count() - 2)
	kern_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kern_label.custom_minimum_size = Vector2(CARD_W - KEY_W, 0)
	var multi := GameState.party.size() > 1
	prev_button.visible = multi
	next_button.visible = multi
	page_label.visible = multi
	set_hint("<  >: other hero   B: back" if multi else DEFAULT_HINT.replace("A: kiezen   ", ""))
	back_button.grab_focus()
	show_member(index)


## Eén regel in de tabel; geeft het waarde-label terug.
func _row(grid: GridContainer, key: String) -> Label:
	var k := UiMenu.label(key, MenuColors.TEXT_DIM)
	k.custom_minimum_size = Vector2(KEY_W, 0)
	k.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid.add_child(k)
	var v := UiMenu.label("", MenuColors.TEXT)
	grid.add_child(v)
	return v


## v0.14: één stat-cel ('ATK' + '17 (+3)') in het stat-raster.
func _stat_cell(grid: GridContainer, stat: String) -> Label:
	var k := UiMenu.label(Equipment.stat_label(stat), MenuColors.TEXT_DIM)
	k.custom_minimum_size = Vector2(STAT_KEY_W, 0)
	grid.add_child(k)
	var v := UiMenu.label("", MenuColors.TEXT)
	v.custom_minimum_size = Vector2(STAT_VAL_W, 0)
	grid.add_child(v)
	return v


## '17' of '17 (+3)' (effectief, met de bonus van de uitrusting; ontwerp par. 5).
static func stat_text(h: Dictionary, stat: String) -> String:
	var eff := Equipment.effective_stat(h, stat)
	var bonus := Equipment.equip_bonus(h, stat)
	if bonus == 0:
		return str(eff)
	return "%d (%s%d)" % [eff, "+" if bonus > 0 else "", bonus]


## Begin bij een bepaalde held (bv. getikt op zijn kaartje in het hoofdmenu).
func start_at(i: int) -> void:
	index = i
	if card:
		show_member(i)


func show_member(i: int) -> void:
	if GameState.party.is_empty():
		return
	index = posmod(i, GameState.party.size())
	var h: Dictionary = GameState.party[index]
	page_label.text = "%d/%d" % [index + 1, GameState.party.size()]
	card.setup(h)
	class_label.text = str(h.get("class", ""))
	HeroPortrait.show_portrait(portrait_view, h)
	exp_label.text = str(int(h["exp"]))
	next_label.text = "%d EXP to go" % PartyActions.exp_to_next(h)
	atk_label.text = stat_text(h, "atk")
	def_label.text = stat_text(h, "def")
	agi_label.text = stat_text(h, "agi")
	mag_label.text = stat_text(h, "mag")
	mdef_label.text = stat_text(h, "mdef")
	weapon_label.text = PartyActions.weapon_name(h)
	var names: Array[String] = []
	for sid in h.get("spells", []):
		var sp := PartyActions.spell_data(str(sid))
		names.append("%s (%d MP)" % [str(sp.get("name", sid)), int(sp.get("mp", 0))])
	spells_label.text = "\n".join(names) if not names.is_empty() else "none"
	kern_label.text = kern_text(h)
	kern_label.visible = kern_label.text != ""
	kern_key.visible = kern_label.visible


## v0.15: 'Golemkern (Kernslag)' voor de hoofdheld; "" = geen kernen (regel verborgen).
static func kern_text(h: Dictionary) -> String:
	if str(h.get("id", "")) != GameState.MAIN_HERO:
		return ""
	var out: Array[String] = []
	for id in GameState.kernfragmenten:
		var f := KernData.fragment(str(id))
		var sk := str(f.get("battle_skill", ""))
		var skn := str(KernData.KERN_SKILLS.get(sk, {}).get("name", ""))
		out.append("%s (%s)" % [f.get("naam", id), skn] if skn != "" else str(f.get("naam", id)))
	return ", ".join(out)


func switch(dir: int) -> void:
	if GameState.party.size() > 1:
		show_member(index + dir)


func _handle_input() -> void:
	var d := horizontal_pressed()
	if d != 0:
		switch(d)


## Portret van een held (v0.14: hero_portrait.gd; blijft hier voor oude aanroepen).
static func portrait_for(h: Dictionary) -> Texture2D:
	return HeroPortrait.portrait(h)
