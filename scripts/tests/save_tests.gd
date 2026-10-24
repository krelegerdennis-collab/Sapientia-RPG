extends Node
## Betrouwbaar opslaan: atomaire vervanging, reservekopie, migratie en foutmeldingen.
## Start: godot --path . -- --savetest

const SAVE := "user://savetest_atomic.json"

var failures := 0
var passes := 0


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
		var p: String = path + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _run() -> void:
	_remove_save(SAVE)
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
	_write(SAVE, "{\"gold\":")
	var corrupt_record := GameState.slot_record(1)
	check("onherstelbaar corrupt bestaand slot wordt niet stil als leeg behandeld",
			not corrupt_record.is_empty() and bool(corrupt_record.get("corrupt", false)))
	GameState.save_path = old_path
	_remove_save(SAVE)

	GameState.gold = 33
	check("save voor oud-formaatproef lukt", GameState.save_game(Vector2i(6, 7), Vector2i.LEFT, SAVE))
	var old := GameState._read_save_file(SAVE)
	old.erase("version")
	_write(SAVE, JSON.stringify(old))
	GameState.new_game("Dax")
	check("oude save zonder versienummer blijft laden",
			GameState.load_game(SAVE) and GameState.gold == 33)

	_remove_save(SAVE)
	GameState.gold = 40
	check("save na een eerdere gelukte save lukt", GameState.save_game(Vector2i(1, 1), Vector2i.DOWN, SAVE))
	_write(SAVE + ".tmp", "{\"gold\":")
	GameState.gold = 41
	check("achtergebleven halve .tmp blokkeert de volgende save niet",
			GameState.save_game(Vector2i(1, 2), Vector2i.DOWN, SAVE)
			and not FileAccess.file_exists(SAVE + ".tmp")
			and int(GameState._read_save_file(SAVE).get("gold", -1)) == 41
			and int(GameState._read_save_file(SAVE + ".bak").get("gold", -1)) == 40)
	var emitted: Array = []
	var on_saved := func(p: String, ok: bool) -> void: emitted.append([p, ok])
	GameState.game_saved.connect(on_saved)
	var bad_ok := GameState.save_game(Vector2i(1, 3), Vector2i.DOWN, "user://bestaat_niet_dir/x.json")
	GameState.save_game(Vector2i(1, 4), Vector2i.DOWN, SAVE)
	GameState.game_saved.disconnect(on_saved)
	check("mislukte save meldt false en een gelukte meldt true via game_saved",
			not bad_ok and emitted.size() == 2 and emitted[0][1] == false and emitted[1][1] == true)

	_remove_save(SAVE)
	print("SAVETEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % [
			"OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)
