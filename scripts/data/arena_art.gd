extends RefCounted
class_name ArenaArt
## Arena-art van RPG ART. Laden alleen als de vlag aan staat én het bestand er is,
## zodat een dichte vlag de rest van de game geen texturen laat inladen.

const ReleaseFlags := preload("res://scripts/data/release_flags.gd")

## Linksboven van het 2x2 Colosseum op de wereldkaart.
## Overlay-tegels en de 2x2-uitgang (px = tegel * 16) hangen alleen aan deze regel.
## ART: (30, 32), dus px (480, 512).
const WORLD_TILE := Vector2i(30, 32)

const WORLD := "res://assets/tiles/wereld_v18_arena.png"
const TILES := "res://assets/tiles/arena/arena_tiles.png"
const NPC := "res://assets/sprites/npc/arena_koopman_wm1_slim.png"
const NPC_IDLE := "res://assets/sprites/npc/arena_koopman_wm1_slim_idle.png"
const ICON := "res://assets/ui/arena/icon_arena.png"
const TOKEN := "res://assets/ui/arena/icon_arena_token.png"


static func world_texture() -> Texture2D:
	if not ReleaseFlags.arena_enabled():
		return null
	return _load(WORLD)


static func tiles_texture() -> Texture2D:
	if not ReleaseFlags.arena_enabled():
		return null
	return _load(TILES)


static func npc_texture() -> Texture2D:
	if not ReleaseFlags.arena_enabled():
		return null
	return _load(NPC)


static func npc_idle_texture() -> Texture2D:
	if not ReleaseFlags.arena_enabled():
		return null
	return _load(NPC_IDLE)


static func arena_icon() -> Texture2D:
	if not ReleaseFlags.arena_enabled():
		return null
	return _load(ICON)


static func token_icon() -> Texture2D:
	if not ReleaseFlags.arena_enabled():
		return null
	return _load(TOKEN)


static func _load(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	return res as Texture2D
