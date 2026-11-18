extends RefCounted
## F6-T14: Action-HUD (scripts/som/som_hud.gd): partyvakken, toast en de terugval-knoppenrij schuiven mee
## met UiTouch.insets (notch/punch-hole), zoals dungeon100_hud.gd. Bij insets 0 (null én Vector4.ZERO)
## blijven ze op de oude plek (pixelgelijk). Losse SomHud met een nep-arena (geen gevecht nodig).
## Wordt geladen door scripts/tests/f6_ux2_tests.gd (map-scan).

const SomHudS := preload("res://scripts/som/som_hud.gd")
const UiTouchC := preload("res://scripts/ui/ui_touch.gd")
const TouchControlsS := preload("res://scripts/touch_controls.gd")
const SomDataS := preload("res://scripts/data/som_data.gd")
## Partyvak (hud_frame 72x20), 21 per held (som_hud._draw_bars).
const FRAME := Vector2(72, 20)
const ROW := 21.0
const NOTCH := Vector4(22, 4, 10, 6)


## Net genoeg arena voor som_hud: geen touch (terugval-rij), geen codex.
class FakeStamina:
	func current(_id: String) -> int:
		return 50


class FakeArena:
	extends Node
	var touch: Control = null
	var codex: Node = null
	var active_id := ""
	var charge := 0.5
	var combat_stamina := FakeStamina.new()

	func active() -> bool:
		return false


func needs_game() -> bool:
	return true


## Waar de vakken getekend worden (bars.position + n * 21).
static func _bars_rect(hud: Node) -> Rect2:
	var n := maxi(1, GameState.party.size())
	return Rect2((hud.bars as Control).global_position, Vector2(FRAME.x, ROW * float(n) - 1.0))


## Oude plekken (vóór F6-T14) bij viewportbreedte vx.
static func _old(hud: Node, vx: float) -> Dictionary:
	var rb: Button = hud.ring_button
	var cb: Button = hud.codex_button
	var sb: Button = hud.switch_button
	var ring := Vector2(vx - 4.0 - 38.0 - 4.0 - rb.size.x, 2.0)
	var codex := Vector2(ring.x - 4.0 - cb.size.x, 2.0)
	var swap := Vector2(codex.x - 4.0 - sb.size.x, 2.0)
	return {"bars": Vector2(4, 4), "toast_pos": Vector2(80, 24), "toast_size": Vector2(vx - 160.0, 30.0),
			"ring": ring, "codex": codex, "swap": swap}


func _make(t: Node, with_touch := false) -> Array:
	var arena := FakeArena.new()
	arena.name = "FakeSomArena"
	if not GameState.party.is_empty():
		arena.active_id = str(GameState.party[0].get("id", ""))
	t.get_tree().root.add_child(arena)
	if with_touch:
		# echte touch_controls (zoals TouchControls/Control in een kamer): de knoppenrij via som_row_slot()
		var layer := CanvasLayer.new()
		layer.name = "TouchControls"
		arena.add_child(layer)
		var tc: Control = TouchControlsS.new()
		tc.name = "Control"
		layer.add_child(tc)
		await t.pframes(1)
		tc.refit()
		arena.touch = tc
	var hud: CanvasLayer = SomHudS.new()
	hud.arena = arena
	arena.add_child(hud)
	await t.pframes(3)
	return [arena, hud]


func run(t: Node) -> void:
	for prof in ["16x9", "19_5x9"]:
		await t.sc.set_profile(prof)
		var vx: float = t.get_viewport().get_visible_rect().size.x
		for zero in [null, Vector4.ZERO]:
			UiTouchC.insets_override = zero
			var made: Array = await _make(t)
			var hud: Node = made[1]
			hud.toast("Test")
			await t.pframes(2)
			var old := _old(hud, vx)
			var tag := "F6-T14 [%s insets %s]" % [prof, zero]
			t.check("%s: partyvakken op de oude plek %s (nu %s)" % [tag, old["bars"], (hud.bars as Control).position],
					(hud.bars as Control).position == old["bars"])
			t.check("%s: toast op de oude plek/maat (nu %s %s)" % [tag, hud.toast_label.position, hud.toast_label.size],
					hud.toast_label.position == old["toast_pos"] and hud.toast_label.size == old["toast_size"])
			t.check("%s: knoppenrij (terugval) op de oude plek" % tag,
					hud.ring_button.position == old["ring"] and hud.codex_button.position == old["codex"]
					and hud.switch_button.position == old["swap"])
			made[0].queue_free()
			await t.pframes(2)
	for cs in [["16x9", NOTCH], ["19_5x9_notch", NOTCH], ["19_5x9", Vector4(30, 0, 30, 0)]]:
		await t.sc.set_profile(cs[0])
		UiTouchC.insets_override = cs[1]
		var made: Array = await _make(t)
		var hud: Node = made[1]
		hud.toast("Seren joined the fight!")
		await t.pframes(3)
		var safe: Rect2 = t.safe()
		var ins: Vector4 = cs[1]
		var tag := "F6-T14 [%s insets %s]" % [cs[0], ins]
		var br := _bars_rect(hud)
		t.check("%s: %d partyvakken %s binnen safe %s" % [tag, GameState.party.size(), br, safe], t.within(br, safe))
		t.check("%s: partyvakken schuiven met de inset (links %.0f, boven %.0f)" % [tag, ins.x, ins.y],
				(hud.bars as Control).position == Vector2(4.0 + ins.x, 4.0 + ins.y))
		var tr: Rect2 = (hud.toast_label as Control).get_global_rect()
		t.check("%s: toast %s binnen safe en gecentreerd" % [tag, tr], t.within(tr, safe)
				and absf(tr.get_center().x - safe.get_center().x) <= 0.5)
		for b in [hud.ring_button, hud.codex_button, hud.switch_button]:
			var r: Rect2 = (b as Control).get_global_rect()
			t.check("%s: knop %s %s binnen safe" % [tag, (b as Control).name, r], t.within(r, safe))
		await t.shot("f6_20_som_hud_%s" % cs[0])
		made[0].queue_free()
		await t.pframes(2)
	await _touch_path(t)
	UiTouchC.insets_override = null


## Touch aan: de rij [Swap][Codex][Ring] komt uit touch_controls.som_row_slot() (naast MENU, met safe_inset).
## Insets 0: op de oude plek (MENU-rect zonder inset). Notch/zijkanten: binnen UiTouch.safe_rect.
func _touch_path(t: Node) -> void:
	var was: bool = TouchControlsS.touch_mode
	TouchControlsS.touch_mode = true
	for cs in [["16x9", null], ["16x9", Vector4.ZERO], ["19_5x9", Vector4.ZERO], ["16x9", NOTCH],
			["19_5x9_notch", NOTCH], ["19_5x9", Vector4(30, 0, 30, 0)]]:
		await t.sc.set_profile(cs[0])
		UiTouchC.insets_override = cs[1]
		var made: Array = await _make(t, true)
		var arena: Node = made[0]
		var hud: Node = made[1]
		var tc: Control = arena.touch
		await t.pframes(2)
		var tag := "F6-T14 touch [%s insets %s]" % [cs[0], cs[1]]
		var buttons: Array = [hud.ring_button, hud.codex_button, hud.switch_button]   # slot 0, 1, 2
		var zero: bool = cs[1] == null or cs[1] == Vector4.ZERO
		if zero:
			# oude plek: MENU = (breedte - rand - 38, rand - 2, 38, 14), rij links ervan (TOP_BUTTON_GAP + breedte per slot)
			var bs: Vector2 = SomDataS.TOP_BUTTON_SIZE
			var m := Rect2(tc.size.x - tc.edge_margin - 38.0, tc.edge_margin - 2.0, 38.0, 14.0)
			var same := true
			var got: Array = []
			for i in buttons.size():
				var want := tc.position + Vector2(m.position.x - (SomDataS.TOP_BUTTON_GAP + bs.x) * float(i + 1), m.get_center().y - bs.y / 2.0)
				var b: Control = buttons[i]
				got.append(b.position)
				same = same and b.position == want and b.size == bs
			t.check("%s: knoppenrij via som_row_slot op de oude plek %s" % [tag, got], same)
		else:
			var safe: Rect2 = t.safe()
			for b in buttons:
				var r: Rect2 = (b as Control).get_global_rect()
				t.check("%s: knop %s %s binnen safe %s" % [tag, (b as Control).name, r, safe], t.within(r, safe))
		var ok_slot := true
		for i in buttons.size():
			ok_slot = ok_slot and (buttons[i] as Control).position == tc.position + tc.som_row_slot(i).position
		t.check("%s: knoppen volgen som_row_slot(0..2)" % tag, ok_slot)
		await t.shot("f6_20_som_hud_touch_%s" % cs[0])
		arena.queue_free()
		await t.pframes(2)
	TouchControlsS.touch_mode = was
