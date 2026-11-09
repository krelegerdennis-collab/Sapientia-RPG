extends RefCounted
## Molen van Gerrit in Wilgendal, na Het Zingende Graan.
## Eén bezoek: rusten, één Zingend Meel, daarna opslaan of de party wisselen.
## Zingend Meel per bezoek: vlag `molen_meel_bezoek` in story_flags (C-7: geen scene-meta meer).
## Save -> laden behoudt de vlag, dus geen tweede meel in hetzelfde bezoek.
## map.gd wist de vlag bij elke binnenkomst die geen laden is (nieuw bezoek).

const UiSfx := preload("res://scripts/ui/ui_sfx.gd")
const FLAG_MEEL := "molen_meel_bezoek"
const REGEL_RUST := "HP and MP restored."
const REGEL_MEEL := "You receive Singing Flour."
const REGEL_ZANG := "The mill turns again."
const REGEL_GEZANG := "Soft singing."
const SFX_ZANG := "molen_zang"
const VRAAG := "What would you like?"
const KEUZES := ["Save", "Switch party", "Done"]
const VRAAG_SAVE := "Save your progress?"
const REGEL_OPGESLAGEN := "Saved."
const REGEL_MISLUKT := "Save failed."
const VRAAG_PARTY := "Who leads the way?"
const REGEL_ALLEEN := "You travel alone."


## Eenmalig, als het zaad de molen weer laat draaien. Placeholder-geluid.
static func zang() -> void:
	if AudioManager.has_sfx(SFX_ZANG):
		AudioManager.play_sfx(SFX_ZANG)
	Dialog.show_lines([REGEL_ZANG, REGEL_GEZANG])
	await Dialog.finished


static func bezoek() -> void:
	_rust()
	Dialog.show_lines([REGEL_RUST])
	await Dialog.finished
	if _meel():
		Dialog.show_lines([REGEL_MEEL])
		await Dialog.finished
	var keuze: int = await Dialog.ask(VRAAG, KEUZES)
	if keuze == 0:
		await _opslaan()
	elif keuze == 1:
		await _wissel()


static func _rust() -> void:
	for h in GameState.party:
		if h == null:
			continue
		h["hp"] = h["max_hp"]
		h["mp"] = h["max_mp"]
	for p in GameState.codex_pages:
		p["hp"] = p["max_hp"]
		p["mp"] = p["max_mp"]


static func _meel() -> bool:
	if GameState.story_flags.has(FLAG_MEEL):
		return false
	GameState.inventory["zingend_meel"] = GameState.item_count("zingend_meel") + 1
	GameState.story_flags[FLAG_MEEL] = true
	return true


## Nieuw bezoek (binnenkomst zonder laden): het meel mag weer.
static func nieuw_bezoek(entry_kind: String) -> void:
	if entry_kind != "load":
		GameState.story_flags.erase(FLAG_MEEL)


static func _opslaan() -> void:
	var keuze: int = await Dialog.ask(VRAAG_SAVE, ["Yes", "No"])
	if keuze != 0:
		return
	var p := _player()
	var tile := Vector2i.ZERO
	var facing := Vector2i.DOWN
	if p != null and p.has_method("get_tile"):
		tile = p.get_tile()
		if "facing" in p:
			facing = p.facing
	if GameState.save_game(tile, facing):
		UiSfx.play(UiSfx.SAVE)
		Dialog.show_lines([REGEL_OPGESLAGEN])
	else:
		Dialog.show_lines([REGEL_MISLUKT])
	await Dialog.finished


static func _wissel() -> void:
	if GameState.party.size() < 2:
		Dialog.show_lines([REGEL_ALLEEN])
		await Dialog.finished
		return
	var namen: Array = []
	for h in GameState.party:
		namen.append(str(h.get("name", "")))
	var i: int = await Dialog.ask(VRAAG_PARTY, namen)
	if i < 0 or not GameState.move_member_to_front(i):
		return
	Dialog.show_lines(["%s leads the way." % namen[i]])
	await Dialog.finished


static func _player() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("Objects/Player")
