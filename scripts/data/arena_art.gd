extends RefCounted
## Geplande art van RPG ART. Laden alleen als de vlag aan staat én het bestand er is.
## Tot die tijd gebruikt de flow bestaande texturen of een code-marker.

const ReleaseFlags := preload("res://scripts/data/release_flags.gd")


static func world_texture() -> Texture2D:
	if not ReleaseFlags.arena_enabled():
		return null
	return _load("res://assets/tiles/wereld_v18_arena.png")


static func npc_texture() -> Texture2D:
	if not ReleaseFlags.arena_enabled():
		return null
	return _load("res://assets/sprites/npc/arena_koopman_wm1_slim.png")


static func token_icon() -> Texture2D:
	if not ReleaseFlags.arena_enabled():
		return null
	return _load("res://assets/ui/icons/icon_arena_token.png")


static func _load(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	return res as Texture2D
