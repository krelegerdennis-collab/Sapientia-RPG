class_name Wm1DormantVideoSlot
extends RefCounted
## Vaste ids voor in-engine dialoog die later een filmpje kan krijgen (WM1, PR #393).
## MAPLETON_VESPER = CS-09; overige ids zijn nog dormant.

const MAPLETON_VESPER := "dialogue_mapleton_vesper"
const ARCHIEF2_CORRUPTED_SEREN := "dialogue_archief2_corrupted_seren"
const ATRIUM_PENDANT := "dialogue_atrium_pendant"
const ATRIUM_THREAT := "dialogue_atrium_threat"
## CS-02 (na Kustos): Sapientia leegt de Golemkern — filmpje in #393.
const CS02_GOLEM_CORE := "dialogue_cs02_golem_core"


const Videos := preload("res://scripts/data/cutscene_videos.gd")


## Eén keer per save: filmpje vóór in-engine dialoog; poort en ontbrekend bestand = meteen verder.
static func before_dialogue(scene_id: String, host: Node = null) -> void:
	match scene_id:
		MAPLETON_VESPER:
			if host == null:
				host = Story._map()
			if host == null:
				host = Story
			if Videos.will_play("cs09"):
				await Videos.play_await("cs09", host, {"map": host})
		_:
			pass
