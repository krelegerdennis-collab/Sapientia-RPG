extends Control
## v0.10 Titelscherm met 'Doorgaan' en 'Nieuw spel'.
## Hoofdpagina: assets/ui/title_main.png (384x216). Titel en ondertitel zitten in die plaat,
## dus logo, kern en glitch worden er niet overheen getekend. Het menu (Doorgaan / Nieuw spel)
## blijft rechtsonder.
## Zonder die plaat: v0.13-titel 'SAPIENTIA', ondertitel 'De Vergeten Archieven', met een lichte
## roze glitch (title_glitch.gd). Art van RPG ART wordt gebruikt zodra die er is:
##   assets/ui/title_bg.png          -> achtergrond 384x216 i.p.v. de bibliotheek;
##   assets/ui/title_logo.png        -> logo 208x36 op (88,10) i.p.v. de tekst;
##   assets/ui/title_ondertitel.png  -> ondertitel 130x13 op (127,43) i.p.v. de tekst (v0.20, Engels);
##   assets/ui/title_logo_glitch.png -> 6 frames over het logo, 1x per 3-5 s op 14 fps;
##   assets/ui/title_kern.png        -> kern van de Golem, 4 frames 24x28 op (188,50), 7 fps.
## Ontbreekt een bestand, dan valt alleen dat stuk terug (tekst / bibliotheek / code-glitch).
## Menu (Doorgaan/Nieuw spel + save-info) rechtsonder, x 240..372, onderkant y 200.
## Betatest en Eindstaat staan links onder: aparte voortgang, niet in dit kaartje.
## v0.13 (afgemaakt): alle titel-art staat in een vaste 'stage' van 384x216 die in het midden
## van het scherm staat (pixel-precies, Nearest). Op bredere/hogere schermen (telefoons zijn vaak
## breder dan 16:9) vult een donkere, vergrote kopie van de achtergrond de randen; zo blijven
## logo, ondertitel en de kern van de Golem precies op hun plek in de achtergrond. Het menu en
## het versielabel staan ook in de stage / rechtsonder.
## Het 'Doorgaan'-kaartje (naam, speeltijd, auto) staat in een paletvenster (UiStyle).
## Doorgaan is grijs (uitgeschakeld) als er nog geen save is (user://save_1.json).
## v0.11: Doorgaan kijkt naar de NIEUWSTE van handmatige save en autosave
## (GameState.has_any_save / read_newest_save / continue_game).

const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const SaveSlotList := preload("res://scripts/ui/save_slot_list.gd")
const SavePrompt := preload("res://scripts/ui/save_prompt.gd")
const UiStyleC := preload("res://scripts/ui/ui_style.gd")
const TitleGlitch := preload("res://scripts/ui/title_glitch.gd")
const BACKDROP := "res://assets/battle/bibliotheek.png"
const TITLE_MAIN := "res://assets/ui/title_main.png"   # hoofdpagina 384x216 (titel zit in de plaat)
const TITLE_BG := "res://assets/ui/title_bg.png"
const TITLE_LOGO := "res://assets/ui/title_logo.png"
const TITLE_SUB := "res://assets/ui/title_ondertitel.png"
const TITLE_LOGO_GLITCH := "res://assets/ui/title_logo_glitch.png"   # 6 frames van 208x36
const TITLE_KERN := "res://assets/ui/title_kern.png"                 # 4 frames van 24x28
const LOGO_POS := Vector2(88, 10)
const SUB_POS := Vector2(127, 43)   # v0.20: Engelse ondertitel 130x13, midden onder het logo (x 192)
const KERN_POS := Vector2(188, 50)
const KERN_SIZE := Vector2(24, 28)
const KERN_FPS := 7.0
const CARD_LEFT := 240.0
const CARD_RIGHT := 372.0
const CARD_BOTTOM := 200.0
const TITLE := "SAPIENTIA"
const SUBTITLE := "The Forgotten Archives"

var continue_button: Button
var load_button: Button
var new_button: Button
var pvp_button: Button
var beta_button: Button
var eind_button: Button
var beta_card: PanelContainer
var beta_info: Label
var title_label: Label
var subtitle_label: Label
var save_info: Label
var glitch: Control             # title_glitch.gd
var logo: TextureRect           # alleen als title_logo.png er is
var background: TextureRect
var card: PanelContainer        # het venster met Doorgaan / Nieuw spel
var subtitle_art: TextureRect   # title_ondertitel.png
var kern: TextureRect           # kloppende kern van de Golem (title_kern.png)
var kern_frames: Array[Texture2D] = []
var kern_frame := 0
var _kern_t := 0.0
## v0.13: vaste 384x216-laag met alle titel-art (midden in beeld); backfill = randen.
var stage: Control
var backfill: TextureRect
var version_label: Label
const STAGE_SIZE := Vector2(384, 216)


func _ready() -> void:
	theme = load(UiMenu.THEME_PATH)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var use_main := ResourceLoader.exists(TITLE_MAIN)
	var own_bg := use_main or ResourceLoader.exists(TITLE_BG)
	var bg_path := TITLE_MAIN if use_main else (TITLE_BG if ResourceLoader.exists(TITLE_BG) else BACKDROP)
	# randen (alleen zichtbaar als het scherm niet precies 16:9 is): donkere vergrote achtergrond
	backfill = TextureRect.new()
	backfill.name = "Backfill"
	backfill.texture = load(bg_path)
	backfill.set_anchors_preset(Control.PRESET_FULL_RECT)
	backfill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backfill.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backfill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backfill.modulate = Color(0.32, 0.3, 0.36) if own_bg else Color(0.55, 0.55, 0.6)
	backfill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backfill)
	stage = Control.new()
	stage.name = "Stage"
	stage.size = STAGE_SIZE
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.texture = load(bg_path)
	bg.position = Vector2.ZERO
	bg.size = STAGE_SIZE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.modulate = Color(1, 1, 1) if own_bg else Color(0.55, 0.55, 0.6)
	stage.add_child(bg)
	background = bg
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0 if own_bg else 0.35)
	dim.position = Vector2.ZERO
	dim.size = STAGE_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(dim)

	# --- titel: de hoofdpagina heeft SAPIENTIA al in de plaat. Anders logo van RPG ART
	# (vaste plekken op 384x216) of tekst met het pixelfont.
	title_label = UiMenu.label(TITLE, UiStyleC.TEXT, 30)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_shadow_color", UiStyleC.GLITCH_DIM)
	title_label.add_theme_constant_override("shadow_offset_x", 1)
	title_label.add_theme_constant_override("shadow_offset_y", 1)
	subtitle_label = UiMenu.label(SUBTITLE, UiStyleC.HILITE)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if use_main:
		title_label.visible = false
		subtitle_label.visible = false
		stage.add_child(title_label)
		stage.add_child(subtitle_label)
	else:
		_build_legacy_title(bg)

	# --- menu rechtsonder (de held in het midden blijft vrij)
	var box := PanelContainer.new()
	box.name = "Card"
	box.add_theme_stylebox_override("panel", UiStyleC.panel("window"))   # v0.13: palet
	card = box
	add_child(box)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	box.add_child(list)
	var row := HBoxContainer.new()
	row.name = "ContinueRow"
	row.add_theme_constant_override("separation", 2)
	list.add_child(row)
	continue_button = UiMenu.button("Doorgaan")
	continue_button.custom_minimum_size = Vector2(0, 16)
	continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(continue_button)
	load_button = UiMenu.button("Laden")
	load_button.name = "LoadButton"
	load_button.custom_minimum_size = Vector2(0, 16)
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(load_button)
	save_info = UiMenu.label("", UiStyleC.TEXT_DIM)
	# v0.13: een lange naam + '(auto)' mag het menu niet breder maken (dan liep het rechts uit
	# beeld): afkappen met '...' binnen de vaste breedte van het menu
	save_info.clip_text = true
	save_info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	list.add_child(save_info)
	new_button = UiMenu.button("Nieuw spel")
	list.add_child(new_button)
	# Buiten het kaartje: het menu moet in y 148..200 blijven (titeltests).
	pvp_button = UiMenu.button("PvP")
	pvp_button.name = "PvpButton"
	pvp_button.custom_minimum_size = Vector2(CARD_RIGHT - CARD_LEFT, 16)
	add_child(pvp_button)
	continue_button.pressed.connect(_on_continue)
	load_button.pressed.connect(_on_load)
	new_button.pressed.connect(_on_new)
	pvp_button.pressed.connect(_on_pvp)
	pvp_button.focus_neighbor_bottom = new_button.get_path()
	new_button.focus_neighbor_top = pvp_button.get_path()
	# Links onder, buiten het kaartje rechts: anders past het menu niet meer in y 148..200.
	var beta_box := PanelContainer.new()
	beta_box.name = "BetaCard"
	beta_box.add_theme_stylebox_override("panel", UiStyleC.panel("window"))
	beta_card = beta_box
	add_child(beta_box)
	var beta_list := VBoxContainer.new()
	beta_list.add_theme_constant_override("separation", 0)
	beta_box.add_child(beta_list)
	beta_button = UiMenu.button("Betatest")
	beta_button.custom_minimum_size = Vector2(116, 16)
	beta_list.add_child(beta_button)
	eind_button = UiMenu.button("Eindstaat")
	eind_button.name = "EindButton"
	eind_button.custom_minimum_size = Vector2(116, 16)
	beta_list.add_child(eind_button)
	beta_info = UiMenu.label("", UiStyleC.TEXT_DIM)
	beta_info.clip_text = true
	beta_info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	beta_info.custom_minimum_size = Vector2(116, 0)
	beta_list.add_child(beta_info)
	beta_button.pressed.connect(_on_beta)
	eind_button.pressed.connect(_on_eind)
	beta_button.focus_neighbor_right = new_button.get_path()
	beta_button.focus_neighbor_bottom = eind_button.get_path()
	eind_button.focus_neighbor_top = beta_button.get_path()
	eind_button.focus_neighbor_right = new_button.get_path()
	new_button.focus_neighbor_left = beta_button.get_path()
	continue_button.focus_neighbor_left = beta_button.get_path()
	continue_button.focus_neighbor_right = load_button.get_path()
	load_button.focus_neighbor_left = continue_button.get_path()
	load_button.focus_neighbor_right = load_button.get_path()

	version_label = UiMenu.label("v" + str(ProjectSettings.get_setting("application/config/version", "")), UiStyleC.TEXT_OFF)
	version_label.name = "Version"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version_label)
	refresh()
	resized.connect(_place_card)
	_place_card.call_deferred()
	# Eigen track. Op web start play() pas na de eerste tik (AudioManager).
	AudioManager.play_music("main_menu", 0.6)
	Transition.fade_in()


## Oude titel (logo, ondertitel, kern, glitch) als title_main.png er niet is.
func _build_legacy_title(bg: TextureRect) -> void:
	if ResourceLoader.exists(TITLE_KERN):
		kern = TextureRect.new()
		kern.name = "Core"
		kern.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var kt: Texture2D = load(TITLE_KERN)
		for f in int(kt.get_width() / KERN_SIZE.x):
			var at := AtlasTexture.new()
			at.atlas = kt
			at.region = Rect2(f * KERN_SIZE.x, 0, KERN_SIZE.x, KERN_SIZE.y)
			kern_frames.append(at)
		kern.texture = kern_frames[0]
		kern.position = KERN_POS
		kern.size = KERN_SIZE
		kern.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(kern)
	glitch = TitleGlitch.new()
	glitch.name = "TitleGlitch"
	stage.add_child(glitch)
	if ResourceLoader.exists(TITLE_LOGO):
		logo = TextureRect.new()
		logo.name = "Logo"
		logo.texture = load(TITLE_LOGO)
		logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glitch.position = LOGO_POS
		glitch.size = logo.texture.get_size()
		glitch.setup(logo)
		glitch.size = logo.texture.get_size()
		if ResourceLoader.exists(TITLE_LOGO_GLITCH):
			glitch.setup_strip(load(TITLE_LOGO_GLITCH), int(logo.texture.get_width()))
		# de tekst blijft bestaan (voor de test), maar onzichtbaar
		title_label.visible = false
		stage.add_child(title_label)
		if ResourceLoader.exists(TITLE_SUB):
			subtitle_art = TextureRect.new()
			subtitle_art.name = "Ondertitel"
			subtitle_art.texture = load(TITLE_SUB)
			subtitle_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			subtitle_art.position = SUB_POS
			subtitle_art.size = subtitle_art.texture.get_size()
			subtitle_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stage.add_child(subtitle_art)
			subtitle_label.visible = false
			stage.add_child(subtitle_label)
		else:
			stage.add_child(subtitle_label)
			subtitle_label.position = Vector2(0, LOGO_POS.y + glitch.size.y + 1)
			subtitle_label.size = Vector2(384, 12)
	else:
		# reserve: tekst bovenin het midden, glitch in code
		glitch.setup(title_label)
		stage.add_child(subtitle_label)
		_place_text_title.call_deferred()
	glitch.set_background(bg)


## Stage (384x216) in het midden; menu rechtsonder IN de stage: x CARD_LEFT..CARD_RIGHT,
## onderkant op CARD_BOTTOM (zo valt het nooit over de held of de Golem in de achtergrond).
func _place_card() -> void:
	stage.position = ((size - STAGE_SIZE) / 2.0).floor()
	card.custom_minimum_size = Vector2(CARD_RIGHT - CARD_LEFT, 0)
	card.reset_size()
	card.position = (stage.position + Vector2(CARD_LEFT, CARD_BOTTOM - card.size.y)).round()
	pvp_button.reset_size()
	pvp_button.position = (card.position + Vector2(0, -pvp_button.size.y - 1.0)).round()
	beta_card.reset_size()
	beta_card.position = (stage.position + Vector2(8, CARD_BOTTOM - beta_card.size.y)).round()
	version_label.reset_size()
	version_label.position = (size - version_label.size - Vector2(4, 1)).round()


func _place_text_title() -> void:
	glitch.size = title_label.get_combined_minimum_size()
	glitch.position = Vector2(roundf((STAGE_SIZE.x - glitch.size.x) / 2.0), 10)
	subtitle_label.reset_size()
	subtitle_label.position = Vector2(roundf((STAGE_SIZE.x - subtitle_label.size.x) / 2.0), glitch.position.y + glitch.size.y)


## Doorgaan aan/uit naar gelang er een save is.
func refresh() -> void:
	var has := GameState.has_any_save()
	continue_button.disabled = not has
	continue_button.focus_mode = Control.FOCUS_ALL if has else Control.FOCUS_NONE
	load_button.disabled = not has
	load_button.focus_mode = Control.FOCUS_ALL if has else Control.FOCUS_NONE
	if has:
		var d := GameState.read_newest_save()
		save_info.text = "  %s  %s%s" % [str(d.get("player_name", "")), UiMenu.format_time(float(d.get("play_time", 0.0))),
				" (auto)" if bool(d.get("autosave", false)) else ""]
		save_info.visible = true
		continue_button.grab_focus()
	else:
		save_info.visible = false
		new_button.grab_focus()
	var beta := GameState.read_beta_save()
	if beta.is_empty():
		beta_info.text = "  aparte voortgang"
	else:
		beta_info.text = "  %s  %s" % [str(beta.get("player_name", "")), UiMenu.format_time(float(beta.get("play_time", 0.0)))]
	beta_info.visible = true


func _process(delta: float) -> void:
	UiMenu.pad_nav(get_viewport())
	if kern and kern_frames.size() > 1:
		_kern_t += delta
		if _kern_t >= 1.0 / KERN_FPS:
			_kern_t -= 1.0 / KERN_FPS
			kern_frame = (kern_frame + 1) % kern_frames.size()
			kern.texture = kern_frames[kern_frame]


func _on_continue() -> void:
	if continue_button.disabled:
		return
	_open_slot_list()


func _on_load() -> void:
	if load_button.disabled:
		return
	_open_slot_list()


func _open_slot_list() -> void:
	if get_node_or_null("SaveSlotList") != null:
		return
	var list := SaveSlotList.new()
	list.picked.connect(_on_slot_picked)
	list.cancelled.connect(_on_slot_cancelled)
	add_child(list)


func _on_slot_picked(slot: int) -> void:
	set_process(false)
	await GameState.continue_slot(slot)


func _on_slot_cancelled() -> void:
	var list := get_node_or_null("SaveSlotList")
	if list != null:
		list.queue_free()


## Nieuw spel: eerst een slot kiezen (1..4). Een gevuld slot vraagt om bevestiging
## ('No' heeft de focus), daarna de naamkeuze; het spel slaat handmatig op in dat slot.
func _on_new() -> void:
	if get_node_or_null("SaveSlotList") != null:
		return
	var list := SaveSlotList.new()
	list.mode = "new"
	list.picked.connect(_on_new_slot_picked)
	list.cancelled.connect(_on_slot_cancelled)
	add_child(list)


var new_slot_prompt: CanvasLayer = null


func _on_new_slot_picked(slot: int) -> void:
	if new_slot_prompt != null:
		return
	var rec := GameState.slot_record(slot)
	if rec.is_empty():
		_start_new_in(slot)
		return
	new_slot_prompt = SavePrompt.new()
	new_slot_prompt.question = "Overwrite slot %d?" % slot
	new_slot_prompt.detail = SaveSlotList.summary(rec.get("data", {}))
	new_slot_prompt.default_no = true
	new_slot_prompt.answered.connect(func(yes: bool) -> void:
		new_slot_prompt = null
		if yes:
			_start_new_in(slot))
	add_child(new_slot_prompt)


func _start_new_in(slot: int) -> void:
	GameState.pending_new_slot = slot
	set_process(false)
	get_tree().change_scene_to_file(GameState.NAME_SCENE)


func _on_pvp() -> void:
	set_process(false)
	get_tree().change_scene_to_file("res://pvp/scenes/pvp_lobby.tscn")


func _on_beta() -> void:
	set_process(false)
	await GameState.start_beta_game()


func _on_eind() -> void:
	set_process(false)
	await GameState.start_eind_game()
