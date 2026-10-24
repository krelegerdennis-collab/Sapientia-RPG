class_name PartyWissel
extends CanvasLayer
## Wisselscherm van de Rustkamer. Actieve groep en de bank.
## Gratis. Dennis en tijdelijke Codex-gasten blijven uit de bank.

signal dicht

const FONT := preload("res://assets/fonts/Dauwpixel-Regular.ttf")

var _status: Label
var _actief: VBoxContainer
var _bank: VBoxContainer


func _ready() -> void:
	layer = 22
	PartyBench.normaliseer()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.gui_input.connect(_op_gui)
	add_child(root)
	var kolom := VBoxContainer.new()
	kolom.position = Vector2(16, 8)
	kolom.size = Vector2(352, 200)
	kolom.add_theme_constant_override("separation", 2)
	root.add_child(kolom)
	var kop := _label("The Rest Room — switching is free", 8)
	kolom.add_child(kop)
	var rijen := HBoxContainer.new()
	rijen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rijen.add_theme_constant_override("separation", 8)
	kolom.add_child(rijen)
	_actief = _kolom(rijen, "Active")
	_bank = _kolom(rijen, "Bench")
	_status = _label("", 8)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 20)
	kolom.add_child(_status)
	var terug := Button.new()
	terug.text = "Back"
	terug.custom_minimum_size = Vector2(0, 22)
	terug.add_theme_font_override("font", FONT)
	terug.add_theme_font_size_override("font_size", 10)  # Dauwpixel is 1:1 op 10; op 8 vallen pixelkolommen weg (W leek V)
	terug.pressed.connect(_sluit)
	kolom.add_child(terug)
	_vul()


func _kolom(ouder: Node, titel: String) -> VBoxContainer:
	var doos := VBoxContainer.new()
	doos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doos.add_theme_constant_override("separation", 2)
	ouder.add_child(doos)
	doos.add_child(_label(titel, 8))
	var lijst := VBoxContainer.new()
	lijst.add_theme_constant_override("separation", 2)
	doos.add_child(lijst)
	return lijst


func _vul() -> void:
	_leeg(_actief)
	_leeg(_bank)
	var pad := str(GameState.current_map)
	var i := 0
	for h in GameState.party:
		if h is Dictionary:
			var held := h as Dictionary
			var naam := str(held.get("name", ""))
			if PartyBench.is_dennis(held):
				_actief.add_child(_knop(naam + " (stays)", func() -> void: _zeg(PartyBench.DENNIS_BLIJFT)))
			elif PartyBench.is_codex_gast(held):
				_actief.add_child(_knop(naam + " (guest)", func() -> void: _zeg(PartyBench.GAST_BLIJFT)))
			else:
				_actief.add_child(_knop(naam + " → bench", _naar_bank.bind(i, pad)))
		i += 1
	i = 0
	for h in GameState.party_bench:
		if h is Dictionary:
			var held := h as Dictionary
			_bank.add_child(_knop(str(held.get("name", "")) + " → party", _naar_groep.bind(i, pad)))
		i += 1
	if _bank.get_child_count() == 0:
		_bank.add_child(_label("Nobody on the bench.", 8))


func _naar_bank(index: int, pad: String) -> void:
	_zeg(PartyBench.naar_bank(index, pad))
	_vul()


func _naar_groep(index: int, pad: String) -> void:
	_zeg(PartyBench.naar_groep(index, pad))
	_vul()


func _zeg(tekst: String) -> void:
	if _status != null:
		_status.text = tekst


func _knop(tekst: String, actie: Callable) -> Button:
	var knop := Button.new()
	knop.text = tekst
	knop.custom_minimum_size = Vector2(0, 18)
	knop.add_theme_font_override("font", FONT)
	knop.add_theme_font_size_override("font_size", 10)  # Dauwpixel is 1:1 op 10; op 8 vallen pixelkolommen weg (W leek V)
	knop.pressed.connect(actie)
	return knop


func _label(tekst: String, grootte: int) -> Label:
	var lab := Label.new()
	lab.text = tekst
	lab.add_theme_font_override("font", FONT)
	lab.add_theme_font_size_override("font_size", grootte)
	lab.add_theme_color_override("font_color", Color("f2e9d8"))
	return lab


func _leeg(doos: Node) -> void:
	for kind in doos.get_children():
		doos.remove_child(kind)
		kind.queue_free()


func _op_gui(event: InputEvent) -> void:
	if event.is_action_pressed("cancel") or event.is_action_pressed("menu"):
		_sluit()


func _sluit() -> void:
	dicht.emit()
	queue_free()
