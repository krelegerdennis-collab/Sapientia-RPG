extends SceneTree
## Lokale presentatie-checks (niet in tests.yml / game_state).
## Start: godot --headless --path . --script res://scripts/tests/telegraph_presentation_local_tests.gd

const TelegraphFloorArt := preload("res://scripts/som/telegraph_floor_art.gd")
const TelegraphLayer := preload("res://scripts/som/telegraph_layer.gd")
const TelegraphState := preload("res://scripts/som/telegraph_state.gd")


func _initialize() -> void:
	var failures := 0
	var passes := 0
	if TelegraphFloorArt.verify_sheet_column_transitions():
		passes += 1
		print("PASS  art: sheet_column flash -> hold")
	else:
		failures += 1
		print("FAIL  art: sheet_column flash -> hold")
	if _layer_entry_sync_sees_column_change():
		passes += 1
		print("PASS  layer: _entries_changed op sheet_column")
	else:
		failures += 1
		print("FAIL  layer: _entries_changed op sheet_column")
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	quit(1 if failures else 0)


func _layer_entry_sync_sees_column_change() -> bool:
	var layer := TelegraphLayer.new()
	var a := TelegraphLayer.DrawEntry.new()
	var b := TelegraphLayer.DrawEntry.new()
	a.fill_steps = 4
	b.fill_steps = 4
	a.phase = TelegraphState.State.ACTIVE
	b.phase = TelegraphState.State.ACTIVE
	a.active_ticks = 10
	b.active_ticks = 10
	a.ticks_left = 10
	b.ticks_left = 3
	layer._entries = [b]
	return layer._entries_changed([a])