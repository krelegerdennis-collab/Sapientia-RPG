extends Node2D
## Eén val in een VALKAMER van de Diepe Grot (grot_kamers.png rij 0). Loopbaar (geen botsing);
## dungeon100_room.gd roept trigger() aan als de speler erop stapt. Verborgen vallen zijn bijna
## onzichtbaar (alleen de "verborgen"-tegel), na het afgaan blijven ze zichtbaar.
## Besluit Dennis 14 okt 2026: een verborgen val FLITST kort (gloed + zichtbare tegel) zodra de speler
## binnen GrotKamers.VAL_FLITS_BEREIK tegels komt; opnieuw pas na weglopen en terugkomen.
## Schade: GrotKamers.val_schade (spijker 5-10% / rune 10% max HP per held, nooit dodelijk).

const Kamers := preload("res://scripts/data/grot_kamers.gd")

var soort := "spijker"
var verborgen := false
var afgegaan := false
var tile := Vector2i.ZERO
var anim: AnimatedSprite2D
## Flits loopt (voor de tests) / de speler is nog in de buurt (geen nieuwe flits tot hij weg is).
var flitsend := false
var in_buurt := false
var flitsen := 0
const FLITS_TIJD := 0.6
const FLITS_KLEUR := Color(1.6, 0.7, 1.6)


static func create(d: Dictionary) -> Node2D:
	var v: Node2D = (load("res://scripts/dungeon/dungeon100_val.gd") as GDScript).new()
	v.set("soort", str(d.get("soort", "spijker")))
	v.set("verborgen", bool(d.get("verborgen", false)))
	var t: Vector2i = d.get("tile", Vector2i.ZERO)
	v.set("tile", t)
	v.position = Vector2(t) * 16.0 + Vector2(8, 1)     # y bovenaan de tegel: y-sort onder de speler
	v.name = "Val_%d_%d" % [t.x, t.y]
	return v


func _ready() -> void:
	add_to_group("grot_val")
	var cfg: Dictionary = Kamers.VALLEN.get(soort, Kamers.VALLEN["spijker"])
	var frames := SpriteFrames.new()
	frames.add_animation("verborgen")
	frames.add_frame("verborgen", Kamers.tegel(int(cfg["verborgen"]), 0))
	frames.add_animation("zichtbaar")
	frames.add_frame("zichtbaar", Kamers.tegel(int(cfg["zichtbaar"]), 0))
	frames.add_animation("actief")
	frames.set_animation_loop("actief", soort == "rune")
	frames.set_animation_speed("actief", 8.0)
	for c in cfg["actief"]:
		frames.add_frame("actief", Kamers.tegel(int(c), 0))
	if frames.has_animation("default"):
		frames.remove_animation("default")
	anim = AnimatedSprite2D.new()
	anim.name = "Anim"
	anim.sprite_frames = frames
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	anim.offset = Vector2(0, 7)
	add_child(anim)
	anim.play("verborgen" if verborgen else "zichtbaar")


## Gaat af: schade aan de levende party, animatie, en geeft de schade per held terug.
func trigger() -> Array[int]:
	var uit: Array[int] = []
	var rol := float(posmod(tile.x * 73 + tile.y * 19, 100)) / 100.0
	for h in GameState.party:
		if not (h is Dictionary) or int(h.get("hp", 0)) <= 0:
			uit.append(0)
			continue
		var dmg := Kamers.val_schade(soort, int(h.get("max_hp", 1)), int(h.get("hp", 0)), rol)
		h["hp"] = int(h["hp"]) - dmg
		uit.append(dmg)
	afgegaan = true
	verborgen = false
	if anim:
		anim.play("actief")
	return uit


## Speler staat op 'speler': flitsen als hij net binnen bereik komt (alleen verborgen, niet afgegaan).
func speler_bij(speler: Vector2i) -> void:
	var dichtbij := Kamers.in_flits_bereik(tile, speler)
	if dichtbij and not in_buurt and verborgen and not afgegaan:
		flits()
	in_buurt = dichtbij


func flits() -> void:
	if anim == null or flitsend:
		return
	flitsend = true
	flitsen += 1
	anim.play("zichtbaar")
	var tw := create_tween()
	tw.tween_property(anim, "modulate", FLITS_KLEUR, FLITS_TIJD * 0.3)
	tw.tween_property(anim, "modulate", Color.WHITE, FLITS_TIJD * 0.7)
	tw.tween_callback(func() -> void:
		flitsend = false
		if verborgen and not afgegaan:
			anim.play("verborgen"))
