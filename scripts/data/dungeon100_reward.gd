extends RefCounted
## Beloning op verdieping 100. Eén keuze per run; de andere twee pas in een nieuwe run.
## Aanroepen ná dungeon100_end_run, zodat de echte party, tas en Codex de beloning krijgen.

const Equipment := preload("res://scripts/equipment.gd")

const RING_ID := "simulatie_ring"
const FLAG_RESET := "dungeon100_ring:reset"
const RESET_LINE := "De Simulatie-ring herstart deze verdieping."
const VRAAG := "Het Warp-kristal breekt open. Kies één beloning."
const KEUZES: Array[String] = ["Codex-monster ECHO", "Grade 4-wapens", "Simulatie-ring"]
const IDS: Array[String] = ["codex", "wapens", "ring"]
const WAPENS: Array[String] = ["bg_g4_superzwaard", "bg_g4_staf_noor", "bg_g4_staf_lotte"]


static func geldig(keuze: String) -> bool:
	return keuze in IDS


static func geef(keuze: String) -> void:
	match keuze:
		"codex":
			GameState.codex_add("echo")
			GameState.mark_seen("echo")
		"wapens":
			for id in WAPENS:
				_bewaar(id)
				_equip_passend(id)
		"ring":
			_bewaar(RING_ID)


static func draagt_ring(party: Array) -> bool:
	for h in party:
		if typeof(h) != TYPE_DICTIONARY:
			continue
		var eq: Dictionary = (h as Dictionary).get("equip", {})
		if str(eq.get("accessoire", "")) == RING_ID:
			return true
	return false


static func _bewaar(id: String) -> void:
	GameState.dungeon100_permanent[id] = int(GameState.dungeon100_permanent.get(id, 0)) + 1
	GameState.dungeon100_delivered[id] = int(GameState.dungeon100_permanent[id])
	GameState.inventory[id] = GameState.item_count(id) + 1


static func _equip_passend(id: String) -> void:
	for h in GameState.party:
		if not (h is Dictionary):
			continue
		var hero: Dictionary = h
		if not Equipment.can_wear(hero, id):
			continue
		Equipment.equip(hero, GameState.inventory, "wapen", id)
		return
