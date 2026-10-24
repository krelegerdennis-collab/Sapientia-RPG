extends "res://scripts/dungeon/dungeon_room.gd"
## Kamer van Het Levende Archief. Zelfde opbouw als DungeonRoom, data uit archief2_rooms.gd
## (via DungeonRooms.room). Platen, de Lotte-ontmoeting en de hub horen hier.

const CanonGenezer := preload("res://world_warper/cutscene/genezer_scene.gd")
const Archief2 := preload("res://scripts/data/archief2.gd")
const PlaatScript := preload("res://scripts/dungeon/groei_plaat.gd")
const WarpScript := preload("res://scripts/dungeon/archief2_warp.gd")

var platen: Array = []


func _ready() -> void:
	super._ready()
	_plaats_platen()
	_plaats_sfeer()
	_plaats_warp()
	_tint_lotte()
	if is_instance_valid(player) and not player.stepped.is_connected(_plaat_stap):
		player.stepped.connect(_plaat_stap)
	_koppel_kern()
	_verhaal()


func start_monster_battle(m: Node) -> void:
	if str(m.data.get("enemy", "")) == "lotte_glitch":
		_start_lotte(m)
		return
	super.start_monster_battle(m)


func zet_brug(plaat_id: String, open: bool) -> void:
	var n := 0 if open else 59
	for b in room.get("bruggen", []):
		if str(b.get("plaat", "")) != plaat_id:
			continue
		for t in b.get("tiles", []):
			var cel := Vector2i(int(t[0]), int(t[1]))
			_cells[cel] = n
			set_tile(ground, cel, n)


func ketting_stap(index: int) -> void:
	var rij: Array = []
	for p in platen:
		if is_instance_valid(p) and str(p.soort) == "ketting":
			rij.append(p)
	rij.sort_custom(func(a, b): return int(a.index) < int(b.index))
	var staten: Array = []
	for p in rij:
		staten.append(int(p.staat))
	var nieuw := Archief2.pas_ketting(staten, index)
	for i in rij.size():
		rij[i].pas_toe(int(nieuw[i]))


func raak_plaat(plaat_id: String, actie: String) -> void:
	for p in platen:
		if is_instance_valid(p) and str(p.plaat_id) == plaat_id:
			p.raak(actie)
			return


func plaat_van(plaat_id: String) -> Node:
	for p in platen:
		if is_instance_valid(p) and str(p.plaat_id) == plaat_id:
			return p
	return null


func _plaat_stap(t: Vector2i) -> void:
	for p in platen:
		if not is_instance_valid(p):
			continue
		if p.tile == t and str(p.soort) != "licht":
			p.raak("stap")


func _plaats_platen() -> void:
	for d in room.get("platen", []):
		var p: Area2D = PlaatScript.new()
		p.setup(self, d)
		$Objects.add_child(p)
		platen.append(p)


func _plaats_sfeer() -> void:
	for s in room.get("sfeer", []):
		var sp := Sprite2D.new()
		sp.name = str(s.get("name", "Sfeer"))
		var path := str(s.get("texture", ""))
		if path != "" and ResourceLoader.exists(path):
			sp.texture = load(path)
		sp.centered = true
		var sc := float(s.get("scale", 1.0))
		sp.scale = Vector2(sc, sc)
		var t: Array = s.get("tile", [0, 0])
		sp.position = Vector2(int(t[0]), int(t[1])) * 16.0 + Vector2(8, 8)
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		$Objects.add_child(sp)


func _plaats_warp() -> void:
	if not room.has("warp"):
		return
	var t: Array = room["warp"]
	var w: Area2D = WarpScript.new()
	w.setup(Vector2i(int(t[0]), int(t[1])))
	add_child(w)


func _tint_lotte() -> void:
	var ml := get_node_or_null("Objects/Monster_lotte")
	if ml and "sprite" in ml and ml.sprite:
		ml.sprite.modulate = Color(0.75, 0.45, 1.15)


func _koppel_kern() -> void:
	for c in get_children():
		var sc = c.get_script()
		if sc and str(sc.resource_path).ends_with("kern_absorption.gd") and c.has_signal("done"):
			if not c.done.is_connected(_na_kern):
				c.done.connect(_na_kern)


func _na_kern() -> void:
	if room_id != "archief_2_v4_genezer":
		return
	if not GameState.kernfragmenten.has(Archief2.KERN_ID):
		return
	# Canon-scène 1 (CANON.md punt 17): de World Warper verschijnt, daarna warp naar de Hal.
	if CanonGenezer.speel(self):
		return
	await _zeg(Archief2.NA_GENEZER, "")
	GameState.story_flags["archief2_naar_warper"] = true
	var NaGenezer := preload("res://world_warper/flow/na_genezer.gd")
	NaGenezer.probeer()


func _verhaal() -> void:
	if GameState.archief2_lotte_join:
		GameState.archief2_lotte_join = false
		Archief2.sluit_lotte_aan()
		await _zeg(Archief2.LOTTE_AANSLUIT, "Seren")
	if room_id == Archief2.ENTREE and not GameState.story_flags.has("archief2_keten"):
		await _zeg(Archief2.KETEN, "")
		GameState.story_flags["archief2_keten"] = true
	# Save-veilig: kern al binnen maar scène 1 nooit afgemaakt (afgesloten tijdens de scène).
	if room_id == "archief_2_v4_genezer" and GameState.kernfragmenten.has(Archief2.KERN_ID) \
			and str(GameState.pending_kern_absorb) == "" and not GameState.world_warper_is_unlocked():
		if CanonGenezer.speel(self):
			return
	if room_id == Archief2.WARPER and not GameState.story_flags.has("archief2_echo"):
		await _zeg(Archief2.ECHO_REGELS, "")
		GameState.story_flags["archief2_echo"] = true


func _zeg(lines: Array, speaker: String) -> void:
	if is_instance_valid(player):
		player.input_locked = true
	await get_tree().create_timer(0.35).timeout
	Dialog.show_lines(lines, speaker)
	await Dialog.finished
	if is_instance_valid(player) and not GameState.changing_map and not GameState.in_battle:
		player.input_locked = false


func _start_lotte(m: Node) -> void:
	_touch_lock = true
	last_touch_id = m.monster_id
	var t := _prepare_battle(m.monster_id)
	var pages: Array = []
	for p in GameState.codex_pages:
		if int(p.get("hp", 0)) > 0:
			pages.append(p)
	var keuze: Dictionary
	# Informatieve regels niet awaiten: start_monster_battle is fire-and-forget
	# (somroomstest, aanraken). await Dialog.finished liet het TURN-BASED gevecht
	# nooit starten als niemand de tekst doorklikte (CI op main: HP/ATK/DEF [] = []).
	if pages.is_empty():
		keuze = Archief2.bondgenoot_voor([], GameState.member_level("dennis"))
		Dialog.show_lines(Archief2.GEEN_CODEX, "")
	elif pages.size() == 1:
		keuze = Archief2.bondgenoot_voor(pages, GameState.member_level("dennis"))
		Dialog.show_lines(["%s fights alongside you." % str(pages[0].get("name", "Monster"))], "")
	else:
		var namen: Array = []
		for p in pages:
			namen.append(str(p.get("name", "Monster")))
		var i := await Dialog.ask("Which Codex monster fights alongside you?", namen, "")
		if i < 0 or i >= pages.size():
			i = 0
		keuze = {"page": pages[i], "tijdelijk": false}
	Archief2.zet_bondgenoot(keuze)
	GameState.pending_story_loss = true
	GameState.archief2_party_filter = "dennis"
	GameState.start_battle(m.group.duplicate(), t, player.facing, terrain_at(t), true, 0, true)
