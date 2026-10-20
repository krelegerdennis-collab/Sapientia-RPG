extends RefCounted
## SoM-proef: PLACEHOLDER-effecten, in code getekend (geen art-bestanden). Magenta = placeholder.
## - slash(): boogje voor de speler (echte aanvalsanimatie komt van RPG ART)
## - number(): zwevend schadegetal / "!" (telegraaf)
## - Gauge: wapenmeter boven het hoofd van de speler (SoM-stijl, % als hij nog niet vol is)

const THEME := preload("res://assets/theme.tres")
const PLACEHOLDER_COLOR := Color("ff1ee6")


static func slash(parent: Node, at: Vector2, dir: Vector2) -> Node2D:
	var s := Slash.new()
	s.position = at
	s.rotation = dir.angle()
	s.z_index = 20
	parent.add_child(s)
	return s


## Aanvalsanimatie van RPG ART (SomData.ATTACK_ANIMS) over de speler-sprite; die is zolang verborgen.
## Sheet: rijen onder/links/rechts/boven, kolommen = frames; voeten op de onderrand.
static func attack_anim(p: Node2D, tex: Texture2D, d: Dictionary) -> Sprite2D:
	var fr: Array = d.get("frame", [48, 48])
	var n := maxi(1, int(d.get("frames", 4)))
	var a := AttackAnim.new()
	a.name = "SomAttackAnim"
	a.texture = tex
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.hframes = n
	a.vframes = maxi(1, tex.get_height() / maxi(1, int(fr[1])))
	a.offset = Vector2(0, 8.0 - float(fr[1]) / 2.0)
	var rows := {Vector2i.DOWN: 0, Vector2i.LEFT: 1, Vector2i.RIGHT: 2, Vector2i.UP: 3}
	a.row = mini(int(rows.get(p.facing, 0)), a.vframes - 1)
	a.fps = float(d.get("fps", 16.0))
	a.body = p.get_node_or_null("Sprite2D") as Sprite2D
	var old := p.get_node_or_null("SomAttackAnim")
	if old:
		old.free()
	p.add_child(a)
	return a


static func number(parent: Node, at: Vector2, text: String, color: Color, life := 0.6) -> Label:
	var l := Label.new()
	l.theme = THEME
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 2)
	l.add_theme_font_size_override("font_size", 8)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.z_index = 30
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(32, 10)
	l.position = (at - Vector2(16, 6)).round()
	l.name = "SomNumber"
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 8.0, life)
	tw.parallel().tween_property(l, "modulate:a", 0.0, life).set_delay(life * 0.5)
	tw.tween_callback(l.queue_free)
	return l


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


class Gauge extends Node2D:
	var arena: Node

	func _ready() -> void:
		z_index = 25
		name = "SomGauge"

	func _process(_delta: float) -> void:
		if arena == null or not is_instance_valid(arena.player):
			return
		position = arena.player.position + Vector2(0, -30)
		queue_redraw()

	func _draw() -> void:
		if arena == null:
			return
		var c: float = arena.charge
		draw_rect(Rect2(-9, 0, 18, 3), Color(0, 0, 0, 0.8))
		var col := Color(0.3, 0.9, 1.0) if c >= 1.0 else Color(1.0, 0.8, 0.2)
		draw_rect(Rect2(-8, 1, 16.0 * c, 1), col)
		if c < 1.0:
			var f: Font = THEME.default_font if THEME.default_font else ThemeDB.fallback_font
			draw_string(f, Vector2(-8, -1), "%d%%" % int(c * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 16, 6, Color(1, 1, 1))


class AttackAnim extends Sprite2D:
	var row := 0
	var fps := 16.0
	var t := 0.0
	var body: Sprite2D

	func _ready() -> void:
		frame = row * hframes
		if body:
			body.visible = false

	func _process(delta: float) -> void:
		t += delta
		var i := int(t * fps)
		if i >= hframes:
			if body:
				body.visible = true
			queue_free()
			return
		frame = row * hframes + i
