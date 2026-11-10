extends Sprite2D
## WM1 HD-2D lichtprops: onderkant-midden anker, 8 fps sheet, optionele voet-collision.

const FEET: Dictionary = {
	"archief_kandelaber": Vector2i(8, 4),
	"archief_wandblaker": Vector2i.ZERO,
	"archief_wandblaker_glow": Vector2i.ZERO,
	"archief_leeslamp": Vector2i.ZERO,
	"archief_leeslamp_glow": Vector2i.ZERO,
	"kas_gloeipot": Vector2i.ZERO,
	"kas_gloeipot_glow": Vector2i.ZERO,
	"kas_gloeiplant": Vector2i(10, 4),
	"kas_gloeiknoppen": Vector2i.ZERO,
	"warper_wandlamp": Vector2i.ZERO,
	"warper_wandlamp_violet": Vector2i.ZERO,
	"warper_kristalzuil": Vector2i(10, 4),
	"woud_gloeizwammen": Vector2i.ZERO,
	"woud_lantaarnpaal": Vector2i(6, 4),
	"woud_waterlelie": Vector2i.ZERO,
	"bouw_stormlamp": Vector2i(6, 4),
	"bouw_stormlamp_glow": Vector2i(6, 4),
	"bouw_vuurkorf": Vector2i(10, 4),
	"binnen_wandlamp": Vector2i.ZERO,
	"binnen_kandelaar": Vector2i.ZERO,
	"wk_kampvuur": Vector2i.ZERO,
	"wk_baken": Vector2i.ZERO,
	"wk_kristal": Vector2i.ZERO,
}

const ANIM_FPS := 8.0

@export var prop_id: String = ""

var _anim_t := 0.0


func _ready() -> void:
	centered = false
	_apply_offset()
	_foot_collision()


func _apply_offset() -> void:
	if texture == null:
		return
	var fw := float(texture.get_width()) / maxf(1.0, float(hframes))
	var fh := float(texture.get_height()) / maxf(1.0, float(vframes))
	offset = Vector2(-fw / 2.0, -fh)


func _pid() -> String:
	if not prop_id.is_empty():
		return prop_id
	var p := name
	if p.begins_with("Lp_"):
		return p.get_slice("_", 1)
	return p


func _foot_collision() -> void:
	var foot: Vector2i = FEET.get(_pid(), Vector2i.ZERO)
	if foot == Vector2i.ZERO:
		return
	var body := StaticBody2D.new()
	body.name = "Foot"
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(foot)
	cs.shape = rect
	cs.position = Vector2(0.0, -float(foot.y) / 2.0)
	body.add_child(cs)
	add_child(body)


func _process(delta: float) -> void:
	if hframes <= 1 and vframes <= 1:
		return
	_anim_t += delta
	if _anim_t < 1.0 / ANIM_FPS:
		return
	_anim_t = 0.0
	frame = (frame + 1) % hframes
