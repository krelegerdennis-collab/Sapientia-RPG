extends RefCounted
## F6-5: World Warper - Rustkamer-wisselen (PartyWissel) en Party-select (WorldWarperPartySelect) binnen
## UiTouch.safe_rect (insets_override 30/0/30/0 en notch 22/4/10/6), geen Label of Button met een letter
## kleiner dan 10, en de ECHO-kistnamen leesbaar (font >= 10, breedte volgt de tekst, niet afgekapt,
## geen overlap). Bouwt de schermen los op (geen hub/kamer nodig); bestaande warper-tests blijven zoals ze zijn.

const PartyWisselS := preload("res://world_warper/kamers/party_wissel.gd")
const PartySelectScene := preload("res://world_warper/services/party_select.tscn")
const EchoKistenS := preload("res://world_warper/kamers/echo_kisten.gd")
const FONT_MIN := 10
## [profiel, insets (links, boven, rechts, onder)]
const CASES := [["16x9", Vector4(30, 0, 30, 0)], ["19_5x9", Vector4(30, 0, 30, 0)], ["19_5x9_notch", Vector4(22, 4, 10, 6)]]


func needs_game() -> bool:
	return true


## Zichtbare Controls met tekst (Label/Button) onder n.
static func text_controls(n: Node, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if (n is Label or n is Button) and str(n.get("text")).strip_edges() != "":
		out.append(n)
	for c in n.get_children():
		text_controls(c, out)


## Alle zichtbare Controls met een echte maat onder n (behalve de opgegeven, bv. een schermvullende root).
static func sized_controls(n: Node, skip: Array, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Control and not (n in skip) and (n as Control).size.x > 0.0 and (n as Control).size.y > 0.0:
		out.append(n)
	for c in n.get_children():
		sized_controls(c, skip, out)


func _check_screen(t: Node, tag: String, top: Node, skip: Array) -> void:
	var safe: Rect2 = t.safe()
	var ctl: Array = []
	sized_controls(top, skip, ctl)
	var out: Array = []
	for c in ctl:
		var r := (c as Control).get_global_rect()
		if not t.within(r, safe):
			out.append("%s %s" % [(c as Control).name, r])
	t.check("%s: %d Controls, allemaal binnen het veilige gebied %s (buiten: %s)" % [tag, ctl.size(), safe, out.slice(0, 4)],
			not ctl.is_empty() and out.is_empty())
	var txt: Array = []
	text_controls(top, txt)
	var small: Array = []
	for c in txt:
		var fs: int = (c as Control).get_theme_font_size("font_size")
		if fs < FONT_MIN:
			small.append("'%s' %d" % [str(c.get("text")).left(16), fs])
	t.check("%s: %d tekstregels, geen letter kleiner dan %d (te klein: %s)" % [tag, txt.size(), FONT_MIN, small],
			not txt.is_empty() and small.is_empty())


func run(t: Node) -> void:
	# iemand op de bank, zodat beide kolommen van de Rustkamer knoppen hebben
	if GameState.party.size() >= 3 and GameState.party_bench.is_empty():
		GameState.party_bench.append(GameState.party[2].duplicate(true))
	for cs in CASES:
		await t.sc.set_profile(cs[0])
		UiTouch.insets_override = cs[1]
		await t.pframes(2)
		var tag := "F6-5 [%s insets %s]" % [cs[0], cs[1]]
		# --- Rustkamer: wisselen
		var pw: CanvasLayer = PartyWisselS.new()
		t.get_tree().root.add_child(pw)
		await t.pframes(4)
		var pw_root: Node = pw.get_child(0)
		_check_screen(t, tag + " Rest Room (PartyWissel)", pw, [pw_root])
		await t.shot("f6_5_wissel_%s" % cs[0])
		pw.queue_free()
		await t.pframes(2)
		# --- Party-select: zonder anker (vult het scherm) en met een anker dicht bij de rand
		var layer := CanvasLayer.new()
		layer.layer = 40
		t.get_tree().root.add_child(layer)
		var ps: Control = PartySelectScene.instantiate()
		layer.add_child(ps)
		await t.pframes(2)
		ps.open()
		await t.pframes(4)
		_check_screen(t, tag + " Party select (geen anker)", ps, [])
		await t.shot("f6_5_party_%s" % cs[0])
		ps.close()
		var vp: Vector2 = t.get_viewport().get_visible_rect().size
		for pos in [Vector2(0, 0), vp - Vector2(60, 40)]:
			var anker := Control.new()
			anker.size = Vector2(20, 20)
			anker.add_to_group("ww_anchor_party")
			layer.add_child(anker)
			anker.global_position = pos
			ps.open()
			await t.pframes(4)
			_check_screen(t, "%s Party select (anker op %s)" % [tag, pos], ps, [])
			ps.close()
			anker.queue_free()
			await t.pframes(2)
		layer.queue_free()
		await t.pframes(2)
	UiTouch.insets_override = null
	# --- ECHO-kisten: namen leesbaar
	var host := Node2D.new()
	t.get_tree().root.add_child(host)
	var kisten: Node2D = EchoKistenS.new()
	kisten.name = "Kisten"
	host.add_child(kisten)
	await t.pframes(3)
	var labels: Array = []
	for vlak in kisten.get_children():
		var lab := (vlak as Node).get_node_or_null("Naam") as Label
		if lab != null:
			labels.append(lab)
	t.check("F6-5 ECHO-kisten: drie namen (%d)" % labels.size(), labels.size() == 3)
	for lab in labels:
		var l := lab as Label
		var fs := l.get_theme_font_size("font_size")
		var w := l.get_minimum_size().x
		t.check("F6-5 ECHO-kist '%s': font %d >= %d, tekst %.0f <= breedte %.0f, niet afgekapt" % [l.text, fs, FONT_MIN, w, l.size.x],
				fs >= FONT_MIN and w <= l.size.x + 0.5 and not l.clip_text and l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING)
	var overlap := 0
	for i in labels.size():
		for j in range(i + 1, labels.size()):
			if (labels[i] as Label).get_global_rect().intersects((labels[j] as Label).get_global_rect()):
				overlap += 1
	t.check("F6-5 ECHO-kisten: namen overlappen elkaar niet (%d)" % overlap, overlap == 0)
	host.queue_free()
	await t.pframes(2)
