extends RefCounted
## Story-afhandeling na een gewonnen REALTIME Golem-gevecht (D3 arena-hook, SomArena.golem_rt_enabled).
## Hergebruikt precies wat de turn-based winst al doet (geen nieuwe verhaaltekst):
##   1. bewaker-vlag StoryData.GOLEM_FLAG ("bewaker:archief_golemhal/golem", DungeonRoom.guard_flag) +
##      NaGenezer.on_guard_flag  (zoals DungeonRoom._restore_after_battle)
##   2. Golemkern via GameState.grant_kern + pending_kern_absorb  (zoals GameState na een baaswinst)
##   3. het bestaande absorptie-moment scripts/kern/kern_absorption.gd op de kaart  (zoals map.gd)
## Host-authoritatief (de aanroeper checkt dat) en eenmalig: de vlag en de kern worden nooit dubbel gezet,
## een tweede aanroep (her-binnenkomst, geladen save) doet niets. Zie docs/combat/golem_story_events.md.

const NaGenezer := preload("res://world_warper/flow/na_genezer.gd")
const KernData := preload("res://scripts/data/kern_data.gd")
const KernAbsorption := preload("res://scripts/kern/kern_absorption.gd")


## Voert de verhaal-beat uit. Geeft true als er iets nieuws gebeurde (false = al eerder gedaan).
static func apply(room_id: String, monster_id: String, enemy_id: String, map: Node) -> bool:
	var vlag := DungeonRoom.guard_flag(room_id, monster_id)
	var nieuw := not GameState.story_flags.has(vlag)
	if nieuw:
		GameState.story_flags[vlag] = true
		NaGenezer.on_guard_flag(vlag, true)
	var kid := KernData.fragment_for_boss(enemy_id)
	var kern_nieuw := kid != "" and GameState.grant_kern(kid, enemy_id)
	if kern_nieuw:
		GameState.pending_kern_absorb = kid
		if map != null and map.is_inside_tree():
			var ka: Node2D = KernAbsorption.new()
			map.add_child(ka)
			ka.start(map, kid)
	NaGenezer.probeer()
	return nieuw or kern_nieuw
