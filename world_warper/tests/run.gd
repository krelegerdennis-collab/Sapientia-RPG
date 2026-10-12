extends SceneTree
## Pure World Warper-tests plus een scène-smoke.
## Geen game_state-dispatch. De job warper-runner in .github/workflows/tests.yml draait dit script.
##
##   godot --headless --path . --script res://world_warper/tests/run.gd
##
## --script eist een SceneTree. De eerste _process draait ná de autoloads.

const UnlockTest := preload("res://world_warper/flow/unlock_test.gd")
const DialoogTest := preload("res://world_warper/guide/dialoog_test.gd")
const DreigingTest := preload("res://world_warper/cutscene/dreiging_test.gd")
const SpawnTest := preload("res://world_warper/wander/spawn_test.gd")
const PartyTest := preload("res://world_warper/services/party_view_test.gd")

var _failures := 0
var _gestart := false


func _process(_delta: float) -> bool:
	if _gestart:
		return true
	_gestart = true
	_draai()
	if _failures == 0:
		print("RESULT OK")
		quit(0)
	else:
		print("RESULT FAIL")
		quit(1)
	return true


func _draai() -> void:
	_rapport("unlock lege flags", UnlockTest.lege_flags())
	_rapport("unlock alleen bewaker", UnlockTest.alleen_bewaker())
	_rapport("unlock al open", UnlockTest.al_open())
	_rapport("unlock andere bewaker", UnlockTest.andere_bewaker())
	# Pas hier laden: destinations.gd noemt GameState, en dat script noemt Transition.
	# Een preload bovenaan parseert dat vóór de autoloads bestaan.
	var DestinationsTest: Script = load("res://world_warper/warp/destinations_test.gd")
	_rapport("warp WM2 dicht", DestinationsTest.call("wm2_dicht"))
	_rapport("warp WM1 echte bestemming", DestinationsTest.call("wm1_echte_bestemming"))
	_rapport("warp onbekend id", DestinationsTest.call("onbekend_id_faalt"))
	_rapport("warp bezoek", DestinationsTest.call("bezoek_filter"))
	_rapport("dialoog", DialoogTest.fouten())
	_dreiging()
	_spawn()
	_party()
	_smoke()


func _dreiging() -> void:
	var node: Node = DreigingTest.new()
	node._run()
	_failures += int(node.get("failures"))


func _spawn() -> void:
	var leeg: Array[Dictionary] = SpawnTest.descriptors([], [])
	_check("spawn lege invoer", leeg.is_empty())
	var party: Array[Dictionary] = SpawnTest.descriptors([
		{"id": "held", "name": "Mira"},
		"geen-dict",
		{},
		{"naam": "Los"},
	], [])
	_check("spawn party houdt id en naam", party.size() == 2 and party[0]["id"] == "held" and party[0]["naam"] == "Mira")
	_check("spawn naam zonder id", party.size() == 2 and party[1]["id"] == "Los" and party[1]["naam"] == "Los")
	var codex: Array[Dictionary] = SpawnTest.descriptors([], [
		{"uid": "a", "id": "soort", "species": "kever", "name": "Kever"},
		{"uid": "b", "species": "kever", "name": "Kever"},
		{"id": "alleen"},
		{"species": "spin"},
	])
	_check("spawn codex uid blijft het exemplaar", codex.size() == 4 and codex[0]["id"] == "a" and codex[0]["naam"] == "Kever")
	_check("spawn twee dezelfde soorten", codex[1]["id"] == "b")
	_check("spawn codex id zonder uid", codex[2]["id"] == "alleen" and codex[2]["naam"] == "alleen")
	_check("spawn codex species als laatste", codex[3]["id"] == "spin" and codex[3]["naam"] == "spin")


func _party() -> void:
	var leeg: Array[String] = PartyTest.lines([])
	_check("party lege lijst", leeg.is_empty())
	var regels: Array[String] = PartyTest.lines([
		{"name": "Mira", "level": 4},
		{"name": "  ", "level": null},
		{"level": "3"},
		{"name": "Bo", "level": 2.9},
		12,
	])
	_check("party naam en niveau", regels.size() == 4 and regels[0] == "Mira, niveau 4")
	_check("party lege naam is Onbekend", regels[1] == "Onbekend, niveau 1")
	_check("party niveau uit tekst", regels[2] == "Onbekend, niveau 3")
	_check("party niveau uit float", regels[3] == "Bo, niveau 2")


func _smoke() -> void:
	var paden := _scenes("res://world_warper")
	if paden.is_empty():
		_fail("smoke geen scènes")
		return
	for pad in paden:
		_smoke_scene(pad)
	var scripts := _bestanden("res://world_warper", ".gd")
	if scripts.is_empty():
		_fail("smoke geen scripts")
		return
	for pad in scripts:
		_smoke_script(pad)


func _smoke_scene(pad: String) -> void:
	if not ResourceLoader.exists(pad):
		_fail("smoke ontbreekt %s" % pad)
		return
	var res: Resource = ResourceLoader.load(pad, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null or not (res is PackedScene):
		_fail("smoke null %s" % pad)
		return
	for dep in ResourceLoader.get_dependencies(pad):
		var bron := _dep_pad(str(dep))
		if bron == "" or bron.ends_with(".gd"):
			continue
		var sub: Resource = ResourceLoader.load(bron, "", ResourceLoader.CACHE_MODE_REUSE)
		if sub == null:
			_fail("smoke kapotte afhankelijkheid %s van %s" % [bron, pad])
			return
	_pass("smoke %s" % pad)


func _smoke_script(pad: String) -> void:
	var scr: Script = load(pad) as Script
	if scr == null or not scr.can_instantiate():
		_fail("smoke script %s" % pad)
		return
	_pass("smoke script %s" % pad)


func _dep_pad(dep: String) -> String:
	var delen := dep.split("::", false)
	for deel in delen:
		var tekst := str(deel)
		if tekst.begins_with("res://") or tekst.begins_with("user://"):
			return tekst
	if dep.begins_with("res://") or dep.begins_with("user://"):
		return dep
	return ""


func _scenes(root: String) -> PackedStringArray:
	return _bestanden(root, ".tscn")


func _bestanden(root: String, ext: String) -> PackedStringArray:
	var uit := PackedStringArray()
	_loop(root, ext, uit)
	uit.sort()
	return uit


func _loop(pad: String, ext: String, uit: PackedStringArray) -> void:
	var dir := DirAccess.open(pad)
	if dir == null:
		return
	dir.list_dir_begin()
	var naam := dir.get_next()
	while naam != "":
		if not naam.begins_with("."):
			var volledig := pad.path_join(naam)
			if dir.current_is_dir():
				_loop(volledig, ext, uit)
			elif naam.ends_with(ext):
				uit.append(volledig)
		naam = dir.get_next()
	dir.list_dir_end()


func _rapport(naam: String, fouten: Variant) -> void:
	if fouten is PackedStringArray:
		var packed := fouten as PackedStringArray
		if packed.is_empty():
			_pass(naam)
			return
		for regel in packed:
			_fail("%s: %s" % [naam, regel])
		return
	if fouten is Array:
		var arr := fouten as Array
		if arr.is_empty():
			_pass(naam)
			return
		for regel in arr:
			_fail("%s: %s" % [naam, str(regel)])
		return
	_fail("%s: onbekend resultaat" % naam)


func _check(naam: String, ok: bool) -> void:
	if ok:
		_pass(naam)
	else:
		_fail(naam)


func _pass(naam: String) -> void:
	print("PASS %s" % naam)


func _fail(naam: String) -> void:
	_failures += 1
	print("FAIL %s" % naam)
