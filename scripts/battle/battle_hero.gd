extends Control
## Eén held op het slagveld (gevechtssprite + effecten).
## Het plaatje is een strook van 10 (of 8) vierkante frames (zie tools/art_v8_heroes.py):
##   0 stil, 1 klaar, 2 aanval A, 3 aanval B, 4 spreuk A, 5 spreuk B, 6 geraakt, 7 KO,
##   8 stil-inademen, 9 stil-uitademen (alleen in v8-strips).
## v8: frames van 210x210 art-pixels, getoond op schaal 0.5 (= 105x105 eenheden); de figuur
## is ±155 echte pixels = ±35% van de schermhoogte (zoals de mockup). 1 art-pixel = 1 echte
## pixel op het 2x-raster. Strips van v7 (160), v6 (80) en de oude 32x32-strips werken ook.
## Idle-animatie: in de 'stil'-pose wisselt de held rustig tussen frame 8, 0, 9, 0 (ademen,
## cape zwaait, de bol op de staf pulseert). Kost bijna niets: alleen een framenummer.
## 'home' = plek van de voeten (onderkant midden) op het slagveld.
## Tik/klik op de held -> signaal 'tapped' (gebruikt bij het kiezen van een doelwit).

signal tapped

const FRAME := {"stil": 0, "klaar": 1, "aanval_a": 2, "aanval_b": 3,
		"spreuk_a": 4, "spreuk_b": 5, "geraakt": 6, "ko": 7}
const BattleScript := preload("res://scripts/battle/battle.gd")
## Tik-vak van de held (ongeveer het lijf; het plaatje zelf is groter, want het wapen
## en de zwaaiboog steken uit).
const SIZE := Vector2(40, 78)
const FEET := Vector2(20, 76)        # voeten binnen het tik-vak (in scherm-eenheden)
const STEP := Vector2(0, -8)         # stapje naar voren = omhoog, richting de vijanden (v9.1)
## Voeten binnen een frame van de fijne art, per framebreedte (zie tools/art_v7_heroes.py).
const ART_FEET := {210: Vector2(105, 203), 160: Vector2(80, 154), 140: Vector2(70, 135), 80: Vector2(40, 77)}
## Bovenkant van het hoofd boven de voeten (eenheden), voor het doel-pijltje.
const HEAD_HEIGHT := 76.0
## Idle-animatie (alleen als de strip 10 frames heeft)
const IDLE_CYCLE := [8, 0, 9, 0]
const IDLE_STEP := 0.42          # seconden per adem-frame
static var _idle_counter := 0

var home := Vector2.ZERO
var stepped_forward := false
var pose := "stil"
var is_ko := false
var _sprite: Sprite2D
var _move_tween: Tween
var _flash_tween: Tween
var _frames := 8
var _idle_t := 0.0
var _idle_i := 0
var _idle_timer: Timer


func setup(texture: Texture2D, feet_position: Vector2) -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	# vierkante frames: aantal = breedte / hoogte (v8: 10, ouder: 8)
	_frames = clampi(roundi(float(texture.get_width()) / maxf(1.0, texture.get_height())), 8, 10)
	_sprite.hframes = _frames
	_sprite.centered = false
	var frame := Vector2(texture.get_width() / float(_frames), texture.get_height())
	if frame.x >= 64:
		# fijne art: halve grootte, voeten van de art op FEET
		var feet: Vector2 = ART_FEET.get(int(frame.x), Vector2(frame.x / 2.0, frame.y - 5.0))
		_sprite.scale = Vector2(0.5, 0.5)
		_sprite.position = FEET - feet * 0.5
	else:
		# oude art (32x32, voeten op 16,30)
		_sprite.position = FEET - Vector2(16, 30)
	add_child(_sprite)
	set_home(feet_position)
	set_pose("stil")
	# elke held ademt op een eigen moment (niet allemaal tegelijk)
	_idle_i = _idle_counter % IDLE_CYCLE.size()
	_idle_t = 0.13 * (_idle_counter % 3)
	_idle_counter += 1
	_setup_idle_timer(_frames >= 10)


func has_idle_animation() -> bool:
	return _frames >= 10


func _setup_idle_timer(aan: bool) -> void:
	if BattleScript.headless_sim:
		aan = false
	if _idle_timer != null:
		_idle_timer.stop()
		_idle_timer.queue_free()
		_idle_timer = null
	set_process(false)
	if not aan:
		return
	_idle_timer = Timer.new()
	_idle_timer.wait_time = IDLE_STEP
	_idle_timer.one_shot = false
	_idle_timer.autostart = true
	_idle_timer.timeout.connect(_idle_stap)
	add_child(_idle_timer)
	# faseverschil per held (zelfde als vroeger via _idle_t)
	_idle_timer.start(maxf(0.01, IDLE_STEP - _idle_t))


func _idle_stap() -> void:
	if pose != "stil" or is_ko:
		return
	_idle_i = (_idle_i + 1) % IDLE_CYCLE.size()
	_sprite.frame = IDLE_CYCLE[_idle_i]


func set_home(feet_position: Vector2) -> void:
	home = feet_position
	position = _target_position()


## v0.15 Rechthoek van de ZICHTBARE art (niet-doorzichtige pixels van de rust-/klaar-/adem-
## frames) als de voeten op 'feet' staan, in de coördinaten van de ouder. Het fijne plaatje is
## breder dan het tik-vak (SIZE); battle.gd zet het commando-kruis er links naast.
static var _art_cache := {}

func art_rect(feet: Vector2) -> Rect2:
	var node_pos := feet - FEET
	if _sprite == null or _sprite.texture == null:
		return Rect2(node_pos, SIZE)
	var tex := _sprite.texture
	var key := "%s|%d" % [tex.resource_path, _frames]
	if not _art_cache.has(key):
		var img := tex.get_image()
		var fw := int(tex.get_width() / _frames)
		var used := Rect2i()
		if img and not img.is_empty():
			for f in [0, 1, 8, 9]:
				if f >= _frames:
					continue
				var r := img.get_region(Rect2i(f * fw, 0, fw, img.get_height())).get_used_rect()
				if r.has_area():
					used = r if not used.has_area() else used.merge(r)
		_art_cache[key] = used
	var u: Rect2i = _art_cache[key]
	if not u.has_area():
		return Rect2(node_pos, SIZE)
	return Rect2(node_pos + _sprite.position + Vector2(u.position) * _sprite.scale, Vector2(u.size) * _sprite.scale)


## Net boven het hoofd van de held (voor het doel-pijltje en schadegetallen).
func head_position() -> Vector2:
	return position + Vector2(FEET.x, FEET.y - HEAD_HEIGHT)


func set_pose(p: String) -> void:
	if is_ko and p != "ko":
		return                     # KO blijft liggen
	pose = p
	if _sprite:
		_sprite.frame = FRAME.get(p, 0)
		_idle_t = 0.0
	if _idle_timer != null:
		if p == "stil" and not is_ko:
			_idle_timer.start(IDLE_STEP)
		else:
			_idle_timer.stop()


## Een stapje naar voren (aan de beurt) of terug naar de eigen plek.
func step(forward: bool) -> void:
	if is_ko:
		forward = false
	stepped_forward = forward
	if _move_tween:
		_move_tween.kill()
		_move_tween = null
	if BattleScript.headless_sim:
		position = _target_position()
		if not is_ko:
			set_pose("klaar" if forward else "stil")
		return
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", _target_position(), 0.12)
	if not is_ko:
		set_pose("klaar" if forward else "stil")


func _target_position() -> Vector2:
	var feet := home + (STEP if stepped_forward else Vector2.ZERO)
	return (feet - FEET).round()


## Aanval: uithalen -> slaan. Blijft in de 'slaan'-pose tot rest() wordt aangeroepen.
func play_attack() -> void:
	set_pose("aanval_a")
	if BattleScript.headless_sim:
		set_pose("aanval_b")
		return
	await get_tree().create_timer(0.14).timeout
	set_pose("aanval_b")


## Spreuk / item: arm omhoog -> glinstering.
func play_cast() -> void:
	set_pose("spreuk_a")
	if BattleScript.headless_sim:
		set_pose("spreuk_b")
		return
	await get_tree().create_timer(0.16).timeout
	set_pose("spreuk_b")


## Terug naar rust (en naar de eigen plek).
func rest() -> void:
	step(false)


## Geraakt: wit flitsen, schudden en even de 'geraakt'-pose.
func hurt() -> void:
	set_pose("geraakt")
	if BattleScript.headless_sim:
		if not is_ko:
			set_pose("klaar" if stepped_forward else "stil")
		return
	flash(Color(2.2, 2.2, 2.2))
	var origin := _target_position()
	var tw := create_tween()
	for i in 4:
		tw.tween_property(self, "position:x", origin.x + (-3.0 if i % 2 == 0 else 3.0), 0.035)
	tw.tween_property(self, "position:x", origin.x, 0.035)
	if not is_inside_tree():
		return      # gevecht al weg (scènewissel)
	await get_tree().create_timer(0.35).timeout
	if not is_ko:
		set_pose("klaar" if stepped_forward else "stil")


## Kleur even veranderen (wit = geraakt, groen = genezen) en terug.
func flash(color: Color) -> void:
	if BattleScript.headless_sim:
		return
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
		set_pose("ko")
	else:
		set_pose("stil")
	_sprite.modulate = _base_modulate()


func _base_modulate() -> Color:
	return Color(0.62, 0.62, 0.72) if is_ko else Color.WHITE   # KO = grijzig


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit()
		accept_event()
