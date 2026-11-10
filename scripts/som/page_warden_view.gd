extends Node2D
class_name PageWardenView
## Beeld voor de realtime Page Warden. Alleen tekenen.
## Lichaam = bestaande page_warden.png. Aanval, fase 2, treffer en pagina-projectiel
## zijn placeholders (magenta hoek + PH) tot RPG ART ze vervangt.
## Telegraafvorm zelf tekent TelegraphLayer vanuit TelegraphAttack; hier alleen lichaam,
## faseflits en de pagina's tijdens het stagger-venster.

const PageWardenBoss := preload("res://scripts/som/page_warden_boss.gd")
const PageWardenFight := preload("res://scripts/som/page_warden_fight.gd")
const BossPhaseMachine := preload("res://scripts/som/boss_phase_machine.gd")

const TEX_BODY := preload("res://assets/sprites/enemies/page_warden.png")
const TEX_ATTACK := preload("res://assets/sprites/bosses/page_warden_attack_ph.png")
const TEX_HIT := preload("res://assets/sprites/bosses/page_warden_hit_ph.png")
const TEX_PHASE2 := preload("res://assets/sprites/bosses/page_warden_phase2_ph.png")
const TEX_PAGE := preload("res://assets/sprites/bosses/page_warden_page_ph.png")
const TEX_FLASH := preload("res://assets/sprites/bosses/phase_flash.png")

var body: Sprite2D
var hit: Sprite2D
var flash: Sprite2D
var _pages: Array = []
var _phase := 0


func _init() -> void:
	body = _sprite(TEX_BODY, 1)
	hit = _sprite(TEX_HIT, 1)
	flash = _sprite(TEX_FLASH, PageWardenBoss.SPRITE_PHASE_FLASH_FRAMES)
	add_child(body)
	add_child(hit)
	add_child(flash)
	hit.visible = false
	flash.visible = false
	for i in 3:
		var p := _sprite(TEX_PAGE, 1)
		p.visible = false
		add_child(p)
		_pages.append(p)
	# 256 px breed → ongeveer 64 px op de kaart. Geen shader.
	scale = Vector2(0.25, 0.25)


static func _sprite(tex: Texture2D, frames: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = maxi(1, frames)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


static func textures_ok() -> bool:
	if TEX_BODY == null or TEX_BODY.get_width() != 256 or TEX_BODY.get_height() != 200:
		return false
	if TEX_ATTACK == null or TEX_ATTACK.get_width() != 512 or TEX_ATTACK.get_height() != 200:
		return false
	if TEX_HIT == null or TEX_HIT.get_width() != 256 or TEX_PHASE2 == null or TEX_PHASE2.get_width() != 256:
		return false
	if TEX_PAGE == null or TEX_PAGE.get_width() != 16 or TEX_PAGE.get_height() != 16:
		return false
	return _corner_marked(TEX_HIT) and _corner_marked(TEX_PHASE2) and _corner_marked(TEX_PAGE) and _corner_marked(TEX_ATTACK)


static func _corner_marked(tex: Texture2D) -> bool:
	var img := tex.get_image()
	if img == null:
		return false
	var c := img.get_pixel(0, 0)
	return is_equal_approx(c.r, 1.0) and c.g < 0.2 and c.b > 0.8


## Host: beeld uit het gevecht. Geen allocatie; de pagina-sprites zijn een vaste pool van 3.
func sync(fight: PageWardenFight) -> void:
	var ph := fight.phase_index()
	if ph != _phase:
		_phase = ph
	var attacking := fight.step == PageWardenFight.Step.WINDUP or fight.step == PageWardenFight.Step.ACTIVE
	if attacking:
		body.texture = TEX_ATTACK
		body.hframes = PageWardenBoss.SPRITE_ATTACK_FRAMES
		body.frame = 1 if fight.step == PageWardenFight.Step.ACTIVE else 0
	else:
		body.texture = TEX_PHASE2 if ph >= 1 else TEX_BODY
		body.hframes = 1
		body.frame = 0
	hit.visible = fight.step == PageWardenFight.Step.ACTIVE or fight.step == PageWardenFight.Step.STAGGER
	flash.visible = fight.is_invulnerable()
	if flash.visible:
		var left := int(fight.pm._invuln_ticks)
		var t := 1.0 - float(left) / float(BossPhaseMachine.INVULN_TICKS)
		flash.frame = clampi(int(t * PageWardenBoss.SPRITE_PHASE_FLASH_FRAMES), 0, PageWardenBoss.SPRITE_PHASE_FLASH_FRAMES - 1)
	var show_pages := fight.core.open or (str(fight.attack_id) == "page_fan" and fight.step == PageWardenFight.Step.WINDUP)
	var i := 0
	for p in _pages:
		var s: Sprite2D = p
		s.visible = show_pages
		if show_pages:
			var ang := float(i) * TAU / 3.0 + float(fight.tick_no) * 0.08
			s.position = Vector2(cos(ang), sin(ang)) * 70.0
		i += 1
