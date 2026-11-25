extends RefCounted
## F6-29: insets_override verplaatst de touch-HUD zonder size_changed.
## refit() loopt via de setter van UiTouch.insets_override (groep touch_safe_inset, geen per-frame-kosten).
## Wordt geladen door scripts/tests/f6_ux2_tests.gd (map-scan); geen aparte suite-registratie.

const NOTCH := Vector4(22, 4, 10, 6)


func needs_game() -> bool:
	return true


func run(t: Node) -> void:
	await t.sc.set_profile("19_5x9")
	var scene: Node = t.sc.scene()
	var touch: Control = scene.get_node_or_null("TouchControls/Control") if scene != null else null
	t.check("F6-29: TouchControls aanwezig", touch != null)
	if touch == null:
		return
	touch.show_menu = true
	touch.show_run = true
	# Zelfde viewport als daarna: geen size_changed. Alleen de override wisselt.
	var stick0: Vector2 = touch.stick_center()
	var a0: Vector2 = touch.a_center()
	var b0: Vector2 = touch.b_center()
	var menu0: Rect2 = touch.menu_rect()
	var run0: Rect2 = touch.run_rect()
	var size0: Vector2 = touch.size
	t.check("F6-29: baseline safe_inset is nul op 19,5:9", touch.safe_inset == Vector4.ZERO)

	UiTouch.insets_override = NOTCH
	var want := _expected_inset(touch, NOTCH)
	t.check("F6-29: safe_inset volgt insets_override zonder size_changed (%s)" % touch.safe_inset,
			touch.safe_inset == want)
	t.check("F6-29: schermmaat ongewijzigd (geen size_changed nodig)", touch.size == size0)
	t.check("F6-29: joystick schuift %s naar rechts" % want.x,
			touch.stick_center().is_equal_approx(stick0 + Vector2(want.x, 0.0)))
	t.check("F6-29: A-knop schuift met rechts/onder-inset",
			touch.a_center().is_equal_approx(a0 + Vector2(-want.z, -want.w)))
	t.check("F6-29: B-knop schuift mee met A",
			touch.b_center().is_equal_approx(b0 + Vector2(-want.z, -want.w)))
	t.check("F6-29: MENU schuift met rechts/boven-inset",
			touch.menu_rect().position.is_equal_approx(menu0.position + Vector2(-want.z, want.y)))
	t.check("F6-29: RUN schuift mee met MENU",
			touch.run_rect().position.is_equal_approx(run0.position + Vector2(-want.z, want.y)))

	UiTouch.insets_override = null
	t.check("F6-29: na reset staat de HUD weer op de baseline",
			touch.safe_inset == Vector4.ZERO
			and touch.stick_center().is_equal_approx(stick0)
			and touch.a_center().is_equal_approx(a0)
			and touch.menu_rect().position.is_equal_approx(menu0.position))


func _expected_inset(touch: Control, ins: Vector4) -> Vector4:
	var layer := touch.get_parent() as CanvasLayer
	var s := layer.scale if layer else Vector2.ONE
	return ins / s.x
