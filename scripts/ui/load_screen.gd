extends CanvasLayer
## v0.22 Veldmenu > Load (Dennis): dezelfde slotlijst als op het titelscherm (save_slot_list.gd).
## Een slot kiezen vraagt eerst om bevestiging (save_prompt.gd, 'No' heeft de focus), omdat
## voortgang die niet is opgeslagen verloren gaat. Ja = GameState.continue_slot (zoals Laden op het
## titelscherm). B / Back = terug naar het veldmenu.

signal closed

const SaveSlotList := preload("res://scripts/ui/save_slot_list.gd")
const SavePrompt := preload("res://scripts/ui/save_prompt.gd")
const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const UiSfx := preload("res://scripts/ui/ui_sfx.gd")

const LAYER := 21
const QUESTION := "Load slot %d?"
const DETAIL := "Unsaved progress will be lost."

var root: Control
var list: Control = null
var prompt: CanvasLayer = null
## Laatste uitkomst (voor de tests): "", "cancelled", "declined" of "loading"
var result := ""
var _slot := -1


func _ready() -> void:
	layer = LAYER
	root = Control.new()
	root.theme = load(UiMenu.THEME_PATH)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_open_list()


func _open_list() -> void:
	list = SaveSlotList.new()
	list.picked.connect(_on_picked)
	list.cancelled.connect(_on_cancelled)
	root.add_child(list)


func _on_picked(slot: int) -> void:
	if prompt != null:
		return
	_slot = slot
	prompt = SavePrompt.new()
	prompt.question = "Load Autosave?" if slot == GameState.AUTOSAVE_SLOT else QUESTION % slot
	prompt.detail = DETAIL
	prompt.default_no = true
	prompt.answered.connect(_on_answer)
	add_child(prompt)


func _on_answer(yes: bool) -> void:
	prompt = null
	if not yes:
		result = "declined"
		return
	result = "loading"
	UiSfx.play(UiSfx.LOAD)
	await GameState.continue_slot(_slot)


func _on_cancelled() -> void:
	if prompt != null:
		return
	result = "cancelled"
	close()


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()
