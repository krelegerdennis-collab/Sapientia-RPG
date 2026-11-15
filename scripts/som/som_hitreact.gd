extends RefCounted
## Client-only hit-react: witte flits (hurt kolom 0 of shader), squash, visuele duw via offset.
## Raakt sim-position en knockback niet aan.

const SomData := preload("res://scripts/data/som_data.gd")
const SomGameFeelData := preload("res://scripts/data/som_gamefeel_data.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
const META_KEY := &"som_hitreact"
const FLASH_SHADER := preload("res://assets/shaders/som_hit_flash.gdshader")
const CELL_H := 16.0

static var _shader_cache: ShaderMaterial


static func _state(m: Node) -> Dictionary:
	if not m.has_meta(META_KEY):
		m.set_meta(META_KEY, {
			"t": -1.0,
			"dir": Vector2i.ZERO,
			"weight": "middel",
			"heavy_squash": false,
			"sprite_off0": Vector2.ZERO,
			"had_shader": false,
			"saved_mat": null,
		})
	return m.get_meta(META_KEY)


static func active(m: Node) -> bool:
	return float(_state(m)["t"]) >= 0.0


static func contact_flash_active(m: Node) -> bool:
	var st: Dictionary = _state(m)
	return float(st["t"]) >= 0.0 and float(st["t"]) < SomData.HIT_FLASH_CONTACT * 1000.0


static func trigger(arena, m: Node, e: Dictionary, dir: Vector2i, weight: String, finisher_or_heavy: bool, full_hurt_pose: bool) -> void:
	if m == null or m.sprite == null:
		return
	var st := _state(m)
	st["t"] = 0.0
	st["dir"] = dir
	st["weight"] = weight
	st["heavy_squash"] = weight == "zwaar" and finisher_or_heavy
	st["sprite_off0"] = m.sprite.offset
	st["had_shader"] = false
	st["saved_mat"] = m.sprite.material
	if _has_hurt_sheet(m):
		if full_hurt_pose:
			arena._monster_pose(m, e, "hurt", 0, arena._hurt_seconds())
		else:
			arena._monster_pose(m, e, "hurt", 0, SomData.HIT_FLASH_CONTACT)
	else:
		_apply_shader_flash(m, st, 1.0)
	m.set_meta(META_KEY, st)


static func _has_hurt_sheet(m: Node) -> bool:
	if m.placeholder or m.size != Vector2i.ONE:
		return false
	var t := SomFx.tex(SomData.MONSTER_SHEET_DIR + str(m.enemy_id) + "_hurt.png")
	return t != null


static func force_hurt_flash_frame(m: Node, e: Dictionary) -> bool:
	if not contact_flash_active(m):
		return false
	if str(e.get("pose", "")) != "hurt":
		return false
	if m.sprite == null:
		return false
	var hms: Array = SomData.MONSTER_SHEETS["hurt"]["ms"]
	var row := mini(SomFx.dir_index(m.facing), m.sprite.vframes - 1)
	m.sprite.frame = row * m.sprite.hframes + 0
	e["pose_el"] = 0.0
	return true


static func tick(m: Node, delta: float) -> void:
	if m == null or m.sprite == null or not m.has_meta(META_KEY):
		return
	var st: Dictionary = _state(m)
	var t_ms := float(st["t"])
	if t_ms < 0.0:
		return
	t_ms += delta * 1000.0
	st["t"] = t_ms
	if t_ms > 270.0:
		_finish(m, st)
		m.set_meta(META_KEY, st)
		return
	var weight := str(st["weight"])
	var phase := SomGameFeelData.squash_phase(t_ms)
	var sc := SomGameFeelData.squash_for(weight, phase, bool(st["heavy_squash"]))
	m.sprite.scale = sc
	var foot_y := _foot_offset_y(sc.y)
	var nudge := SomGameFeelData.nudge_px(weight, t_ms)
	var dx := float(st["dir"].x)
	if dx == 0.0:
		dx = float(st["dir"].y)
	var off0: Vector2 = st["sprite_off0"]
	m.sprite.offset = off0 + Vector2(dx * nudge, foot_y)
	if not _has_hurt_sheet(m):
		_apply_shader_flash(m, st, 1.0 if t_ms < SomData.HIT_FLASH_CONTACT * 1000.0 else 0.0)
	m.set_meta(META_KEY, st)


static func _foot_offset_y(scale_y: float) -> float:
	return -CELL_H * 0.5 * (1.0 - scale_y)


static func _apply_shader_flash(m: Node, st: Dictionary, amount: float) -> void:
	if _shader_cache == null:
		_shader_cache = ShaderMaterial.new()
		_shader_cache.shader = FLASH_SHADER
	if st.get("had_shader", false) == false and amount > 0.0:
		st["had_shader"] = true
		m.sprite.material = _shader_cache
	_shader_cache.set_shader_parameter("flash", amount)


static func _finish(m: Node, st: Dictionary) -> void:
	st["t"] = -1.0
	m.sprite.scale = Vector2.ONE
	m.sprite.offset = st["sprite_off0"]
	if bool(st.get("had_shader", false)):
		m.sprite.material = st.get("saved_mat")
		st["had_shader"] = false
	if _shader_cache != null:
		_shader_cache.set_shader_parameter("flash", 0.0)