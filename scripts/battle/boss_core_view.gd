extends Control
## v0.14 (RPG CODE) Beeld van de ROZE KERN (boss_core.gd) op het plaatje van de Golem.
##   dicht: twee pantserplaten (steenkleuren van de Golem) over de kern, met een dun roze
##          naadje ertussen (je ziet dat er iets achter zit)
##   open : de platen schuiven opzij en verdwijnen, de kern krijgt een roze gloed die
##          pulseert, en de idle-animatie van de kern loopt sneller
## Kind van de vijand-knop; tekent in pixels van het baas-plaatje (schaal k), dus hij schaalt
## mee met de vijand. Klikken gaan erdoorheen (de vijand blijft aantikbaar).

const BossCore := preload("res://scripts/battle/boss_core.gd")

## kleuren uit de steen van golem_boss_v2.py (RPG ART)
const STONE := Color("524a44")
const STONE_LIGHT := Color("6b6258")
const STONE_DARK := Color("2c2622")
const EDGE := Color("1e1916")
const RIVET := Color("8c8270")
const SEAM := Color("e2789e")          # UiStyle.GLITCH (zacht roze)
const GLOW := Color("ff5fc8")          # roze gloed van de open kern
## idle-snelheid van de Golem: gewoon / kern open (sec per frame)
const IDLE_OPEN := 0.15

var core: BossCore
var k := 1.0                 # schermeenheden per art-pixel
var open_amount := 0.0       # 0 = platen dicht, 1 = helemaal open
var _t := 0.0
var _tween: Tween
var _idle_normal := 0.4


func setup(c: BossCore, enemy: Control, still_width: float) -> void:
	core = c
	name = "BossCore"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	k = enemy.size.x / maxf(1.0, still_width)
	position = core.rect.position * k
	size = core.rect.size * k
	var idle: Timer = enemy.get_node_or_null("Idle")
	if idle:
		_idle_normal = idle.wait_time
	open_amount = 1.0 if core.open else 0.0
	core.changed.connect(_on_changed)


func is_open_shown() -> bool:
	return open_amount >= 0.99


func plates_shown() -> bool:
	return open_amount <= 0.01


func _on_changed(is_open: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "open_amount", 1.0 if is_open else 0.0, 0.3)
	var idle: Timer = get_parent().get_node_or_null("Idle") if get_parent() else null
	if idle:
		idle.wait_time = IDLE_OPEN if is_open else _idle_normal


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if core == null:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var w := core.rect.size.x
	var h := core.rect.size.y
	# roze gloed (alleen als de kern open gaat/is), pulserend
	if open_amount > 0.0:
		var pulse := 0.5 + 0.5 * sin(_t * 9.0)
		for i in 4:
			var grow := 2.0 + 3.0 * i + 2.0 * pulse
			var a := open_amount * (0.30 - 0.06 * i) * (0.7 + 0.3 * pulse)
			draw_rect(Rect2(-grow, -grow, w + 2.0 * grow, h + 2.0 * grow), Color(GLOW, a), false, 2.0)
		draw_rect(Rect2(2, 2, w - 4, h - 4), Color(GLOW, 0.18 * open_amount * pulse))
	# pantserplaten: links en rechts, schuiven opzij en vervagen
	if open_amount < 1.0:
		var half := w / 2.0
		var shift := open_amount * (half + 4.0)
		var alpha := 1.0 - open_amount
		_plate(Rect2(-shift, 0, half, h), alpha, true)
		_plate(Rect2(half + shift, 0, half, h), alpha, false)
		if open_amount <= 0.01:
			# dun roze naadje tussen de platen (de kern zit erachter)
			draw_rect(Rect2(half - 1, 3, 2, h - 6), Color(SEAM, 0.55 + 0.25 * sin(_t * 3.0)))


func _plate(r: Rect2, alpha: float, left: bool) -> void:
	draw_rect(r, Color(EDGE, alpha))
	var inner := r.grow(-1.0)
	draw_rect(inner, Color(STONE, alpha))
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 2)), Color(STONE_LIGHT, alpha))           # licht boven
	draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 2), Vector2(inner.size.x, 2)), Color(STONE_DARK, alpha))
	# horizontale groef halverwege
	draw_rect(Rect2(inner.position + Vector2(1, inner.size.y / 2.0 - 1), Vector2(inner.size.x - 2, 2)), Color(STONE_DARK, alpha))
	# klinknagels aan de buitenkant
	var x := inner.position.x + (2.0 if left else inner.size.x - 4.0)
	for y in [inner.position.y + 4.0, inner.end.y - 6.0]:
		draw_rect(Rect2(x, y, 2, 2), Color(RIVET, alpha))
