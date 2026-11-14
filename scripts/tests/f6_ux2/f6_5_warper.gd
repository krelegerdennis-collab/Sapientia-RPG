extends RefCounted
## F6-5: World Warper / Rustkamer binnen het veilige gebied en leesbare letters.
## - PartyWissel (Rustkamer-wisselen) en WorldWarperPartySelect: alle zichtbare Controls binnen safe_rect,
##   op 16:9, 16:9 met insets 30/0/30/0 en 19,5:9+notch (22/4/10/6).
## - Geen Label/Button met font_size < 10 op de drie schermen.
## - Echo-kistlabels: font 10, vak breed genoeg voor de hele tekst, labels raken elkaar niet.

const PARTY_SCENE := preload("res://world_warper/services/party_select.tscn")
const MIN_FONT := 10
const ANCHOR_GROUP := "ww_anchor_party"
## [profiel, extra insets-override of null (dan die van het profiel)]
const CASES := [["16x9", null], ["16x9", Vector4(30, 0, 30, 0)], ["19_5x9_notch", null]]


func run(t: Node) -> void:
	for c in CASES:
		await t.sc.set_profile(str(c[0]))
		if c[1] != null:
			UiTouch.insets_override = c[1]
			await t.sc.pframes(2)
		var tag := "F6-5 [%s%s]" % [c[0], "" if c[1] == null else " insets %s" % [c[1]]]
		await _party_wissel(t, tag)
		await _party_select(t, tag)
	await t.sc.set_profile("16x9")
	await _echo_kisten(t)


func _party_wissel(t: Node, tag: String) -> void:
	var scherm := PartyWissel.new()
	t.sc.scene().add_child(scherm)
	await t.sc.pframes(3)
	var root: Control = scherm.get_child(0) as Control
	var kolom: Control = root.get_child(0) as Control if root != null and root.get_child_count() > 0 else null
	t.check(tag + " PartyWissel gebouwd", kolom != null)
	if kolom != null:
		var bad := _outside(t, kolom)
		t.check(tag + " PartyWissel: alles binnen safe_rect %s" % [bad], bad.is_empty())
		var klein := _small_fonts(kolom)
		t.check(tag + " PartyWissel: geen letters < %d %s" % [MIN_FONT, klein], klein.is_empty())
	scherm.queue_free()
	await t.sc.pframes(2)


func _party_select(t: Node, tag: String) -> void:
	var laag := CanvasLayer.new()
	laag.layer = 20
	t.sc.scene().add_child(laag)
	# 1) zonder anker: vult de ouder, maar binnen het veilige gebied
	var p: Control = PARTY_SCENE.instantiate() as Control
	laag.add_child(p)
	await t.sc.pframes(2)
	p.call("open")
	await t.sc.pframes(3)
	_check_select(t, tag + " PartySelect zonder anker", p)
	p.queue_free()
	await t.sc.pframes(2)
	# 2) met een anker in de hoeken: het paneel schuift naar binnen
	var vp: Vector2 = t.sc.viewport_size()
	for hoek in [Vector2.ZERO, vp - Vector2(40, 40)]:
		var anker := Control.new()
		anker.position = hoek
		anker.size = Vector2(8, 8)
		anker.add_to_group(ANCHOR_GROUP)
		laag.add_child(anker)
		var q: Control = PARTY_SCENE.instantiate() as Control
		laag.add_child(q)
		await t.sc.pframes(2)
		q.call("open")
		await t.sc.pframes(3)
		_check_select(t, tag + " PartySelect anker %s" % [hoek], q)
		q.queue_free()
		anker.queue_free()
		await t.sc.pframes(2)
	laag.queue_free()
	await t.sc.pframes(2)


func _check_select(t: Node, tag: String, p: Control) -> void:
	t.check(tag + ": open", p.visible)
	var bad := _outside(t, p)
	t.check(tag + ": alles binnen safe_rect %s" % [bad], bad.is_empty())
	var klein := _small_fonts(p)
	t.check(tag + ": geen letters < %d %s" % [MIN_FONT, klein], klein.is_empty())


func _echo_kisten(t: Node) -> void:
	var kisten := EchoKisten.new()
	t.sc.scene().add_child(kisten)
	await t.sc.pframes(3)
	var labels: Array[Label] = []
	for k in kisten.get_children():
		if k is Sprite2D:
			var lab := (k as Node).get_node_or_null("Label") as Label
			if lab != null:
				labels.append(lab)
	t.check("F6-5 echo-kisten: drie labels", labels.size() == EchoKisten.SOORTEN.size())
	for i in labels.size():
		var lab := labels[i]
		var verwacht := str(EchoKisten.NAMEN[EchoKisten.SOORTEN[i]])
		t.check("F6-5 echo-kist '%s': tekst volledig" % verwacht, lab.text == verwacht)
		t.check("F6-5 echo-kist '%s': font %d >= %d" % [verwacht, lab.get_theme_font_size("font_size"), MIN_FONT],
				lab.get_theme_font_size("font_size") >= MIN_FONT)
		t.check("F6-5 echo-kist '%s': minimumbreedte %.0f <= vak %.0f" % [verwacht, lab.get_minimum_size().x, lab.size.x],
				lab.get_minimum_size().x <= lab.size.x + 0.01)
		t.check("F6-5 echo-kist '%s': tekst past in het vak (geen clip)" % verwacht, t.text_fits(lab))
	var raakt := false
	for i in labels.size():
		for j in range(i + 1, labels.size()):
			if labels[i].get_global_rect().intersects(labels[j].get_global_rect()):
				raakt = true
	t.check("F6-5 echo-kisten: labels overlappen elkaar niet", not raakt)
	kisten.queue_free()
	await t.sc.pframes(2)


## Zichtbare Controls (incl. de wortel) die buiten het veilige gebied vallen.
## Inhoud van een ScrollContainer telt niet: die knipt bewust.
func _outside(t: Node, root: Control) -> Array[String]:
	var bad: Array[String] = []
	var veilig: Rect2 = t.safe()
	for c in _controls(root):
		if not t.within(c.get_global_rect(), veilig):
			bad.append("%s %s" % [c.name, c.get_global_rect()])
	return bad


func _small_fonts(root: Control) -> Array[String]:
	var bad: Array[String] = []
	for c in _controls(root):
		if (c is Label or c is Button) and c.get_theme_font_size("font_size") < MIN_FONT:
			bad.append("%s '%s' %d" % [c.name, str(c.get("text")), c.get_theme_font_size("font_size")])
	return bad


func _controls(root: Control, out: Array[Control] = []) -> Array[Control]:
	if root.visible:
		out.append(root)
		if not (root is ScrollContainer):
			for k in root.get_children():
				if k is Control:
					_controls(k as Control, out)
	return out
