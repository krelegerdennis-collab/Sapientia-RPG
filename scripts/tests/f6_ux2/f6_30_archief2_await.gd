extends RefCounted
## F6-30: als archief2_room mid-dialoog wordt vrijgegeven, staan archief2_keten,
## archief2_echo en archief2_naar_warper al, en volgt geen
## "Resumed function _zeg() after await, but class instance is gone".
## Registratie: map-scan in scripts/tests/f6_ux2_tests.gd (--f6uxtest2).

const Archief2 := preload("res://scripts/data/archief2.gd")
const Canon := preload("res://world_warper/cutscene/canon_scenes.gd")
const GONE := "class instance is gone"

func needs_game() -> bool:
	return true


func run(t: Node) -> void:
	var flags_voor: Dictionary = GameState.story_flags.duplicate(true)
	var kernen_voor: Dictionary = GameState.kernfragmenten.duplicate(true)
	var lotte_voor: bool = GameState.archief2_lotte_join
	var pending_voor: String = str(GameState.pending_kern_absorb)
	GameState.archief2_lotte_join = false
	GameState.pending_kern_absorb = ""
	if Dialog.is_open:
		Dialog.close()
	await t.pframes(2)

	await _geval(t, "archief2_keten", Archief2.ENTREE_SCENE, "archief2_keten", false)
	await _geval(t, "archief2_echo", Archief2.WARPER_SCENE, "archief2_echo", false)
	await _geval(t, "archief2_naar_warper", "res://scenes/maps/archief_2_v4_genezer.tscn", "archief2_naar_warper", true)

	if Dialog.is_open:
		Dialog.close()
	GameState.story_flags = flags_voor
	GameState.kernfragmenten = kernen_voor
	GameState.archief2_lotte_join = lotte_voor
	GameState.pending_kern_absorb = pending_voor
	await t.pframes(2)


func _geval(t: Node, tag: String, scene: String, vlag: String, na_kern: bool) -> void:
	GameState.story_flags.erase("archief2_keten")
	GameState.story_flags.erase("archief2_echo")
	GameState.story_flags.erase("archief2_naar_warper")
	GameState.archief2_lotte_join = false
	if na_kern:
		GameState.story_flags[Canon.FLAG_GENEZER] = true
		GameState.kernfragmenten[Archief2.KERN_ID] = {"bron": "test"}
		GameState.pending_kern_absorb = ""
	if Dialog.is_open:
		Dialog.close()

	var host := Node.new()
	host.name = "F6_30_%s" % tag
	t.get_tree().root.add_child(host)
	var packed: PackedScene = load(scene) as PackedScene
	t.check("%s: scène laadt (%s)" % [tag, scene], packed != null)
	if packed == null:
		host.queue_free()
		return
	var room: Node = packed.instantiate()
	host.add_child(room)
	await t.pframes(6)
	t.check("%s: kamer staat in de boom" % tag, is_instance_valid(room) and room.is_inside_tree())
	if na_kern and is_instance_valid(room):
		room._na_kern()
		await t.pframes(2)

	t.check("%s: vlag %s staat vóór het einde van de dialoog" % [tag, vlag], GameState.story_flags.has(vlag))

	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2000 and not Dialog.is_open:
		await t.pframes(1)
	t.check("%s: dialoog is open (mid-dialoog)" % tag, Dialog.is_open)

	var log_voor := _log_tekst()
	if is_instance_valid(room):
		room.free()
	await t.pframes(8)
	t.check("%s: kamer is weg" % tag, not is_instance_valid(room))
	if Dialog.is_open:
		Dialog.close()
	await t.pframes(20)

	t.check("%s: vlag %s blijft staan na free" % [tag, vlag], GameState.story_flags.has(vlag))
	var extra := _log_nieuw(log_voor)
	var fout := extra.find(GONE) >= 0 or extra.find("SCRIPT ERROR") >= 0 or extra.find("previously freed") >= 0
	t.check("%s: geen resume-fout (instance gone) in de err-log" % tag, not fout)
	if fout:
		print("INFO  F6-30 %s log-nieuw: %s" % [tag, extra.substr(0, 400)])

	if is_instance_valid(host):
		host.queue_free()
	await t.pframes(3)
	if Dialog.is_open:
		Dialog.close()


func _log_pad() -> String:
	var p := ProjectSettings.globalize_path("user://logs/godot.log")
	if FileAccess.file_exists(p):
		return p
	return OS.get_user_data_dir().path_join("logs/godot.log")


func _log_tekst() -> String:
	var p := _log_pad()
	if not FileAccess.file_exists(p):
		return ""
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s


func _log_nieuw(voor: String) -> String:
	var nu := _log_tekst()
	if nu.begins_with(voor):
		return nu.substr(voor.length())
	return nu
