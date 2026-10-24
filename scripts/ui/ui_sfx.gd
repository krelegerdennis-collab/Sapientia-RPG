extends RefCounted
## UX-polish (fase 6): één plek voor de geluiden van UI-acties. Alles loopt via de autoload
## AudioManager (assets/audio/audio_manifest.json). Zonder AudioManager of zonder bestand blijft
## het stil, zonder error. Knoppen (BaseButton) klikken vanzelf (AudioManager.ui_press_sounds);
## dit bestand is voor acties zonder knop: menu open/dicht, doorklikken, opslaan, uitrusten, ...

const CLICK := "menu_click"
const CURSOR := "menu_hover"
const CONFIRM := "menu_confirm"
const CANCEL := "menu_cancel"
const ERROR := "menu_error"
const OPEN := "menu_open"
const CLOSE := "menu_close"
const TAB := "tab_switch"
const ADVANCE := "dialogue_advance"
const BLIP := "dialogue_blip"
const SAVE := "save_game"
const LOAD := "load_game"
const EQUIP := "item_equip"
const UNEQUIP := "item_unequip"
const USE_ITEM := "item_use_potion"
const COINS := "gold_coins"
const COMMAND := "command_select"
const TARGET := "target_select"

## Alle cues die dit spel zelf afspeelt (de test controleert dat ze in het manifest staan).
const ALL := [CLICK, CURSOR, CONFIRM, CANCEL, ERROR, OPEN, CLOSE, TAB, ADVANCE, BLIP, SAVE, LOAD,
		EQUIP, UNEQUIP, USE_ITEM, COINS, COMMAND, TARGET]


static func play(cue: String) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var audio := tree.root.get_node_or_null("AudioManager")
	if audio == null or not audio.has_method("play_sfx") or not audio.has_sfx(cue):
		return false
	return bool(audio.play_sfx(cue))


## Geef een knop een eigen cue (i.p.v. de gewone klik), bv. CANCEL voor 'Back'.
static func tag(button: BaseButton, cue: String) -> void:
	button.set_meta("ui_sound", cue)
