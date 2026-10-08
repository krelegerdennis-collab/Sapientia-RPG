extends VBoxContainer
## v0.11 Doelkeuze in het veldmenu: één knop per held met een PartyCard (naam, Lv,
## HP/MP-balken). Tikken of A = 'chosen(index in GameState.party)'.
## Gebruikt door items_screen.gd en magic_screen.gd.

signal chosen(index: int)

const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const PartyCard := preload("res://scripts/ui/party_card.gd")

const CARD_INDENT := 10        # ruimte links voor het '>'-pijltje van de knop
const BUTTON_H := 34           # PartyCard.HEIGHT + 2

var buttons: Array[Button] = []
var cards: Array = []


func _ready() -> void:
	add_theme_constant_override("separation", 0)


## (Opnieuw) opbouwen voor de huidige party.
func build(party: Array) -> void:
	for b in buttons:
		b.queue_free()
	buttons.clear()
	cards.clear()
	for i in party.size():
		var b := UiMenu.button("")
		b.custom_minimum_size = Vector2(0, BUTTON_H)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): chosen.emit(i))
		var card := PartyCard.new()
		card.setup(party[i])
		card.set_anchors_preset(Control.PRESET_FULL_RECT)
		card.offset_left = CARD_INDENT
		card.offset_top = 1
		b.add_child(card)
		add_child(b)
		buttons.append(b)
		cards.append(card)
	# omhoog/omlaag blijft binnen deze lijst en loopt rond (D-pad én pijltjes)
	link_ring(buttons)


## Knoppen in een ring: omhoog/omlaag (focus_neighbor_*) en volgende/vorige (focus_next/
## previous, gebruikt door UiMenu.pad_nav) blijven binnen de lijst; links/rechts doet niets.
static func link_ring(list: Array) -> void:
	var n := list.size()
	for i in n:
		var b: Control = list[i]
		var prev: Control = list[(i - 1 + n) % n]
		var next: Control = list[(i + 1) % n]
		b.focus_neighbor_top = b.get_path_to(prev)
		b.focus_previous = b.get_path_to(prev)
		b.focus_neighbor_bottom = b.get_path_to(next)
		b.focus_next = b.get_path_to(next)
		b.focus_neighbor_left = NodePath(".")
		b.focus_neighbor_right = NodePath(".")


func refresh() -> void:
	for c in cards:
		c.refresh()


func focus_first(index := 0) -> void:
	if buttons.is_empty():
		return
	buttons[clampi(index, 0, buttons.size() - 1)].grab_focus()


func focused_index() -> int:
	for i in buttons.size():
		if buttons[i].has_focus():
			return i
	return -1
