extends Node2D
class_name GolemBossView
## D3 PR B: beeld voor de realtime Golem (sprites uit PR #341). Alleen tekenen, geen gameplay:
## gasten kunnen dit uit events/snapshots voeden; de host voedt het uit GolemFight (sync()).
##   - golem_boss_v2.png -> golem_boss_v2_damaged.png vanaf fase 2
##   - golem_core_open.png (2 frames) op de kern-rect zolang het venster open is
##   - telegraph_marker.png (3 frames = windup-voortgang) op het doel tijdens een windup
##   - phase_flash.png (4 frames) tijdens de 90 onkwetsbare ticks van een fasewissel

const GolemBoss := preload("res://scripts/som/golem_boss.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const GolemFight := preload("res://scripts/som/golem_fight.gd")

var body: Sprite2D
var core_glow: Sprite2D
var marker: Sprite2D
var flash: Sprite2D
var _phase := 0
var _windup_total := 1


func _init() -> void:
	body = _sprite(GolemBoss.SPRITE_NORMAL, 1)
	core_glow = _sprite(GolemBoss.SPRITE_CORE_OPEN, GolemBoss.SPRITE_CORE_OPEN_FRAMES)
	marker = _sprite(GolemBoss.SPRITE_TELEGRAPH, GolemBoss.SPRITE_TELEGRAPH_FRAMES)
	flash = _sprite(GolemBoss.SPRITE_PHASE_FLASH, GolemBoss.SPRITE_PHASE_FLASH_FRAMES)
	# kern-rect uit game_data (ongewijzigd): midden van [82,52,30,30] t.o.v. het midden van 196x182
	var r: Array = ((GameData.ENEMIES[GolemBoss.ENEMY_ID]["boss"] as Dictionary)["core"] as Dictionary).get("rect", [82, 52, 30, 30])
	core_glow.position = Vector2(float(r[0]) + float(r[2]) / 2.0 - 98.0, float(r[1]) + float(r[3]) / 2.0 - 91.0)
	for s in [body, core_glow, marker, flash]:
		add_child(s)
	core_glow.visible = false
	marker.visible = false
	flash.visible = false


static func _sprite(path: String, frames: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path) as Texture2D
	s.hframes = maxi(1, frames)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


## Alle #341-sprites laden en hebben de verwachte framebreedte.
static func textures_ok() -> bool:
	for pair in [[GolemBoss.SPRITE_TELEGRAPH, GolemBoss.SPRITE_TELEGRAPH_FRAMES], [GolemBoss.SPRITE_CORE_OPEN, GolemBoss.SPRITE_CORE_OPEN_FRAMES],
			[GolemBoss.SPRITE_PHASE_FLASH, GolemBoss.SPRITE_PHASE_FLASH_FRAMES], [GolemBoss.SPRITE_DAMAGED, 1]]:
		var tex := load(str(pair[0])) as Texture2D
		if tex == null or tex.get_width() % int(pair[1]) != 0:
			return false
	return true


## Host: beeld uit de staat van het gevecht. target_px = doelpositie van de telegraaf (lokaal).
func sync(fight, target_px: Vector2 = Vector2.ZERO) -> void:
	var ph: int = fight.phase_index()
	if ph != _phase:
		_phase = ph
		body.texture = load(GolemBoss.SPRITE_DAMAGED if ph >= 1 else GolemBoss.SPRITE_NORMAL) as Texture2D
	core_glow.visible = fight.core.open
	if core_glow.visible:
		core_glow.frame = (fight.tick_no / 8) % GolemBoss.SPRITE_CORE_OPEN_FRAMES
	var in_windup: bool = fight.step == GolemFight.Step.WINDUP
	marker.visible = in_windup
	if in_windup:
		_windup_total = maxi(_windup_total, int(fight.step_left))
		var done := 1.0 - float(fight.step_left) / float(maxi(1, _windup_total))
		marker.frame = clampi(int(done * GolemBoss.SPRITE_TELEGRAPH_FRAMES), 0, GolemBoss.SPRITE_TELEGRAPH_FRAMES - 1)
		marker.position = target_px
	else:
		_windup_total = 1
	flash.visible = fight.is_invulnerable()
	if flash.visible:
		var left: int = fight.pm._invuln_ticks
		var t := 1.0 - float(left) / float(fight.pm.INVULN_TICKS)
		flash.frame = clampi(int(t * GolemBoss.SPRITE_PHASE_FLASH_FRAMES), 0, GolemBoss.SPRITE_PHASE_FLASH_FRAMES - 1)
