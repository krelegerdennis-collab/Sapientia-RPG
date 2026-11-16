extends RefCounted
## Slot voor de noordpoort lobby → hal. apply() zet de uitgang dicht tot noor_lid.

const FLAG := "noor_lid"
const CLOSED_LINE := "The gate is closed."


static func is_open() -> bool:
	return Story.has_flag(FLAG)


static func apply(exit: MapExit, target_map: String, target_spawn: String) -> void:
	if exit == null:
		return
	if is_open():
		exit.target_map = target_map
		exit.target_spawn = target_spawn
		var empty: Array[String] = []
		exit.lines = empty
	else:
		exit.target_map = ""
		exit.target_spawn = ""
		var closed: Array[String] = [CLOSED_LINE]
		exit.lines = closed
