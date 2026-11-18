extends RefCounted
## F6.3 guard: map.gd roept RunUitleg.op_stap zonder await aan. Meerdere stappen in hetzelfde
## of volgende frames mogen de RUN-uitleg maar één keer tonen.
## Registratie: scripts/tests/f6_ux2_tests.gd (map-scan).

const SD := preload("res://scripts/data/story_data.gd")
const RunUitleg := preload("res://scripts/run_uitleg.gd")


func needs_game() -> bool:
	return true


func run(t: Node) -> void:
	GameState.story_flags.erase(SD.RUN_UITLEG_FLAG)
	if not GameState.change_map("res://scenes/maps/huis_wilgendal.tscn", "bed"):
		t.check("F6.3g: kaart huis laden", false)
		return
	var ok: bool = await t.sc.wait_scene("Huis", 12.0)
	t.check("F6.3g: huis geladen", ok)
	if not ok:
		return
	await t.pframes(8)
	var m: Node = t.sc.scene()
	var p: Node = m.get_node_or_null("Objects/Player")
	t.check("F6.3g: speler aanwezig", p != null)
	if p == null:
		return
	var tile: Vector2i = p.get_tile()
	var getoond := [0]
	# Drie stappen in hetzelfde frame (zoals map.gd zonder await).
	m.call("_on_player_stepped", tile)
	m.call("_on_player_stepped", tile)
	m.call("_on_player_stepped", tile)
	await t.pframes(2)
	t.check("F6.3g: uitleg open", Dialog.is_open and str(Dialog._lines[0]) == SD.RUN_UITLEG_LINE)
	t.check("F6.3g: guard actief tijdens lezen", RunUitleg.is_bezig())
	t.check("F6.3g: één regel in de dialoog", Dialog._lines.size() == 1)
	# Lees de regel uit; tel hoeveel keer de dialoog daarna nog opengaat.
	while Dialog.is_open:
		Dialog.advance()
		await t.pframes(2)
	for i in 3:
		m.call("_on_player_stepped", tile)
		await t.pframes(2)
		if Dialog.is_open:
			getoond[0] += 1
			while Dialog.is_open:
				Dialog.advance()
				await t.pframes(2)
	t.check("F6.3g: geen tweede RUN-uitleg na sluiten", getoond[0] == 0)
	t.check("F6.3g: vlag gezet", GameState.story_flags.has(SD.RUN_UITLEG_FLAG))
	t.check("F6.3g: guard weer vrij", not RunUitleg.is_bezig())
