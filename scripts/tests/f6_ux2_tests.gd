extends Node
## F6 UX-fixes WM1, tweede suite (--f6uxtest2). Los van --f6uxtest (f6_ux_tests.gd), zodat er niets botst.
## Start: godot --path . -- --f6uxtest2
##
## De checks per ticket staan elk in een eigen bestand in scripts/tests/f6_ux2/ (f6_8_*.gd, f6_5_*.gd, ...).
## Deze runner start het spel één keer in Wilgendal en draait daarna elk deel op naamvolgorde.
## Zo raken de vier F6-PR's elkaar niet: elke PR voegt alleen zijn eigen bestand toe.
## Een deel is een RefCounted met  func run(t: Node) -> void  en gebruikt t.check(...) en t.sc (Scenarios).

const Scenarios := preload("res://tools/ui_polish/ui_scenarios.gd")
const PARTS_DIR := "res://scripts/tests/f6_ux2"

var failures := 0
var passes := 0
var sc: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sc = Scenarios.new()
	add_child(sc)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	await sc.wait_scene("Title")
	await sc.pframes(10)
	check("spel start in Wilgendal", await sc.start_game())
	var parts := _parts()
	check("f6_ux2: deelchecks gevonden (%d)" % parts.size(), not parts.is_empty())
	for p in parts:
		print("---- " + p.get_file())
		var part: RefCounted = load(p).new()
		await part.run(self)
		await sc.close_all()
		await sc.set_profile("16x9")
	print("F6UXTEST2 %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _parts() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(PARTS_DIR):
		if f.ends_with(".gd"):
			out.append(PARTS_DIR.path_join(f))
	out.sort()
	return out


# ---------------------------------------------------------------- hulpjes voor de delen
## Veilig gebied in viewport-eenheden voor het huidige profiel.
func safe() -> Rect2:
	return UiTouch.safe_rect(sc.viewport_size(), get_viewport())


func within(r: Rect2, bounds: Rect2) -> bool:
	return r.position.x >= bounds.position.x - 0.5 and r.position.y >= bounds.position.y - 0.5 \
			and r.end.x <= bounds.end.x + 0.5 and r.end.y <= bounds.end.y + 0.5


## WCAG-contrast (relatieve luminantie, sRGB) tussen twee kleuren.
static func contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _lum(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


## Past de tekst van een knop of label in zijn eigen vak (niet afgekapt)?
func text_fits(c: Control) -> bool:
	var font: Font = c.get_theme_font("font")
	var fs := c.get_theme_font_size("font_size")
	var w := font.get_string_size(str(c.get("text")), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return w <= c.size.x + 0.5
