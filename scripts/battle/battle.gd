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

const UiSfx := preload("res://scripts/ui/ui_sfx.gd")
const UiTouchC := preload("res://scripts/ui/ui_touch.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const BerggrotData := preload("res://scripts/data/berggrot_data.gd")
const PartyActions := preload("res://scripts/party_actions.gd")
const KoopmanData := preload("res://scripts/data/koopman_data.gd")
const PartyLimiet := preload("res://scripts/party_limiet.gd")   # v0.22 max 4 helden + 1 monster
const ActorSfx := preload("res://scripts/data/actor_sfx.gd")
const Dungeon100Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const EndgameBestiary := preload("res://scripts/data/endgame_bestiary.gd")
const Dungeon100Blue := preload("res://scripts/data/dungeon100_blue.gd")
const KamerData := preload("res://world_warper/kamers/kamers.gd")
const SomDataB := preload("res://scripts/data/som_data.gd")   # SoM-proef: Action-modus baas-vermenigvuldiger
const COMMANDS := ["Attack", "Magic", "Item", "Defend", "Flee", "Codex"]
## v0.19 Codex-knop (index 5): submenu 'Vangen' (Leeg Boek op een vijand, met vangkans per doel)
## en 'Wissel bondgenoot' (niet-KO pagina's + 'Geen'; kost de beurt van de held). Verborgen in
## het oefengevecht en zolang de Codex 0 pagina's EN 0 Lege Boeken heeft. Regels: HANDOFF_FUSIE.md.
const CODEX_ROW_H := 16           # oude regelhoogte van de Codex-menu's (nu LIST_ROW_H; blijft voor oude verwijzingen)
const CODEX_ROWS_MAX := 5         # wissel-lijst: zoveel regels tegelijk, daarna ▲/▼
## Magie- en Item-lijst: tikmaat (25 eenheden = ~48 dp), met venster + ▲/▼ als er meer dan LIST_ROWS_MAX zijn.
const LIST_ROW_H := 25
const LIST_ROW_MIN := 16          # kleiner dan dit wordt een lijst nooit; liever over een held heen dan onbruikbaar klein
const LIST_ROWS_MAX := 5
const LIST_CHROME := 13.0         # marges van het lijstje (boven + onder) plus 1 eenheid lucht
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
const DamageCalc := preload("res://scripts/battle/damage_calc.gd")   # schadeformules (static)
const BossCoreView := preload("res://scripts/battle/boss_core_view.gd")
const CodexBattle := preload("res://scripts/battle/codex_battle.gd")   # Codex: vangen + bondgenoot
const BattleLayoutScript := preload("res://scripts/battle/battle_layout.gd")
const BattleCommandsScript := preload("res://scripts/battle/battle_commands.gd")
const BattleRulesScript := preload("res://scripts/battle/battle_rules.gd")
const BattleTipsScript := preload("res://scripts/battle/battle_tips.gd")
const BattleKernScript := preload("res://scripts/battle/battle_kern.gd")
const BattleStatusScript := preload("res://scripts/battle/battle_status.gd")
const BattleBossScript := preload("res://scripts/battle/battle_boss.gd")
const BattleRewardsScript := preload("res://scripts/battle/battle_rewards.gd")
## schadegetal op de open kern (roze) en op het pantser (grijs)
const CORE_HIT_COLOR := Color("ff8ad8")
const ARMOR_HIT_COLOR := Color("b5a78d")
const SUBMENU_TOP := 14.0         # lijstje rechtsboven (het titeltabje valt er net boven); de bericht-strook is dan weg
const CROSS_MARGIN := 4.0         # ruimte tot de rechterrand
const BOX_GAP := 3.0
## v0.22 ruimte tussen het zijspeler-label van het monster en de B-knop
const SIDE_GAP := 3.0
## Hoeveel art-pixels per scherm-eenheid (2 = "16-bit plus", 768x432).
const DETAIL := 2

## Toestand van het gevecht (docs/STATE_MACHINES.md §2). Strings, zodat tests en logs ze direct lezen:
##   intro -> command <-> target_enemy / target_ally ; command -> busy <-> message_wait
## Alleen via _set_state() zetten; nieuwe toestand = constante erbij + in STATES (de suite
## --statemachinetest controleert dat elke toestand die dit bestand zet een bekende is).
const ST_INTRO := "intro"                 ## vóór de eerste ronde
const ST_COMMAND := "command"             ## kruis/lijstje open: de speler kiest een commando
const ST_TARGET_ENEMY := "target_enemy"   ## pijltje op een vijand
const ST_TARGET_ALLY := "target_ally"     ## pijltje op een held
const ST_BUSY := "busy"                   ## acties spelen af, geen invoer
const ST_MESSAGE_WAIT := "message_wait"   ## wacht op A/tik bij een bericht of de winstpagina
const STATES: Array[String] = [ST_INTRO, ST_COMMAND, ST_TARGET_ENEMY, ST_TARGET_ALLY, ST_BUSY, ST_MESSAGE_WAIT]
## Toestanden waarin de speler iets kiest (zie choosing()).
const CHOOSING_STATES: Array[String] = [ST_COMMAND, ST_TARGET_ENEMY, ST_TARGET_ALLY]
var state := ST_INTRO
## Vorige toestand (debug/tests): wat er vóór de laatste _set_state stond.
var prev_state := ""
var current_hero := -1
var _hero_top_y := 0.0           # bovenkant van het heldenblok (voor de hoogte van de lijstjes)
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
var stun_boss_immune := SpellRules.STUN_BOSS_IMMUNE   # simulator kan dit per gevecht omzetten
var stun_chance := -1.0                               # < 0 = SpellRules.STUN_CHANCE (simulator: vergelijking)
## v0.21 (tests): laatste effect van een vaardigheid en aantal counters in dit gevecht
var last_skill_effect: Dictionary = {}
var counters_done := 0
## Alleen voor tests: >= 0 forceert de eerstvolgende vluchtworp (0.0 = succes).
var flee_roll_override := -1.0
## Welke tips er getoond zijn (voor de autotest): "aanval", "item"
var tips_shown := {}
var hero_nodes: Array = []    # battle_hero.gd per held
var status_boxes: Array = []  # hero_status_box.gd per held
var codex: CodexBattle            # Codex (scripts/battle/codex_battle.gd)
## v0.22 Beurtvolgorde van de laatste ronde (alleen de actieve combatanten: max 4 helden + 1 monster).
var last_plan: Array = []
var _previous_scale_size := Vector2i.ZERO
## push_music in _ready, pop in _exit_tree. Alleen poppen als we zelf gepusht hebben.
var _battle_music_pushed := false
## T27: s25_check — `enabled` één keer in _ready, niet elke frame in _process.
var _pp_on := false
var _pp_lbl := ""


func _ready() -> void:
	_layout_h = BattleLayoutScript.new(self)
	# T27: s25_check RISK — gevecht-enter (battle_gras/woud/archief/baas_golem/kas)
	_pp_on = PerfProbe.enabled
	if _pp_on:
		_pp_lbl = PerfProbe.battle_label(GameState.pending_backdrop_id, GameState.pending_boss, GameState.pending_enemies)
		PerfProbe.begin(_pp_lbl)
	tutorial = GameState.pending_tutorial.duplicate(true)
	if touch and "stick_low" in touch:
		touch.stick_low = true      # Action-HUD overal: joystick linksonder, kruis past naast de helden
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
		if row >= PartyLimiet.MAX_HELDEN:
			break                                  # v0.22: de rest staat in de reserve
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
	_make_boss_bar()
	_refresh_party()
	_layout()
	resized.connect(_layout)
	_start_battle_music()
	_run.call_deferred()
	if _pp_on:
		PerfProbe.end(_pp_lbl)


## Demo-fix 3: zichtbare HP-balk voor de baas (eerste vijand met een kern / in een baasgevecht).
var boss_bar: Control = null
var _layout_h: RefCounted
var _cmds_h: RefCounted
var _tips_h: RefCounted
var _kern_h: RefCounted
var _status_h: RefCounted
var _boss_h: RefCounted
var _rewards_h: RefCounted


func _rewards():
	if _rewards_h == null:
		_rewards_h = BattleRewardsScript.new(self)
	return _rewards_h


func _boss():
	if _boss_h == null:
		_boss_h = BattleBossScript.new(self)
	return _boss_h


func _kern():
	if _kern_h == null:
		_kern_h = BattleKernScript.new(self)
	return _kern_h


func _status():
	if _status_h == null:
		_status_h = BattleStatusScript.new(self)
	return _status_h


func _tips():
	if _tips_h == null:
		_tips_h = BattleTipsScript.new(self)
	return _tips_h


func _cmds():
	if _cmds_h == null:
		_cmds_h = BattleCommandsScript.new(self)
	return _cmds_h


# ================================================================ scherm/layout (battle_layout.gd)
func _make_boss_bar() -> void:
	_layout_h.make_boss_bar()


func _place_boss_bar(w: float) -> void:
	_layout_h.place_boss_bar(w)


## Het venster rendert tijdens het gevecht 2x zo veel pixels; zie battle_layout.enter_detail_mode().
func _enter_detail_mode() -> void:
	_layout_h.enter_detail_mode()


func _apply_hd_ui() -> void:
	_layout_h.apply_hd_ui()


func _make_cross() -> void:
	_layout_h.make_cross()


func _list_row_h(n: int) -> int:
	return _layout_h.list_row_h(n)


func _safe() -> Vector4:
	return _layout_h.safe()


func _fit_to_screen() -> void:
	_layout_h.fit_to_screen()


func _exit_tree() -> void:
	if _battle_music_pushed:
		_battle_music_pushed = false
		AudioManager.pop_music(0.35)
	if _layout_h:
		_layout_h.leave_detail_mode()


## Alleen de baas van Archief 2 (De Genezer) heeft een eigen track; de rest blijft zoals het was.
static func battle_music_for(enemies: Array, boss: bool) -> String:
	return BattleRulesScript.battle_music_for(enemies, boss)


func _start_battle_music() -> void:
	var track := battle_music_for(GameState.pending_enemies, GameState.pending_boss)
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
			# Bazen zijn altijd turn-based, ook in Action (21 okt 2026): GEEN Action-baasvermenigvuldiger meer.
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


func _add_enemy_idle(node: TextureButton, data: Dictionary) -> void:
	_layout_h.add_enemy_idle(node, data)


func _add_enemy_under(node: TextureButton, data: Dictionary) -> void:
	_layout_h.add_enemy_under(node, data)


func _show_hit_frame(node: Control) -> void:
	await _layout_h.show_hit_frame(node)


static func sprite_top(path: String, tex: Texture2D) -> float:
	return BattleLayoutScript.sprite_top(path, tex)


func _layout() -> void:
	_layout_h.layout()


func _place_cross(w: float, h: float) -> void:
	_layout_h.place_cross(w, h)


func _box_left_for_cross(left: float, right: float, count: int) -> float:
	return _layout_h.box_left_for_cross(left, right, count)


func enemy_region(w: float) -> Array:
	return _layout_h.enemy_region(w)


func _place_menu(i: int, _animate: bool) -> void:
	_layout_h.place_menu(i, _animate)


func _layout_enemies(w: float, dx: float) -> void:
	_layout_h.layout_enemies(w, dx)


func stage_x(w: float, h: float) -> float:
	return _layout_h.stage_x(w, h)


func enemy_feet(node: Control) -> Vector2:
	return _layout_h.enemy_feet(node)


func _sort_by_feet(layer: Control) -> void:
	_layout_h.sort_by_feet(layer)


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
		_set_state(ST_BUSY)
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
		SessieLog.ronde(round_no, plan)
		last_plan = plan.duplicate()   # v0.22: beurtvolgorde van deze ronde (partytest)
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
		# #8 (EDGECASES_ITEMS_STATUS): KO door gif/brand melden zoals elke andere KO (bericht, geluid, fade).
		await _report_kos(heroes + enemies)
		if _alive(enemies).is_empty():
			await _victory()
			return
		if codex.party_down():
			await _defeat()
			return
		_reserved.clear()


# ================================================================ commando's kiezen (battle_commands.gd)
func _choose_commands() -> Array:
	var actions: Array = []
	actions.resize(heroes.size())
	_reserved.clear()
	var cmds: RefCounted = _cmds()
	var i: int = cmds.next_alive_hero(-1)
	while i < heroes.size():
		cmds.set_active_hero(i)
		var act = await cmds.choose_for_hero(heroes[i], cmds.prev_alive_hero(i) != -1)
		if act == null:
			var prev: int = cmds.prev_alive_hero(i)
			if prev != -1:
				cmds.unreserve(actions[prev])
				actions[prev] = null
				i = prev
			continue
		if act["type"] == "flee":
			for a in actions:
				cmds.unreserve(a)
			cmds.set_active_hero(-1)
			return [act]
		actions[i] = act
		i = cmds.next_alive_hero(i)
	cmds.set_active_hero(-1)
	return actions.filter(func(a): return a != null)


func _set_active_hero(i: int) -> void:
	_cmds().set_active_hero(i)


func _choose_for_hero(hero: Dictionary, can_go_back: bool):
	return await _cmds().choose_for_hero(hero, can_go_back)


func has_usable_magic(hero: Dictionary) -> bool:
	return _cmds().has_usable_magic(hero)


func show_notice(text: String) -> void:
	_cmds().show_notice(text)


func codex_command_shown() -> bool:
	return _cmds().codex_command_shown()


func _choose_codex(hero: Dictionary):
	return await _cmds().choose_codex(hero)


func _choose_swap(hero: Dictionary):
	return await _cmds().choose_swap(hero)


func _choose_spell(hero: Dictionary):
	return await _cmds().choose_spell(hero)


func _choose_item(hero: Dictionary):
	return await _cmds().choose_item(hero)


func _available_items() -> Array:
	return _cmds().available_items()


## Heeft dit item een effect in het gevecht? (genezen, revive, tegengif, vangen, spreuk leren)
## Lore-voorwerpen (Faded Note), sleutels en veld-items (Stun Bomb, Warp) dus niet (#1/#12).
static func battle_usable(it: Dictionary) -> bool:
	return BattleRulesScript.battle_usable(it)


## Zou een genees-item (heal_hp/heal_mp) dit doel helpen? Zelfde regel als het veld (#2).
static func heal_would_help(t: Dictionary, it: Dictionary) -> bool:
	return BattleRulesScript.heal_would_help(t, it)


func _items_left(id: String) -> int:
	return _cmds().items_left(id)


func _unreserve(action) -> void:
	_cmds().unreserve(action)


func _next_alive_hero(from: int) -> int:
	return _cmds().next_alive_hero(from)


func _prev_alive_hero(from: int) -> int:
	return _cmds().prev_alive_hero(from)


func _select_enemy(label := Callable(), prefix := ""):
	return await _cmds().select_enemy(label, prefix)


func _select_ally():
	return await _cmds().select_ally()


func _select_ko():
	return await _cmds().select_ko()


# ================================================================ doel kiezen (_pick_target blijft hier: ux_tests / UiSfx.TARGET)


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
			UiSfx.play(UiSfx.TARGET)
			break
		if Input.is_action_just_pressed("interact"):
			result = living[idx]
			UiSfx.play(UiSfx.TARGET)
			break
		if Input.is_action_just_pressed("cancel"):
			UiSfx.play(UiSfx.CANCEL)
			break
		if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_up"):
			idx = posmod(idx - 1, living.size())
			UiSfx.play(UiSfx.CURSOR)
		elif Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("move_down"):
			idx = posmod(idx + 1, living.size())
			UiSfx.play(UiSfx.CURSOR)
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
	if state == ST_TARGET_ENEMY:
		_tapped = c


## Tik op een heldensprite of op zijn statusvak.
func _on_hero_tapped(row: int) -> void:
	if state == ST_TARGET_ALLY:
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
		if int(actor.get("skip", 0)) <= 0:
			actor.erase("stun_immune")
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
			# #7: revive-spreuk zonder KO-doel kost geen MP (zelfde regel als de Feniksveer, H3)
			if str(sp.get("type", "")) == "revive" and _ko_target(a["target"]).is_empty():
				show_message(PartyActions.MSG_NO_EFFECT)
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
			if not battle_usable(it):              # #1/#12: geen gevechtseffect = nooit verbruiken
				show_message(PartyActions.MSG_NO_EFFECT)
				await _wait(MESSAGE_TIME)
				return
			if str(it.get("teach", "")) != "":
				var ally := _valid_ally(a["target"])
				var spell_id := str(it["teach"])
				if ally.is_empty() or not PartyActions.teach_spell(ally["s"], spell_id):
					show_message(PartyActions.MSG_NO_EFFECT)
					await _wait(MESSAGE_TIME)
					return
				GameState.remove_item(id, 1)
				show_message("%s uses %s!" % [actor["name"], it["name"]])
				await _hero_wind_up(actor, false)
				show_message("%s learns %s!" % [ally["name"], GameData.SPELLS[spell_id]["name"]])
				_refresh_party()
				await _wait(MESSAGE_TIME)
				_hero_rest(actor)
				return
			# H3: eerst bepalen of het item effect heeft; pas dan afschrijven
			var dood: Dictionary = {}
			if float(it.get("revive", 0.0)) > 0.0:
				dood = _ko_target(a["target"])
			var cure_t: Dictionary = {}
			if bool(it.get("cure", false)):
				cure_t = _valid_ally(a["target"])
			# #2: genees-item pas verbruiken als het doel (bij uitvoeren) HP/MP tekort komt
			var heal_t: Dictionary = {}
			var is_heal := float(it.get("revive", 0.0)) <= 0.0 and not bool(it.get("cure", false)) \
					and not bool(it.get("capture", false))
			if is_heal:
				heal_t = _valid_ally(a["target"])
			if (float(it.get("revive", 0.0)) > 0.0 and dood.is_empty()) \
					or (bool(it.get("cure", false)) and not _has_curable(cure_t)) \
					or (is_heal and not heal_would_help(heal_t, it)):
				show_message(PartyActions.MSG_NO_EFFECT)
				await _wait(MESSAGE_TIME)
				return
			GameState.remove_item(id, 1)
			show_message("%s uses %s!" % [actor["name"], it["name"]])
			await _hero_wind_up(actor, false)
			if it.get("capture", false):
				await codex.capture(actor, a["target"])   # Codex: Leeg Boek
				_hero_rest(actor)
				return
			if not dood.is_empty():                  # Feniksveer (Koopman)
				var back := PartyActions.revive(dood["s"], float(it["revive"]))
				_revive_combatant(dood, back)
				show_message("%s gets back up! (%d HP)" % [dood["name"], back])
				await _wait(MESSAGE_TIME)
				_hero_rest(actor)
				return
			if not cure_t.is_empty():                # Tegengif (Koopman): gif en binden weg
				var t := cure_t
				if t.has("dots"):
					t["dots"] = (t["dots"] as Array).filter(func(d): return not bool(d.get("gif", false)))
				if str(t.get("skip_reden", "")) == Archief2Vijanden.SKIP_REDEN_BIND:
					t["skip"] = 0
				show_message("%s is cured." % t["name"])
				await _wait(MESSAGE_TIME)
				_hero_rest(actor)
				return
			await _heal(heal_t, int(it["heal_hp"]), int(it["heal_mp"]))
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


## Schadeberekening staat in DamageCalc (scripts/battle/damage_calc.gd); dit zijn dunne wrappers
## met de oude namen, zodat aanroepers (tests, tools/battlesim) ongewijzigd blijven.
func _physical_damage(attacker: Dictionary, target: Dictionary, mult: float) -> int:
	return DamageCalc.physical_damage(attacker, target, mult)


func _spell_amount(caster: Dictionary, spell: Dictionary, target: Dictionary) -> int:
	return DamageCalc.spell_amount(caster, spell, target)


## Basis zonder geluk en zonder randf(): de simulator-AI schat er schade mee.
func physical_base(attacker: Dictionary, target: Dictionary, mult: float) -> float:
	return DamageCalc.physical_base(attacker, target, mult)


func spell_base(caster: Dictionary, spell: Dictionary, target: Dictionary) -> float:
	return DamageCalc.spell_base(caster, spell, target)


func _buff_mult(c: Dictionary, stat: String) -> float:
	return DamageCalc.buff_mult(c, stat)


func _token_mult(c: Dictionary) -> float:
	return DamageCalc.token_mult(c)


func _apply_buffs(ally: Dictionary, spell: Dictionary, caster: Dictionary) -> void:
	_status().apply_buffs(ally, spell, caster)


func _add_hot(ally: Dictionary, spell: Dictionary, caster: Dictionary) -> void:
	_status().add_hot(ally, spell, caster)


func _apply_spell_status(target: Dictionary, spell: Dictionary) -> void:
	_status().apply_spell_status(target, spell)


## Telt als baas voor verlamming/bevriezing: een vijand in een baasgevecht of met "is_boss".
func is_boss_target(t: Dictionary) -> bool:
	return BattleRulesScript.is_boss_target(t)


func _tick_ailments(c: Dictionary) -> void:
	_status().tick_ailments(c)


func _revive(t, amount: int) -> void:
	var ally := _ko_target(t)
	if ally.is_empty():
		show_message("That has no effect right now.")
		await _wait(MESSAGE_TIME)
		return
	_revive_combatant(ally, amount)
	show_message("%s gets back up." % ally["name"])
	await _wait(MESSAGE_TIME)


## Wie staat er op? Het gekozen doel als dat KO is en nog meedoet, anders de eerste KO-held.
## Leeg = niemand is KO. Gedeeld door de revive-spreuk en de Feniksveer.
func _ko_target(t) -> Dictionary:
	if t is Dictionary and int((t as Dictionary)["s"]["hp"]) <= 0 and in_battle(t):
		return t
	for h in heroes:
		if int(h["s"]["hp"]) <= 0:
			return h
	return {}


## Gedeelde revive (spreuk + item): HP terug, KO-pose weg (H1) en reported_ko gewist,
## zodat een volgende KO weer gemeld wordt (H2).
func _revive_combatant(c: Dictionary, hp: int) -> void:
	c["s"]["hp"] = mini(maxi(1, hp), int(c["s"]["max_hp"]))
	c.erase("reported_ko")
	clear_ko_status(c)
	if c.get("node") != null:
		c["node"].set_ko(false)
	_refresh_party()


## #3/#4/#17: wie opstaat begint schoon. Binden/bevriezing (skip), gif/brand, HoT en buffs van
## voor de KO vervallen, ongeacht in welke ronde de revive valt.
static func clear_ko_status(c: Dictionary) -> void:
	BattleRulesScript.clear_ko_status(c)


## Tegengif: valt er iets te genezen (gif-DoT of gebonden door een Rankje)?
func _has_curable(t: Dictionary) -> bool:
	return BattleRulesScript.has_curable(t)


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
	var roll := flee_roll_override if flee_roll_override >= 0.0 else randf()
	flee_roll_override = -1.0
	if roll < chance:
		show_message("Made it! You got away.")
		await _wait(MESSAGE_TIME)
		return true
	show_message("Couldn't flee!")
	await _wait(MESSAGE_TIME)
	return false


func _avg_agi(list: Array) -> float:
	return BattleRulesScript.avg_agi(_alive(list))


# ================================================================ v0.14 roze kern / Archief 2 (battle_boss.gd)
## De Genezer: eerste klap is scripted (ongeveer 30%). true = het gevecht is daar gestopt.
func _archief2_opening() -> bool:
	return await _boss().archief2_opening()


## Daarna 8-12% van het doel, en hij herstelt hetzelfde aantal.
func _archief2_leech(actor: Dictionary) -> void:
	await _boss().archief2_leech(actor)


## Vijanden met een kern (alleen de Golem in een baasgevecht).
func core_enemies() -> Array:
	return _boss().core_enemies()


## Tekst voor de roze strook tijdens het kiezen ("" = geen kern open).
func _core_banner() -> String:
	return _boss().core_banner()


# ================================================================ v0.15 schild omhoog
## Vijand-skill {"type": "guard", "def_mult": 2.0}: i.p.v. aanvallen DEF x def_mult, de rest van
## deze ronde en de hele volgende ronde. Getoond met een bericht, een blauwe tint en (tijdens
## het kiezen) de strook bovenin.
const GUARD_TEXT := "%s raises a shield! (DEF x2)"
const GUARD_BANNER := "%s: shield up! (DEF x2)"
const GUARD_TINT := Color(0.7, 0.88, 1.3)


func _guard_up(actor: Dictionary, skill: Dictionary) -> void:
	await _boss().guard_up(actor, skill)


func _guard_tick(c: Dictionary) -> void:
	_boss().guard_tick(c)


## DEF van een doelwit, met schild omhoog (x guard_mult).
func _defense_of(t: Dictionary) -> float:
	return _boss().defense_of(t)


## Eén keer aan het begin: uitleg in één regel.
func _core_hint() -> void:
	await _boss().core_hint()


## Begin van een ronde: gaat de kern open, dan het bericht 'De kern gloeit roze!'.
func _core_round_start() -> void:
	await _boss().core_round_start()


## Actie van de Golem aan het eind van de oplaad-ronde: wankelen of Hamerslag.
func _core_resolve(a: Dictionary) -> void:
	await _boss().core_resolve(a)


## Korte roze flits op de vijand (kern gaat open).
func _flash_enemy(e: Dictionary) -> void:
	var node: CanvasItem = e["node"]
	var tw: Tween = create_tween()
	tw.tween_property(node, "modulate", Color(1.6, 0.8, 1.5), 0.12)
	tw.tween_property(node, "modulate", Color.WHITE, 0.25)


# ================================================================ einde
func _victory() -> void:
	await _rewards().victory()


func grant_fixed_boss_drops() -> Array:
	return _rewards().grant_fixed_boss_drops()


func _dungeon100_boss_loot() -> String:
	return _rewards().dungeon100_boss_loot()


## Tekst van de eerste overwinningspagina (ook gebruikt door de autotest).
func victory_text(exp_total: int, gold_total: int, loot_lines: Array = []) -> String:
	# Kolommen over de hele vensterbreedte (zoals Lufia 2): naam links,
	# 'VOLG. LEVEL' in het midden, getal rechts uitgelijnd. Letters zijn 6 px breed.
	var width := victory_panel.size.x if victory_panel.size.x > 0 else size.x - 20.0
	return BattleRulesScript.victory_text(exp_total, gold_total, loot_lines, heroes, width)


func _victory_page(text: String) -> void:
	await _rewards().victory_page(text)


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
		_set_state(ST_MESSAGE_WAIT)
		_message_tapped = false
		var t := 0.0
		while true:
			await get_tree().process_frame
			t += get_process_delta_time()
			message_arrow.visible = fmod(t, 0.8) < 0.5
			if Input.is_action_just_pressed("interact") or _message_tapped:
				break
		message_arrow.hide()
		_set_state(ST_BUSY)
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
	return state in CHOOSING_STATES


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
	# T27: s25_check RISK — gevecht-frame; `_pp_on` uit _ready, geen PerfProbe.enabled per frame
	if _pp_on:
		PerfProbe.begin(_pp_lbl)
	if not caption.visible or choosing() or state == ST_MESSAGE_WAIT:
		if _pp_on:
			PerfProbe.end(_pp_lbl)
		return
	_caption_left -= delta
	if _caption_left <= 0.0:
		caption.modulate.a = clampf(1.0 + _caption_left / CAPTION_FADE, 0.0, 1.0)
		if caption.modulate.a <= 0.0:
			caption.hide()
	if _pp_on:
		PerfProbe.end(_pp_lbl)


## Tik ergens op het scherm = verder (als er op een tik gewacht wordt).
func _unhandled_input(event: InputEvent) -> void:
	if state != ST_MESSAGE_WAIT:
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
		box.active = i == current_hero and choosing()
		box.targeted = i == _target_row
		box.queue_redraw()


func _set_state(s: String) -> void:
	if not (s in STATES):
		push_error("battle: onbekende toestand '%s' (zie STATES)" % s)
	prev_state = state
	state = s
	_refresh_party()
	state_changed.emit(s)


func _alive(list: Array) -> Array:
	return list.filter(func(c): return c["s"]["hp"] > 0)


# ================================================================ v0.11 oefengevecht (battle_tips.gd)
func _make_tip() -> void:
	_tips().make_tip()


func tip_text(hero: Dictionary) -> String:
	return _tips().tip_text(hero)


func _show_tip(hero: Dictionary) -> void:
	_tips().show_tip(hero)


func tip_origin() -> Vector2:
	return _tips().tip_origin()


func _hide_tip() -> void:
	_tips().hide_tip()


# ================================================================ v0.15 kernvaardigheden (battle_kern.gd)
## Uit kernfragmenten (scripts/data/kern_data.gd, KERN_SKILLS). Geen MP: na gebruik laadt de
## vaardigheid "cooldown" rondes op (in c["kern_cd"][id]; telt af aan het eind van elke ronde).
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


func _kern_skills(hero: Dictionary) -> Array:
	return _kern().kern_skills(hero)


## Rondes tot de vaardigheid weer klaar is (0 = klaar).
func kern_charge(hero: Dictionary, id: String) -> int:
	return _kern().kern_charge(hero, id)


func kern_ready(hero: Dictionary, id: String) -> bool:
	return _kern().kern_ready(hero, id)


## Regel in het menu: "Kernkracht KERN" (klaar) of "Kernkracht (2)" (nog 2 rondes opladen).
func kern_entry_text(hero: Dictionary, id: String) -> String:
	return _kern().kern_entry_text(hero, id)


## Schade van een fysieke kernvaardigheid: ATK x atk_mult - DEF x def_factor, +/- 15%,
## verdedigen = helft (zoals _physical_damage, maar met minder pantser).
func kern_damage(attacker: Dictionary, target: Dictionary, skill: Dictionary) -> int:
	return DamageCalc.kern_damage(attacker, target, skill)


func kern_base(attacker: Dictionary, target: Dictionary, skill: Dictionary) -> float:
	return DamageCalc.kern_base(attacker, target, skill)


func _kern_strike(a: Dictionary) -> void:
	await _kern().kern_strike(a)


func _kern_tick(c: Dictionary) -> void:
	_kern().kern_tick(c)


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


## v0.21: verkleinfactor (<= 1) zodat een plaatje binnen de maximummaat valt.
## Baas ("is_boss"): BOSS_MAX_ART_W x BOSS_MAX_ART_H; anders alleen de hoogte MAX_ENEMY_ART_H.
static func art_fit(size: Vector2, is_boss: bool) -> float:
	return BattleLayoutScript.art_fit(size, is_boss, MAX_ENEMY_ART_H, BOSS_MAX_ART_W, BOSS_MAX_ART_H)
