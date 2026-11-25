extends RefCounted
## Eenmalige RUN-uitleg bij de eerste vrije stap op het veld (F6.3).

const SD := preload("res://scripts/data/story_data.gd")


static func _suite_draait() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--autotest" or arg == "--menutest" or (arg.begins_with("--") and arg.ends_with("test")):
			return true
	return false


static func op_stap(speler: Node) -> void:
	if _suite_draait():
		return
	if GameState.story_flags.has(SD.RUN_UITLEG_FLAG):
		return
	if not _mag(speler):
		return
	Dialog.show_lines([SD.RUN_UITLEG_LINE])
	# Vlag pas zetten als de speler de regel echt gelezen en gesloten heeft.
	await Dialog.finished
	GameState.story_flags[SD.RUN_UITLEG_FLAG] = true


static func _mag(speler: Node) -> bool:
	if not GameState.field_free():
		return false
	if GameState.in_battle:
		return false
	if Dialog.is_open:
		return false
	var story: Node = speler.get_node_or_null("/root/Story")
	if story != null and bool(story.get("running")):
		return false
	if speler.get("input_locked") == true:
		return false
	if speler.get("_scripted") == true:
		return false
	return true