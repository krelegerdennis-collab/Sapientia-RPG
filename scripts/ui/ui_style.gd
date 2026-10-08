class_name UiStyle
extends RefCounted
## v0.13 PALET 'Inkt & Perkament' – het ENIGE bestand met de UI-kleuren.
## Alle schermen (gevecht, tekstvak, tip, menu's, titel) lezen hun kleuren en vensterstijl
## hier. Stijl: 'glitched digital decay meets dark academia', passend bij de geschilderde
## achtergronden: half doorzichtige diepe inkt-panelen (navy-bruin), dunne perkament-gouden
## randen, crème tekst; warm rood voor HP, teal voor MP. Glitch-accent (zacht roze/teal)
## ALLEEN voor highlights. Zie docs/ARTSTYLE.md hoofdstuk 13.
##
## Gebruik:  UiStyle.panel("window" | "soft" | "status" | "tab" | "button")  -> StyleBoxFlat
##           UiStyle.apply_to_theme(theme)   (GameState doet dit bij de start voor assets/theme.tres)
## Oude namen (MAGENTA, CYAN, BAR_MAGENTA, ...) bestaan nog als alias, zodat oude code werkt.

# ---------------------------------------------------------------- basis
const INK := Color("120f1a")            # diepe inkt (navy-bruin), achtergrond van vensters
const INK_LIGHT := Color("221b2a")      # iets lichter (rijen, knoppen)
const PANEL_ALPHA := 0.82               # vensters: half doorzichtig
const SOFT_ALPHA := 0.70                # strook, tip: nog wat lichter
const BORDER := Color("c9aa6e")         # dun perkament-goud
const BORDER_DIM := Color("6a5838")     # rustige rand
const BORDER_DARK := BORDER_DIM         # (alias)
const TEXT := Color("f2e9d8")           # crème
const TEXT_DIM := Color("b5a78d")       # labels
const TEXT_OFF := Color("6c6455")       # uitgeschakeld
const SHADOW := Color("07060a")

# ---------------------------------------------------------------- accenten
const HILITE := Color("f0c674")         # selectie / actieve held: warm goud
const HILITE_HOT := Color("fff1c8")
const HILITE_DIM := Color("8a6a2e")
const TEAL := Color("6fd3c2")           # doelwit, genezen, MP
const TEAL_HOT := Color("cbf5ec")
const TEAL_DIM := Color("2d6c62")
const GLITCH := Color("e2789e")         # zacht roze glitch-accent (alleen highlights)
const GLITCH_DIM := Color("7a3452")
const KO := Color("a85a5a")

# ---------------------------------------------------------------- balken
## [licht bovenrandje, vulling, donkere onderrand]
const BAR_HP := [Color("f6b49c"), Color("cc4a3c"), Color("6a2320")]
const BAR_HP_LOW := [Color("ffd99c"), Color("e3902e"), Color("764612")]
const BAR_MP := [Color("c6f2e3"), Color("3fb49c"), Color("1a5a50")]
const BAR_EMPTY := Color("0d0b12")
const BAR_EDGE := Color("050407")

## Ruis in het tekstvak (glitch_noise.gd): donker inkt, warm
const NOISE := [Color("1d1822"), Color("272030"), Color("332a3a"), Color("4a3e4c"), Color("6e5e5e")]

# ---------------------------------------------------------------- oude namen (alias)
const WINDOW := INK
const MAGENTA := HILITE
const MAGENTA_HOT := HILITE_HOT
const MAGENTA_DIM := HILITE_DIM
const CYAN := TEAL
const CYAN_HOT := TEAL_HOT
const CYAN_DIM := TEAL_DIM
const BAR_GREY := BAR_HP
const BAR_MAGENTA := BAR_HP
const BAR_CYAN := BAR_MP
const BAR_LOW := BAR_HP_LOW


## Accentkleur van een held ("magenta" = Noor, "cyaan" = Lotte, "" = geen).
static func accent(name: String) -> Color:
	match name:
		"magenta":
			return GLITCH
		"cyaan":
			return TEAL
	return TEXT


## Vensterstijl uit het palet. kind:
##   "window" = tekstvak, menu's (inkt 82%, gouden rand)
##   "soft"   = bericht-strook, tip (lichter, rustige rand)
##   "status" = statusvak in het gevecht (geen marges, rustige rand)
##   "tab"    = klein titel-tabje
##   "button" = commandoknop / lijstknop
static func panel(kind := "window", border: Color = BORDER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK.r, INK.g, INK.b, PANEL_ALPHA)
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.anti_aliasing = false
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 1
	match kind:
		"soft":
			sb.bg_color.a = SOFT_ALPHA
			sb.border_color = Color(border.r, border.g, border.b, 0.6)
			sb.content_margin_top = 2
			sb.content_margin_bottom = 2
		"status":
			sb.border_color = BORDER_DIM if border == BORDER else border
			sb.set_content_margin_all(0)
		"tab":
			sb.border_color = BORDER_DIM if border == BORDER else border
			sb.content_margin_left = 5
			sb.content_margin_right = 5
			sb.content_margin_top = 1
			sb.content_margin_bottom = 0
			sb.shadow_size = 0
		"button":
			sb.bg_color = Color(INK_LIGHT.r, INK_LIGHT.g, INK_LIGHT.b, 0.9)
			sb.border_color = BORDER_DIM if border == BORDER else border
			sb.set_content_margin_all(2)
			sb.shadow_size = 0
	return sb


# ---------------------------------------------------------------- v0.16 Lufia 2-blauw
## v0.16 (wens Dennis, ref. Lufia 2): ALLE tekstvakken in hetzelfde klassieke blauw van RPG ART
## (art_tekstvak_v15/out, LEESMIJ.txt; handwerk).
##   "vak"    = tekstvak_blauw.png: verteller, systeem, tutorial, kisten, buit na het gevecht
##   "ballon" = ballon_blauw.png: spraakballon van een personage (+ staart ballon_staart.png)
## 24x48 9-slice, marge 6 rondom, horizontaal TILE, verticaal STRETCH, volledig dekkend.
## (Pixel-scherp: de Control die hem tekent zet texture_filter op NEAREST.)
const BOX_TEXTURES := {"vak": "res://assets/ui/tekstvak_blauw.png", "ballon": "res://assets/ui/ballon_blauw.png"}
const TAIL_TEXTURE := "res://assets/ui/ballon_staart.png"   # 32x12 = 2 frames 16x12 (0 omlaag, 1 omhoog)
const BOX_MARGIN := 6
const BOX_TEXT := Color("f4f6ff")       # witte tekst (zoals Lufia 2)
const BOX_SHADOW := Color("0a0c20")     # outline-kleur van de ballon
const BOX_NAME := Color("f0c674")       # naam in het tabje: warm goud (HILITE)


## Blauwe StyleBoxTexture ("vak" of "ballon"). content = binnenmarges voor Containers.
static func blue_box(kind := "vak", content := Vector4(7, 6, 7, 6)) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(str(BOX_TEXTURES.get(kind, BOX_TEXTURES["vak"])))
	sb.texture_margin_left = BOX_MARGIN
	sb.texture_margin_top = BOX_MARGIN
	sb.texture_margin_right = BOX_MARGIN
	sb.texture_margin_bottom = BOX_MARGIN
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	return sb


## Is dit een blauw vak van RPG ART? (voor de tests) kind "" = vak of ballon.
static func is_blue_box(sb: StyleBox, kind := "") -> bool:
	if not (sb is StyleBoxTexture) or (sb as StyleBoxTexture).texture == null:
		return false
	var path := (sb as StyleBoxTexture).texture.resource_path
	if kind != "":
		return path == str(BOX_TEXTURES.get(kind, ""))
	return path in BOX_TEXTURES.values()


## Zet het palet in een Theme (vensters, labels, knoppen). Gedeeld door alle schermen.
static func apply_to_theme(theme: Theme) -> void:
	if theme == null:
		return
	var win := panel("window")
	theme.set_stylebox("panel", "Panel", win)
	theme.set_stylebox("panel", "PanelContainer", win)
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_shadow_color", "Label", SHADOW)
	for k in ["font_color", "font_focus_color", "font_hover_color"]:
		theme.set_color(k, "Button", TEXT)
	for k in ["font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(k, "Button", HILITE_HOT)
	theme.set_color("font_disabled_color", "Button", TEXT_OFF)
