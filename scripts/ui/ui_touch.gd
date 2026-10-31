class_name UiTouch
extends RefCounted
## Gedeelde afspraken voor touch en veilig scherm (WM1-schermen). Geen scene, geen autoload.
##
## Tikmaat: het spel rendert 384x216 eenheden over de hoogte van het scherm. Een telefoon in
## landschap is ~411 dp hoog (Galaxy S25 Ultra: 1080 px bij 2,625 px/dp, of 1440 px bij 3,5), dus
## 1 eenheid = 411/216 = 1,9 dp. 48 dp = 25,2 eenheden. TOUCH_MIN = 25 (= 47,6 dp) is de ondergrens
## voor knoppen die de speler moet raken; het tikvlak mag groter zijn dan wat je ziet.
## Lijstregels (16 eenheden = 30 dp) blijven compact: die kiest de speler met cursor + A of tik,
## en een scherm met veel regels moet nog scrollen. Zie docs/ui/polish/README.md.
const TOUCH_MIN := 25.0
## Hoogte van een lijstregel in schermen met weinig, grote keuzes (winkel, Codex, tekstvak-keuzes).
const ROW_TOUCH := 25.0
## Maximale inset per kant (eenheden): een rare waarde van het platform mag het scherm niet opeten.
const INSET_MAX := 48.0

## Test/screenshot-override: Vector4(links, boven, rechts, onder) in eenheden. null = platform.
static var insets_override: Variant = null
## Test-hook: nep-DisplayServer-insets (Windows-taakbalk). insets() gebruikt dit alleen op mobiel;
## op desktop/headless blijft het resultaat nul, ook als dit gezet is.
static var test_display_insets: Variant = null


## Veilig gebied (notch/punch-hole, afgeronde hoeken, gebarenbalk) als marges in viewport-eenheden.
## Alleen op mobiel (Android/iOS) leest dit DisplayServer.get_display_safe_area(). Op desktop en
## headless altijd nul: Windows geeft anders de taakbalk als 'safe area' (~16 viewport-px onder),
## waardoor tekstvak/ballon naar 'boven' valt. Tests en screenshots zetten insets_override.
static func insets(vp: Viewport = null) -> Vector4:
	if insets_override != null:
		return _clamp_insets(insets_override as Vector4)
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	if test_display_insets != null:
		return _clamp_insets(test_display_insets as Vector4)
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var screen := Vector2(DisplayServer.screen_get_size())
	if safe.size.x <= 0.0 or safe.size.y <= 0.0 or screen.x <= 0.0 or screen.y <= 0.0:
		return Vector4.ZERO
	var px := Vector4(safe.position.x, safe.position.y, screen.x - safe.end.x, screen.y - safe.end.y)
	var unit := 1.0
	if vp != null:
		var win_h := float(maxi(1, vp.get_window().size.y)) if vp.get_window() != null else screen.y
		unit = vp.get_visible_rect().size.y / win_h
	return _clamp_insets(px * unit)


static func _clamp_insets(v: Vector4) -> Vector4:
	return Vector4(clampf(v.x, 0.0, INSET_MAX), clampf(v.y, 0.0, INSET_MAX),
			clampf(v.z, 0.0, INSET_MAX), clampf(v.w, 0.0, INSET_MAX))


## Het veilige gebied als rechthoek binnen een viewportgrootte.
static func safe_rect(vp_size: Vector2, vp: Viewport = null) -> Rect2:
	var i := insets(vp)
	return Rect2(Vector2(i.x, i.y), vp_size - Vector2(i.x + i.z, i.y + i.w))


## Tikvlak voor een zichtbare rechthoek: minstens TOUCH_MIN hoog en breed, zelfde midden.
## 'extra' groeit er aan alle kanten bovenop (de bestaande marge rond knoppen).
static func hit_rect(visible: Rect2, extra := 0.0, min_size := TOUCH_MIN) -> Rect2:
	var r := visible.grow(extra)
	var gx := maxf(0.0, (min_size - r.size.x) / 2.0)
	var gy := maxf(0.0, (min_size - r.size.y) / 2.0)
	return r.grow_individual(gx, gy, gx, gy)


## Is dit tikvlak groot genoeg (>= TOUCH_MIN in beide richtingen)?
static func big_enough(r: Rect2, min_size := TOUCH_MIN) -> bool:
	return r.size.x >= min_size - 0.01 and r.size.y >= min_size - 0.01
