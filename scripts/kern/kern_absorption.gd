extends Node2D
## v0.15 KERNFRAGMENT: het absorptie-moment na een baasgevecht (zie HANDOFF_KERN.md).
## map.gd start dit als GameState.pending_kern_absorb gezet is (de kern zelf is dan AL gegeven
## en zit in de autosave; dit is alleen het beeld + bericht).
##   1. kort wachten tot de kaart in beeld is (fade-in)
##   2. effect assets/fx/kern_absorptie.png (192x48 = 4 frames van 48x48, 0,12 s per frame, niet
##      loopen), midden (24,24) op de borst van de held (12 px boven zijn voeten), plus een zachte
##      roze gloed in code (zoals het savepunt) en een roze flits op de held
##   3. bericht: '{naam} absorbeert de Golemkern!' + wat hij vrijspeelt
##   4. alles weg, speler weer vrij, autosave ("kern")

const FX := "res://assets/fx/kern_absorptie.png"
const FRAMES := 4
const FRAME_TIME := 0.12
const START_DELAY := 0.45                 # na de fade-in (Transition 0,3 s)
const CHEST := Vector2(0, -4)             # borst: tile-midden + 8 = voeten, 12 hoger = -4
const GLOW_RADIUS := 28.0
const KernData := preload("res://scripts/data/kern_data.gd")
const BookPoint := preload("res://scripts/book_point.gd")

signal done

var map: Node = null
var fragment_id := ""
var fx: Sprite2D
var glow: Sprite2D
## voor de tests: "", "effect", "bericht", "klaar"
var phase := ""
## voor de tests: welke frames er getoond zijn en hoe lang het effect duurde (s, speltijd,
## inclusief het vervagen van 0,25 s)
var frames_shown: Array = []
var effect_time := 0.0
var _t := 0.0
var _color := Color(1.0, 0.36, 0.78)


## Start het moment op deze kaart voor kernfragment 'id'.
func start(p_map: Node, id: String) -> void:
	map = p_map
	fragment_id = id
	name = "KernAbsorptie"
	var f := KernData.fragment(id)
	_color = f.get("kleur", _color)
	var player: Node2D = map.player
	player.input_locked = true
	if not await _wait(START_DELAY):
		return
	# loopt er een verhaal-cutscene of staat er tekst open (bijv. na het gevecht)? Eerst die.
	while Story.running or Dialog.is_open:
		if not await _wait(0.0):
			return
	if not _alive():
		return
	player.input_locked = true
	# gloed (achter het effect) + effect, als kind van de held: loopt dus mee met de camera
	glow = Sprite2D.new()
	glow.name = "KernGloed"
	glow.texture = BookPoint.aura_texture(_color)
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.position = CHEST
	glow.scale = Vector2.ONE * (GLOW_RADIUS * 2.0 / float(glow.texture.get_width()))
	glow.modulate = Color(1, 1, 1, 0.0)
	glow.z_index = 5
	player.add_child(glow)
	fx = Sprite2D.new()
	fx.name = "KernEffect"
	fx.texture = load(FX)
	fx.hframes = FRAMES
	fx.frame = 0
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.centered = true                     # 48x48: midden = (24,24)
	fx.position = CHEST
	fx.z_index = 6
	player.add_child(fx)
	phase = "effect"
	var tw := create_tween()
	tw.tween_property(glow, "modulate:a", 0.85, FRAME_TIME * 2.0)
	for i in FRAMES:
		fx.frame = i
		frames_shown.append(i)
		if i == FRAMES - 1:      # flits/opname: de held licht roze op
			var fl := create_tween()
			fl.tween_property(player.sprite, "modulate", Color(1.8, 0.9, 1.6), 0.06)
			fl.tween_property(player.sprite, "modulate", Color.WHITE, 0.4)
		if not await _wait(FRAME_TIME):
			return
	# niet loopen: het laatste frame vervaagt, de gloed blijft zacht pulseren tijdens het bericht
	var out := create_tween()
	out.tween_property(fx, "modulate:a", 0.0, 0.25)
	if not await _wait(0.25):
		return
	phase = "bericht"
	Dialog.show_lines(lines_for(id))
	await Dialog.finished
	# gezien = klaar (ook als de kaart hierna meteen wisselt)
	if GameState.pending_kern_absorb == id:
		GameState.pending_kern_absorb = ""
	var gone := create_tween()
	gone.tween_property(glow, "modulate:a", 0.0, 0.3)
	if not await _wait(0.3):
		return
	if is_instance_valid(fx):
		fx.queue_free()
	if is_instance_valid(glow):
		glow.queue_free()
	if is_instance_valid(player):
		player.input_locked = false
	phase = "klaar"
	if is_instance_valid(map) and map.has_method("try_autosave"):
		map.try_autosave("kern")
	done.emit()
	queue_free()


## Wacht (0 = één beeld). false = de kaart is intussen weg (mapwissel): dan stopt het moment;
## pending_kern_absorb blijft staan, dus het speelt op de volgende kaart alsnog (de kern zelf is
## al gegeven en opgeslagen).
func _wait(seconds: float) -> bool:
	if not _alive():
		return false
	if seconds <= 0.0:
		await get_tree().process_frame
	else:
		await get_tree().create_timer(seconds).timeout
	return _alive()


func _alive() -> bool:
	return is_inside_tree() and is_instance_valid(map) and map.is_inside_tree() \
			and map.player != null and is_instance_valid(map.player)


func _process(delta: float) -> void:
	if phase == "effect":
		effect_time += delta      # speltijd (zelfde klok als de timers)
	if phase == "bericht" and is_instance_valid(glow):
		_t += delta
		glow.modulate.a = 0.55 + 0.25 * sin(_t * TAU / 1.6)


## De tekst van het moment (uit de data, dus ook goed voor latere kernen).
static func lines_for(id: String) -> Array:
	var f := KernData.fragment(id)
	var lines: Array = ["{naam} absorbeert de %s!" % f.get("naam", id)]
	var sk := str(f.get("battle_skill", ""))
	if KernData.KERN_SKILLS.has(sk):
		lines.append("Nieuwe vaardigheid: %s. (In het gevecht: Magie > %s)" % [KernData.KERN_SKILLS[sk]["name"], KernData.KERN_SKILLS[sk]["name"]])
	for ab in KernData.abilities_of(f):     # v0.16: een fragment kan meer wereldvaardigheden geven
		if KernData.WORLD_ABILITIES.has(ab):
			lines.append("Nieuw: %s. %s" % [KernData.WORLD_ABILITIES[ab]["name"], KernData.WORLD_ABILITIES[ab]["desc"]])
	return lines
