extends RefCounted
## Client-only hit-react: witte flits (hurt kolom 0 of shader), squash, visuele duw via offset.
## Raakt sim-position en knockback niet aan.

const SomData := preload("res://scripts/data/som_data.gd")
const SomGameFeelData := preload("res://scripts/data/som_gamefeel_data.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
const META_KEY := &"som_hitreact"
const FLASH_SHADER := preload("res://assets/shaders/som_hit_flash.gdshader")
const FOOT_PIVOT := 8.0
const WorldSfx := preload("res://scripts/audio/world_sfx.gd")


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
			"flash_mat": null,
		})
	return m.get_meta(META_KEY)


static func active(m: Node) -> bool:
	return float(_state(m)["t"]) >= 0.0


static func contact_flash_active(m: Node) -> bool:
	var st: Dictionary = _state(m)
	return float(st["t"]) >= 0.0 and float(st["t"]) < SomData.HIT_FLASH_CONTACT * 1000.0


## Klap is dodelijk als de vijand-dict een hp heeft en die op of onder 0 staat (damage_enemy trekt hp eerst af).
static func hurt_is_lethal(e: Dictionary) -> bool:
	return e.has("hp") and int(e["hp"]) <= 0


static func trigger(arena, m: Node, e: Dictionary, dir: Vector2i, weight: String, finisher_or_heavy: bool, full_hurt_pose: bool) -> void:
	if m == null or m.sprite == null:
		return
	# post-RC sfx: niet-dodelijke treffer (de doodsslag: SomDeathGlitch). Begrensd door het manifest:
	# enemy_hurt min_interval_ms 80 (AudioManager.play_sfx, globaal per sleutel) = max 1 per ~5 ticks.
	# CO-OP: alleen de HOST hoort dit (damage_enemy draait niet op de gast; die zet hp uit de
	# snapshot in SomArena.apply_coop_snapshot). Netcode-follow-up: gast-sfx.
	# Dodelijke klap (hp <= 0): geen enemy_hurt, het death-pad (SomDeathGlitch) speelt enemy_death.
	if not hurt_is_lethal(e):
		WorldSfx.play(WorldSfx.ENEMY_HURT)
	var st := _state(m)
	st["t"] = 0.0
	st["dir"] = dir
	st["weight"] = weight
	st["heavy_squash"] = weight == "zwaar" and finisher_or_heavy
	st["sprite_off0"] = m.sprite.offset
	var flash_mat: ShaderMaterial = st.get("flash_mat")
	if m.sprite.material != flash_mat:
		st["saved_mat"] = m.sprite.material
	st["had_shader"] = false
	if _has_hurt_sheet(m):
		if full_hurt_pose:
			arena._monster_pose(m, e, "hurt", 0, arena._hurt_seconds())
		else:
			arena._monster_pose(m, e, "hurt", 0, SomData.HIT_FLASH_CONTACT)
	else:
		_ensure_flash_mat(m, st)
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
	var row := mini(SomFx.dir_index(m.facing), m.sprite.vframes - 1)
	m.sprite.frame = row * m.sprite.hframes + 0
	e["pose_el"] = 0.0
	return true


static func _hitstop_ticks(m: Node) -> int:
	if m == null:
		return 0
	var room: Variant = m.get("room")
	if room == null:
		return 0
	var som: Variant = room.get("som")
	if som == null or not som.get("enemies").has(m):
		return 0
	return int(som.enemies[m].get("hitstop", 0))


static func tick(m: Node, delta: float) -> void:
	if m == null or m.sprite == null or not m.has_meta(META_KEY):
		return
	var st: Dictionary = _state(m)
	var t_ms := float(st["t"])
	if t_ms < 0.0:
		return
	if _hitstop_ticks(m) <= 0:
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
	var off0: Vector2 = st["sprite_off0"]
	var off_y := (off0.y + FOOT_PIVOT) / sc.y - FOOT_PIVOT
	var nudge_v := Vector2.ZERO
	if st["dir"] != Vector2i.ZERO:
		var dir := Vector2(st["dir"]).normalized()
		var nudge := SomGameFeelData.nudge_px(weight, t_ms)
		# Hele pixels (pixel-perfect), ook diagonaal: geen sub-pixel jitter.
		nudge_v = (dir * nudge).round()
	m.sprite.offset = Vector2(off0.x + nudge_v.x, off_y + nudge_v.y)
	if not _has_hurt_sheet(m):
		_apply_shader_flash(m, st, 1.0 if t_ms < SomData.HIT_FLASH_CONTACT * 1000.0 else 0.0)
	m.set_meta(META_KEY, st)


static func _ensure_flash_mat(m: Node, st: Dictionary) -> void:
	var mat: ShaderMaterial = st.get("flash_mat")
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = FLASH_SHADER
		st["flash_mat"] = mat
	if m.sprite.material != mat:
		m.sprite.material = mat
	st["had_shader"] = true


static func _apply_shader_flash(m: Node, st: Dictionary, amount: float) -> void:
	_ensure_flash_mat(m, st)
	var mat: ShaderMaterial = st["flash_mat"]
	mat.set_shader_parameter("flash", amount)


static func _finish(m: Node, st: Dictionary) -> void:
	st["t"] = -1.0
	m.sprite.scale = Vector2.ONE
	m.sprite.offset = st["sprite_off0"]
	if bool(st.get("had_shader", false)):
		var mat: ShaderMaterial = st.get("flash_mat")
		if mat != null:
			mat.set_shader_parameter("flash", 0.0)
		m.sprite.material = st.get("saved_mat")
		st["had_shader"] = false