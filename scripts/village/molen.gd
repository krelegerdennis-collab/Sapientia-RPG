extends RefCounted
## Molen van Gerrit in Wilgendal, na Het Zingende Graan.
## Eén bezoek: rusten, één Zingend Meel, daarna opslaan of de party wisselen.
## Het meel zit op de map (meta). Een nieuw bezoek is een nieuwe scène.

const UiSfx := preload("res://scripts/ui/ui_sfx.gd")
const META := "zingend_meel_gegeven"
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
	var tree := Engine.get_main_loop() as SceneTree
	var map: Node = tree.current_scene if tree != null else null
	if _meel(map):
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


static func _meel(map: Node) -> bool:
	if map != null and bool(map.get_meta(META, false)):
		return false
	GameState.inventory["zingend_meel"] = GameState.item_count("zingend_meel") + 1
	if map != null:
		map.set_meta(META, true)
	return true


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
