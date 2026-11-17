class_name LobbyPortraitSlot
extends Control
## 36x36 co-op lobby seat: rol-lijst + 32x32 heldenportret (RPG ART).
## Met set_look() het gebakken portret van de eigen look (PortraitBaker); bij een fout het vaste portret.

const SLOT_SIZE := 36
const PORTRAIT_POS := Vector2(2, 2)
const PORTRAIT_SIZE := 32
const ROLES: PackedStringArray = ["tank", "heal", "control", "dps"]
const HEROES: PackedStringArray = ["dennis", "lotte", "noor", "kael", "orion"]

const _ACHTER: Dictionary = {
	"tank": preload("res://assets/ui/lobby/lijst_tank_achter.png"),
	"heal": preload("res://assets/ui/lobby/lijst_heal_achter.png"),
	"control": preload("res://assets/ui/lobby/lijst_control_achter.png"),
	"dps": preload("res://assets/ui/lobby/lijst_dps_achter.png"),
}
const _VOOR: Dictionary = {
	"tank": preload("res://assets/ui/lobby/lijst_tank_voor.png"),
	"heal": preload("res://assets/ui/lobby/lijst_heal_voor.png"),
	"control": preload("res://assets/ui/lobby/lijst_control_voor.png"),
	"dps": preload("res://assets/ui/lobby/lijst_dps_voor.png"),
}
const _PORTRAITS: Dictionary = {
	"dennis": preload("res://assets/ui/lobby/portret_dennis.png"),
	"lotte": preload("res://assets/ui/lobby/portret_lotte.png"),
	"noor": preload("res://assets/ui/lobby/portret_noor.png"),
	"kael": preload("res://assets/ui/lobby/portret_kael.png"),
	"orion": preload("res://assets/ui/lobby/portret_orion.png"),
}

var _achter: TextureRect
var _portrait: TextureRect
var _voor: TextureRect
var _hero_id := ""
var _role := ""
## Look van de speler in deze stoel (dict of AvatarBlob). null = vast heldenportret.
var _look: Variant = null
var _source := ""


func _ready() -> void:
	custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_achter = _make_rect(Vector2.ZERO, Vector2(SLOT_SIZE, SLOT_SIZE))
	_portrait = _make_rect(PORTRAIT_POS, Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE))
	_voor = _make_rect(Vector2.ZERO, Vector2(SLOT_SIZE, SLOT_SIZE))
	add_child(_achter)
	add_child(_portrait)
	add_child(_voor)
	if _role != "" or _hero_id != "":
		_apply()


func _make_rect(pos: Vector2, size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.position = pos
	rect.custom_minimum_size = size
	rect.size = size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func set_seat(hero_id: String, role: String) -> void:
	var hid := hero_id.strip_edges()
	var rol := role.strip_edges().to_lower()
	if hid == _hero_id and rol == _role:
		return
	_hero_id = hid
	_role = rol
	if is_node_ready():
		_apply()


## Eigen look tonen in plaats van het vaste portret. Lukt bakken niet: vast portret.
func set_look(look: Variant) -> void:
	_look = look
	if is_node_ready():
		_apply()


## "baked", "hero" of "" (geen portret).
func portrait_source() -> String:
	return _source


func portrait_texture() -> Texture2D:
	return _portrait.texture if _portrait != null else null


func frame_back_texture() -> Texture2D:
	return _achter.texture if _achter != null else null


func frame_front_texture() -> Texture2D:
	return _voor.texture if _voor != null else null


func _apply() -> void:
	var back: Texture2D = _ACHTER.get(_role) as Texture2D
	var front: Texture2D = _VOOR.get(_role) as Texture2D
	_achter.texture = back
	_voor.texture = front
	_achter.visible = back != null
	_voor.visible = front != null
	var face: Texture2D = null
	if _hero_id != "" and _PORTRAITS.has(_hero_id):
		face = _PORTRAITS[_hero_id] as Texture2D
	_source = "hero" if face != null else ""
	if _look != null and _hero_id != "":
		var baked := PortraitBaker.bake(_look)
		if baked != null:
			face = baked
			_source = "baked"
	_portrait.texture = face
	_portrait.visible = face != null