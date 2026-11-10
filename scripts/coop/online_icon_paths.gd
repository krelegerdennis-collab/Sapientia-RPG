class_name OnlineIconPaths
extends RefCounted
## Pad-tabel voor rol- en emote-iconen.
## Definitieve art (RPG ART, aparte PR) landt op de FINAL-paden.
## Zolang dat bestand er niet is, valt de lobby terug op de gemarkeerde
## placeholder onder assets/placeholder/online/. Geen codewijziging nodig
## als de art-PR de FINAL-bestanden dropt.

const ROLE_ORDER: PackedStringArray = ["Tank", "Heal", "Control", "Dps"]
const EMOTE_COUNT := 4
const EMOTE_SLUGS: PackedStringArray = [
	"0_help", "1_hier_heen", "2_goed_gedaan", "3_bedankt",
]

const _ROLE_SLUG := {
	"Tank": "rol_tank",
	"Heal": "rol_heal",
	"Control": "rol_control",
	"Dps": "rol_dps",
}

const _PH_ROLE := {
	"Tank": preload("res://assets/placeholder/online/rol_tank.png"),
	"Heal": preload("res://assets/placeholder/online/rol_heal.png"),
	"Control": preload("res://assets/placeholder/online/rol_control.png"),
	"Dps": preload("res://assets/placeholder/online/rol_dps.png"),
}

const _PH_EMOTE: Array[Texture2D] = [
	preload("res://assets/placeholder/online/emote_0_help.png"),
	preload("res://assets/placeholder/online/emote_1_hier_heen.png"),
	preload("res://assets/placeholder/online/emote_2_goed_gedaan.png"),
	preload("res://assets/placeholder/online/emote_3_bedankt.png"),
]

static var _cache: Dictionary = {}


static func role_final_paths(role: String) -> PackedStringArray:
	var slug := str(_ROLE_SLUG.get(role, ""))
	if slug == "":
		return PackedStringArray()
	return PackedStringArray([
		"res://assets/ui/icons/rollen/icons16/%s.png" % slug,
		"res://assets/ui/icons/rollen/icons32/%s.png" % slug,
	])


static func emote_final_paths(emote_id: int) -> PackedStringArray:
	if emote_id < 0 or emote_id >= EMOTE_SLUGS.size():
		return PackedStringArray()
	var slug := "emote_%s" % EMOTE_SLUGS[emote_id]
	return PackedStringArray([
		"res://assets/ui/icons/emotes/icons16/%s.png" % slug,
		"res://assets/ui/icons/emotes/icons32/%s.png" % slug,
	])


static func role_placeholder(role: String) -> Texture2D:
	return _PH_ROLE.get(role, null) as Texture2D


static func emote_placeholder(emote_id: int) -> Texture2D:
	if emote_id < 0 or emote_id >= _PH_EMOTE.size():
		return null
	return _PH_EMOTE[emote_id]


static func role_texture(role: String) -> Texture2D:
	return _first(role_final_paths(role), role_placeholder(role))


static func emote_texture(emote_id: int) -> Texture2D:
	return _first(emote_final_paths(emote_id), emote_placeholder(emote_id))


static func using_placeholder(role_or_paths: PackedStringArray) -> bool:
	for path in role_or_paths:
		if ResourceLoader.exists(path):
			return false
	return true


static func _first(paths: PackedStringArray, fallback: Texture2D) -> Texture2D:
	for path in paths:
		if _cache.has(path):
			return _cache[path] as Texture2D
		if ResourceLoader.exists(path):
			var res: Variant = load(path)
			if res is Texture2D:
				_cache[path] = res
				return res as Texture2D
	return fallback
