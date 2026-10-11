extends CanvasLayer
## HUD van de 100-verdiepingen-kerker: een klein pilletje linksboven met 'Verdieping X/100'
## (X = GameState.dungeon100_floor). Alleen zichtbaar als je in de kerker bent (verdieping 1..100)
## en niet in een gevecht; anders verborgen. GameState._ready() hangt hem aan de root, dus hij
## blijft staan als de scène wisselt (verdieping naar verdieping, gevecht en terug).
##
## STIJL: hetzelfde pilletje als de MENU-knop van de touch-besturing (scripts/touch_controls.gd,
## rechtsboven, x 8 van de rand, y 6, 14 hoog), met het palet 'Inkt & Perkament' uit ui_style.gd:
## inkt-paneel, perkament-gouden rand, crème tekst, het getal in warm goud. Op een rustverdieping
## (10, 20, ...) is de rand goud en staat er een klein cyaan 'rust'-puntje: daar is een rustpunt.
## LAGEN: 4 = onder het tekstvak (5), de touch-knoppen (10) en het veldmenu (20); alleen een
## tekstvak bovenin kan eroverheen vallen. De HUD vangt geen tikken (mouse_filter = IGNORE).
## Kost niets per frame: alleen een vergelijking van twee getallen; tekenen alleen bij verandering.

const UiStyleC := preload("res://scripts/ui/ui_style.gd")
const RulesC := preload("res://scripts/dungeon/dungeon100_rules.gd")

const LAYER := 4
const FONT_SIZE := 10
## Positie en hoogte (zelfde rand/hoogte als de MENU-knop, maar links).
const POS := Vector2(8, 6)
const HEIGHT := 14.0
const PAD_X := 5.0

var view: Control
## Wat er nu getekend wordt (voor de tests): de verdieping en of de HUD zichtbaar is.
var shown_floor := 0
var _last_floor := -1
var _last_battle := false


func _init() -> void:
	name = "Dungeon100Hud"


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	view = Control.new()
	view.name = "View"
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.ui_theme:
		view.theme = GameState.ui_theme
	add_child(view)
	view.draw.connect(_draw_pill)
	refresh()


func _process(_delta: float) -> void:
	var f: int = GameState.dungeon100_floor
	var b: bool = GameState.in_battle
	if f != _last_floor or b != _last_battle:
		refresh()


## Zichtbaarheid en tekening bijwerken; houdt ook de hoogst bereikte verdieping bij.
func refresh() -> void:
	var f: int = GameState.dungeon100_floor
	_last_floor = f
	_last_battle = GameState.in_battle
	GameState.dungeon100_best = RulesC.best_after(GameState.dungeon100_best, f)
	shown_floor = clampi(f, 0, RulesC.FLOORS)
	visible = RulesC.shows_hud(f) and not _last_battle
	if view:
		view.queue_redraw()


## Het pilletje (voor de tests en voor wie de plek wil weten).
func pill_rect() -> Rect2:
	var font := view.get_theme_default_font()
	var w := font.get_string_size(RulesC.hud_text(shown_floor), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	if RulesC.is_rest_floor(shown_floor):
		w += 9.0
	return Rect2(POS, Vector2(ceilf(w + PAD_X * 2.0), HEIGHT))


## Tekenen op 'view' (via het draw-signaal: een CanvasLayer kan zelf niet tekenen).
func _draw_pill() -> void:
	if not visible:
		return
	var rest := RulesC.is_rest_floor(shown_floor)
	var r := pill_rect()
	view.draw_rect(r, Color(UiStyleC.INK.r, UiStyleC.INK.g, UiStyleC.INK.b, UiStyleC.SOFT_ALPHA + 0.1))
	view.draw_rect(r, UiStyleC.BORDER if rest else UiStyleC.BORDER_DIM, false, 1.0)
	var font := view.get_theme_default_font()
	var x := r.position.x + PAD_X
	var y := r.position.y + 11.0
	if rest:
		var c := Vector2(x + 2.0, r.position.y + HEIGHT / 2.0)
		view.draw_circle(c, 2.0, UiStyleC.TEAL_DIM)
		view.draw_circle(c, 1.0, UiStyleC.TEAL_HOT)
		x += 9.0
	var parts := [["Floor ", UiStyleC.TEXT_DIM], [str(shown_floor), UiStyleC.HILITE],
			["/%d" % RulesC.FLOORS, UiStyleC.TEXT_DIM]]
	for p in parts:
		var pos := Vector2(x, y).round()
		view.draw_string(font, pos + Vector2(1, 1), p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UiStyleC.SHADOW)
		view.draw_string(font, pos, p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, p[1])
		x += font.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
