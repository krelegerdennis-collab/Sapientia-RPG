extends Node
## Betrouwbaar opslaan: atomaire vervanging, reservekopie, migratie en suspend.
## Start: godot --path . -- --savetest

const SAVE := "user://savetest_atomic.json"
const SUSPEND_SAVE := "user://savetest_suspend.json"

var failures := 0
var passes := 0


class SuspendScene extends Node:
	var path := ""

	func try_autosave(reason: String) -> bool:
		return GameState.autosave(Vector2i(7, 8), Vector2i.DOWN, reason)


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _remove_save(path: String) -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		var p := path + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _run() -> void:
	_remove_save(SAVE)
	_remove_save(SUSPEND_SAVE)
	GameState.new_game("Dax")
	GameState.current_map = "res://scenes/maps/wilgendal.tscn"

	GameState.gold = 10
	check("eerste atomaire save lukt", GameState.save_game(Vector2i(2, 3), Vector2i.DOWN, SAVE))
	GameState.gold = 20
	check("tweede atomaire save lukt", GameState.save_game(Vector2i(4, 5), Vector2i.UP, SAVE))
	check("atomaire save laat geen half tijdelijk bestand achter",
			not FileAccess.file_exists(SAVE + ".tmp")
			and int(GameState._read_save_file(SAVE).get("gold", -1)) == 20)
	check("vorige goede save staat als enige reservekopie",
			int(GameState._read_save_file(SAVE + ".bak").get("gold", -1)) == 10)
	check("save bevat een versienummer",
			int(GameState._read_save_file(SAVE).get("version", -1)) == GameState.SAVE_VERSION)

	_write(SAVE, "{\"gold\":")
	GameState.gold = 999
	check("corrupte hoofd-save laadt de reservekopie",
			GameState.load_game(SAVE) and GameState.gold == 10)

	_remove_save(SAVE)
	check("ontbrekende hoofd- en reserve-save crasht niet en laadt niet",
			not GameState.load_game(SAVE) and GameState.read_save(SAVE).is_empty())
	var old_path := GameState.save_path
	GameState.save_path = SAVE
	check("zonder beide bestanden toont het slot schoon als leeg voor New Game",
			GameState.slot_record(1).is_empty())
	GameState.save_path = old_path

	GameState.gold = 33
	check("save voor oud-formaatproef lukt", GameState.save_game(Vector2i(6, 7), Vector2i.LEFT, SAVE))
	var old := GameState._read_save_file(SAVE)
	old.erase("version")
	_write(SAVE, JSON.stringify(old))
	GameState.new_game("Dax")
	check("oude save zonder versienummer blijft laden",
			GameState.load_game(SAVE) and GameState.gold == 33)

	var prior_autosave := GameState.autosave_path
	GameState.autosave_path = SUSPEND_SAVE
	Settings.set_value("autosave", true)
	var fake := SuspendScene.new()
	get_tree().root.add_child(fake)
	var previous_scene := get_tree().current_scene
	get_tree().current_scene = fake
	GameState.in_battle = true
	GameState._notification(NOTIFICATION_APPLICATION_PAUSED)
	check("pauzeren tijdens een gevecht schrijft geen save",
			not FileAccess.file_exists(SUSPEND_SAVE)
			and not FileAccess.file_exists(SUSPEND_SAVE + ".tmp"))
	GameState.in_battle = false
	GameState._notification(NOTIFICATION_APPLICATION_PAUSED)
	check("pauzeren in een veilige veldstaat hergebruikt save_game",
			int(GameState.read_save(SUSPEND_SAVE).get("gold", -1)) == 33)
	get_tree().current_scene = previous_scene
	fake.queue_free()
	GameState.autosave_path = prior_autosave
	GameState.in_battle = false

	_remove_save(SAVE)
	_remove_save(SUSPEND_SAVE)
	print("SAVETEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % [
			"OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)
