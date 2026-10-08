extends Control
## Codex-bondgenoot op het slagveld (Kernfragment stap 2): een ingeschreven monster dat naast
## Dennis meevecht, van ACHTEREN gezien (zoals de helden). Zelfde aanroepen als battle_hero.gd
## (setup/step/rest/hurt/flash/set_ko/head_position/art_rect), zodat battle.gd hem als held
## kan behandelen.
## Rug-sprite: "sprite_back" van de vijand in GameData.ENEMIES (afspraak Forge v17; RPG ART,
## <id>_rug.png, zelfde canvas/anker als het vooraanzicht, voeten op rij H-7, 2x-resolutie ->
## schaal 0.5). Ontbreekt die, dan een plaatsvervanger: het vooraanzicht gespiegeld en donkerder
## ('placeholder' = true).

signal tapped

const CodexData := preload("res://scripts/data/codex_data.gd")
const SIZE := Vector2(44, 56)          # tik-vak
const FEET := Vector2(22, 54)          # voeten binnen het tik-vak
const STEP := Vector2(0, -8)           # stapje naar voren (omhoog)
const PLACEHOLDER_TINT := Color(0.5, 0.5, 0.62)
const KO_TINT := Color(0.42, 0.42, 0.5)

var home := Vector2.ZERO
var stepped_forward := false
var pose := "stil"
var is_ko := false
var placeholder := false
var texture_path := ""
var _sprite: Sprite2D
var _move_tween: Tween
var _flash_tween: Tween
var _art_size := Vector2(40, 40)
var _feet_h := 36.0        # afstand voeten -> bovenkant van het plaatje (eenheden, rechtop)


## species_id = soort uit CodexData.SPECIES.
func setup_species(species_id: String, feet_position: Vector2) -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sp := CodexData.species(species_id)
	var tex: Texture2D = null
	texture_path = str(sp.get("back", ""))
	if texture_path != "" and ResourceLoader.exists(texture_path):
		tex = load(texture_path)
	else:
		placeholder = true
		texture_path = str(sp.get("front", ""))
		if texture_path != "" and ResourceLoader.exists(texture_path):
			tex = load(texture_path)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = tex
	_sprite.flip_h = placeholder
	add_child(_sprite)
	if tex != null:
		var sc := CodexData.ALLY_ART_SCALE * float(sp.get("ally_scale", 1.0))
		_art_size = Vector2(tex.get_size()) * sc
		_feet_h = float(tex.get_height() - CodexData.FEET_FROM_BOTTOM) * sc
		_sprite.scale = Vector2(sc, sc)
		_sprite.position = (FEET - Vector2(_art_size.x / 2.0, _feet_h)).round()
	_sprite.modulate = _base_modulate()
	set_home(feet_position)


func set_home(feet_position: Vector2) -> void:
	home = feet_position
	position = _target_position()


func _target_position() -> Vector2:
	return (home + (STEP if stepped_forward else Vector2.ZERO) - FEET).round()


func art_rect(feet: Vector2) -> Rect2:
	var node_pos := feet - FEET
	if _sprite == null:
		return Rect2(node_pos, SIZE)
	return Rect2(node_pos + _sprite.position, _art_size)


func head_position() -> Vector2:
	return position + Vector2(FEET.x, FEET.y - _feet_h)


func has_idle_animation() -> bool:
	return false


func set_pose(p: String) -> void:
	if is_ko and p != "ko":
		return
	pose = p


func step(forward: bool) -> void:
	if is_ko:
		forward = false
	stepped_forward = forward
	if _move_tween:
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", _target_position(), 0.12)
	set_pose("klaar" if forward else "stil")


## Aanval: een sprongetje naar voren.
func play_attack() -> void:
	set_pose("aanval_a")
	var tw := create_tween()
	tw.tween_property(_sprite, "position:y", _sprite.position.y - 10.0, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sprite, "position:y", _sprite.position.y, 0.1)
	await get_tree().create_timer(0.14).timeout
	set_pose("aanval_b")


## Vaardigheid: gloed.
func play_cast() -> void:
	set_pose("spreuk_a")
	flash(Color(1.5, 1.4, 0.8))
	await get_tree().create_timer(0.16).timeout
	set_pose("spreuk_b")


func rest() -> void:
	step(false)


func hurt() -> void:
	set_pose("geraakt")
	flash(Color(2.2, 2.2, 2.2))
	var origin := _target_position()
	var tw := create_tween()
	for i in 4:
		tw.tween_property(self, "position:x", origin.x + (-3.0 if i % 2 == 0 else 3.0), 0.035)
	tw.tween_property(self, "position:x", origin.x, 0.035)
	await get_tree().create_timer(0.35).timeout
	if not is_ko:
		set_pose("klaar" if stepped_forward else "stil")


func flash(color: Color) -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_sprite.modulate = color
	_flash_tween.tween_property(_sprite, "modulate", _base_modulate(), 0.25)


func set_ko(ko: bool) -> void:
	if _flash_tween:
		_flash_tween.kill()
	is_ko = ko
	if ko:
		stepped_forward = false
		position = _target_position()
		pose = "ko"
	else:
		set_pose("stil")
	_sprite.modulate = _base_modulate()
	# KO: plat op de grond (half zo hoog, voeten blijven staan)
	var sy := 0.55 if ko else 1.0
	_sprite.scale.y = absf(_sprite.scale.x) * sy
	_sprite.position.y = roundf(FEET.y - _feet_h * sy)


func _base_modulate() -> Color:
	if is_ko:
		return KO_TINT
	return PLACEHOLDER_TINT if placeholder else Color.WHITE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit()
		accept_event()
