class_name Wm1DormantVideoSlot
extends RefCounted
## Vaste ids voor in-engine dialoog die later een filmpje kan krijgen (WM1, PR #393).
## Geen playback en geen paden: alleen één poort om later CutsceneVideos / story ["video", id] aan te hangen.

const MAPLETON_VESPER := "dialogue_mapleton_vesper"
const ARCHIEF2_CORRUPTED_SEREN := "dialogue_archief2_corrupted_seren"
const ATRIUM_PENDANT := "dialogue_atrium_pendant"
const ATRIUM_THREAT := "dialogue_atrium_threat"
## CS-02 (na Kustos): Sapientia leegt de Golemkern — filmpje in #393.
const CS02_GOLEM_CORE := "dialogue_cs02_golem_core"


## Eén keer per save afspelen, daarna de bestaande dialoog — nog niet geïmplementeerd.
static func before_dialogue(_scene_id: String) -> void:
	pass
