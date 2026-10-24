extends RefCounted
## UX-polish (fase 6): veilige zone (notch/camera-gat, afgeronde hoeken, gebaren-balk) in logische
## eenheden. Het spel is 216 eenheden hoog en wordt op 19,5:9 (468 breed) of 20:9 (480 breed)
## breder, niet hoger. DisplayServer.get_display_safe_area() geeft de veilige rechthoek in
## schermpixels; hier omgerekend naar eenheden. Op PC (geen notch) is alles 0.
##
## Gebruik: SafeArea.insets() -> Vector4(links, boven, rechts, onder) in eenheden.
## Randmarges van HUD en menu's tellen hier bij op (touch_controls.gd, menu_screen.gd, ...).

## Maximum: een rare waarde van het systeem mag het scherm nooit opeten.
const MAX_INSET := 40.0


## Pure rekenfunctie (testbaar): veilige rechthoek + venstergrootte in pixels -> eenheden.
## view_size = zichtbare viewport in eenheden (bv. 468x216).
static func insets_from(safe: Rect2, window_px: Vector2, view_size: Vector2) -> Vector4:
	if window_px.x <= 0.0 or window_px.y <= 0.0 or safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return Vector4.ZERO
	var k := Vector2(view_size.x / window_px.x, view_size.y / window_px.y)
	var l := safe.position.x * k.x
	var t := safe.position.y * k.y
	var r := (window_px.x - safe.end.x) * k.x
	var b := (window_px.y - safe.end.y) * k.y
	return Vector4(_clamp(l), _clamp(t), _clamp(r), _clamp(b))


static func _clamp(v: float) -> float:
	return clampf(roundf(v), 0.0, MAX_INSET)


## Testen/demo: zet een vaste waarde (Vector4) i.p.v. het systeem te vragen; null = systeem.
static var override: Variant = null


## Nu: DisplayServer + het hoofdvenster. Alleen op een telefoon (op PC valt de 'veilige zone' van
## het beeldscherm niet samen met het venster); headless/PC = ZERO.
static func insets(vp: Viewport = null) -> Vector4:
	if override is Vector4:
		return override
	if not OS.has_feature("mobile") or DisplayServer.get_name() == "headless":
		return Vector4.ZERO
	var tree := Engine.get_main_loop() as SceneTree
	var v: Viewport = vp if vp != null else (tree.root if tree != null else null)
	if v == null:
		return Vector4.ZERO
	var win := DisplayServer.window_get_size()
	var safe := Rect2(DisplayServer.get_display_safe_area())
	return insets_from(safe, Vector2(win), v.get_visible_rect().size)


## Zichtbare rechthoek (eenheden) min de veilige randen.
static func safe_rect(view_size: Vector2, ins: Vector4) -> Rect2:
	return Rect2(ins.x, ins.y, maxf(0.0, view_size.x - ins.x - ins.z), maxf(0.0, view_size.y - ins.y - ins.w))
