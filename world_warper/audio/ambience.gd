class_name WorldWarperAmbience
extends RefCounted
## Aanroepen voor de ambience van de World Warper.
##
## Geen audiobestanden en geen manifest-wijziging: ontbrekende cues blijven stil.
## AudioManager.play_music / play_sfx geven dan false terug en crashen niet.
## Deze klasse instantieert geen andere systemen.
##
## TODO(design): muzikale richting is een lage tech-hum, paars/sci-fi.

const MUSIC_AMBIENT := "ww_ambient"
const SFX_HUM := "ww_hum"
const SFX_WARP := "ww_warp"
const SFX_GLITCH := "ww_sapientia_glitch"


func play_hub() -> void:
	_play_music(MUSIC_AMBIENT)


func play_hum() -> void:
	_play_sfx(SFX_HUM)


func play_warp() -> void:
	_play_sfx(SFX_WARP)


func play_glitch() -> void:
	_play_sfx(SFX_GLITCH)


func _audio_manager() -> Node:
	var loop := Engine.get_main_loop()
	var tree := loop as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("AudioManager")


func _play_music(track_name: String) -> void:
	var audio := _audio_manager()
	if audio == null or not audio.has_method("play_music"):
		return
	# false (onbekende track of ontbrekend bestand) blijft stil.
	audio.call("play_music", track_name)


func _play_sfx(sound_name: String) -> void:
	var audio := _audio_manager()
	if audio == null or not audio.has_method("play_sfx"):
		return
	audio.call("play_sfx", sound_name)
