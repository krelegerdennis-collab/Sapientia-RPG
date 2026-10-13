extends Node
## Onthulling van De Spiegel (Archief 4).
## Start:  godot --path . -- --spiegeltest [--shots=/pad/map]
##   Deel A: de letterlijke zinnen staan in de data, de weigering breekt, kracht niet,
##           De Spiegel heeft geen gevechts-HP, H-1 t/m H-5 blijven leeg.
##   Deel B: de kamer speelt de scène. Daarna is de kern opgenomen, Dennis zwijgt,
##           Noor en Lotte zeggen niets, en de wereldkaart wijst er niet naartoe.
## Zet geen verhaalvlag. Zit niet in de export als startscène.

const Data := preload("res://scripts/data/spiegel_data.gd")
const GD := preload("res://scripts/data/game_data.gd")

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	print("=== Deel A: data ===")
	_data()
	print("=== Deel B: kamer ===")
	await _kamer()
	print("SPIEGELTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await pframes(10)
	get_tree().quit(1 if failures else 0)


func _data() -> void:
	for zin in [Data.KAMER, Data.WAARHEID, Data.FEIT_H6, Data.FEIT_GEMAAKT, Data.FEIT_HANGER,
			Data.FEIT_TERUG, Data.WEIGERING, Data.LAATSTE, Data.KERN]:
		check("zin exact: %s" % zin, Data.heeft_zin(zin))
	check("weigering letterlijk", Data.heeft_zin("Ik ben Dennis. En dat is genoeg."))
	check("laatste woorden letterlijk",
			Data.heeft_zin("Je bent sterker dan de vorige vijf. Misschien... ben jij de eerste die het haalt."))
	var alles := "\n".join(Data.zinnen())
	for leeg in ["H-1", "H-2", "H-3", "H-4", "H-5"]:
		check("%s niet ingevuld" % leeg, not alles.contains(leeg))
	check("H-6 staat in de tekst", alles.contains("Proefpersoon H-6"))
	check("vorige vijf blijft zonder namen", alles.contains("de vorige vijf"))
	var stilte := Data.beat_index("stilte")
	var vragen := Data.beat_index("vragen")
	var weigering := Data.beat_index("weigering")
	var laatste := Data.beat_index("laatste")
	var na := Data.beat_index("na")
	check("Dennis: stilte, dan vragen, dan de weigering",
			stilte >= 0 and stilte < vragen and vragen < weigering)
	check("daarna de laatste woorden, dan de kern", weigering < laatste and laatste < na)
	var vragen_beat: Dictionary = Data.BEATS[vragen]
	var vraag_regels: Array = vragen_beat.get("tekst", [])
	check("de vragen eindigen op een vraagteken",
			not vraag_regels.is_empty() and vraag_regels.all(func(r: String) -> bool: return r.ends_with("?")))
	check("stilte heeft geen tekst", not (Data.BEATS[stilte] as Dictionary).has("tekst"))
	var heel: Dictionary = {"gebroken": false, "gebroken_door": ""}
	var door_kracht: Dictionary = Data.pas_toe("kracht", heel)
	var door_weigering: Dictionary = Data.pas_toe("weigering", heel)
	check("kracht breekt de spiegel niet", door_kracht["gebroken"] == false and str(door_kracht["gebroken_door"]) == "")
	check("de weigering breekt de spiegel", door_weigering["gebroken"] == true
			and str(door_weigering["gebroken_door"]) == "weigering")
	check("De Spiegel heeft geen gevechts-HP", not Data.heeft_gevechts_hp())
	var vijand := false
	for id in GD.ENEMIES:
		var e: Dictionary = GD.ENEMIES[id]
		if str(id).find("spiegel") >= 0 or str(e.get("name", "")).find("Spiegel") >= 0:
			vijand = true
	check("De Spiegel staat niet als vijand met HP in de gevechtsdata", not vijand)
	var uit: Dictionary = Data.speel()
	check("afspelen: gebroken door de weigering, niet door kracht",
			uit["gebroken"] == true and str(uit["gebroken_door"]) == "weigering" and uit["kracht_breekt"] == false)
	check("afspelen: geen gevechts-HP", uit["gevechts_hp"] == false and not uit.has("hp"))
	check("na-scène: kern van Archief 4 opgenomen", uit["kern_opgenomen"] == true and Data.heeft_zin(Data.KERN))
	check("na de weigering zwijgt Dennis", (uit["dennis_na_weigering"] as Array).is_empty())
	check("Noor zegt niets", (uit["noor"] as Array).is_empty() and not Data.sprekers().has("Noor"))
	check("Lotte zegt niets", (uit["lotte"] as Array).is_empty() and not Data.sprekers().has("Lotte"))
	check("geen gesprek op de World Warper", (uit["world_warper"] as Array).is_empty())
	check("scène staat niet in scenes/maps", not Data.SCENE.contains("scenes/maps/"))
	var ph := FileAccess.get_file_as_string("res://tools/placeholders_v17.txt")
	check("placeholder kamer geregistreerd", ph.contains("assets/bg/spiegel_kamer.png")
			and ph.contains("assets/bg/spiegel_kamer_gebroken.png"))
	for pad in ["res://scenes/maps/wereldkaart.tscn", "res://scripts/data/story_data.gd",
			"res://scripts/data/dungeon_rooms.gd", "res://scripts/data/archief2_rooms.gd",
			"res://world_warper/warp/destinations.gd"]:
		var tekst := FileAccess.get_file_as_string(pad)
		check("%s wijst niet naar de spiegelkamer" % pad.get_file(),
				not tekst.contains("spiegel_kamer") and not tekst.contains("spiegel_data"))


func _kamer() -> void:
	var stap := GameState.story_step
	var vlaggen: Dictionary = GameState.story_flags.duplicate()
	var kernen := GameState.kernfragmenten.size()
	var party := GameState.party.size()
	get_tree().change_scene_to_file(Data.SCENE)
	var kamer: Node = await _wacht_kamer()
	check("debug-scène start", kamer != null and kamer.name == "SpiegelKamer")
	if kamer == null:
		return
	check("kamer is eerst heel", kamer.gebroken == false
			and str(kamer.achtergrond.texture.resource_path).ends_with("spiegel_kamer.png"))
	var tex: Texture2D = kamer.achtergrond.texture
	check("achtergrond 384x216", tex != null and tex.get_size() == Vector2(384, 216))
	# v0.21: echte art van RPG ART (batch 8), geen magenta placeholder-hoek meer; staat in handwerk.txt
	var hoek := tex.get_image().get_pixel(0, 0)
	check("echte art: geen magenta hoek, in handwerk.txt", not (hoek.r > 0.9 and hoek.b > 0.8 and hoek.g < 0.25)
			and FileAccess.get_file_as_string("res://tools/handwerk.txt").contains("assets/bg/spiegel_kamer_gebroken.png"))
	await pframes(2)
	await screenshot("spiegel_kamer")
	var n := 0
	while not kamer.klaar and n < 800:
		if Dialog.is_open:
			Dialog.advance()
		n += 1
		await pframes(1)
	check("scène speelt af", kamer.klaar)
	check("de weigering is getoond en breekt de spiegel",
			kamer.gebroken and kamer.breek_zin == "Ik ben Dennis. En dat is genoeg."
			and kamer.getoond.has(Data.WEIGERING))
	check("gebroken plaatje staat", str(kamer.achtergrond.texture.resource_path).ends_with("spiegel_kamer_gebroken.png"))
	check("kern opgenomen, daarna niets meer van Dennis", kamer.kern_opgenomen
			and kamer.getoond[kamer.getoond.size() - 1] == Data.KERN
			and kamer.getoond.has(Data.LAATSTE))
	var dennis_na := false
	var gezien := false
	for id in kamer.gespeeld:
		if id == "weigering":
			gezien = true
			continue
		if gezien and id in ["vragen", "stilte"]:
			dennis_na = true
	check("na de weigering geen nieuwe vraag of stilte van Dennis", gezien and not dennis_na)
	check("verhaalstap ongewijzigd", GameState.story_step == stap)
	check("geen verhaalvlag gezet", GameState.story_flags == vlaggen)
	check("geen kern via het gevechtssysteem", GameState.kernfragmenten.size() == kernen)
	check("groep ongewijzigd", GameState.party.size() == party)
	check("wereldkaart niet de lopende map", not str(GameState.current_map).contains("spiegel"))
	await screenshot("spiegel_gebroken")


func _wacht_kamer() -> Node:
	for _i in 90:
		var s := get_tree().current_scene
		if s != null and s.name == "SpiegelKamer" and s.is_node_ready():
			return s
		await pframes(1)
	return null


func pframes(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func screenshot(naam: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot mogelijk")
		return
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join(naam + ".png"))
	print("INFO  screenshot: ", shots.path_join(naam + ".png"), " ", img.get_size())
