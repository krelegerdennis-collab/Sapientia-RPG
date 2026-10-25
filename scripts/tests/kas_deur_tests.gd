extends Node
## Kas-poort op de wereldkaart (--kasdeurtest): dicht zonder Vesper, open met noor_lid na de Golem.
## Start: godot --path . -- --kasdeurtest

const SD := preload("res://scripts/data/story_data.gd")
const Berggrot := preload("res://scripts/data/berggrot_data.gd")

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	await _wacht(func() -> bool: return GameState._preloading.is_empty(), 15.0)
	_story_pick_tests()
	_wereldkaart_exit_tests()
	print("KASDEURTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _story_pick_tests() -> void:
	GameState.new_game("Dax")
	var had_golem: bool = GameState.story_flags.has(SD.GOLEM_FLAG)
	var had_lid: bool = GameState.story_flags.has(Berggrot.TUNNEL_VLAG)
	GameState.story_flags.erase(SD.GOLEM_FLAG)
	GameState.story_flags.erase(Berggrot.TUNNEL_VLAG)

	var no_archive: Dictionary = Story.pick("naar_leven")
	var no_archive_do: Array = no_archive.get("do", [])
	var no_archive_txt := _say_text(no_archive_do)
	check("dicht zonder First Archive: sealed shut", no_archive_txt.contains("sealed shut")
			and no_archive_txt.contains("First Archive"))
	check("dicht zonder First Archive: speler stapt terug", no_archive_do.size() > 1 and no_archive_do[1][0] == "walk")

	GameState.story_flags[SD.GOLEM_FLAG] = true
	var no_vesper: Dictionary = Story.pick("naar_leven")
	var no_vesper_do: Array = no_vesper.get("do", [])
	var no_vesper_txt := _say_text(no_vesper_do)
	check("dicht met Golem maar zonder Vesper: geen default", str(no_vesper.get("do", "")) != "default")
	check("dicht met Golem maar zonder Vesper: hint noemt Vesper", no_vesper_txt.contains("Vesper")
			and no_vesper_txt.contains("Dark Wood"))
	check("dicht met Golem maar zonder Vesper: speler stapt terug", no_vesper_do.size() > 1 and no_vesper_do[1][0] == "walk")

	GameState.story_flags[Berggrot.TUNNEL_VLAG] = true
	var open: Dictionary = Story.pick("naar_leven")
	check("open met Golem en Vesper (noor_lid)", str(open.get("do", "")) == "default")

	if not had_golem:
		GameState.story_flags.erase(SD.GOLEM_FLAG)
	if not had_lid:
		GameState.story_flags.erase(Berggrot.TUNNEL_VLAG)


func _wereldkaart_exit_tests() -> void:
	var wereld: Node = (load("res://scenes/maps/wereldkaart.tscn") as PackedScene).instantiate()
	var ex: Node = wereld.get_node("Exits/NaarKas")
	check("wereldkaart NaarKas: event naar_leven", str(ex.event) == "naar_leven")
	check("wereldkaart NaarKas: doel leven_ingang", str(ex.target_map).ends_with("leven_ingang.tscn"))
	wereld.free()


func _say_text(do_steps: Array) -> String:
	if do_steps.is_empty() or not (do_steps[0] is Array):
		return ""
	var first: Array = do_steps[0]
	if first.size() < 3 or first[0] != "say":
		return ""
	return " ".join(first[2])


func _wacht(cond: Callable, sec: float) -> void:
	var t := 0.0
	while not cond.call() and t < sec:
		t += get_process_delta_time()
		await get_tree().process_frame
