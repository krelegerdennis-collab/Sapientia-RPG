extends Node
## ALLEEN VOOR TESTEN - WM1-bugjacht: regressietests voor bugs die met de apen-test (willekeurige
## invoer) en de dataschouw op Worldmap 1 gevonden zijn. Zie docs/qa/WM1_BUGJACHT.md.
## Start:  godot --path . -- --wm1bugtest [--shots=/pad/map]
## Zit niet in de export (scripts/tests/*).

const ShopScreen := preload("res://scripts/ui/shop_screen.gd")

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(2026)
	# waakhond: hangt er iets, dan stopt de test zelf (met een FAIL)
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func():
		check("waakhond: test klaar binnen 300 s", false)
		print("RESULT FOUT (waakhond)")
		get_tree().quit(1))
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	print("=== A: winkelscherm: kopen en verkopen via de knoppen ===")
	await _shop_tests()
	print("WM1BUGTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await pframes(10)
	get_tree().quit(1 if failures else 0)


func _shop_buttons(shop: Node) -> Array:
	var out: Array = []
	for c in shop.content.get_children():
		if c is Button:
			out.append(c)
	return out


## Bug WM1-01: kopen/verkopen herbouwt de lijst terwijl de ingedrukte knop zijn signaal nog uitzendt.
## _clear() deed c.free() op die knop: "Attempted to free a locked object" (SCRIPT ERROR). De fout brak
## _show_koop()/_show_verkoop() halverwege af: na een aankoop/verkoop met A of een tik bleef de lijst
## half leeg (Sell-knop weg) en de knop bleef als wees achter. Nu queue_free().
## (De bestaande tests roepen _on_buy/_on_sell direct aan en raken dit pad dus niet.)
func _shop_tests() -> void:
	GameState.new_game("Dax")
	GameState.gold = 1000
	GameState.inventory = {}
	var shop: Node = ShopScreen.new()
	shop.name = "ShopScreen"
	shop.shop_id = "wilgendal_wapen"
	get_tree().root.add_child(shop)
	await pframes(5)
	var knoppen := _shop_buttons(shop)
	check("winkel: Sell-knop + 3 wapens", knoppen.size() == 4)
	var oud: Array = knoppen.duplicate()
	var goud_voor: int = GameState.gold
	(knoppen[1] as Button).pressed.emit()
	await pframes(3)
	check("kopen via knop: goud omlaag, item in de tas",
			GameState.gold < goud_voor and GameState.item_count("kort_zwaard") == 1)
	var na_koop := _shop_buttons(shop)
	check("kopen via knop: lijst opnieuw opgebouwd (Sell-knop + 3 wapens terug, %d knoppen)" % na_koop.size(),
			na_koop.size() == 4 and str(na_koop[0].get_meta("label", "")) == "Sell")
	var wezen := 0
	for b in oud:
		if is_instance_valid(b) and not b.is_queued_for_deletion() and not b.is_inside_tree():
			wezen += 1
	check("kopen via knop: geen wees-knoppen achtergebleven (%d)" % wezen, wezen == 0)

	(_shop_buttons(shop)[0] as Button).pressed.emit()
	await pframes(3)
	var verkoop := _shop_buttons(shop)
	check("verkoopscherm toont de gekochte zwaard-rij", verkoop.size() == 2)
	var oud2: Array = verkoop.duplicate()
	var goud_mid: int = GameState.gold
	(verkoop[1] as Button).pressed.emit()
	await pframes(3)
	check("verkopen via knop: goud omhoog, item weg",
			GameState.gold > goud_mid and GameState.item_count("kort_zwaard") == 0)
	var wezen2 := 0
	for b in oud2:
		if is_instance_valid(b) and not b.is_queued_for_deletion() and not b.is_inside_tree():
			wezen2 += 1
	check("verkopen via knop: geen wees-knoppen achtergebleven (%d)" % wezen2, wezen2 == 0)
	check("na de laatste verkoop staat 'Nothing to sell.' in het scherm",
			_shop_buttons(shop).size() == 1)
	shop.queue_free()
	await pframes(3)
