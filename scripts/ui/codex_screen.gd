extends "res://scripts/ui/menu_screen.gd"
## Codex (Kernfragment stap 2): veldmenu > Codex, zoals het capsule-menu van Lufia 2.
##   links : de pagina's ('Mosslijm   Lv 3'; '*' = actieve bondgenoot), onderaan 'Geen bondgenoot'
##   rechts: naam, plaatje, level, HP/MP, ATK/DEF/SPD, EXP, vaardigheden, element
## A / tik op een pagina = die wordt de bondgenoot (vecht mee); A op 'Geen' = niemand.
## B / MENU / 'Terug' = terug naar het hoofdmenu. Alles is tikbaar (regels van 16 hoog).
## v0.19 GLITCH-FUSIE (Kernfragment stap 3): knop 'Fusie' rechtsboven (of rechts op de D-pad):
##   1. kies pagina 1   2. kies pagina 2   3. voorbeeld van het resultaat -> 'Fuseren!' of 'Annuleren'.
##   B gaat telkens één stap terug. Regels: CodexData.FUSION_TABLE / GameState.codex_fuse().

const CodexData := preload("res://scripts/data/codex_data.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const TargetList := preload("res://scripts/ui/target_list.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")
## v0.19: glitch-shader voor het plaatje van een gefuseerd monster (verschoven banden + roze kleurrand)
const GLITCH_SHADER := """shader_type canvas_item;
uniform float amount = 1.0;
uniform vec4 tint : source_color = vec4(0.86, 0.6, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.89, 0.47, 0.62, 1.0);
varying vec4 vcol;
void vertex() { vcol = COLOR; }
void fragment() {
	vec2 uv = UV;
	float band = floor(uv.y * 14.0) + floor(TIME * 6.0) * 7.0;
	float r = fract(sin(band * 12.9898) * 43758.5453);
	uv.x += r > 0.82 ? (r - 0.91) * 0.25 * amount : 0.0;
	vec4 c = texture(TEXTURE, uv);
	vec4 g = texture(TEXTURE, uv + vec2(0.035 * amount, 0.0));
	float edge = clamp(g.a - c.a, 0.0, 1.0);
	vec3 rgb = mix(c.rgb * tint.rgb, edge_color.rgb, edge);
	COLOR = vec4(rgb, max(c.a, edge * 0.85)) * vcol;
}
"""

const LIST_W := 132
const NAME_W := 13         # tekens voor de naam in de lijst; langste soort is "Wortelkruiper"
const NONE_ID := ""
const HINT := "A: bondgenoot   >: fusie   B: terug"
## v0.19 fusie: stappen ("" = gewoon Codex-scherm)
const MODE_A := "kies_a"
const MODE_B := "kies_b"
const MODE_PREVIEW := "voorbeeld"
const FUSE_W := 44
const HINT_A := "Fusie: kies pagina 1   B: terug"
const HINT_B := "Fusie: kies pagina 2   B: terug"
const HINT_PREVIEW := "A: fuseren (beide pagina's gaan op)   B: terug"

var scroll: ScrollContainer
var list: VBoxContainer
var entries: Array[Button] = []
var uids: Array = []            # per regel: page-uid of NONE_ID ('Geen bondgenoot')
var name_label: Label
var picture: TextureRect
var stats_label: Label
var skills_label: Label
var state_label: Label
var empty_label: Label
var shown_uid := "-"
## v0.19 fusie
var mode := ""
var pick_a := ""
var pick_b := ""
var preview := {}
var fuse_button: Button
var parents_label: Label
var _glitch_mat: ShaderMaterial


func _build() -> void:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	content.add_child(body)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(LIST_W, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 6
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)
	empty_label = UiMenu.label("Nog geen pagina's.", MenuColors.TEXT_DIM)
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(empty_label)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 2)
	body.add_child(detail)
	name_label = UiMenu.label("", MenuColors.TITLE)
	detail.add_child(name_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	detail.add_child(row)
	picture = TextureRect.new()
	picture.custom_minimum_size = Vector2(52, 52)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(picture)
	stats_label = UiMenu.label("", MenuColors.TEXT)
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stats_label)
	skills_label = UiMenu.label("", MenuColors.TEXT_DIM)
	skills_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skills_label.custom_minimum_size = Vector2(100, 0)
	detail.add_child(skills_label)
	state_label = UiMenu.label("", MenuColors.INFO)
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_label.custom_minimum_size = Vector2(100, 0)
	detail.add_child(state_label)
	# v0.19 fusie: knop vóór 'Terug' (tikken; met de D-pad: rechts)
	fuse_button = UiMenu.button("Fusie")
	fuse_button.custom_minimum_size = Vector2(FUSE_W, ROW_H)
	fuse_button.focus_mode = Control.FOCUS_NONE
	fuse_button.pressed.connect(start_fusion)
	header_row.add_child(fuse_button)
	header_row.move_child(fuse_button, header_row.get_child_count() - 2)
	parents_label = UiMenu.label("", MenuColors.TEXT_DIM)
	parents_label.visible = false
	list.add_child(parents_label)
	list.move_child(parents_label, 0)
	_glitch_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GLITCH_SHADER
	_glitch_mat.shader = sh
	set_hint(HINT)
	rebuild()


func rebuild(keep_uid := "-") -> void:
	for b in entries:
		list.remove_child(b)
		b.queue_free()
	entries.clear()
	uids = []
	parents_label.visible = mode == MODE_PREVIEW
	if mode == MODE_PREVIEW:
		_build_preview_rows()
		return
	match mode:
		MODE_A:
			header.text = "Fusie: kies pagina 1"
		MODE_B:
			header.text = "Fusie: kies pagina 2"
		_:
			header.text = "Codex   %d/%d pagina's" % [GameState.codex_pages.size(), CodexData.MAX_PAGES]
	_update_fuse_button()
	for p in GameState.codex_pages:
		uids.append(str(p["uid"]))
	if not uids.is_empty() and mode == "":
		uids.append(NONE_ID)
	for uid in uids:
		var b := UiMenu.button(entry_label(uid))
		b.custom_minimum_size = Vector2(LIST_W - 4, ROW_H)
		b.focus_entered.connect(show_page.bind(uid))
		b.pressed.connect(choose.bind(uid))
		list.add_child(b)
		entries.append(b)
		if mode == MODE_B and uid == pick_a:
			_mark_pick(b)                       # pagina 1 blijft gemarkeerd ('1')
			b.focus_entered.connect(func(): _mark_pick(b))
			b.focus_exited.connect(func(): _mark_pick(b))
		elif uid != NONE_ID and CodexData.is_fused(GameState.codex_page(uid)):
			_tint_glitch_row(b)
	TargetList.link_ring(entries)
	empty_label.visible = entries.is_empty()
	if entries.is_empty():
		name_label.text = ""
		stats_label.text = ""
		skills_label.text = "Gebruik een Leeg Boek in een gevecht op een verzwakt monster."
		state_label.text = ""
		back_button.grab_focus()
		return
	var i := uids.find(keep_uid)
	if i < 0:
		i = maxi(0, uids.find(GameState.codex_active))
	if mode == MODE_B and uids[i] == pick_a and uids.size() > 1:
		i = (i + 1) % uids.size()
	entries[i].grab_focus()
	show_page(uids[i])


## Tekst van een regel ('* Mosslijm  Lv 3'); '*' = actieve bondgenoot.
func entry_label(uid: String) -> String:
	if uid == NONE_ID:
		return ("* " if GameState.codex_active == "" else "  ") + "Geen bondgenoot"
	var p := GameState.codex_page(uid)
	var mark := "* " if GameState.codex_active == uid else "  "
	var n := str(p["name"])
	if n.length() > NAME_W:
		n = n.substr(0, NAME_W - 1) + "."
	return "%s%s Lv%d" % [mark, n.rpad(NAME_W), int(p["level"])]


func entry_text(i: int) -> String:
	return str(entries[i].get_meta("label", ""))


func show_page(uid: String) -> void:
	if mode == MODE_PREVIEW:
		return
	shown_uid = uid
	if uid == NONE_ID:
		name_label.text = "Geen bondgenoot"
		name_label.add_theme_color_override("font_color", MenuColors.TITLE)
		picture.texture = null
		picture.material = null
		stats_label.text = ""
		skills_label.text = "%s vecht zonder Codex-monster." % _hero_name()
		state_label.text = "Gekozen." if GameState.codex_active == "" else "A: niemand laten meevechten."
		return
	var p := GameState.codex_page(uid)
	if p.is_empty():
		return
	_show_page_data(p)
	match mode:
		MODE_A:
			state_label.text = "A: kies dit als pagina 1."
		MODE_B:
			state_label.text = "Al gekozen als pagina 1." if uid == pick_a else "A: kies dit als pagina 2."
		_:
			if GameState.codex_active == uid:
				state_label.text = "Vecht mee naast %s." % _hero_name()
			else:
				state_label.text = "A: laat dit monster meevechten."


## Naam van de hoofdheld (GameState.MAIN_HERO; nooit een vaste naam).
func _hero_name() -> String:
	for h in GameState.party:
		if str(h.get("id", "")) == GameState.MAIN_HERO:
			return str(h["name"])
	return str(GameState.party[0]["name"]) if not GameState.party.is_empty() else ""


## Details van pagina 'p' (ook het fusie-voorbeeld) in het rechterdeel.
func _show_page_data(p: Dictionary) -> void:
	var sp := CodexData.species(str(p["species"]))
	var fused := CodexData.is_fused(p)
	name_label.text = "%s  Lv %d" % [p["name"], int(p["level"])]
	name_label.add_theme_color_override("font_color", UiStyle.GLITCH if fused else MenuColors.TITLE)
	var front := str(sp.get("front", ""))
	picture.texture = GameState.get_resource(front) if ResourceLoader.exists(front) else null
	var col := Color(0.62, 0.62, 0.72) if int(p["hp"]) <= 0 else Color.WHITE
	picture.modulate = col
	picture.material = _glitch_mat if fused else null
	var need: int = maxi(0, GameData.exp_for_level(int(p["level"]) + 1) - int(p["exp"]))
	stats_label.text = "HP %d/%d  MP %d/%d\nATK %d  DEF %d  SPD %d\nEXP %d  volg. %d\nElement: %s" % [
			int(p["hp"]), int(p["max_hp"]), int(p["mp"]), int(p["max_mp"]),
			int(p["atk"]), int(p["def"]), int(p["agi"]), int(p["exp"]), need, str(p.get("element", "-"))]
	var names: Array = (p["skills"] as Array).map(func(x): return str(CodexData.skill(str(x)).get("name", x)))
	skills_label.text = "Vaardigheden: " + (", ".join(names) if not names.is_empty() else "-")


## A / tik: deze pagina wordt de bondgenoot ('Geen' = niemand). In de fusie-stappen: pagina kiezen.
func choose(uid: String) -> void:
	if mode == MODE_A:
		pick_a = uid
		_set_mode(MODE_B, uid)
		return
	if mode == MODE_B:
		if uid == pick_a:
			show_message("Kies een andere pagina.", MenuColors.TEXT_DIM)
			return
		pick_b = uid
		preview = GameState.codex_fusion_preview(pick_a, pick_b)
		if preview.is_empty():
			show_message(GameState.codex_fusion_reason(pick_a, pick_b), MenuColors.TEXT_DIM)
			return
		_set_mode(MODE_PREVIEW)
		return
	GameState.codex_set_active(uid)
	for i in entries.size():
		UiMenu.set_label(entries[i], entry_label(uids[i]))
	show_page(uid)
	if uid == NONE_ID:
		show_message("Geen bondgenoot.")
	else:
		show_message("%s vecht mee!" % GameState.codex_page(uid)["name"])


# ---------------------------------------------------------------- glitch-fusie (v0.19)
func _handle_input() -> void:
	if mode == "" and horizontal_pressed() == 1:
		start_fusion()


## 'Fusie' / rechts: begin met pagina 1 kiezen (minstens 2 pagina's nodig).
func start_fusion() -> void:
	if mode != "":
		return
	if GameState.codex_pages.size() < 2:
		show_message("Voor een fusie heb je twee pagina's nodig.", MenuColors.TEXT_DIM)
		return
	pick_a = ""
	pick_b = ""
	preview = {}
	_set_mode(MODE_A, shown_uid)


func _set_mode(m: String, keep_uid := "-") -> void:
	mode = m
	quiet()                      # dezelfde druk op A/B telt niet nog eens in de nieuwe stap
	clear_message()
	set_hint({MODE_A: HINT_A, MODE_B: HINT_B, MODE_PREVIEW: HINT_PREVIEW}.get(m, HINT))
	rebuild(keep_uid)


## B: in de fusie één stap terug; anders het scherm dicht.
func back() -> void:
	match mode:
		MODE_PREVIEW:
			_set_mode(MODE_B, pick_b)
		MODE_B:
			_set_mode(MODE_A, pick_a)
		MODE_A:
			_set_mode("", pick_a)
		_:
			close()


func _update_fuse_button() -> void:
	fuse_button.visible = mode == "" and not GameState.codex_pages.is_empty()
	if GameState.codex_pages.size() < 2:
		_set_button_color(fuse_button, MenuColors.TEXT_OFF)
	else:
		UiMenu.set_label(fuse_button, "Fusie")


## Pagina 1 in stap 2: '1' vooraan (zelfde breedte als '> '), gedimd goud.
func _mark_pick(b: Button) -> void:
	b.text = "1 " + str(b.get_meta("label", ""))
	_set_button_color(b, MenuColors.ACCENT_SOFT)


## Regel van een gefuseerd monster: naam in glitch-roze (met focus gewoon goud).
func _tint_glitch_row(b: Button) -> void:
	var f := func():
		if not b.has_focus():
			b.add_theme_color_override("font_color", UiStyle.GLITCH)
	b.focus_exited.connect(f)
	f.call()


## Stap 3: de twee ouders, 'Fuseren!' en 'Annuleren'; rechts het resultaat.
func _build_preview_rows() -> void:
	header.text = "Fusie: voorbeeld"
	_update_fuse_button()
	var a := GameState.codex_page(pick_a)
	var b := GameState.codex_page(pick_b)
	parents_label.text = "%s Lv%d\n+ %s Lv%d" % [_short(str(a["name"])), int(a["level"]), _short(str(b["name"])), int(b["level"])]
	for t in [["Fuseren!", confirm_fusion], ["Annuleren", back]]:
		var btn := UiMenu.button(t[0])
		btn.custom_minimum_size = Vector2(LIST_W - 4, ROW_H)
		btn.pressed.connect(t[1])
		list.add_child(btn)
		entries.append(btn)
	TargetList.link_ring(entries)
	_show_page_data(preview)
	var rule: Array = preview["fusion"].get("rule", [])
	var how := "Glitch-variant van %s." % _short(str(a["name"])) if rule.is_empty() else "Fusietabel: %s + %s." % rule
	var inh: Array = (preview["fusion"].get("inherited", []) as Array).map(func(x): return str(CodexData.skill(str(x)).get("name", x)))
	state_label.text = how + ("" if inh.is_empty() else " Erft: " + ", ".join(inh) + ".")
	state_label.add_theme_color_override("font_color", UiStyle.GLITCH)
	entries[0].grab_focus()


func _short(n: String) -> String:
	return n if n.length() <= NAME_W else n.substr(0, NAME_W - 1) + "."


## 'Fuseren!': A + B -> de nieuwe pagina (GameState.codex_fuse). Daarna terug naar de Codex,
## met de nieuwe pagina gekozen, een korte glitch en een melding.
func confirm_fusion() -> void:
	if mode != MODE_PREVIEW:
		return
	var page := GameState.codex_fuse(pick_a, pick_b)
	if page.is_empty():
		show_message(GameState.codex_fusion_reason(pick_a, pick_b), MenuColors.TEXT_DIM)
		_set_mode("")
		return
	pick_a = ""
	pick_b = ""
	preview = {}
	state_label.add_theme_color_override("font_color", MenuColors.INFO)
	_set_mode("", str(page["uid"]))
	if Engine.has_singleton("Crt") or get_node_or_null("/root/Crt") != null:
		get_node("/root/Crt").start_glitch(0.18)
	show_message("Fusie gelukt: %s, Lv %d!" % [page["name"], int(page["level"])], UiStyle.GLITCH)
