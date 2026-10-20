extends RefCounted
## SoM-proef: effecten en poses. Met de art van RPG ART (assets/sprites/som/combat|fx|ui|monsters, paden in
## som_data.gd) waar die er is; anders de PLACEHOLDER in code (magenta boog, Label-cijfers).
## - Anim: speelt een reeks frames met eigen duur per frame; seint 'hit' aan het begin van hit_index
##   (de treffer van een slag) en 'finished' aan het eind. Verbergt zolang het lichaam ('body').
## - attack_anim/cast_anim/pose: held-poses (48x48, voeten op de onderrand -> offset (0,-16)).
## - slash/spark/number/telegraph: FX; Gauge: wapenmeter boven de held.

const SomData := preload("res://scripts/data/som_data.gd")
const THEME := preload("res://assets/theme.tres")
const PLACEHOLDER_COLOR := Color("ff1ee6")
const DIR_INDEX := {Vector2i.DOWN: 0, Vector2i.LEFT: 1, Vector2i.RIGHT: 2, Vector2i.UP: 3}

static var _cache := {}


## Texture uit de cache (één keer laden; nooit in _process). null = bestand ontbreekt.
static func tex(path: String) -> Texture2D:
	if path == "":
		return null
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


static func dir_index(d: Vector2i) -> int:
	return int(DIR_INDEX.get(d, 0))


## Held-pose-sprite op node p (48x48-cellen, voeten op de onderrand).
static func _hero_anim(p: Node2D, t: Texture2D, hf: int, vf: int, frames: Array, ms: Array, anim_name := "SomAttackAnim") -> Anim:
	var old := p.get_node_or_null(anim_name)
	if old:
		old.finish_now()
		old.free()
	var a := Anim.new()
	a.name = anim_name
	a.texture = t
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.hframes = hf
	a.vframes = vf
	a.offset = Vector2(0, 8.0 - float(t.get_height() / vf) / 2.0)
	a.seq = frames
	a.ms = ms
	a.body = p.get_node_or_null("Sprite2D") as Sprite2D
	p.add_child(a)
	return a


## Aanval: rij = kijkrichting, kolommen = frames; treffer aan het begin van d["hit_frame"].
static func attack_anim(p: Node2D, t: Texture2D, d: Dictionary) -> Anim:
	var n := maxi(1, int(d.get("frames", 6)))
	var fr: Array = d.get("frame", [48, 48])
	var vf := maxi(1, t.get_height() / maxi(1, int(fr[1])))
	var row := mini(dir_index(p.facing), vf - 1)
	var frames: Array = []
	for i in n:
		frames.append(row * n + i)
	var ms: Array = d.get("ms", [])
	if ms.size() < n:
		ms = []
		for i in n:
			ms.append(int(1000.0 / float(d.get("fps", 16.0))))
	var a := _hero_anim(p, t, n, vf, frames, ms)
	a.hit_index = clampi(int(d.get("hit_frame", 1)) - 1, 0, n - 1)
	return a


## Spreuk: 3 kolommen x 4 rijen; frame 1, daarna 2-3 in een lus (SomData.CAST_MS).
static func cast_anim(p: Node2D, t: Texture2D) -> Anim:
	var row := dir_index(p.facing)
	var b := row * 3
	return _hero_anim(p, t, 3, 4, [b, b + 1, b + 2, b + 1, b + 2], SomData.CAST_MS, "SomCastAnim")


## Getroffen: 4 kolommen (richtingen) x 1 rij, één frame voor 'sec'.
static func hurt_pose(p: Node2D, t: Texture2D, sec: float) -> Anim:
	return _hero_anim(p, t, 4, 1, [dir_index(p.facing)], [int(sec * 1000.0)], "SomHurtAnim")


## KO (blijft liggen tot hij weer opstaat): los Sprite2D "SomKO"; lichaam verborgen.
static func set_ko(p: Node2D, t: Texture2D, on: bool) -> void:
	var k := p.get_node_or_null("SomKO") as Sprite2D
	var body := p.get_node_or_null("Sprite2D") as Sprite2D
	if on and k == null and t:
		k = Sprite2D.new()
		k.name = "SomKO"
		k.texture = t
		k.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		k.offset = Vector2(0, 8.0 - t.get_height() / 2.0)
		p.add_child(k)
	elif not on and k:
		k.free()
	if body and t:
		body.visible = not on


static func slash(parent: Node, at: Vector2, dir: Vector2) -> Node2D:
	var t := tex(SomData.FX_SLASH)
	if t:
		var a := Anim.new()
		a.name = "SomSlash"
		a.texture = t
		a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		a.hframes = 4
		a.seq = [0, 1, 2, 3]
		a.ms = [40, 40, 40, 40]
		a.position = at
		a.rotation = dir.angle()
		a.z_index = 20
		parent.add_child(a)
		return a
	var s := Slash.new()
	s.position = at
	s.rotation = dir.angle()
	s.z_index = 20
	parent.add_child(s)
	return s


static func spark(parent: Node, at: Vector2) -> void:
	var t := tex(SomData.FX_SPARK)
	if t == null:
		return
	var a := Anim.new()
	a.name = "SomSpark"
	a.texture = t
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.hframes = 4
	a.seq = [0, 1, 2, 3]
	a.ms = [50, 50, 50, 50]
	a.position = at
	a.z_index = 22
	parent.add_child(a)


## Rij in dmg_digits.png: 0 wit, 1 rood (schade aan de party), 2 groen (genezen).
static func _digit_row(color: Color) -> int:
	if color.g > color.r + 0.2:
		return 2
	if color.r > 0.9 and color.g < 0.6:
		return 1
	return 0


## Zwevend getal ("12", "+30") of "!" (telegraaf). Met art: pixel-cijfers / fx_telegraph; anders een Label.
static func number(parent: Node, at: Vector2, text: String, color: Color, life := 0.6) -> Node2D:
	var digits := tex(SomData.UI_DIGITS)
	var bang := tex(SomData.FX_TELEGRAPH)
	var n: Node2D
	if text == "!" and bang:
		var s := Sprite2D.new()
		s.texture = bang
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		n = s
	elif digits and text.trim_prefix("+").is_valid_int():
		var d := Digits.new()
		d.sheet = digits
		d.text = text.trim_prefix("+")
		d.row = _digit_row(color)
		n = d
	else:
		var holder := Node2D.new()
		var l := Label.new()
		l.theme = THEME
		l.text = text
		l.add_theme_color_override("font_color", color)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		l.add_theme_constant_override("outline_size", 2)
		l.add_theme_font_size_override("font_size", 8)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(32, 10)
		l.position = Vector2(-16, -6)
		holder.add_child(l)
		n = holder
	n.name = "SomNumber"
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.z_index = 30
	n.position = at.round()
	parent.add_child(n)
	var tw := n.create_tween()
	tw.tween_property(n, "position:y", n.position.y - 8.0, life)
	tw.parallel().tween_property(n, "modulate:a", 0.0, life).set_delay(life * 0.5)
	tw.tween_callback(n.queue_free)
	return n


## Frames afspelen met een eigen duur per frame (ms). seq = frame-indexen in de sheet.
class Anim extends Sprite2D:
	signal hit
	signal finished
	var seq: Array = [0]
	var ms: Array = [100]
	## Index in seq waarbij 'hit' valt (aan het begin van dat frame); -1 = geen.
	var hit_index := -1
	var body: Sprite2D
	## Verstreken tijd in ms (voor tests).
	var elapsed_ms := 0.0
	var index := 0
	var hit_done := false
	var hit_at_ms := -1.0
	var _done := false

	func _ready() -> void:
		frame = int(seq[0])
		if body:
			body.visible = false
		if hit_index == 0:
			_hit()

	func total_ms() -> float:
		var t := 0.0
		for m in ms:
			t += float(m)
		return t

	## Begin van frame i in ms.
	func start_of(i: int) -> float:
		var t := 0.0
		for k in mini(i, ms.size()):
			t += float(ms[k])
		return t

	func _process(delta: float) -> void:
		elapsed_ms += delta * 1000.0
		while index < seq.size() - 1 and elapsed_ms >= start_of(index + 1):
			index += 1
			frame = int(seq[index])
			if index == hit_index:
				_hit()
		if elapsed_ms >= total_ms():
			finish_now()
			queue_free()

	func _hit() -> void:
		if hit_done:
			return
		hit_done = true
		hit_at_ms = elapsed_ms
		hit.emit()

	func finish_now() -> void:
		if _done:
			return
		_done = true
		if hit_index >= 0 and not hit_done:
			_hit()
		if body and is_instance_valid(body) and body.get_parent().get_node_or_null("SomKO") == null:
			body.visible = true
		finished.emit()


class Digits extends Node2D:
	var sheet: Texture2D
	var text := ""
	var row := 0

	func _draw() -> void:
		var w := text.length() * 6 - 1
		var x := -w / 2
		for ch in text:
			var n := int(ch)
			draw_texture_rect_region(sheet, Rect2(x, -4, 5, 7), Rect2(n * 5, row * 7, 5, 7))
			x += 6


class Slash extends Node2D:
	var t := 0.0
	const LIFE := 0.15

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
		if t >= LIFE:
			queue_free()

	func _draw() -> void:
		var a := 1.0 - t / LIFE
		var c := PLACEHOLDER_COLOR
		c.a = a
		draw_arc(Vector2.ZERO, 8.0, -1.2, 1.2, 8, c, 2.0)
		draw_arc(Vector2.ZERO, 5.0, -0.9, 0.9, 6, Color(1, 1, 1, a), 1.0)


## Wapenmeter boven de bestuurde held: gauge_bar + gauge_fill (+ glinster als hij vol is).
class Gauge extends Node2D:
	var arena: Node
	var _t := 0.0
	var bar: Texture2D
	var fill: Texture2D
	var glint: Texture2D

	func _ready() -> void:
		z_index = 25
		name = "SomGauge"
		bar = _load_tex(SomData.UI_GAUGE_BAR)
		fill = _load_tex(SomData.UI_GAUGE_FILL)
		glint = _load_tex(SomData.UI_GAUGE_GLINT)

	static func _load_tex(p: String) -> Texture2D:
		return load(p) if ResourceLoader.exists(p) else null

	func _process(delta: float) -> void:
		if arena == null or not is_instance_valid(arena.player):
			return
		_t += delta
		position = arena.player.position + Vector2(0, -30)
		queue_redraw()

	func _draw() -> void:
		if arena == null:
			return
		var c: float = arena.charge
		if bar and fill:
			draw_texture(bar, Vector2(-9, 0))
			draw_texture_rect_region(fill, Rect2(-8, 1, roundf(16.0 * c), 2), Rect2(0, 0, roundf(16.0 * c), 2))
			if c >= 1.0 and glint:
				var f := int(_t * 6.0) % 2
				draw_texture_rect_region(glint, Rect2(-9, 0, 18, 4), Rect2(f * 18, 0, 18, 4))
			return
		draw_rect(Rect2(-9, 0, 18, 3), Color(0, 0, 0, 0.8))
		var col := Color(0.3, 0.9, 1.0) if c >= 1.0 else Color(1.0, 0.8, 0.2)
		draw_rect(Rect2(-8, 1, 16.0 * c, 1), col)
