extends Control
## Gevechtsscène in Lufia 2-stijl.
##
## Verloop van een ronde:
##   1. Kies voor ELKE held een commando (Aanval, Magie, Item, Verdedig, Vluchten).
##      Met B (cancel) ga je terug naar de vorige keuze / vorige held.
##   2. De vijanden kiezen ook (willekeurig doelwit).
##   3. Iedereen voert zijn actie uit, de snelste (hoogste AGI) eerst.
##   4. Alle vijanden verslagen = winst (EXP + goud), alle helden KO = game over.
##
## Getallen (stats, spreuken, items) staan in scripts/data/game_data.gd.
##
## "16-bit plus" (v6): het gevecht tekent op een raster van 768x432 (2x zo fijn
## als de rest van het spel). De indeling en alle getallen hieronder blijven in
## 384x216-eenheden: de hele scène wordt 2x geschaald, en de gevechts-art is op
## dubbele resolutie getekend en wordt op schaal 0.5 getoond. Zo valt elke art-pixel
## precies op één pixel van het fijne raster. Zie _enter_detail_mode().
##
## v7/v8 'De Vergeten Bibliotheek' (zoals Dennis' mockup): grijze bibliotheek met digitaal
## verval, GROTE helden (v8: ±155 fijne pixels = ±35% van de schermhoogte) links op een
## rij, vijanden rechts.
## Opbouw van het scherm (384x216, liggend):
##   - bovenste ±42%: het slagveld (helden links, vijanden rechts)
##   - daaronder links het berichtvenster met tabje 'De Vergeten Bibliotheek' en ruis-
##     textuur, rechts het commandomenu (▶-pijltjes, tabje met de naam van de held)
##   - onderaan één statusvak per held (hero_status_box.gd), tussen de D-pad
##     en de A/B-knoppen in, zodat niets onder je duimen valt
##   - na de winst een groot doorzichtig venster met EXP, goud en VOLG. LEVEL
##   - over alles heen het scanline-filter (autoload Crt, instellingen in game_data.gd)

signal state_changed(new_state: String)
signal damage_shown(target_name: String, amount: int)

const GameData := preload("res://scripts/data/game_data.gd")
const BerggrotData := preload("res://scripts/data/berggrot_data.gd")
const PartyActions := preload("res://scripts/party_actions.gd")
const KoopmanData := preload("res://scripts/data/koopman_data.gd")
const ActorSfx := preload("res://scripts/data/actor_sfx.gd")
const Dungeon100Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const EndgameBestiary := preload("res://scripts/data/endgame_bestiary.gd")
const Dungeon100Blue := preload("res://scripts/data/dungeon100_blue.gd")
const KamerData := preload("res://world_warper/kamers/kamers.gd")
const COMMANDS := ["Attack", "Magic", "Item", "Defend", "Flee", "Codex"]
## v0.19 Codex-knop (index 5): submenu 'Vangen' (Leeg Boek op een vijand, met vangkans per doel)
## en 'Wissel bondgenoot' (niet-KO pagina's + 'Geen'; kost de beurt van de held). Verborgen in
## het oefengevecht en zolang de Codex 0 pagina's EN 0 Lege Boeken heeft. Regels: HANDOFF_FUSIE.md.
const CODEX_ROW_H := 16           # regelhoogte van de Codex-menu's (tikken met een vinger)
const CODEX_ROWS_MAX := 5         # wissel-lijst: zoveel regels tegelijk, daarna ▲/▼
## Hoe lang een gevechtsbericht in beeld blijft (A drukken = sneller).
const MESSAGE_TIME := 0.8
const HeroScript := preload("res://scripts/battle/battle_hero.gd")
const StatusBoxScript := preload("res://scripts/battle/hero_status_box.gd")
## Voeten van de helden (bij 384 breed): op een rij links, licht verspringend (zoals de
## mockup). Een 4e held staat in de achterste rij ertussen.
## v9.1: elke held staat midden boven zijn eigen statusvak ("elk vakje is een plek voor
## een karakter"), voeten HERO_BOX_GAP boven de bovenrand van het vak.
const HERO_BOX_GAP := 3.0
## Reserve-plekken (alleen als er geen statusvakken zijn).
const HERO_SLOTS := [Vector2(40, 124), Vector2(92, 127), Vector2(144, 124), Vector2(118, 117)]
## Vijanden: van ENEMY_LEFT tot de rechterrand, naast elkaar (zie _layout_enemies).
## v9.1: voor-achter-opstelling (zoals Lufia 2 / Dragon Quest): de party onderaan (boven de
## statusvakken, van achteren), de vijanden BOVENIN op een rij, midden op het scherm, iets
## kleiner (ENEMY_DEPTH_SCALE) zodat ze verder weg lijken. Laag 'Enemies' wordt vóór 'Party'
## getekend, dus de helden staan ervoor. Voeten op ENEMY_FEET_Y, om en om iets lager.
## ENEMY_DEPTH_SCALE = 1.0 geeft weer pixel-scherpe vijanden (1 art-pixel = 1 pixel).
const ENEMY_DEPTH_SCALE := 0.88
const ENEMY_LEFT := 8.0           # rij mag van rand tot rand (marge), gecentreerd
## v0.13: een vijand op het 'podium' (de baas) bleef links van de kolom met het commando-
## kruis (rechts). v0.15: het kruis staat LINKS naast de held; rechts hoeft niets meer vrij.
const STAGE_RIGHT_RESERVE := 0.0
## v0.15 COMMANDO-KRUIS LINKS naast de party (wens van Dennis): rechterkant van het kruis
## CROSS_HERO_GAP links van de linkerkant van de meest linkse held (zijn zichtbare art), verticaal
## ter hoogte van de heldenrij; nooit over een held, statusvak of de D-pad. De vijandenrij
## begint rechts van het kruis (_enemy_left_reserve), zodat het naam-tabje er niet over valt.
const CROSS_HERO_GAP := 3.0
const CROSS_EDGE := 3.0           # minimale afstand tot de linkerrand
const CROSS_TAB_ROOM := 13.0      # ruimte boven het kruis voor het naam-tabje
const ENEMY_FEET_Y := 102.0
const ENEMY_FEET_Y_MAX := 102.0
## Hoogste vijand-plaatje (fijne pixels) dat op ware grootte past. Hoger wordt passend
## verkleind (vangnet voor nieuwe art). 194 = Kennis-Beest; dan blijft er boven zijn kop
## ruimte voor de bericht-strook.
const MAX_ENEMY_ART_H := 194
## v0.21: BAAS-UITZONDERING. Een vijand met "is_boss": true in game_data mag tot BOSS_MAX_ART_W x
## BOSS_MAX_ART_H fijne pixels op ware grootte staan (RPG ART tekent nieuwe bazen op die maat).
## Groter wordt ook bij een baas passend verkleind. Gewone vijanden houden MAX_ENEMY_ART_H.
const BOSS_MAX_ART_W := 256
const BOSS_MAX_ART_H := 200
## v9: geen berichtvenster meer. Berichten staan kort in een smalle, half doorzichtige
## strook bovenin (Caption). Het commandomenu staat boven het statusvak van de held die
## aan de beurt is en schuift mee (zie battle_menu.gd anchor_to()).
const CAPTION_TOP := 3.0
const CAPTION_HOLD := 1.8        # seconden in beeld na het laatste bericht (daarna vervagen)
const CAPTION_FADE := 0.25
const CURSOR_MIN_Y := 30.0        # punt van het doel-pijltje nooit hoger (onder de strook)
const MENU_GAP := 2.0            # ruimte tussen menu en statusvak
const MENU_TOP := 108.0          # (oude plek; alleen als er geen statusvakken zijn)
const MENU_WIDTH := 94.0         # normale breedte (submenu's mogen breder worden)
## v0.13: commando-KRUIS (command_cross.gd) i.p.v. de lijst (v0.15: LINKS naast de helden, zie _place_cross);
## spreuken/items in een lijstje rechtsboven (SUBMENU_TOP); doelkeuze met pijltje + naamlabel.
const CommandCrossScript := preload("res://scripts/battle/command_cross.gd")
const CodexDataScript := preload("res://scripts/data/codex_data.gd")   # v0.19 Codex-knop
## v0.14 (RPG CODE) roze kern van de Golem-baas: regels + beeld (zie boss_core.gd)
const BossCore := preload("res://scripts/battle/boss_core.gd")
const KernData := preload("res://scripts/data/kern_data.gd")   # v0.15 kernvaardigheden
const Archief2 := preload("res://scripts/data/archief2.gd")
const Archief2Vijanden := preload("res://scripts/data/archief2_vijanden.gd")
const SpellRules := preload("res://scripts/data/spell_rules.gd")
const BossCoreView := preload("res://scripts/battle/boss_core_view.gd")
const CodexBattle := preload("res://scripts/battle/codex_battle.gd")   # Codex: vangen + bondgenoot
## schadegetal op de open kern (roze) en op het pantser (grijs)
const CORE_HIT_COLOR := Color("ff8ad8")
const ARMOR_HIT_COLOR := Color("b5a78d")
const SUBMENU_TOP := 24.0
const CROSS_MARGIN := 4.0         # ruimte tot de rechterrand
const BOX_GAP := 3.0
## Hoeveel art-pixels per scherm-eenheid (2 = "16-bit plus", 768x432).
const DETAIL := 2

## Huidige toestand (handig voor debuggen en de autotest):
## intro, command, target_enemy, target_ally, busy, message_wait
var state := "intro"
var current_hero := -1
var heroes: Array = []     # combatanten (Dictionary) voor de party
var enemies: Array = []    # combatanten voor de vijanden
var _reserved := {}        # item-id -> aantal al gekozen deze ronde
var _tapped = null         # combatant die is aangetikt tijdens doelkeuze
var _message_tapped := false
var _next_uid := 0
var _target_row := -1
var last_ally_target_row := -1   # laatst gekozen held als doelwit (voor de autotest)
var _caption_left := 0.0
var _menu_left := 0.0            # grenzen voor het menu (D-pad links, A/B rechts)
var _menu_right := 384.0
var _menu_hero := -1             # boven wiens statusvak het menu nu staat
var cross: Control                 # v0.13 commando-kruis
var _enemy_left_reserve := 0.0     # v0.15: vijanden beginnen rechts van het kruis
var target_name: PanelContainer    # v0.13 naam van het doelwit (klein label bij het pijltje)
var target_name_label: Label
var target_index := -1             # v0.13 gekozen doelwit in de lijst (voor de autotest)
var target_list: Array = []        # v0.13 kiesbare doelwitten (links -> rechts)

@onready var caption: Panel = $Caption
@onready var message_label: Label = $Caption/Label
@onready var message_arrow: Control = $Caption/Arrow
@onready var menu: PanelContainer = $CommandMenu
@onready var enemy_layer: Control = $Enemies
@onready var effects: Control = $Effects
@onready var target_cursor: Control = $TargetCursor
@onready var party_layer: Control = $Party
@onready var status_bar: Control = $StatusBar
@onready var victory_panel: PanelContainer = $VictoryWindow
@onready var victory_label: Label = $VictoryWindow/VictoryLabel
@onready var touch: Control = $TouchControls/Control
## v0.11 oefengevecht (proloog): {"tutorial": true, "enemy_hp": n, ...} of {} = gewoon
var tutorial: Dictionary = {}
## v0.15: vluchten mag niet in een baasgevecht (zoals Lufia 2). Tests mogen dit uitzetten.
var can_flee := true
var tip_panel: Panel
var tip_label: Label
var round_no := 0
## v0.21 (tests): laatste effect van een vaardigheid en aantal counters in dit gevecht
var last_skill_effect: Dictionary = {}
var counters_done := 0
## Welke tips er getoond zijn (voor de autotest): "aanval", "item"
var tips_shown := {}
var hero_nodes: Array = []    # battle_hero.gd per held
var status_boxes: Array = []  # hero_status_box.gd per held
var codex: CodexBattle            # Codex (scripts/battle/codex_battle.gd)
var _previous_scale_size := Vector2i.ZERO
## push_music in _ready, pop in _exit_tree. Alleen poppen als we zelf gepusht hebben.
var _battle_music_pushed := false


func _ready() -> void:
	tutorial = GameState.pending_tutorial.duplicate(true)
	_enter_detail_mode()
	_apply_hd_ui()
	_make_cross()
	menu.hide()
	target_cursor.hide()
	message_arrow.hide()
	victory_panel.hide()
	caption.gui_input.connect(_on_message_gui_input)
	victory_panel.gui_input.connect(_on_message_gui_input)
	# Helden: verwijzen direct naar GameState.party, dus schade blijft bewaard.
	# Archief 2, Lotte: alleen Dennis (plus één Codex-bondgenoot). Verdieping 3-4: de hele party.
	var row := 0
	for i in GameState.party.size():
		var h: Dictionary = GameState.party[i]
		if GameState.archief2_party_filter != "" and str(h.get("id", "")) != GameState.archief2_party_filter:
			continue
		var c := _make_combatant(h["name"], h, true, row)
		heroes.append(c)
		var path: String = h.get("battle_sprite", "")
		if path == "" or not ResourceLoader.exists(path):
			path = "res://assets/sprites/battle/dennis.png"   # reserve-plaatje
		var node: Control = HeroScript.new()
		node.name = "Held_" + str(h["name"])
		party_layer.add_child(node)
		node.setup(GameState.get_resource(path), Vector2.ZERO)
		node.tapped.connect(_on_hero_tapped.bind(row))
		if int(h["hp"]) <= 0:
			node.set_ko(true)
		c["node"] = node
		hero_nodes.append(node)
		var box: Control = StatusBoxScript.new()
		box.name = "Status_" + str(h["name"])
		status_bar.add_child(box)
		box.setup(h)
		box.tapped.connect(_on_hero_tapped.bind(row))
		status_boxes.append(box)
		row += 1
	# Codex: de actieve bondgenoot naast de helden (combatant met "ally": true)
	codex = CodexBattle.new(self)
	codex.add_allies()
	# Achtergrond: hangt af van het terrein waar het gevecht begon (zie game_data.gd).
	if GameState.pending_backdrop != "" and ResourceLoader.exists(GameState.pending_backdrop):
		$Backdrop.texture = GameState.get_resource(GameState.pending_backdrop)
	# Vijanden
	var ids: Array = GameState.pending_enemies
	if ids.is_empty():
		ids = GameState.pick_encounter_group()   # scène los gestart met F6
	_spawn_enemies(ids)
	if not tutorial.is_empty():
		_make_tip()
	_refresh_party()
	_layout()
	resized.connect(_layout)
	_start_battle_music()
	_run.call_deferred()


# ================================================================ fijn raster (768x432)
## Het venster rendert tijdens het gevecht 2x zo veel pixels (content_scale_size),
## en deze scène + de touch-knoppen worden 2x geschaald. Alles in deze scène
## rekent dus gewoon verder in 384x216. Bij het verlaten zetten we het terug,
## zodat de overworld er precies hetzelfde uitziet als altijd.
func _enter_detail_mode() -> void:
	var win := get_window()
	_previous_scale_size = win.content_scale_size
	if _previous_scale_size == Vector2i.ZERO:
		_previous_scale_size = Vector2i(384, 216)
	win.content_scale_size = _previous_scale_size * DETAIL
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	scale = Vector2(DETAIL, DETAIL)
	$TouchControls.scale = Vector2(DETAIL, DETAIL)
	_fit_to_screen()
	get_viewport().size_changed.connect(_fit_to_screen)


## Vensters met dunne, scherpe randen op het 2x-raster (zie hd_ui.gd). We passen een
## KOPIE van het thema aan, zodat de vensters in de overworld niet veranderen.
func _apply_hd_ui() -> void:
	if theme:
		var t: Theme = theme.duplicate()
		for type_name in ["Panel", "PanelContainer"]:
			if t.has_stylebox("panel", type_name):
				t.set_stylebox("panel", type_name,
						HdUi.hd_style(t.get_stylebox("panel", type_name), "res://assets/ui/window_hd.png"))
		theme = t
	# v0.13: palet (scripts/ui/ui_style.gd) voor strook en overwinningsvenster
	# v0.16: buit/beloning na het gevecht in het blauwe Lufia 2-vak (zelfde als de tekstvakken)
	victory_panel.add_theme_stylebox_override("panel", UiStyle.blue_box("vak", Vector4(9, 7, 9, 6)))
	victory_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	victory_label.add_theme_color_override("font_color", UiStyle.BOX_TEXT)
	victory_label.add_theme_color_override("font_shadow_color", UiStyle.BOX_SHADOW)
	caption.add_theme_stylebox_override("panel", UiStyle.panel("soft"))


## v0.13: commando-kruis + doelnaam-label maken.
func _make_cross() -> void:
	cross = CommandCrossScript.new()
	cross.name = "CommandCross"
	add_child(cross)
	move_child(cross, $TouchControls.get_index())     # onder de touch-knoppen
	target_name = PanelContainer.new()
	target_name.name = "TargetName"
	target_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_name.add_theme_stylebox_override("panel", UiStyle.panel("tab", UiStyle.TEAL_DIM))
	target_name_label = Label.new()
	target_name_label.add_theme_color_override("font_color", UiStyle.TEXT)
	target_name.add_child(target_name_label)
	add_child(target_name)
	move_child(target_name, $TouchControls.get_index())
	target_name.hide()


func _fit_to_screen() -> void:
	if not is_inside_tree():
		return
	position = Vector2.ZERO
	size = get_viewport_rect().size / DETAIL
	if touch and touch.has_method("refit"):
		touch.refit()


func _exit_tree() -> void:
	if _battle_music_pushed:
		_battle_music_pushed = false
		AudioManager.pop_music(0.35)
	if get_viewport().size_changed.is_connected(_fit_to_screen):
		get_viewport().size_changed.disconnect(_fit_to_screen)
	if touch and get_viewport().size_changed.is_connected(touch.refit):
		get_viewport().size_changed.disconnect(touch.refit)
	if _previous_scale_size != Vector2i.ZERO:
		get_window().content_scale_size = _previous_scale_size


func _start_battle_music() -> void:
	var track := "gevecht_miniboss" if GameState.pending_boss else "gevecht_normaal"
	_battle_music_pushed = true
	AudioManager.push_music(track, 0.4)


# ================================================================ opbouw
func _make_combatant(display_name: String, stats: Dictionary, is_hero: bool, row: int) -> Dictionary:
	_next_uid += 1
	return {"uid": _next_uid, "name": display_name, "s": stats, "is_hero": is_hero,
			"defending": false, "row": row, "node": null}


func _enemy_known(id: String) -> bool:
	return GameData.ENEMIES.has(id) or BerggrotData.has_enemy(id)


func _enemy_base(id: String) -> Dictionary:
	if GameData.ENEMIES.has(id):
		return GameData.ENEMIES[id]
	return BerggrotData.enemy(id)


func _spawn_enemies(ids: Array) -> void:
	# onbekende id's (bv. een oude naam) overslaan; nooit een gevecht zonder vijanden
	ids = ids.filter(func(i): return _enemy_known(str(i)))
	if ids.is_empty():
		push_warning("Gevecht zonder bekende vijanden; gebruik de eerste encountergroep")
		ids = GameData.ENCOUNTER_GROUPS[0]["enemies"].duplicate()
	var counts := {}
	for id in ids:
		counts[id] = counts.get(id, 0) + 1
	var seen := {}
	for id in ids:
		var data: Dictionary = _enemy_base(str(id)).duplicate(true)
		if GameState.pending_boss:
			data = BossCore.apply_boss(data)   # v0.14: baas-stats + kern (alleen in een baasgevecht)
			can_flee = false                   # v0.15: niet vluchten voor een baas
			# Task #4: baas van de dungeon van 100 verdiepingen (verdieping 0 = ongewijzigd)
			data = Dungeon100Scaling.battle_enemy(data, GameState.dungeon100_floor, true)
		else:
			data.erase("boss")
			if GameState.dungeon100_floor > 0:
				# Task #4: monsterschaal per verdieping (vervangt hier het kamerniveau "tier")
				data = Dungeon100Scaling.battle_enemy(data, GameState.dungeon100_floor, false)
			elif GameState.pending_tier > 0 and not bool(data.get("unique", false)):
				# v0.14: monsterniveau van de dungeonverdieping (0 = gewoon; game_data.gd TIERS)
				# v0.19: een uniek monster (Inktwurm) heeft zijn eigen vaste niveau ("encounter_level")
				# Eerste Archief: dezelfde tabel, daarna omlaag naar doel-level 7.
				if GameState.pending_archief:
					data = GameData.apply_archief_tier(data, GameState.pending_tier)
				else:
					data = GameData.apply_tier(data, GameState.pending_tier)
		if tutorial.has("enemy_hp"):
			data["max_hp"] = int(tutorial["enemy_hp"])   # oefengevecht: iets taaier
		data["hp"] = data["max_hp"]
		data["level"] = int(data.get("encounter_level", 1))
		var display_name: String = data["name"]
		if counts[id] > 1:   # "Papiergeest A", "Papiergeest B", ...
			seen[id] = seen.get(id, 0) + 1
			display_name += " " + char(64 + seen[id])
		var c := _make_combatant(display_name, data, false, -1)
		c["id"] = id
		GameState.mark_seen(id)   # bestiarium: gezien
		if GameState.pending_boss and GameState.dungeon100_floor > 0:
			var end_id := EndgameBestiary.id_for_floor(GameState.dungeon100_floor)
			if end_id != "":
				GameState.mark_seen(end_id)
		var node := TextureButton.new()
		# v0.19: nog geen art (bv. de Inktwurm)? dan de plaatsvervanger (GameData.enemy_sprite)
		var sprite_path := GameData.enemy_sprite(data)
		var tex: Texture2D = GameState.get_resource(sprite_path)
		node.texture_normal = tex
		# Alle gevechts-art is 2x zo fijn getekend: op halve grootte tonen, zodat
		# 1 art-pixel = 1 pixel van het 768-raster. NIET afronden: een oneven breedte
		# (bv. 79) wordt dan 39,5 eenheden = precies 79 echte pixels.
		var art_scale := ENEMY_DEPTH_SCALE / DETAIL
		# vangnet voor nieuwe/vervangen art: een te hoog plaatje (> MAX_ENEMY_ART_H fijne
		# pixels) wordt iets kleiner getoond, zodat het nooit over de bericht-strook valt
		art_scale *= art_fit(tex.get_size(), bool(data.get("is_boss", false)))
		node.ignore_texture_size = true
		node.stretch_mode = TextureButton.STRETCH_SCALE
		node.size = Vector2(tex.get_size()) * art_scale
		node.custom_minimum_size = node.size
		# bovenkant van het echte plaatje (voor het doel-pijltje); één keer per plaatje
		# uitgerekend en bewaard (get_image() is een trage GPU-terugleesactie op telefoons)
		c["top"] = sprite_top(sprite_path, tex) * art_scale
		node.focus_mode = Control.FOCUS_NONE
		node.pressed.connect(_on_enemy_pressed.bind(c))
		if data.get("tint") is Array and (data["tint"] as Array).size() >= 3:
			var tn: Array = data["tint"]
			node.modulate = Color(float(tn[0]), float(tn[1]), float(tn[2]))
		_add_enemy_idle(node, data)
		enemy_layer.add_child(node)
		c["node"] = node
		if data.has("core"):   # v0.14: roze kern (Golem-baas)
			c["core"] = BossCore.new(data["core"])
			var view: Control = BossCoreView.new()
			node.add_child(view)
			view.setup(c["core"], node, float(node.get_meta("still").get_width()))
		enemies.append(c)


static var _top_cache := {}


## v0.13: optionele idle-animatie van een vijand (game_data.gd: "idle" = strook met
## "idle_frames" frames, elk frame even groot als "sprite"; "idle_time" = sec per frame).
## Zonder "idle" blijft het plaatje stil (zoals altijd).
## Optioneel ook "hit" = plaatje (zelfde grootte/ankerpunt) dat even getoond wordt bij schade.
func _add_enemy_idle(node: TextureButton, data: Dictionary) -> void:
	node.set_meta("still", node.texture_normal)
	var hit_path := str(data.get("hit", ""))
	if hit_path != "" and ResourceLoader.exists(hit_path):
		node.set_meta("hit_tex", GameState.get_resource(hit_path))
	_add_enemy_under(node, data)
	var path := str(data.get("idle", ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	var strip: Texture2D = GameState.get_resource(path)
	var n := maxi(1, int(data.get("idle_frames", 2)))
	var fw := strip.get_width() / n
	var frames: Array[Texture2D] = []
	for i in n:
		var at := AtlasTexture.new()
		at.atlas = strip
		at.region = Rect2(i * fw, 0, fw, strip.get_height())
		frames.append(at)
	node.texture_normal = frames[0]
	node.set_meta("idle_frames", frames)
	var timer := Timer.new()
	timer.name = "Idle"
	timer.wait_time = float(data.get("idle_time", 0.5))
	timer.autostart = true
	var k := [0]
	timer.timeout.connect(func():
		k[0] = (k[0] + 1) % frames.size()
		if not node.has_meta("hit_until"):
			node.texture_normal = frames[k[0]])
	node.add_child(timer)


const HIT_SHOW := 0.3

## v0.13: optionele aparte laag ONDER/achter de vijand (bv. de runecirkel van de Golem):
## game_data.gd "under" = strook met "under_frames" frames, "under_pos" = [x, y] linksboven in
## de pixels van het vijand-plaatje (mag eronder uitsteken), "under_time" = sec per frame.
func _add_enemy_under(node: TextureButton, data: Dictionary) -> void:
	var path := str(data.get("under", ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	var strip: Texture2D = GameState.get_resource(path)
	var n := maxi(1, int(data.get("under_frames", 1)))
	var fw := strip.get_width() / n
	var frames: Array[Texture2D] = []
	for i in n:
		var at := AtlasTexture.new()
		at.atlas = strip
		at.region = Rect2(i * fw, 0, fw, strip.get_height())
		frames.append(at)
	var still: Texture2D = node.texture_normal
	var k := node.size.x / float(still.get_width())    # zelfde schaal als het vijand-plaatje
	var up: Array = data.get("under_pos", [0, 0])
	var under := TextureRect.new()
	under.name = "Under"
	under.texture = frames[0]
	under.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	under.stretch_mode = TextureRect.STRETCH_SCALE
	under.position = Vector2(float(up[0]), float(up[1])) * k
	under.size = Vector2(fw, strip.get_height()) * k
	under.show_behind_parent = true
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	under.set_meta("frames", frames)
	node.add_child(under)
	if n > 1:
		var timer := Timer.new()
		timer.name = "UnderTimer"
		timer.wait_time = float(data.get("under_time", 0.8))
		timer.autostart = true
		var j := [0]
		timer.timeout.connect(func():
			j[0] = (j[0] + 1) % frames.size()
			under.texture = frames[j[0]])
		node.add_child(timer)

## v0.13: raak-plaatje even tonen (alleen als de vijand er een heeft), daarna terug naar
## het idle-frame / het stille plaatje.
func _show_hit_frame(node: Control) -> void:
	if not (node is TextureButton) or not node.has_meta("hit_tex"):
		return
	var b := node as TextureButton
	var token := Time.get_ticks_usec()
	b.set_meta("hit_until", token)
	b.texture_normal = b.get_meta("hit_tex")
	await get_tree().create_timer(HIT_SHOW).timeout
	if not is_instance_valid(b) or b.get_meta("hit_until", 0) != token:
		return
	b.remove_meta("hit_until")
	var idle_t: Timer = b.get_node_or_null("Idle")
	if b.has_meta("idle_frames") and idle_t:
		b.texture_normal = b.get_meta("idle_frames")[0]
	else:
		b.texture_normal = b.get_meta("still")


## Eerste niet-doorzichtige rij van een plaatje (gecachet).
static func sprite_top(path: String, tex: Texture2D) -> float:
	if not _top_cache.has(path):
		var img := tex.get_image()
		_top_cache[path] = float(img.get_used_rect().position.y) if img and not img.is_empty() else 0.0
	return _top_cache[path]


## Alles op zijn plek zetten (ook opnieuw als het scherm van grootte verandert).
func _layout() -> void:
	var w := size.x if size.x > 0 else 384.0
	var h := size.y if size.y > 0 else 216.0
	var dx := roundf((w - 384.0) / 2.0)
	# Knoppen: statusvakken tussen de D-pad en de B-knop, menu links van de A-knop.
	var left := 78.0
	var right := 300.0
	var menu_right := w - 49.0
	if touch and touch.has_method("dpad_center"):
		left = touch.dpad_center().x + touch.dpad_radius * 1.2 + 4.0
		right = touch.b_center().x - touch.button_radius * 1.25 - 4.0
		menu_right = floorf(touch.a_center().x - touch.button_radius * 1.25 - 1.0)
	# v0.13: lijstje (spreuken/items) rechtsboven; het kruis rechtsonder boven A/B
	menu.right_edge = w - CROSS_MARGIN
	menu.top_edge = SUBMENU_TOP
	menu.bottom_edge = -1.0
	_menu_left = left
	_menu_right = right
	_fit_caption()
	# Statusvakken: onderaan
	var count := status_boxes.size()
	if count > 0:
		# v0.15: links ruimte maken voor het commando-kruis naast de eerste held (als het past)
		var box_left := _box_left_for_cross(left, right, count)
		var bw := floorf((right - box_left - BOX_GAP * (count - 1)) / count)
		bw = minf(bw, 88.0)
		var total := bw * count + BOX_GAP * (count - 1)
		var x0 := roundf(box_left + (right - box_left - total) / 2.0)
		for i in count:
			var box: Control = status_boxes[i]
			box.position = Vector2(x0 + i * (bw + BOX_GAP), h - StatusBoxScript.HEIGHT - 3)
			box.size = Vector2(bw, StatusBoxScript.HEIGHT)
			box.queue_redraw()
	# Helden: midden boven hun eigen statusvak (reserve: de oude vaste plekken)
	for i in hero_nodes.size():
		var slot: Vector2
		if i < status_boxes.size():
			var box: Control = status_boxes[i]
			slot = Vector2(roundf(box.position.x + box.size.x / 2.0), box.position.y - HERO_BOX_GAP)
		elif i < HERO_SLOTS.size():
			slot = HERO_SLOTS[i] + Vector2(dx, 0)
		else:
			slot = HERO_SLOTS[HERO_SLOTS.size() - 1] + Vector2(dx + 26 * (i - HERO_SLOTS.size() + 1), 0)
		hero_nodes[i].set_home(slot)
	_sort_by_feet(party_layer)
	# v0.15: het kruis links naast de helden (hangt af van waar de helden staan)
	_place_cross(w, h)
	_layout_enemies(w, dx)
	_place_menu(maxi(_menu_hero, 0), false)


## v0.15 Commando-kruis LINKS naast de party (zie CROSS_HERO_GAP). Horizontaal: rechterkant net
## links van de meest linkse held (zichtbare art en tik-vak, ook als hij een stap naar voren zet).
## Verticaal: midden op de hoogte van de helden, maar boven de statusvakken en - als het kruis
## boven de D-pad uitkomt - boven de D-pad. Past het niet naast de helden (heel smal scherm), dan
## links tegen de rand en boven de helden.
func _place_cross(w: float, h: float) -> void:
	if cross == null:
		return
	var span: float = CommandCrossScript.BUTTON * 3.0 + CommandCrossScript.GAP * 2.0
	var half := span / 2.0
	# heldenblok: linkerkant, boven- en onderkant (tik-vak + art, thuis en een stap naar voren)
	var hero_l := w
	var hero_top := h
	var hero_bottom := 0.0
	for node in hero_nodes:
		var rects: Array = [Rect2(node.home - node.FEET, node.SIZE),
				Rect2(node.home + node.STEP - node.FEET, node.SIZE)]
		if node.has_method("art_rect"):
			rects.append(node.art_rect(node.home))
		for r in rects:
			hero_l = minf(hero_l, r.position.x)
			hero_top = minf(hero_top, r.position.y)
			hero_bottom = maxf(hero_bottom, r.end.y)
	if hero_nodes.is_empty():
		hero_l = w * 0.45
		hero_top = h * 0.45
		hero_bottom = h - StatusBoxScript.HEIGHT - 6.0
	var right := floorf(hero_l - CROSS_HERO_GAP)
	var x0 := maxf(CROSS_EDGE, right - span)
	var beside := x0 + span <= right + 0.5
	var r_x := Rect2(x0, 0, span, h)
	# onderkant: niet over een statusvak of (als het kruis erboven komt) de D-pad
	var bottom_limit := h - CROSS_EDGE
	for box in status_boxes:
		var br := Rect2(box.position, box.size)
		if br.position.x < r_x.end.x and br.end.x > r_x.position.x:
			bottom_limit = minf(bottom_limit, br.position.y - 2.0)
	if touch and touch.has_method("dpad_center"):
		var dc: Vector2 = touch.dpad_center()
		var dr: float = touch.dpad_radius * 1.2
		if x0 < dc.x + dr:
			bottom_limit = minf(bottom_limit, dc.y - dr - 2.0)
	var cy: float
	if beside:
		# midden op de heldenrij (iets hoger dan het midden: dichter bij hun bovenlijf)
		cy = (hero_top + hero_bottom) / 2.0 - 4.0
	else:
		# geen plek naast de helden: boven ze
		cy = hero_top - 2.0 - half
	cy = minf(cy, bottom_limit - half)
	cy = maxf(cy, CAPTION_TOP + 1.0 + CROSS_TAB_ROOM + half)
	cross.place(Vector2(roundf(x0 + half), floorf(cy)))
	# vijanden rechts van het kruis (en zijn naam-tabje) houden
	var cr: Rect2 = cross.cross_rect()
	_enemy_left_reserve = cr.end.x + 3.0 if cr.position.y - CROSS_TAB_ROOM < ENEMY_FEET_Y + 6.0 else 0.0


## v0.15 Linkerrand van de statusvakken zodat het kruis (CROSS_EDGE + kruis + CROSS_HERO_GAP)
## links naast de art van de eerste held past. Schuift de vakken alleen naar rechts zolang ze
## minstens MIN_BOX_W breed blijven; anders blijft alles staan (het kruis gaat dan boven de helden).
const MIN_BOX_W := 56.0

func _box_left_for_cross(left: float, right: float, count: int) -> float:
	if hero_nodes.is_empty() or not hero_nodes[0].has_method("art_rect"):
		return left
	var span: float = CommandCrossScript.BUTTON * 3.0 + CommandCrossScript.GAP * 2.0
	var art_off: float = -hero_nodes[0].art_rect(Vector2.ZERO).position.x     # art links van de voeten
	var tap_off: float = hero_nodes[0].FEET.x
	var need := CROSS_EDGE + span + CROSS_HERO_GAP + maxf(art_off, tap_off)  # midden van held 0
	var l := left
	while l < right:
		var bw := minf(floorf((right - l - BOX_GAP * (count - 1)) / count), 88.0)
		if bw < MIN_BOX_W:
			return left
		var total := bw * count + BOX_GAP * (count - 1)
		var x0 := roundf(l + (right - l - total) / 2.0)
		if x0 + roundf(bw / 2.0) >= need:
			return l
		l += 1.0
	return left


## v0.15 Gebied voor de vijandenrij: [links, rechts] (rechts van het kruis).
func enemy_region(w: float) -> Array:
	return [maxf(ENEMY_LEFT, _enemy_left_reserve), w - ENEMY_LEFT]


## Commandomenu boven het statusvak van held i (linkerkanten gelijk, geklemd tussen
## D-pad en A/B). animate = kort opzij schuiven naar de volgende held.
## v0.13: het lijstje staat vast rechtsboven (niet meer over de held heen).
func _place_menu(i: int, _animate: bool) -> void:
	_menu_hero = i
	menu.bottom_edge = -1.0
	menu.place()


## Vijanden naast elkaar van ENEMY_LEFT tot de rechterrand (de baas is breed, de rest
## klein). Past het niet, dan schuiven ze iets over elkaar.
func _layout_enemies(w: float, dx: float) -> void:
	var n := enemies.size()
	if n == 0:
		return
	# v0.15: gecentreerd over de hele breedte; alleen als de rij over het kruis (links) zou vallen
	# schuift hij naar rechts (enemy_region) en zo nodig iets in elkaar.
	var reg := enemy_region(w)
	var region_l: float = reg[0]
	var region_r: float = reg[1]
	var gap := 4.0
	var total := 0.0
	for e in enemies:
		total += e["node"].size.x
	total += gap * (n - 1)
	var avail := region_r - region_l
	var x := maxf(region_l, ENEMY_LEFT + maxf(0.0, (region_r - ENEMY_LEFT - total) / 2.0))
	if total > avail and n > 1:
		gap -= (total - avail) / (n - 1)
		x = region_l
	elif total < avail:
		# v0.10: heeft de achtergrond een vaste plek (bv. de magenta cirkel van de baas),
		# dan staat de rij daar horizontaal boven (game_data.gd BACKDROP_STAGE)
		var sx := stage_x(w, size.y if size.y > 0 else 216.0)
		if not is_nan(sx):
			var cap := maxf(region_l + total, region_r - STAGE_RIGHT_RESERVE)
			x = clampf(roundf(sx - total / 2.0), region_l, cap - total)
	for i in n:
		var node: Control = enemies[i]["node"]
		var feet := Vector2(x + node.size.x / 2.0, ENEMY_FEET_Y + (2.0 if i % 2 == 1 else 0.0))
		feet.y += float(enemies[i]["s"].get("y_offset", 0))
		# hoog plaatje: zo ver omlaag als nodig (max. ENEMY_FEET_Y_MAX) zodat de bovenkant in beeld blijft
		feet.y = maxf(feet.y, minf(enemy_feet(node).y, ENEMY_FEET_Y_MAX))
		node.position = (feet - enemy_feet(node)).round()
		x += node.size.x + gap
	_sort_by_feet(enemy_layer)


## x op het scherm van het 'podium' in de achtergrond (NAN als die er niet is).
## De achtergrond vult het scherm (keep aspect covered), dus: schaal + centreren.
func stage_x(w: float, h: float) -> float:
	var stage = GameData.BACKDROP_STAGE.get(GameState.pending_backdrop_id)
	var tex: Texture2D = $Backdrop.texture
	if stage == null or tex == null:
		return NAN
	var ts := tex.get_size()
	var sc := maxf(w / ts.x, h / ts.y)
	return (w - ts.x * sc) / 2.0 + float(stage.x) * sc


## Voeten binnen een vijand-plaatje: midden onderaan (de grondschaduw).
func enemy_feet(node: Control) -> Vector2:
	return Vector2(roundf(node.size.x / 2.0), node.size.y - 3.0 * ENEMY_DEPTH_SCALE)


## Wie lager op het scherm staat, wordt later (= ervoor) getekend.
func _sort_by_feet(layer: Control) -> void:
	var kids := layer.get_children()
	kids.sort_custom(func(a, b): return a.position.y + a.size.y < b.position.y + b.size.y)
	for k in kids.size():
		layer.move_child(kids[k], k)


# ================================================================ hoofdlus
func _run() -> void:
	await Transition.fade_in()
	var names: Array = enemies.map(func(e): return e["name"])
	var intro := "Monsters appear!"
	if names.size() == 1:
		intro = "%s appears!" % names[0]
	await say(intro)
	await _core_hint()
	if await _archief2_opening():
		return
	while true:
		round_no += 1
		await _core_round_start()
		var plan: Array = await _choose_commands()
		menu.close()
		cross.close()
		_hide_tip()
		_set_state("busy")
		if plan.size() == 1 and plan[0]["type"] == "flee":
			if await _try_flee():
				await GameState.end_battle("flee")
				return
			plan = []
		else:
			plan.append_array(codex.ally_actions())   # Codex: bondgenoot handelt zelf
		for e in _alive(enemies):
			if e.has("core") and e["core"].open:
				plan.append({"type": "core_charge", "actor": e, "target": null})   # v0.14: laadt op
			elif bool(e["s"].get("archief2_leech", false)):
				plan.append({"type": "archief2_leech", "actor": e, "target": null})
			else:
				plan.append({"type": "attack", "actor": e, "target": null})
		for a in plan:
			a["speed"] = float(a["actor"]["s"]["agi"]) * _buff_mult(a["actor"], "agi") + randf() * 3.0
			if a["type"] == "core_charge":
				a["speed"] = -1000.0   # de oplaad-actie komt altijd als laatste
			if a["type"] == "defend":
				a["actor"]["defending"] = true   # verdedigen telt vanaf het begin van de ronde
		plan.sort_custom(func(a, b): return a["speed"] > b["speed"])
		for a in plan:
			if a["actor"]["s"]["hp"] <= 0:
				continue
			await _execute(a)
			if _alive(enemies).is_empty():
				await _victory()
				return
			if codex.party_down():   # Codex: alle echte helden KO (de bondgenoot telt niet)
				await _defeat()
				return
		for c in heroes + enemies:
			c["defending"] = false
			_guard_tick(c)   # v0.15: schild omhoog telt af
			Archief2Vijanden.tick(c)   # v0.21: counter telt af
			_kern_tick(c)    # v0.15: kernvaardigheden laden op
			_tick_ailments(c)
		_refresh_party()
		if _alive(enemies).is_empty():
			await _victory()
			return
		if codex.party_down():
			await _defeat()
			return
		_reserved.clear()


# ================================================================ commando's kiezen
func _choose_commands() -> Array:
	var actions: Array = []
	actions.resize(heroes.size())
	_reserved.clear()
	var i := _next_alive_hero(-1)
	while i < heroes.size():
		_set_active_hero(i)
		var act = await _choose_for_hero(heroes[i], _prev_alive_hero(i) != -1)
		if act == null:
			var prev := _prev_alive_hero(i)
			if prev != -1:
				_unreserve(actions[prev])
				actions[prev] = null
				i = prev
			continue
		if act["type"] == "flee":
			for a in actions:
				_unreserve(a)
			_set_active_hero(-1)
			return [act]
		actions[i] = act
		i = _next_alive_hero(i)
	_set_active_hero(-1)
	return actions.filter(func(a): return a != null)


## De held die kiest stapt naar voren, de rest staat op zijn plek.
func _set_active_hero(i: int) -> void:
	current_hero = i
	if i >= 0:
		_place_menu(i, true)
	for j in hero_nodes.size():
		var node: Control = hero_nodes[j]
		var forward := j == i
		if node.stepped_forward != forward or (forward and node.pose != "klaar"):
			node.step(forward)
	_refresh_party()


func _choose_for_hero(hero: Dictionary, can_go_back: bool):
	var last := 0          # na 'terug' uit een submenu/doelkeuze staat het kruis weer daar
	while true:
		_set_state("command")
		show_message("What will %s do?" % hero["name"])
		_show_tip(hero)
		var allowed := [
			true,
			not hero["s"]["spells"].is_empty() or not _kern_skills(hero).is_empty(),   # v0.15: + kern
			not _available_items().is_empty(),
			true,
			tutorial.is_empty() and can_flee,   # oefengevecht / baas (v0.15): niet vluchten
			_items_left(CodexDataScript.BOOK_ITEM) > 0 or codex.can_swap(),   # v0.19 Codex
		]
		cross.open(hero["name"], allowed, last, can_go_back, [] if codex_command_shown() else [COMMANDS.size() - 1])
		var cmd: int = await cross.finished
		cross.deactivate()
		last = maxi(cmd, 0)
		match cmd:
			-1:
				return null
			0:
				var t = await _select_enemy()
				if t != null:
					return {"type": "attack", "actor": hero, "target": t}
			1:
				var s = await _choose_spell(hero)
				if s != null:
					return s
			2:
				var it = await _choose_item(hero)
				if it != null:
					return it
			3:
				return {"type": "defend", "actor": hero}
			4:
				return {"type": "flee", "actor": hero}
			5:
				var c = await _choose_codex(hero)
				if c != null:
					return c
	return null


## v0.19: staat de Codex-knop in het kruis? Niet in het oefengevecht, en niet zolang er nog
## niets te doen is (0 pagina's en 0 Lege Boeken).
func codex_command_shown() -> bool:
	if not tutorial.is_empty() or GameState.practice_battle:
		return false
	return not GameState.codex_pages.is_empty() or GameState.item_count(CodexDataScript.BOOK_ITEM) > 0


## v0.19 Codex-submenu: 0 = Vangen, 1 = Wissel bondgenoot. Uitgeschakeld = grijs met de reden.
func _choose_codex(hero: Dictionary):
	var book: String = CodexDataScript.BOOK_ITEM
	var last := 0
	while true:
		_set_state("command")
		var books := _items_left(book)
		var vangen := "Capture  Book x%d" % books if books > 0 else "Capture: no Blank Book"
		var wissel := "Swap ally"
		if not codex.can_swap():
			wissel = "Swap: Codex empty" if GameState.codex_pages.is_empty() else "Swap: all down"
		show_message("Codex: capture or swap?")
		menu.open("Codex", [{"text": vangen, "enabled": books > 0},
				{"text": wissel, "enabled": codex.can_swap()}], last, true, CODEX_ROW_H)
		var k: int = await menu.finished
		menu.close()
		if k == -1:
			return null
		last = k
		if k == 0:
			var bk := "1 book" if books == 1 else "%d books" % books
			var t = await _select_enemy(func(c): return "%s %s (%s)" % [c["name"], codex.capture_hint(c), bk], "Capture: ")
			if t != null:
				_reserved[book] = _reserved.get(book, 0) + 1
				return {"type": "item", "actor": hero, "item": book, "target": t}   # zelfde weg als Item
		else:
			var sw = await _choose_swap(hero)
			if sw != null:
				return sw
	return null


## v0.19 Wissel-lijst: niet-KO pagina's ('Lv' + naam) en onderaan 'Geen'. De bondgenoot die nu
## meevecht staat erin maar is grijs ('nu'); 'Geen' is grijs als er geen bondgenoot is.
func _choose_swap(hero: Dictionary):
	var cur := codex.current_ally_uid()
	var pages: Array = codex.swap_choices()
	var entries := []
	var start := 0
	for i in pages.size():
		var p: Dictionary = pages[i]
		var here := str(p["uid"]) == cur
		entries.append({"text": "%s Lv%d%s" % [p["name"], int(p["level"]), " now" if here else ""], "enabled": not here})
	entries.append({"text": "None", "enabled": cur != ""})
	show_message("Who fights with you?")
	menu.open("Swap", entries, start, true, CODEX_ROW_H, CODEX_ROWS_MAX)
	var k: int = await menu.finished
	menu.close()
	if k == -1:
		return null
	var uid := "" if k >= pages.size() else str(pages[k]["uid"])
	return {"type": "codex_swap", "actor": hero, "page": uid}


func _choose_spell(hero: Dictionary):
	while true:
		_set_state("command")
		var ids: Array = hero["s"]["spells"]
		var entries := []
		for id in ids:
			var sp: Dictionary = GameData.SPELLS[id]
			entries.append({"text": "%-7s %dMP" % [sp["name"], sp["mp"]], "enabled": hero["s"]["mp"] >= sp["mp"]})
		# v0.15: kernvaardigheden onder de spreuken (geen MP, wel opladen)
		var kern := _kern_skills(hero)
		for id in kern:
			entries.append({"text": kern_entry_text(hero, id), "enabled": kern_ready(hero, id)})
		show_message("Which spell?" if kern.is_empty() else ("Which skill?" if ids.is_empty() else "Which spell or skill?"))
		menu.open("Magic" if kern.is_empty() else ("Core" if ids.is_empty() else "Magic/Core"), entries)
		var k: int = await menu.finished
		menu.close()        # v0.13: lijstje weg, dan is het doel goed te zien
		if k == -1:
			return null
		if k >= ids.size():
			var kid: String = kern[k - ids.size()]
			if not kern_ready(hero, kid):
				continue
			var kt = await _select_enemy()
			if kt != null:
				return {"type": "kern_skill", "actor": hero, "skill": kid, "target": kt}
			continue
		var spell: Dictionary = GameData.SPELLS[ids[k]]
		var t = null
		match spell["target"]:
			"enemy":
				t = await _select_enemy()
			"ally":
				t = await _select_ally()
			"ko":
				t = await _select_ko()
			"all_enemies", "all_allies":
				return {"type": "spell", "actor": hero, "spell": ids[k], "target": null}
		if t != null:
			return {"type": "spell", "actor": hero, "spell": ids[k], "target": t}
	return null


func _choose_item(hero: Dictionary):
	while true:
		_set_state("command")
		var ids := _available_items()
		if ids.is_empty():
			return null
		var entries := []
		for id in ids:
			entries.append({"text": "%s x%d" % [GameData.ITEMS[id].get("short", GameData.ITEMS[id]["name"]), _items_left(id)], "enabled": true})
		show_message("Which item?")
		menu.open("Item", entries)
		var k: int = await menu.finished
		menu.close()
		if k == -1:
			return null
		var t = null
		if str(GameData.ITEMS[ids[k]].get("target", "ally")) == "enemy":
			t = await _select_enemy()      # Codex: Leeg Boek op een vijand
		else:
			t = await _select_ally()
		if t != null:
			_reserved[ids[k]] = _reserved.get(ids[k], 0) + 1
			return {"type": "item", "actor": hero, "item": ids[k], "target": t}
	return null


func _available_items() -> Array:
	var ids := []
	for id in GameData.ITEMS:
		if _items_left(id) > 0:
			ids.append(id)
	return ids


func _items_left(id: String) -> int:
	return GameState.item_count(id) - int(_reserved.get(id, 0))


func _unreserve(action) -> void:
	if action != null and action["type"] == "item":
		_reserved[action["item"]] = maxi(0, _reserved.get(action["item"], 0) - 1)


func _next_alive_hero(from: int) -> int:
	for j in range(from + 1, heroes.size()):
		if heroes[j]["s"]["hp"] > 0 and not heroes[j].get("ally", false):
			return j
	return heroes.size()


func _prev_alive_hero(from: int) -> int:
	for j in range(from - 1, -1, -1):
		if heroes[j]["s"]["hp"] > 0 and not heroes[j].get("ally", false):
			return j
	return -1


# ================================================================ doel kiezen
## Doel kiezen: de namen staan in het menu (op dezelfde plek als het commandomenu) en een
## pijltje wijst het doel aan. Kiezen met omhoog/omlaag/links/rechts + A, op een naam tikken
## of op de vijand zelf tikken. B = terug.
## v0.19: label (optioneel) = tekst bij het pijltje (bv. 'Mosslijm 35%' bij Vangen); prefix komt
## ervoor in de berichtstrook.
func _select_enemy(label := Callable(), prefix := ""):
	_set_state("target_enemy")
	var living := _alive(enemies)
	# v9.1: vijanden staan bovenin; het pijltje blijft onder de bericht-strook (dan wijst het
	# iets in het plaatje, op het hoofd)
	var above := func(c): return Vector2(c["node"].position.x + roundf(c["node"].size.x / 2.0), maxf(c["node"].position.y + float(c.get("top", 0)) - 2.0, CURSOR_MIN_Y))
	return await _pick_target(living, "Doel", above, false, label, prefix)


func _select_ally():
	_set_state("target_ally")
	var living := _alive(heroes)
	var result = await _pick_target(living, "On whom?", func(c): return c["node"].head_position() + Vector2(0, -2), true)
	if result != null:
		last_ally_target_row = result["row"]
	return result


func _select_ko():
	var dead: Array = []
	for h in heroes:
		if int(h["s"]["hp"]) <= 0:
			dead.append(h)
	if dead.is_empty():
		show_message("Niemand is bewusteloos.")
		await _wait(MESSAGE_TIME)
		return null
	_set_state("target_ally")
	return await _pick_target(dead, "Wie?", func(c): return c["node"].head_position() + Vector2(0, -2), true)


## v0.13: geen namenlijst meer. Een pijltje (richtpijl.png) wijst het doel aan, met de naam
## in een klein label. Links/rechts (en omhoog/omlaag) = volgende/vorige, A = kiezen,
## B = terug naar het kruis, of tik direct op de vijand / held / zijn statusvak.
func _pick_target(living: Array, _title: String, point: Callable, heroes_side: bool, label := Callable(),
		prefix := ""):
	# van links naar rechts op het scherm
	living = living.duplicate()
	living.sort_custom(func(a, b): return a["node"].position.x < b["node"].position.x)
	target_list = living
	cross.hide()
	_tapped = null
	var result = null
	var idx := 0
	var shown := -1
	while true:
		if idx != shown:
			shown = idx
			target_index = idx
			if heroes_side:
				_target_row = living[idx]["row"]
				_refresh_party()
			var lab := str(label.call(living[idx])) if label.is_valid() else str(living[idx]["name"])
			show_message(("On whom? " if heroes_side else prefix) + lab)
			target_name_label.text = lab
		var tip: Vector2 = point.call(living[idx])
		target_cursor.point_at(tip)
		target_cursor.show()
		_place_target_name(tip)
		target_name.show()
		await get_tree().process_frame
		if _tapped != null and _tapped["is_hero"] == heroes_side and _tapped["s"]["hp"] > 0:
			result = _tapped
			break
		if Input.is_action_just_pressed("interact"):
			result = living[idx]
			break
		if Input.is_action_just_pressed("cancel"):
			break
		if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_up"):
			idx = posmod(idx - 1, living.size())
		elif Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("move_down"):
			idx = posmod(idx + 1, living.size())
	target_cursor.hide()
	target_name.hide()
	target_index = -1
	target_list = []
	_target_row = -1
	_tapped = null
	_refresh_party()
	cross.show()
	return result


## Naamlabel boven het pijltje (of eronder als het niet past), binnen beeld.
func _place_target_name(tip: Vector2) -> void:
	target_name.size = Vector2.ZERO
	target_name.reset_size()
	var w := size.x if size.x > 0 else 384.0
	var ts := target_name.size
	var y := tip.y - 13.0 - ts.y
	if y < 2.0:
		y = tip.y + 2.0
	target_name.position = Vector2(clampf(roundf(tip.x - ts.x / 2.0), 2.0, w - 2.0 - ts.x), roundf(y))


func _on_enemy_pressed(c: Dictionary) -> void:
	if state == "target_enemy":
		_tapped = c


## Tik op een heldensprite of op zijn statusvak.
func _on_hero_tapped(row: int) -> void:
	if state == "target_ally":
		_tapped = heroes[row]


func _on_message_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_message_tapped = true


# ================================================================ acties uitvoeren
func _execute(a: Dictionary) -> void:
	var actor: Dictionary = a["actor"]
	if int(actor.get("skip", 0)) > 0:
		actor["skip"] = int(actor["skip"]) - 1
		var reden := str(actor.get("skip_reden", "bevriezing"))
		var zin := "%s is paralyzed and skips a turn." if reden == "verlamming" else "%s is frozen and skips a turn."
		if reden == Archief2Vijanden.SKIP_REDEN_BIND:
			zin = "%s is bound and skips a turn."
		show_message(zin % actor["name"])
		await _wait(MESSAGE_TIME)
		return
	match a["type"]:
		"attack":
			var t = _valid_target(a["target"], not actor["is_hero"])
			var getrokken = Archief2Vijanden.pulled_target(actor)   # v0.21: Wortelgeest trok hem aan
			if getrokken != null and in_battle(getrokken):
				t = getrokken
			if t == null:
				return
			var mult := 1.0
			var text := "%s attacks!" % actor["name"]
			var gekozen: Dictionary = {}
			for skill in actor["s"].get("skills", []):
				if randf() < float(skill["chance"]):
					if str(skill.get("type", "")) == "guard":   # v0.15: schild omhoog i.p.v. aanvallen
						if int(actor.get("guard", 0)) > 0:
							continue
						await _guard_up(actor, skill)
						return
					mult = float(skill["power"])
					text = "%s: %s!" % [actor["name"], skill["name"]]
					gekozen = skill
					break
			show_message(text)
			ActorSfx.play(actor, "vaardigheid" if not gekozen.is_empty() else "aanval")
			if actor["is_hero"]:
				await _hero_wind_up(actor, true)
			else:
				await _enemy_lunge(actor, t)
			var dmg := _physical_damage(actor, t, mult)
			await _damage(t, dmg)
			await _skill_effect(actor, t, gekozen, dmg)
			await _counter(t, actor)
			_hero_rest(actor)
		"spell":
			var sp: Dictionary = GameData.SPELLS[a["spell"]]
			if actor["s"]["mp"] < sp["mp"]:
				show_message("%s doesn't have enough MP!" % actor["name"])
				await _wait(MESSAGE_TIME)
				return
			actor["s"]["mp"] -= sp["mp"]
			_refresh_party()
			show_message("%s casts %s!" % [actor["name"], sp["name"]])
			ActorSfx.play(actor, "vaardigheid")
			await _hero_wind_up(actor, false)
			var stype := str(sp.get("type", "damage"))
			match sp["target"]:
				"enemy":
					var t = _valid_target(a["target"], false)
					if t != null:
						await _damage(t, Archief2.schaal_element(_spell_amount(actor, sp, t), t, str(sp.get("element", ""))))
						_apply_spell_status(t, sp)
				"all_enemies":
					var targets := _alive(enemies)
					for t in targets:
						_hit(t, Archief2.schaal_element(_spell_amount(actor, sp, t), t, str(sp.get("element", ""))))
						_apply_spell_status(t, sp)
					await _wait(0.7)
					await _report_kos(targets)
				"ally", "ko":
					if stype == "revive":
						await _revive(a["target"], _spell_amount(actor, sp, {}))
					elif stype == "buff":
						var ally := _valid_ally(a["target"])
						if not ally.is_empty():
							_apply_buffs(ally, sp, actor)
							await _wait(MESSAGE_TIME)
					elif stype == "hot":
						var ally_hot := _valid_ally(a["target"])
						if not ally_hot.is_empty():
							_add_hot(ally_hot, sp, actor)
							await _wait(MESSAGE_TIME)
					else:
						await _heal(_valid_ally(a["target"]), _spell_amount(actor, sp, {}), 0)
				"all_allies":
					for ally_all in _alive(heroes):
						if stype == "buff":
							_apply_buffs(ally_all, sp, actor)
						elif stype == "hot":
							_add_hot(ally_all, sp, actor)
						else:
							await _heal(ally_all, _spell_amount(actor, sp, {}), 0)
					if stype == "buff" or stype == "hot":
						await _wait(MESSAGE_TIME)
			_hero_rest(actor)
		"item":
			var id: String = a["item"]
			_reserved[id] = maxi(0, _reserved.get(id, 0) - 1)
			if GameState.item_count(id) <= 0:
				show_message("No %s left!" % GameData.ITEMS[id]["name"])
				await _wait(MESSAGE_TIME)
				return
			var it: Dictionary = GameData.ITEMS[id]
			if str(it.get("teach", "")) != "":
				var ally := _valid_ally(a["target"])
				var spell_id := str(it["teach"])
				if ally.is_empty() or not PartyActions.teach_spell(ally["s"], spell_id):
					show_message(PartyActions.MSG_NO_EFFECT)
					await _wait(MESSAGE_TIME)
					return
				GameState.inventory[id] -= 1
				show_message("%s uses %s!" % [actor["name"], it["name"]])
				await _hero_wind_up(actor, false)
				show_message("%s learns %s!" % [ally["name"], GameData.SPELLS[spell_id]["name"]])
				_refresh_party()
				await _wait(MESSAGE_TIME)
				_hero_rest(actor)
				return
			GameState.inventory[id] -= 1
			show_message("%s uses %s!" % [actor["name"], it["name"]])
			await _hero_wind_up(actor, false)
			if it.get("capture", false):
				await codex.capture(actor, a["target"])   # Codex: Leeg Boek
				_hero_rest(actor)
				return
			if float(it.get("revive", 0.0)) > 0.0:     # Feniksveer (Koopman)
				var dood = a["target"] if a["target"] != null and int(a["target"]["s"]["hp"]) <= 0 else null
				if dood == null:
					for h in heroes:
						if int(h["s"]["hp"]) <= 0:
							dood = h
							break
				if dood == null:
					show_message(PartyActions.MSG_NO_EFFECT)
				else:
					var back := PartyActions.revive(dood["s"], float(it["revive"]))
					show_message("%s gets back up! (%d HP)" % [dood["name"], back])
					_refresh_party()
				await _wait(MESSAGE_TIME)
				_hero_rest(actor)
				return
			if bool(it.get("cure", false)):          # Tegengif (Koopman): gif en binden weg
				var t := _valid_ally(a["target"])
				if t.has("dots"):
					t["dots"] = (t["dots"] as Array).filter(func(d): return not bool(d.get("gif", false)))
				if str(t.get("skip_reden", "")) == Archief2Vijanden.SKIP_REDEN_BIND:
					t["skip"] = 0
				show_message("%s is cured." % t["name"])
				await _wait(MESSAGE_TIME)
				_hero_rest(actor)
				return
			if bool(it.get("stun_room", false)):     # alleen in het veld: niet verbruiken
				GameState.inventory[id] = int(GameState.inventory.get(id, 0)) + 1
				show_message(PartyActions.MSG_NO_EFFECT)
				await _wait(MESSAGE_TIME)
				_hero_rest(actor)
				return
			await _heal(_valid_ally(a["target"]), int(it["heal_hp"]), int(it["heal_mp"]))
			_hero_rest(actor)
		"defend":
			show_message("%s defends." % actor["name"])
			await _wait(MESSAGE_TIME)
		"core_charge":
			await _core_resolve(a)
		"kern_skill":
			await _kern_strike(a)
		"archief2_leech":
			await _archief2_leech(actor)
		"codex_ally":
			if in_battle(actor):           # v0.19: weggewisseld in deze ronde = geen actie meer
				await codex.ally_turn(a)
		"codex_swap":
			show_message("%s opens the Codex..." % actor["name"])
			await _hero_wind_up(actor, false)
			await codex.swap_ally(a)
			_hero_rest(actor)


## Held stapt naar voren en haalt uit (aanval) of heft de staf (spreuk/item).
func _hero_wind_up(actor: Dictionary, is_attack: bool) -> void:
	var node: Control = actor["node"]
	if not actor["is_hero"] or node == null:
		await _wait(0.4)
		return
	node.step(true)
	await _wait(0.14)
	if is_attack:
		await node.play_attack()
	else:
		await node.play_cast()
		await _wait(0.12)


## v0.21 Archief 2: effect van een vaardigheid na de schade (binden, gif, heelbeet, trekken).
func _skill_effect(actor: Dictionary, t: Dictionary, skill: Dictionary, dmg: int) -> void:
	if skill.is_empty():
		return
	var zin := Archief2Vijanden.apply(actor, t, skill, dmg)
	if zin != "":
		last_skill_effect = {"type": str(skill.get("type", "")), "actor": actor["name"], "target": t["name"]}
		_refresh_party()
		show_message(zin)
		await _wait(MESSAGE_TIME)


## v0.21: de Wortelgeest-bondgenoot slaat terug na een klap (counter, tot het einde van de ronde).
func _counter(t: Dictionary, attacker: Dictionary) -> void:
	if not Archief2Vijanden.counters(t, attacker) or not in_battle(t):
		return
	t["counter"] = 0
	counters_done += 1
	show_message("%s counters!" % t["name"])
	await _damage(attacker, _physical_damage(t, attacker, Archief2Vijanden.COUNTER_POWER))


func _hero_rest(actor: Dictionary) -> void:
	if actor["is_hero"] and actor["node"] != null:
		actor["node"].rest()


## Vijand springt naar de held die hij aanvalt, en daarna terug.
func _enemy_lunge(actor: Dictionary, target: Dictionary) -> void:
	var node: Control = actor["node"]
	await _wait(0.2)
	var origin := node.position
	var to: Vector2 = target["node"].head_position() + Vector2(0, 24) if target["is_hero"] else origin
	var dir := (to - (origin + node.size * Vector2(0.5, 0.62))).normalized()
	var tw := create_tween()
	tw.tween_property(node, "position", (origin + dir * 16.0).round(), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.08)
	tw.tween_property(node, "position", origin, 0.14)
	await _wait(0.1)


## Schadeformule: ATK - DEF/2, +/- 15% geluk, verdedigen = halve schade.
## Zwakte telt alleen als het doel weak_matters heeft (Archief 2). Andere vijanden blijven gelijk.
func _physical_damage(attacker: Dictionary, target: Dictionary, mult: float) -> int:
	var base := float(attacker["s"]["atk"]) * _buff_mult(attacker, "atk") * mult - _defense_of(target) / 2.0
	var dmg := maxi(1, roundi(base * randf_range(0.85, 1.15)))
	if target["defending"]:
		dmg = maxi(1, int(dmg / 2.0))
	dmg = maxi(1, roundi(float(dmg) * Archief2.zwakte_fysiek(attacker, target)))
	return dmg


## Spreuken: power op level 1 + power_per_level per level erboven, maal het element, +/- 10%.
func _spell_amount(caster: Dictionary, spell: Dictionary, target: Dictionary) -> int:
	var lvl := int(caster["s"].get("level", 1))
	var base := SpellRules.power_at(spell, lvl) * SpellRules.factor(spell, str(caster["s"].get("id", "")), target) * _token_mult(caster)
	return maxi(1, roundi(base * randf_range(0.9, 1.1)))


func _buff_mult(c: Dictionary, stat: String) -> float:
	var m := _token_mult(c)
	for b in c.get("buffs", []):
		if typeof(b) != TYPE_DICTIONARY:
			continue
		if str(b.get("stat", "")) == stat and int(b.get("turns", 0)) > 0:
			m *= 1.0 + float(b.get("pct", 0.0))
	return m


## "H-5's Token" van de Koopman (CANON §12): +10% stats voor de helden tegen dienaren van Sapientia.
func _token_mult(c: Dictionary) -> float:
	if not bool(c.get("is_hero", false)):
		return 1.0
	return KoopmanData.token_factor(GameState.koopman_token, not GameState.practice_battle)


func _apply_buffs(ally: Dictionary, spell: Dictionary, caster: Dictionary) -> void:
	var rows: Array = spell.get("buffs", [])
	if rows.is_empty() and str(spell.get("buff_stat", "")) != "":
		var key := "buff_" + str(spell.get("buff_stat", "def"))
		ally[key] = int(ally.get(key, 0)) + int(spell.get("buff_n", 1))
	if not ally.has("buffs"):
		ally["buffs"] = []
	var mult := SpellRules.buff_factor(spell, str(caster["s"].get("id", "")))
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		(ally["buffs"] as Array).append({
			"stat": str(row.get("stat", "def")),
			"pct": float(row.get("pct", 0.0)) * mult,
			"turns": int(row.get("turns", 3)),
		})
	show_message("%s is versterkt." % ally["name"])


func _add_hot(ally: Dictionary, spell: Dictionary, caster: Dictionary) -> void:
	if not ally.has("hots"):
		ally["hots"] = []
	var turns := int(spell.get("hot_turns", 3))
	(ally["hots"] as Array).append({"amount": _spell_amount(caster, spell, {}), "turns": turns})
	show_message("%s herstelt langzaam." % ally["name"])


func _apply_spell_status(target: Dictionary, spell: Dictionary) -> void:
	if int(target["s"]["hp"]) <= 0:
		return
	var fx := SpellRules.on_hit(spell)
	if float(fx.get("dot_pct", 0.0)) > 0.0:
		if not target.has("dots"):
			target["dots"] = []
		(target["dots"] as Array).append({"pct": float(fx["dot_pct"]), "turns": int(fx.get("dot_turns", 3))})
	if int(fx.get("skip", 0)) > 0:
		target["skip"] = maxi(int(target.get("skip", 0)), int(fx["skip"]))
		target["skip_reden"] = str(fx.get("skip_reden", "bevriezing"))


func _tick_ailments(c: Dictionary) -> void:
	var dots: Array = c.get("dots", [])
	var left_dots: Array = []
	if int(c["s"]["hp"]) > 0:
		for d in dots:
			if typeof(d) != TYPE_DICTIONARY:
				continue
			var pct := float(d.get("pct", 0.0))
			var dmg := maxi(1, roundi(float(c["s"]["max_hp"]) * pct))
			c["s"]["hp"] = maxi(0, int(c["s"]["hp"]) - dmg)
			d["turns"] = int(d.get("turns", 1)) - 1
			if int(d["turns"]) > 0 and int(c["s"]["hp"]) > 0:
				left_dots.append(d)
	c["dots"] = left_dots
	var hots: Array = c.get("hots", [])
	var left_hots: Array = []
	for h in hots:
		if typeof(h) != TYPE_DICTIONARY:
			continue
		if int(c["s"]["hp"]) > 0:
			var room := int(c["s"]["max_hp"]) - int(c["s"]["hp"])
			c["s"]["hp"] += mini(int(h.get("amount", 0)), maxi(0, room))
		h["turns"] = int(h.get("turns", 1)) - 1
		if int(h["turns"]) > 0:
			left_hots.append(h)
	c["hots"] = left_hots
	var buffs: Array = c.get("buffs", [])
	var left_buffs: Array = []
	for b in buffs:
		if typeof(b) != TYPE_DICTIONARY:
			continue
		b["turns"] = int(b.get("turns", 1)) - 1
		if int(b["turns"]) > 0:
			left_buffs.append(b)
	c["buffs"] = left_buffs
	if int(c["s"]["hp"]) <= 0 and bool(c.get("is_hero", false)) and c.get("node") != null:
		c["node"].set_ko(true)


func _revive(t, amount: int) -> void:
	var ally: Dictionary = {}
	if t is Dictionary and int((t as Dictionary)["s"]["hp"]) <= 0 and in_battle(t):
		ally = t
	else:
		for h in heroes:
			if int(h["s"]["hp"]) <= 0:
				ally = h
				break
	if ally.is_empty():
		show_message("That has no effect right now.")
		await _wait(MESSAGE_TIME)
		return
	ally["s"]["hp"] = mini(maxi(1, amount), int(ally["s"]["max_hp"]))
	if ally.get("node") != null:
		ally["node"].set_ko(false)
	_refresh_party()
	show_message("%s gets back up." % ally["name"])
	await _wait(MESSAGE_TIME)


## v0.19: doet deze combatant nog mee? (een weggewisselde bondgenoot niet meer)
func in_battle(c) -> bool:
	if c == null:
		return false
	for list in [heroes, enemies]:
		for x in list:
			if x["uid"] == c["uid"]:
				return true
	return false


func _valid_target(t, target_heroes: bool):
	var pool := _alive(heroes if target_heroes else enemies)
	if pool.is_empty():
		return null
	if t != null and t["s"]["hp"] > 0 and in_battle(t):
		return t
	return pool.pick_random()   # vijanden kiezen een willekeurige held


func _valid_ally(t) -> Dictionary:
	if t != null and t["s"]["hp"] > 0 and in_battle(t):
		return t
	var pool := _alive(heroes)
	pool.sort_custom(func(a, b): return a["s"]["hp"] < b["s"]["hp"])
	return pool[0]


func _damage(t: Dictionary, amount: int) -> void:
	_hit(t, amount)
	await _wait(0.6)
	await _report_kos([t])


## Schade toepassen + effecten (knipperen, schudden, getal), zonder te wachten.
func _hit(t: Dictionary, amount: int) -> void:
	if not tutorial.is_empty() and t["is_hero"]:
		amount = mini(amount, maxi(0, int(t["s"]["hp"]) - 1))   # oefengevecht: nooit KO
	var number_color := Color("f4f4f8")   # schade: wit met donkere rand (v7)
	if t.has("core"):   # v0.14: door het pantser (x0,4, grijs) of op de open kern (x2, roze)
		number_color = CORE_HIT_COLOR if t["core"].open else ARMOR_HIT_COLOR
		amount = t["core"].scale_damage(amount)
	t["s"]["hp"] = maxi(0, int(t["s"]["hp"]) - amount)
	_popup_number(t, str(amount), number_color)
	ActorSfx.play(t, "raak")
	if t["is_hero"]:
		show_message("%s takes %d damage." % [t["name"], amount])
		var node: Control = t["node"]
		node.hurt()
		if t["s"]["hp"] <= 0:
			node.set_ko(true)
		status_boxes[t["row"]].flash(Color(1, 0.15, 0.45))
		_shake(status_boxes[t["row"]], 2.0)
		_refresh_party()
	else:
		_show_hit_frame(t["node"])
		_blink(t["node"])
		_shake(t["node"], 3.0)
	damage_shown.emit(t["name"], amount)


func _report_kos(targets: Array) -> void:
	for t in targets:
		if t["s"]["hp"] > 0 or t.get("reported_ko", false):
			continue
		t["reported_ko"] = true
		ActorSfx.play(t, "dood")
		if t["is_hero"]:
			show_message("%s is down!" % t["name"])
		else:
			GameState.mark_defeated(str(t.get("id", "")))   # bestiarium: verslagen
			if GameState.pending_boss and GameState.dungeon100_floor > 0:
				var end_id := EndgameBestiary.id_for_floor(GameState.dungeon100_floor)
				if end_id != "":
					GameState.mark_defeated(end_id)
			var tw := create_tween()
			tw.tween_property(t["node"], "modulate:a", 0.0, 0.3)
			tw.tween_callback(t["node"].hide)
			show_message("%s is defeated!" % t["name"])
		await _wait(MESSAGE_TIME)


func _heal(t: Dictionary, hp: int, mp: int) -> void:
	var s: Dictionary = t["s"]
	var real_hp := mini(hp, int(s["max_hp"]) - int(s["hp"]))
	var real_mp := mini(mp, int(s["max_mp"]) - int(s["mp"]))
	s["hp"] += real_hp
	s["mp"] += real_mp
	_refresh_party()
	t["node"].flash(Color(0.7, 1.6, 1.7))                # cyaan gloed (genezen)
	status_boxes[t["row"]].flash(UiStyle.TEAL)
	if hp > 0:
		_popup_number(t, "+%d" % real_hp, UiStyle.TEAL_HOT)
		show_message("%s recovers %d HP." % [t["name"], real_hp])
	else:
		_popup_number(t, "+%d" % real_mp, UiStyle.TEAL)
		show_message("%s recovers %d MP." % [t["name"], real_mp])
	await _wait(MESSAGE_TIME)


func _try_flee() -> bool:
	show_message("The party tries to flee...")
	await _wait(MESSAGE_TIME)
	var chance := clampf(0.5 + (_avg_agi(heroes) - _avg_agi(enemies)) * 0.04, 0.1, 0.95)
	if randf() < chance:
		show_message("Made it! You got away.")
		await _wait(MESSAGE_TIME)
		return true
	show_message("Couldn't flee!")
	await _wait(MESSAGE_TIME)
	return false


## De Genezer: eerste klap is scripted (ongeveer 30%). true = het gevecht is daar gestopt.
func _archief2_opening() -> bool:
	for e in enemies:
		if not bool(e["s"].get("archief2_open", false)):
			continue
		var pool: Array = []
		for c in heroes:
			if not bool(c.get("ally", false)) and int(c["s"]["hp"]) > 0:
				pool.append(c)
		if pool.is_empty():
			return false
		var t: Dictionary = pool[0]
		var dmg := Archief2.openingslag(int(t["s"]["max_hp"]))
		var zin := str(e["s"].get("archief2_zin", Archief2.KERN_ZIN))
		await say(zin)
		await _damage(t, dmg)
		GameState.archief2_last_open = {"schade": dmg, "max": int(t["s"]["max_hp"]), "id": str(t["s"].get("id", ""))}
		if codex.party_down():
			await _defeat()
			return true
	return false


## Daarna 8-12% van het doel, en hij herstelt hetzelfde aantal.
func _archief2_leech(actor: Dictionary) -> void:
	var pool: Array = []
	for c in _alive(heroes):
		if not bool(c.get("ally", false)):
			pool.append(c)
	if pool.is_empty():
		pool = _alive(heroes)
	if pool.is_empty():
		return
	var t: Dictionary = pool[0]
	var n := Archief2.leech_hoeveelheid(randf(), int(t["s"]["max_hp"]))
	show_message("%s corrigeert %s." % [actor["name"], t["name"]])
	await _damage(t, n)
	var voor := int(actor["s"]["hp"])
	actor["s"]["hp"] = mini(int(actor["s"]["max_hp"]), voor + n)
	GameState.archief2_last_leech = {"schade": n, "heal": n, "bij": int(actor["s"]["hp"]) - voor}
	show_message("%s herstelt %d." % [actor["name"], n])
	await _wait(MESSAGE_TIME)


func _avg_agi(list: Array) -> float:
	var living := _alive(list)
	if living.is_empty():
		return 0.0
	var total := 0.0
	for c in living:
		total += float(c["s"]["agi"])
	return total / living.size()


# ================================================================ v0.14 roze kern (Golem-baas)
## Vijanden met een kern (alleen de Golem in een baasgevecht).
func core_enemies() -> Array:
	return enemies.filter(func(e): return e.has("core"))


## Tekst voor de roze strook tijdens het kiezen ("" = geen kern open).
func _core_banner() -> String:
	for e in core_enemies():
		if e["s"]["hp"] > 0 and e["core"].open:
			return BossCore.MSG_WINDOW
	for e in enemies:   # v0.15: schild omhoog (Mech. Wachter)
		if e["s"]["hp"] > 0 and int(e.get("guard", 0)) > 0:
			return GUARD_BANNER % e["name"]
	return ""


# ================================================================ v0.15 schild omhoog
## Vijand-skill {"type": "guard", "def_mult": 2.0}: i.p.v. aanvallen DEF x def_mult, de rest van
## deze ronde en de hele volgende ronde. Getoond met een bericht, een blauwe tint en (tijdens
## het kiezen) de strook bovenin.
const GUARD_TEXT := "%s raises a shield! (DEF x2)"
const GUARD_BANNER := "%s: shield up! (DEF x2)"
const GUARD_TINT := Color(0.7, 0.88, 1.3)


func _guard_up(actor: Dictionary, skill: Dictionary) -> void:
	ActorSfx.play(actor, "vaardigheid")
	actor["guard"] = 2
	actor["guard_mult"] = float(skill.get("def_mult", 2.0))
	if actor["node"]:
		actor["node"].modulate = GUARD_TINT
	show_message(GUARD_TEXT % actor["name"])
	await _wait(MESSAGE_TIME)


func _guard_tick(c: Dictionary) -> void:
	if int(c.get("guard", 0)) <= 0:
		return
	c["guard"] = int(c["guard"]) - 1
	if c["guard"] == 0 and c["node"] and c["s"]["hp"] > 0:
		c["node"].modulate = Color.WHITE


## DEF van een doelwit, met schild omhoog (x guard_mult).
func _defense_of(t: Dictionary) -> float:
	var d := float(t["s"]["def"]) * _buff_mult(t, "def") + float(t.get("buff_def", 0))
	if int(t.get("guard", 0)) > 0:
		d *= float(t.get("guard_mult", 2.0))
	return d


## Eén keer aan het begin: uitleg in één regel.
func _core_hint() -> void:
	if not core_enemies().is_empty():
		await say(BossCore.MSG_HINT)


## Begin van een ronde: gaat de kern open, dan het bericht 'De kern gloeit roze!'.
func _core_round_start() -> void:
	for e in core_enemies():
		if e["s"]["hp"] > 0 and e["core"].start_round(round_no):
			_flash_enemy(e)
			await say(BossCore.MSG_OPEN % e["name"])


## Actie van de Golem aan het eind van de oplaad-ronde: wankelen of Hamerslag.
func _core_resolve(a: Dictionary) -> void:
	var actor: Dictionary = a["actor"]
	var core = actor["core"]
	if core.resolve() == "break":
		show_message(BossCore.MSG_BREAK % actor["name"])
		_shake(actor["node"], 4.0)
		await _wait(MESSAGE_TIME * 1.5)
	else:
		var t = _valid_target(a["target"], true)
		if t == null:
			return
		show_message(BossCore.MSG_SLAM % [actor["name"], core.slam_name])
		ActorSfx.play(actor, "vaardigheid")
		await _enemy_lunge(actor, t)
		await _damage(t, _physical_damage(actor, t, core.slam_power))
	if _alive(heroes).size() > 0:
		show_message(BossCore.MSG_CLOSE)
		await _wait(MESSAGE_TIME)


## Korte roze flits op de vijand (kern gaat open).
func _flash_enemy(e: Dictionary) -> void:
	var node: CanvasItem = e["node"]
	var tw := create_tween()
	tw.tween_property(node, "modulate", Color(1.6, 0.8, 1.5), 0.12)
	tw.tween_property(node, "modulate", Color.WHITE, 0.25)


# ================================================================ einde
## Overwinning: groot doorzichtig venster over het slagveld (zoals Lufia 2).
## Pagina 1: EXP, goud en per held hoeveel EXP er nog nodig is voor het
## volgende level. Daarna één pagina per held die een level omhoog gaat.
func _victory() -> void:
	# Vijanden die buiten _report_kos vielen (bv. door een status-tick) tellen ook als verslagen.
	for e in enemies:
		if int(e["s"]["hp"]) <= 0 and not e.get("reported_ko", false):
			e["reported_ko"] = true
			GameState.mark_defeated(str(e.get("id", "")))
	var practice := GameState.practice_battle
	var exp_total := 0
	var gold_total := 0
	var book_lines: Array = []
	var loot_page := ""
	if practice:
		var buit := KamerData.toegepaste_buit(true, 0, 0)
		exp_total = buit.x
		gold_total = buit.y
	else:
		for e in enemies:
			if e.get("captured", false):
				continue   # Codex: ingeschreven monsters geven geen EXP/goud
			exp_total += int(e["s"]["exp"])
			gold_total += int(e["s"]["gold"])
		GameState.gold += gold_total
		book_lines = grant_fixed_boss_drops()
		loot_page = _dungeon100_boss_loot()
	await _wait(0.3)
	# EXP uitdelen (alleen helden die nog staan), level-ups onthouden
	var level_pages: Array[String] = []
	if not practice:
		for h in _alive(heroes):
			if h.get("ally", false):
				continue   # Codex: de bondgenoot krijgt zijn EXP hieronder (codex.victory_exp)
			var s: Dictionary = h["s"]
			var before: Dictionary = s.duplicate()
			var msgs := GameState.give_exp(s, exp_total)
			if msgs.is_empty():
				continue
			var gains := "HP+%d" % (s["max_hp"] - before["max_hp"])
			if s["max_mp"] > before["max_mp"]:
				gains += " MP+%d" % (s["max_mp"] - before["max_mp"])
			gains += " ATK+%d DEF+%d AGI+%d" % [s["atk"] - before["atk"], s["def"] - before["def"], s["agi"] - before["agi"]]
			level_pages.append("%s\n%s" % [msgs[msgs.size() - 1], gains])
		level_pages.append_array(codex.victory_exp(exp_total))
		if loot_page != "":
			level_pages.append(loot_page)
	_refresh_party()
	caption.hide()
	if practice:
		victory_label.text = KamerData.OEFEN_KLAAR
	else:
		victory_label.text = victory_text(exp_total, gold_total, book_lines)
	# Venster precies zo hoog als de tekst, zodat de helden eronder zichtbaar blijven.
	victory_panel.offset_bottom = victory_panel.offset_top + victory_panel.get_combined_minimum_size().y
	victory_panel.show()
	await _victory_page(victory_label.text)
	for page in level_pages:
		await _victory_page(page)
	await GameState.end_battle("win")


## Vaste baasbuit ("n" in drops) van het Eerste Archief. Niet in de 100-verdiepingen-kerker
## (die heeft een eigen buit) en niet voor een gevangen of nog levend monster.
## Geeft de regels voor het overwinningsvenster (leeg = niets).
func grant_fixed_boss_drops() -> Array:
	if not GameState.pending_boss or GameState.dungeon100_floor > 0:
		return []
	var totals := {}
	var names := {}
	for e in enemies:
		if e.get("captured", false) or int(e["s"].get("hp", 0)) > 0:
			continue
		for d in GameData.fixed_drops(e["s"].get("drops", [])):
			var id := str(d["item"])
			totals[id] = int(totals.get(id, 0)) + int(d["n"])
			names[id] = str(d["name"])
	var lines: Array = []
	for id in totals:
		GameState.inventory[id] = GameState.item_count(id) + int(totals[id])
		lines.append("Got %dx %s." % [int(totals[id]), names[id]])
	return lines


## Task #4: na een baas in de dungeon van 100 verdiepingen: de gegarandeerde buit in de tas (en het
## goud erbij), de baasvlag zetten. Geeft de tekst van de buitpagina ("" = geen baasbuit).
func _dungeon100_boss_loot() -> String:
	var floor_nr: int = GameState.dungeon100_floor
	if floor_nr <= 0 or not GameState.pending_boss:
		return ""
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var loot := Dungeon100Blue.with_warp(Dungeon100Scaling.boss_loot(floor_nr, rng), floor_nr)    # eindbaas: + Warp-kristal
	GameState.gold += Dungeon100Scaling.grant_loot(loot, GameState.inventory)
	GameState.story_flags[Dungeon100Scaling.boss_flag(floor_nr)] = true
	return "Boss loot!\n" + "\n".join(Dungeon100Scaling.loot_lines(loot))


## Tekst van de eerste overwinningspagina (ook gebruikt door de autotest).
func victory_text(exp_total: int, gold_total: int, loot_lines: Array = []) -> String:
	var lines: Array[String] = ["Gained %d EXP." % exp_total, "Gained %d GOLD." % gold_total]
	for line in loot_lines:
		lines.append(str(line))
	lines.append("")
	# Kolommen over de hele vensterbreedte (zoals Lufia 2): naam links,
	# 'VOLG. LEVEL' in het midden, getal rechts uitgelijnd. Letters zijn 6 px breed.
	var width := victory_panel.size.x if victory_panel.size.x > 0 else size.x - 20.0
	var cols := maxi(30, int((width - 28.0) / 6.0) - 1)
	var col_label := int(cols * 0.36)
	for h in heroes:
		var s: Dictionary = h["s"]
		var need: int = maxi(0, GameData.exp_for_level(int(s["level"]) + 1) - int(s["exp"]))
		var left := str(s["name"]).rpad(col_label - 1) + " NEXT LEVEL"
		lines.append(left + " " + str(need).lpad(cols - left.length() - 1))
	return "\n".join(lines)


func _victory_page(text: String) -> void:
	victory_label.text = text
	_set_state("message_wait")
	_message_tapped = false
	await get_tree().process_frame      # de tik die het vorige venster sloot telt niet mee
	_message_tapped = false
	var arrow: Control = victory_panel.get_node("VictoryArrow")
	var t := 0.0
	while true:
		await get_tree().process_frame
		t += get_process_delta_time()
		arrow.visible = fmod(t, 0.8) < 0.5     # knipperend pijltje = tik of druk op A
		if Input.is_action_just_pressed("interact") or _message_tapped:
			break
	arrow.hide()
	_set_state("busy")


func _defeat() -> void:
	if GameState.pending_story_loss:
		await say("The glitch breaks. This battle is not an end.", true)
		await GameState.end_battle("lose")
		return
	if GameState.practice_battle:
		await say(KamerData.OEFEN_VERLIES, true)
		await GameState.end_battle("lose")
		return
	await say("The party is defeated...", true)
	# v0.19: wakker worden waar je deze kamer/map binnenkwam (baas: in de kamer ervoor)
	await say(GameState.defeat_text(GameState.pending_boss), true)
	await GameState.end_battle("lose")


# ================================================================ berichten & effecten
## Toon een bericht bovenin. wait_for_input = wachten tot de speler A drukt / tikt.
func say(text: String, wait_for_input := false) -> void:
	show_message(text)
	if wait_for_input:
		_set_state("message_wait")
		_message_tapped = false
		var t := 0.0
		while true:
			await get_tree().process_frame
			t += get_process_delta_time()
			message_arrow.visible = fmod(t, 0.8) < 0.5
			if Input.is_action_just_pressed("interact") or _message_tapped:
				break
		message_arrow.hide()
		_set_state("busy")
	else:
		await _wait(MESSAGE_TIME)


## Bericht in de strook bovenin (kort; vervaagt CAPTION_HOLD sec. na het laatste bericht,
## behalve terwijl de speler kiest of moet tikken).
func show_message(text: String) -> void:
	# v0.14: kern van de Golem open? Dan blijft er tijdens het kiezen een roze strook staan.
	var banner := _core_banner() if choosing() else ""
	message_label.text = banner if banner != "" else text
	message_label.modulate = CORE_HIT_COLOR if banner != "" else Color.WHITE
	_caption_left = CAPTION_HOLD
	caption.modulate.a = 1.0
	# v0.13: tijdens het kiezen geen strook bovenin (het kruis en het doel-label zeggen
	# al wie/wat er gekozen wordt); de tekst blijft in message_label staan.
	caption.visible = text != "" and (not choosing() or banner != "")
	_fit_caption()


## Kiest de speler nu (kruis, lijstje of doelwit)?
func choosing() -> bool:
	return state in ["command", "target_enemy", "target_ally"]


## Strook precies zo groot als de tekst, horizontaal gecentreerd bovenin.
func _fit_caption() -> void:
	if not caption:
		return
	var w := size.x if size.x > 0 else 384.0
	message_label.size = Vector2.ZERO
	var ts := message_label.get_combined_minimum_size()
	var cw := minf(ceilf(ts.x) + 18.0, w - 16.0)
	var ch := ceilf(ts.y) + 2.0
	caption.size = Vector2(cw, ch)
	caption.position = Vector2(roundf((w - cw) / 2.0), CAPTION_TOP)
	message_label.position = Vector2(8, 1)
	message_label.size = Vector2(cw - 16.0, ts.y)


func _process(delta: float) -> void:
	if not caption.visible or state in ["command", "target_enemy", "target_ally", "message_wait"]:
		return
	_caption_left -= delta
	if _caption_left <= 0.0:
		caption.modulate.a = clampf(1.0 + _caption_left / CAPTION_FADE, 0.0, 1.0)
		if caption.modulate.a <= 0.0:
			caption.hide()


## Tik ergens op het scherm = verder (als er op een tik gewacht wordt).
func _unhandled_input(event: InputEvent) -> void:
	if state != "message_wait":
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_message_tapped = true


## Wacht een aantal seconden (A ingedrukt houden = sneller).
## v0.11: ook sneller/langzamer met 'Gevechtstempo' in de Opties (autoload Settings).
func _wait(seconds: float) -> void:
	var t := 0.0
	var settings := get_node_or_null("/root/Settings")
	var tempo: float = settings.battle_speed() if settings else 1.0
	while t < seconds:
		# Een test (of game over) kan het gevecht weghalen terwijl deze lus nog loopt.
		if not is_inside_tree():
			return
		await get_tree().process_frame
		if not is_inside_tree():
			return
		var speed := 3.0 if Input.is_action_pressed("interact") else 1.0
		t += get_process_delta_time() * speed * tempo


func _popup_number(t: Dictionary, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03))
	label.add_theme_constant_override("outline_size", 3)
	var pos: Vector2
	if t["is_hero"]:
		pos = t["node"].head_position() + Vector2(-text.length() * 3, -13)   # boven het hoofd
	else:
		var node: Control = t["node"]
		pos = node.position + Vector2(roundf(node.size.x / 2.0) - text.length() * 3, node.size.y * 0.3)
	label.position = pos.round()
	effects.add_child(label)
	var tw := create_tween()
	tw.tween_property(label, "position:y", pos.y - 10, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(label, "modulate:a", 0.0, 0.25)
	tw.tween_callback(label.queue_free)


func _blink(node: CanvasItem) -> void:
	var tw := create_tween()
	for i in 3:
		tw.tween_callback(node.hide)
		tw.tween_interval(0.05)
		tw.tween_callback(node.show)
		tw.tween_interval(0.05)


func _shake(node: Control, strength: float) -> void:
	# v0.11: 'Schudden' uit in de Opties = niet schudden
	var settings := get_node_or_null("/root/Settings")
	if settings and not settings.shake_enabled():
		return
	var origin := node.position
	var tw := create_tween()
	for i in 4:
		var dx := strength if i % 2 == 0 else -strength
		tw.tween_property(node, "position:x", origin.x + dx, 0.03)
	tw.tween_property(node, "position:x", origin.x, 0.03)


## Statusvakken bijwerken: wie is aan de beurt, wie wordt gekozen.
func _refresh_party() -> void:
	for i in status_boxes.size():
		var box: Control = status_boxes[i]
		box.active = i == current_hero and state in ["command", "target_enemy", "target_ally"]
		box.targeted = i == _target_row
		box.queue_redraw()


func _set_state(s: String) -> void:
	state = s
	_refresh_party()
	state_changed.emit(s)


func _alive(list: Array) -> Array:
	return list.filter(func(c): return c["s"]["hp"] > 0)


# ================================================================ v0.11 oefengevecht
## Tip-venster links (boven de D-pad): eerst "Aanval", daarna "Item".
func _make_tip() -> void:
	tip_panel = Panel.new()
	tip_panel.name = "TipPanel"
	# v0.16: tutorialtekst in hetzelfde blauwe vak als de verteller (Lufia 2-stijl)
	tip_panel.add_theme_stylebox_override("panel", UiStyle.blue_box("vak", Vector4.ZERO))
	tip_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tip_panel)
	tip_label = Label.new()
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.add_theme_color_override("font_color", UiStyle.BOX_TEXT)
	tip_label.add_theme_color_override("font_shadow_color", UiStyle.BOX_SHADOW)
	tip_panel.add_child(tip_label)
	tip_panel.hide()


func tip_text(hero: Dictionary) -> String:
	var hurt := int(hero["s"]["hp"]) < int(hero["s"]["max_hp"])
	if round_no <= 1 or not hurt or _available_items().is_empty():
		tips_shown["aanval"] = true
		return "TIP: Attack, then the Moss Slime."
	tips_shown["item"] = true
	return "TIP: hurt? Item > Herb gives HP back."


func _show_tip(hero: Dictionary) -> void:
	if tip_panel == null:
		return
	tip_label.text = tip_text(hero)
	var w := 132.0
	tip_label.position = Vector2(7, 5)
	tip_label.custom_minimum_size = Vector2(w - 14, 0)
	tip_label.size = Vector2(w - 14, 0)
	# Hoogte uit het lettertype zelf (een Label met autowrap meldt bij breedte 0 per letter een regel).
	var font := tip_label.get_theme_font("font")
	var fs := tip_label.get_theme_font_size("font_size")
	var th := font.get_multiline_string_size(tip_label.text, HORIZONTAL_ALIGNMENT_LEFT, w - 14, fs,
			-1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND).y
	tip_label.size = Vector2(w - 14, th)
	var h := ceilf(th) + 10.0
	tip_panel.size = Vector2(w, h)
	tip_panel.position = Vector2(6, 22)   # linksboven, onder de strook, ver boven de D-pad
	tip_panel.show()


func _hide_tip() -> void:
	if tip_panel:
		tip_panel.hide()


# ================================================================ v0.15 kernvaardigheden
## Uit kernfragmenten (scripts/data/kern_data.gd, KERN_SKILLS). Geen MP: na gebruik laadt de
## vaardigheid "cooldown" rondes op (in c["kern_cd"][id]; telt af aan het eind van elke ronde).
const KERN_TINT := Color(1.45, 0.85, 1.9)       # v0.16: paarse flits (Kernkracht)
## v0.16 KERNKRACHT: paarse vuurbal uit de hand (scripts/kern/kern_vuurbal.gd) i.p.v. een zwaardslag.
const KernVuurbal := preload("res://scripts/kern/kern_vuurbal.gd")
const KERN_FX_SCALE := 2.0            # bal 16x16 -> 32 eenheden (gevechtsbeeld is groter dan het veld)
const KERN_FIREBALL_SPEED := 260.0    # eenheden per seconde langs de boog (~0,35-0,5 s van de hand naar de vijand)
const KERN_HAND := Vector2(30, 1)     # opgeheven rechterhand t.o.v. head_position() (held van achteren, spreuk-pose)
## De vijanden staan (van achter de held gezien) vlak boven/achter hem: een rechte lijn zou door zijn
## hoofd gaan. Daarom een boog: hoger als het doel dichtbij is, vlakker als het ver weg staat.
const KERN_ARC := Vector2(16, 52)     # min/max boog-hoogte in eenheden
## laatste vuurbal / inslag (voor de tests en screenshots)
var last_kern_fireball: Node2D
var last_kern_impact: Node2D
const KERN_HIT_TEXT := "%s: %s!"


func _kern_skills(hero: Dictionary) -> Array:
	if not hero.get("is_hero", false):
		return []
	return GameState.kern_skills_of(str(hero["s"].get("id", "")))


## Rondes tot de vaardigheid weer klaar is (0 = klaar).
func kern_charge(hero: Dictionary, id: String) -> int:
	return int(hero.get("kern_cd", {}).get(id, 0))


func kern_ready(hero: Dictionary, id: String) -> bool:
	return kern_charge(hero, id) <= 0


## Regel in het menu: "Kernkracht KERN" (klaar) of "Kernkracht (2)" (nog 2 rondes opladen).
func kern_entry_text(hero: Dictionary, id: String) -> String:
	var n := str(KernData.KERN_SKILLS[id]["name"])
	var cd := kern_charge(hero, id)
	return ("%-10s CORE" % n) if cd <= 0 else ("%-10s (%d)" % [n, cd])


## Schade van een fysieke kernvaardigheid: ATK x atk_mult - DEF x def_factor, +/- 15%,
## verdedigen = helft (zoals _physical_damage, maar met minder pantser).
func kern_damage(attacker: Dictionary, target: Dictionary, skill: Dictionary) -> int:
	var base := float(attacker["s"]["atk"]) * float(skill.get("atk_mult", 1.5)) \
			- _defense_of(target) * float(skill.get("def_factor", 0.25))
	var dmg := maxi(1, roundi(base * randf_range(0.85, 1.15)))
	if target["defending"]:
		dmg = maxi(1, int(dmg / 2.0))
	return dmg


func _kern_strike(a: Dictionary) -> void:
	var actor: Dictionary = a["actor"]
	var id: String = a["skill"]
	var skill: Dictionary = KernData.KERN_SKILLS.get(id, {})
	if skill.is_empty() or not kern_ready(actor, id):
		return
	var t = _valid_target(a["target"], false)
	if t == null:
		return
	if not actor.has("kern_cd"):
		actor["kern_cd"] = {}
	actor["kern_cd"][id] = int(skill.get("cooldown", 3))
	show_message(KERN_HIT_TEXT % [actor["name"], skill["name"]])
	ActorSfx.play(actor, "vaardigheid")
	if actor["node"]:
		var tw := create_tween()
		tw.tween_property(actor["node"], "modulate", KERN_TINT, 0.15)
		tw.tween_property(actor["node"], "modulate", Color.WHITE, 0.35)
	if str(skill.get("fx", "")) == "vuurbal":
		await _kern_fireball(actor, t)     # v0.16: hand vooruit, vuurbal, inslag
	else:
		await _hero_wind_up(actor, true)
	if t["node"]:
		var tw2 := create_tween()
		tw2.tween_property(t["node"], "modulate", KERN_TINT, 0.08)
		tw2.tween_property(t["node"], "modulate", GUARD_TINT if int(t.get("guard", 0)) > 0 else Color.WHITE, 0.3)
	await _damage(t, kern_damage(actor, t, skill))
	_hero_rest(actor)


## v0.16 Kernkracht: held stapt naar voren en steekt de hand uit (spreuk-pose, geen zwaardzwaai),
## de paarse vuurbal vliegt van de hand naar het doel, dan de inslag (niet loopen) op het doel.
func _kern_fireball(actor: Dictionary, t: Dictionary) -> void:
	await _hero_wind_up(actor, false)
	var target_node: Control = t["node"]
	if effects == null or target_node == null or actor["node"] == null:
		return
	var from: Vector2 = actor["node"].head_position() + KERN_HAND
	var to: Vector2 = target_node.position + target_node.size * Vector2(0.5, 0.35)   # zichtbare bovenkant
	var vb: Node2D = KernVuurbal.new()
	vb.scale = Vector2.ONE * KERN_FX_SCALE
	effects.add_child(vb)
	last_kern_fireball = vb
	var arc := clampf(KERN_ARC.y - from.distance_to(to) * 0.25, KERN_ARC.x, KERN_ARC.y)
	await vb.fly(from, to, KERN_FIREBALL_SPEED, arc)
	vb.queue_free()
	last_kern_impact = KernVuurbal.impact(effects, to, KERN_FX_SCALE)


func _kern_tick(c: Dictionary) -> void:
	if not c.has("kern_cd"):
		return
	for id in c["kern_cd"]:
		c["kern_cd"][id] = maxi(0, int(c["kern_cd"][id]) - 1)


## v0.21: verkleinfactor (<= 1) zodat een plaatje binnen de maximummaat valt.
## Baas ("is_boss"): BOSS_MAX_ART_W x BOSS_MAX_ART_H; anders alleen de hoogte MAX_ENEMY_ART_H.
static func art_fit(size: Vector2, is_boss: bool) -> float:
	var f := 1.0
	if is_boss:
		if size.y > BOSS_MAX_ART_H:
			f = minf(f, float(BOSS_MAX_ART_H) / size.y)
		if size.x > BOSS_MAX_ART_W:
			f = minf(f, float(BOSS_MAX_ART_W) / size.x)
	elif size.y > MAX_ENEMY_ART_H:
		f = float(MAX_ENEMY_ART_H) / size.y
	return f
