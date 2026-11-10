extends Node2D
class_name PageWardenView
## Beeld voor de realtime Page Warden. Alleen tekenen.
## Lichaam = page_warden.png; aanval, fase 2, treffer en pagina uit assets/sprites/bosses/.
## Voetenanker (128, 194) ligt op de oorsprong, zodat een framewissel niet verspringt.
## De vliegende pagina zit op een eigen node die de 0,25-lichaamsschaal opheft (16×16).
## Telegraafvorm tekent TelegraphLayer; hier alleen lichaam, faseflits en pagina's.

const PageWardenBoss := preload("res://scripts/som/page_warden_boss.gd")
const PageWardenFight := preload("res://scripts/som/page_warden_fight.gd")
const BossPhaseMachine := preload("res://scripts/som/boss_phase_machine.gd")

const TEX_BODY := preload("res://assets/sprites/enemies/page_warden.png")
const TEX_ATTACK := preload("res://assets/sprites/bosses/page_warden_attack_ph.png")
const TEX_HIT := preload("res://assets/sprites/bosses/page_warden_hit_ph.png")
const TEX_PHASE2 := preload("res://assets/sprites/bosses/page_warden_phase2_ph.png")
const TEX_PAGE := preload("res://assets/sprites/bosses/page_warden_page_ph.png")
const TEX_FLASH := preload("res://assets/sprites/bosses/phase_flash.png")

## Pixel van de voeten in elk 256×200-frame. Zelfde punt bij idle, aanval en fase 2.
const FEET := Vector2(128, 194)
const BODY_SCALE := 0.25
## Straal van de pagina's in kaartpixels (de projectiel-node staat op schaal 1).
const PAGE_RADIUS := 36.0

var body: Sprite2D
var hit: Sprite2D
var flash: Sprite2D
var projectiles: Node2D
var _pages: Array = []
var _phase := 0


func _init() -> void:
	body = _sprite(TEX_BODY, 1)
	hit = _sprite(TEX_HIT, 1)
	flash = _sprite(TEX_FLASH, PageWardenBoss.SPRITE_PHASE_FLASH_FRAMES)
	_anchor_feet(body)
	_anchor_feet(hit)
	add_child(body)
	add_child(hit)
	add_child(flash)
	hit.visible = false
	flash.visible = false
	# Flits op het midden van het lijf, niet op de voeten.
	flash.position = Vector2(0, -(FEET.y - 100.0))
	# 256 px breed → ongeveer 64 px op de kaart. Geen shader.
	scale = Vector2(BODY_SCALE, BODY_SCALE)
	projectiles = Node2D.new()
	projectiles.name = "PageProjectiles"
	# Tegenschaal: pagina blijft 16×16, los van het lijf.
	projectiles.scale = Vector2.ONE / BODY_SCALE
	add_child(projectiles)
	for i in 3:
		var p := _sprite(TEX_PAGE, 1)
		p.visible = false
		projectiles.add_child(p)
		_pages.append(p)


static func _sprite(tex: Texture2D, frames: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = maxi(1, frames)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


## Laden + maten. Geen kleurcheck: de platen komen binnen op deze bestandsnamen.
static func textures_ok() -> bool:
	if TEX_BODY == null or TEX_BODY.get_width() != 256 or TEX_BODY.get_height() != 200:
		return false
	if TEX_ATTACK == null or TEX_ATTACK.get_width() != 512 or TEX_ATTACK.get_height() != 200:
		return false
	if TEX_HIT == null or TEX_HIT.get_width() != 256 or TEX_HIT.get_height() != 200:
		return false
	if TEX_PHASE2 == null or TEX_PHASE2.get_width() != 256 or TEX_PHASE2.get_height() != 200:
		return false
	if TEX_PAGE == null or TEX_PAGE.get_width() != 16 or TEX_PAGE.get_height() != 16:
		return false
	return true


## Waar pixel FEET van dit frame landt, in de lokale ruimte van de sprite.
static func frame_feet_local(s: Sprite2D) -> Vector2:
	if s == null or s.texture == null:
		return Vector2.INF
	var fw := float(s.texture.get_width()) / float(maxi(1, s.hframes))
	var fh := float(s.texture.get_height()) / float(maxi(1, s.vframes))
	var top_left := s.offset
	if s.centered:
		top_left -= Vector2(fw, fh) * 0.5
	return top_left + FEET


static func _anchor_feet(s: Sprite2D) -> void:
	s.centered = false
	s.offset = -FEET


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
	_anchor_feet(body)
	# Trefferflits alleen bij stagger en recovery. Tijdens ACTIVE blijft het slagframe zichtbaar.
	hit.visible = fight.step == PageWardenFight.Step.STAGGER or fight.step == PageWardenFight.Step.RECOVERY
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
			s.position = Vector2(cos(ang), sin(ang)) * PAGE_RADIUS
		i += 1
