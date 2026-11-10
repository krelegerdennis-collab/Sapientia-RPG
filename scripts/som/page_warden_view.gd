extends Node2D
class_name PageWardenView
## Beeld voor de realtime Page Warden. Alleen tekenen.
## Lichaam, aanval, fase 2, treffer en pagina: definitieve art van RPG ART.
## De *_ph.png-namen zijn historisch; de paden blijven (handwerk).
## Voetenanker (128, 194) ligt op de oorsprong, zodat een framewissel niet verspringt.
## De vliegende pagina zit op een eigen node die de 0,25-lichaamsschaal opheft (16×16).
## Telegraafvorm tekent TelegraphLayer; hier alleen lichaam, faseflits en pagina's.

const PageWardenBoss := preload("res://scripts/som/page_warden_boss.gd")
const PageWardenFight := preload("res://scripts/som/page_warden_fight.gd")
const BossPhaseMachine := preload("res://scripts/som/boss_phase_machine.gd")
const TelegraphState := preload("res://scripts/som/telegraph_state.gd")

const TEX_BODY := preload("res://assets/sprites/enemies/page_warden.png")
## *_ph.png is historisch; dit is definitieve art van RPG ART.
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
## Bestaand pose-byte in de vijand-snapshot. Alleen de co-op Page Warden zet bits;
## andere vijanden blijven 0. Formaat (20 bytes) groeit niet.
const POSE_HIT := 1
const POSE_ORBIT := 2
const POSE_FLASH := 4
const POSE_FRAME_SHIFT := 3

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


## Laden + maten, inclusief de hoogte van hit en fase 2. Geen kleurcheck.
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
	var attacking := fight.step == PageWardenFight.Step.WINDUP or fight.step == PageWardenFight.Step.ACTIVE
	var show_hit := fight.step == PageWardenFight.Step.STAGGER or fight.step == PageWardenFight.Step.RECOVERY
	var show_pages := fight.core.open or (str(fight.attack_id) == "page_fan" and fight.step == PageWardenFight.Step.WINDUP)
	var flash_on := fight.is_invulnerable()
	var flash_t := 0.0
	if flash_on:
		var left := int(fight.pm._invuln_ticks)
		flash_t = 1.0 - float(left) / float(BossPhaseMachine.INVULN_TICKS)
	_paint(fight.phase_index(), attacking, 1 if fight.step == PageWardenFight.Step.ACTIVE else 0,
			show_hit, show_pages, fight.tick_no, flash_on, flash_t)


## Gast: platen uit de snapshot. phase = telegraaf (WINDUP/ACTIVE/RECOVERY).
## pose = stagger-flits, kern-pagina's en faseflits. Geen fight, geen RNG.
func sync_guest(boss_phase: int, tele_phase: int, attack_id: String, orbit_tick: int, pose: int = 0) -> void:
	var windup := tele_phase == TelegraphState.State.WINDUP
	var active := tele_phase == TelegraphState.State.ACTIVE
	var recovery := tele_phase == TelegraphState.State.RECOVERY
	var show_hit := (recovery or (pose & POSE_HIT) != 0) and not windup and not active
	var show_pages := (attack_id == "page_fan" and windup) or (pose & POSE_ORBIT) != 0
	var flash_on := (pose & POSE_FLASH) != 0
	var flash_t := 0.0
	if flash_on:
		var frame := (pose >> POSE_FRAME_SHIFT) & 3
		flash_t = float(frame) / float(PageWardenBoss.SPRITE_PHASE_FLASH_FRAMES)
	_paint(boss_phase, windup or active, 1 if active else 0, show_hit, show_pages, orbit_tick, flash_on, flash_t)


func _paint(boss_phase: int, attacking: bool, strike_frame: int, show_hit: bool, show_pages: bool, orbit_tick: int, flash_on: bool, flash_t: float) -> void:
	_phase = boss_phase
	if attacking:
		body.texture = TEX_ATTACK
		body.hframes = PageWardenBoss.SPRITE_ATTACK_FRAMES
		body.frame = strike_frame
	else:
		body.texture = TEX_PHASE2 if boss_phase >= 1 else TEX_BODY
		body.hframes = 1
		body.frame = 0
	_anchor_feet(body)
	# Trefferflits bij stagger (host) en recovery. Tijdens ACTIVE blijft het slagframe zichtbaar.
	hit.visible = show_hit
	flash.visible = flash_on
	if flash_on:
		flash.frame = clampi(int(flash_t * PageWardenBoss.SPRITE_PHASE_FLASH_FRAMES), 0, PageWardenBoss.SPRITE_PHASE_FLASH_FRAMES - 1)
	var i := 0
	for p in _pages:
		var s: Sprite2D = p
		s.visible = show_pages
		if show_pages:
			var ang := float(i) * TAU / 3.0 + float(orbit_tick) * 0.08
			s.position = Vector2(cos(ang), sin(ang)) * PAGE_RADIUS
		i += 1
