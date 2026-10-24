extends Node
## ALLEEN VOOR TESTEN - UX-polish WM1 (release fase 6). Nieuwe suite; raakt geen bestaande tests.
## Start:  godot --path . -- --uxtest [--shots=/pad/map]   (scripts/tests/ux_tests.gd)
##   Deel A: Engelse spelertekst (data-scan, scenes, regressie op de gerepareerde Nederlandse regels)
##   Deel B: tikdoelen >= 48dp (UiTouch): titel, veldmenu + alle subschermen, opslaan, winkel, dialoogkeuzes,
##           HUD (A/B/MENU/RUN/KERN), gevechtskruis en -menu, Action-knoppen; bekende uitzonderingen geteld
##   Deel C: tutorials: elke tutorial 1x, altijd te skippen, menupaden in de tekst bestaan, geen herstart
##   Deel D: 19,5:9 en 20:9 + veilige zone (notch): alles binnen beeld en binnen de veilige rechthoek
##   Deel E: geluid: UI-cues in het manifest, knoppen klikken, menu open/dicht, dialoog, opslaan, en het
##           volume (muziek/effecten/mute) blijft bewaard na een herstart van Settings
## De maatstok en de veilige zone komen uit scripts/ui/ui_touch.gd (PR #219); dit bestand test alleen wat --uipolishtest niet doet.
## Met --shots=map: ux_*.png (384x216 resp. 468x216/480x216 viewport-beelden).
## Zit niet in de export (scripts/tests/*).

const UiSfx := preload("res://scripts/ui/ui_sfx.gd")
const SD := preload("res://scripts/data/story_data.gd")
const GD := preload("res://scripts/data/game_data.gd")
const SomDataT := preload("res://scripts/data/som_data.gd")
const ShopData := preload("res://scripts/data/shop_data.gd")
const PartyActions := preload("res://scripts/party_actions.gd")
const SaveScreenS := preload("res://scripts/ui/save_screen.gd")
const SavePromptS := preload("res://scripts/ui/save_prompt.gd")
const SaveSlotListS := preload("res://scripts/ui/save_slot_list.gd")
const BattleS := preload("res://scripts/battle/battle.gd")
const FieldMenuS := preload("res://scripts/ui/field_menu.gd")
const OptionsScreenS := preload("res://scripts/ui/options_screen.gd")
const EquipmentS := preload("res://scripts/equipment.gd")
const SettingsS := preload("res://scripts/settings.gd")

const FLAG := "tutorial_na_inktwurm_gezien"
const EV := "tutorial_na_inktwurm"
const WILGENDAL := "res://scenes/maps/wilgendal.tscn"

## Nederlandse stopwoorden (hele woorden). Een speler-zin met >= 2 hiervan telt als Nederlands.
const NL_STOP := ["de", "het", "een", "niet", "geen", "naar", "voor", "met", "van", "bij", "maar", "dat", "deze",
		"je", "jij", "jouw", "wij", "zijn", "wordt", "worden", "heeft", "hebben", "kan", "moet", "ook", "nog", "meer",
		"alleen", "tijdens", "tegen", "onder", "boven", "waar", "wie", "hoe", "waarom", "kun", "kom", "neem", "geef",
		"vecht", "herstelt", "versterkt", "geneest", "opslaan", "sluiten", "terug", "kies", "kiezen", "stap", "erop",
		"laat", "groeien", "waarheen", "eilanden", "niemand", "gezelschap", "wisselen", "gratis", "rustkamer"]
## Nederlandse spelersnamen (CANON 'Engelse spelersnamen'): mogen niet in speler-tekst staan.
const NL_NAMES := ["Wilgendal", "Gerrit", "Tante Mien", "Jelle Hamer", "Berggrot", "Levende Archief", "De Hal",
		"De Hanger", "Diepe Grot", "Wachtershuis", "Donker Woud", "Esdoorn"]
## Sleutels waarvan de waarde een id/bestandsnaam is (blijft Nederlands).
const ID_KEYS := ["id", "node", "map", "spawn", "event", "flag", "enemy", "group", "scene", "tile", "kind", "soort",
		"sprite", "npc", "shop_id", "icon", "icoon", "art", "texture", "path", "key", "needs", "plaat", "tint"]
## Scripts (met data-constanten) die de speler-tekst bevatten.
const TEXT_SCRIPTS := [
	"res://scripts/data/game_data.gd", "res://scripts/data/story_data.gd", "res://scripts/data/archief2.gd",
	"res://scripts/data/archief2_rooms.gd", "res://scripts/data/wilgendal_dorp.gd", "res://scripts/data/shop_data.gd",
	"res://scripts/data/koopman_data.gd", "res://scripts/data/koopman_winkel.gd", "res://scripts/data/codex_data.gd",
	"res://scripts/data/quest_data.gd", "res://scripts/data/som_data.gd", "res://scripts/data/kern_data.gd",
	"res://scripts/data/berggrot_data.gd", "res://scripts/data/dungeon_rooms.gd", "res://scripts/data/puzzle_rooms.gd",
	"res://scripts/data/woud_rooms.gd", "res://scripts/data/spiegel_data.gd", "res://scripts/data/echo_grot.gd",
	"res://scripts/data/scenes_data.gd", "res://scripts/data/book_data.gd", "res://scripts/data/werkplaats_recepten.gd",
	"res://scripts/data/grot_kamers.gd", "res://scripts/data/level_scale.gd", "res://scripts/data/endgame_bestiary.gd",
	"res://scripts/data/spells.gd", "res://scripts/data/grade_gear.gd", "res://scripts/party_bench.gd",
	"res://scripts/party_limiet.gd", "res://world_warper/kamers/kamers.gd", "res://world_warper/services/rekruut.gd",
	"res://world_warper/data/echo_questlog.gd", "res://pvp/data/teams.gd", "res://scripts/ui/save_screen.gd",
	"res://scripts/ui/field_menu.gd", "res://scripts/ui/options_screen.gd", "res://scripts/ui/items_screen.gd",
]
## Nederlandse regels die in deze fase zijn vervangen: ze mogen niet terugkomen (bestand -> teksten).
const REMOVED_DUTCH := {
	"res://scripts/party_actions.gd": ["Geneest over tijd", "\"Versterkt\""],
	"res://scripts/battle/battle.gd": ["Niemand is bewusteloos", "is versterkt", "herstelt langzaam", "herstelt %d", "corrigeert", "\"Doel\"", "\"Wie?\""],
	"res://scripts/ui/save_screen.gd": ["Overschrijven?", "Hier opslaan?", "\"Goud\"", "kies   B: terug"],
	"res://scripts/data/archief2.gd": ["Een Mosslijm vecht", "Archief 1 sent", "Archief 2 answered"],
	"res://scripts/data/archief2_rooms.gd": ["Een groei-plaat", "Archief 1 sent"],
	"res://scripts/data/story_data.gd": ["Archief 1 sent"],
	"res://scripts/data/spiegel_data.gd": ["core of Archief 4"],
	"res://scripts/dungeon/groei_plaat.gd": ["Alleen Seren"],
	"res://scripts/dungeon/archief2_room.gd": ["vecht mee"],
	"res://scripts/dungeon/archief2_warp.gd": ["Waarheen", "\"Opslaan\"", "\"Wilgendal\"", "Archief-ingang", "Andere eilanden"],
	"res://scripts/data/spell_rules.gd": ["\"Deze held\""],
	"res://scripts/ui/codex_screen.gd": ["Erft:"],
	"res://scripts/ui/status_screen.gd": ["kiezen"],
	"res://world_warper/services/party_select.gd": ["Niemand in het gezelschap", ".text = \"Sluiten\""],
	"res://world_warper/kamers/party_wissel.gd": ["Rustkamer", "(blijft)", "(gast)", "→ bank", "→ groep", "\"Actief\"", "\"Bank\""],
	"res://world_warper/kamers/echo_kisten.gd": ["\"Uitrusting\"", "\"Accessoire\""],
	"res://pvp/data/teams.gd": ["Gebalanceerd", "Hoog risico", "Traag, dubbele"],
	"res://scenes/maps/berggrot_bouwplaats.tscn": ["Hendrik says"],
}
## Bekende Nederlandse spelertekst die BLIJFT: een bestaande suite toetst de exacte tekst (en die mag deze
## taak niet aanpassen). Lijst en reden: docs/UX_POLISH_WM1.md. Deze test bewaakt dat de lijst niet groeit.
const KNOWN_DUTCH_PINNED := {
	"res://scripts/data/spell_rules.gd": "Dax leert geen magie.",
	"res://scripts/data/story_data.gd": "Het Zingende Graan",
	"res://scripts/data/game_data.gd": "\"benen\": \"Benen\"",
	"res://scripts/data/archief2.gd": "page[\"name\"] = \"Mosslijm\"",
	"res://pvp/data/modes.gd": "\"Vroeg\"",
}

var failures := 0
var passes := 0
var _scanned := 0
var shots := ""
var _am: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	seed(2026)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_until(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [shots, name])
	print("INFO  screenshot: %s/%s.png %s" % [shots, name, img.get_size()])


func scene() -> Node:
	return get_tree().current_scene


func vp_rect() -> Rect2:
	return Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)


func tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await pframes(2)
	Input.action_release(action)
	await pframes(2)


func _run() -> void:
	await wait_until(func() -> bool: return GameState._preloading.is_empty(), 15.0)
	_am = get_node_or_null("/root/AudioManager")
	print("=== Deel A: Engelse tekst ===")
	_text_tests()
	print("=== Deel B: tikdoelen 48dp ===")
	_touch_math_tests()
	await _touch_screen_tests()
	print("=== Deel C: tutorials ===")
	_tutorial_data_tests()
	await _tutorial_runtime_tests()
	print("=== Deel D: 19,5:9 / 20:9 + veilige zone ===")
	await _aspect_tests()
	print("=== Deel E: geluid en volume ===")
	await _audio_tests()
	print("UXTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await pframes(10)
	get_tree().quit(1 if failures else 0)


# ================================================================ helpers: kaart en menu
func open_map() -> Node:
	GameState.new_game("Dax")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	GameState.change_map(WILGENDAL, "")
	var ok := await wait_until(_map_ready, 15.0)
	await pframes(30)
	return scene() if ok else null


func _map_ready() -> bool:
	var s := scene()
	return s != null and s.name == "Wilgendal" and s.is_node_ready() and not GameState.changing_map


func _choices_visible() -> bool:
	return Dialog.has_choices() and Dialog._choice_box != null and Dialog._choice_box.visible


func _is_title() -> bool:
	return scene() != null and scene().name == "Title" and scene().is_node_ready()


func _is_battle() -> bool:
	return scene() != null and scene().name == "Battle" and scene().is_node_ready()


func _page_ready() -> bool:
	return Dialog.is_open and Dialog.has_choices() and not Dialog._is_typing()


func _page2_ready() -> bool:
	return _page_ready() and Dialog.text_label.text == SD.TUT_INKT_PAGES[1]


func _tut_done() -> bool:
	return not Story.running and not Dialog.is_open


func _typed() -> bool:
	return not Dialog._is_typing()


func open_field_menu(map: Node) -> Node:
	await tap("menu")
	await pframes(8)
	return map.get_node_or_null("FieldMenu")


func close_field_menu(map: Node) -> void:
	var fm: Node = map.get_node_or_null("FieldMenu")
	if fm != null:
		if fm.sub != null:
			fm.sub.close()
			await pframes(4)
		fm.close()
		await pframes(6)


## Controls onder root met tekst die breder is dan de knop (afgekapt/over de rand).
func clipped_buttons(root: Node) -> Array:
	var out: Array = []
	_clipped(root, out)
	return out


func _clipped(n: Node, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Button and (n as Control).size.x > 0.0:
		var b := n as Button
		var font: Font = b.get_theme_font("font")
		var fs: int = b.get_theme_font_size("font_size")
		var w := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if b.text != "" and w > b.size.x + 0.5:
			out.append("%s '%s' %.0f > %.0f" % [b.name, b.text, w, b.size.x])
	for c in n.get_children():
		_clipped(c, out)


## Zichtbare knoppen die (deels) buiten 'area' liggen (inhoud van een ScrollContainer telt niet mee).
func outside(root: Node, area: Rect2) -> Array:
	var out: Array = []
	_outside(root, area.grow(0.5), out)
	return out


func _outside(n: Node, area: Rect2, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is ScrollContainer:
		return
	if n is BaseButton and (n as Control).size.y > 0.0 and not area.encloses((n as Control).get_global_rect()):
		out.append("%s %s" % [n.name, (n as Control).get_global_rect()])
	for c in n.get_children():
		_outside(c, area, out)


## Zichtbare knoppen onder root die lager of smaller zijn dan min_size (UiTouch.TOUCH_MIN).
func small_targets(root: Node, min_size: float = UiTouch.TOUCH_MIN) -> Array:
	var out: Array = []
	_small(root, min_size, out)
	return out


func _small(n: Node, min_size: float, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is BaseButton and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE and not (n as BaseButton).disabled:
		var c := n as Control
		if c.size.y < min_size - 0.01:
			out.append(c)
	for ch in n.get_children():
		_small(ch, min_size, out)


func small_names(root: Node) -> String:
	return ", ".join(small_targets(root).map(func(c): return "%s '%s' %s" % [c.name, str(c.get("text")), c.size]))


# ================================================================ deel A: tekst
func _text_tests() -> void:
	var hits: Array = []
	for path in TEXT_SCRIPTS:
		if not ResourceLoader.exists(path):
			continue
		var script: GDScript = load(path)
		var consts: Dictionary = script.get_script_constant_map()
		for k in consts:
			_scan(consts[k], "%s:%s" % [path.get_file(), k], "", hits)
	for h in hits:
		print("INFO  Nederlands: %s" % h)
	check("data-scan: geen Nederlandse spelerzin in %d scripts, %d strings bekeken (stopwoorden en spelersnamen)" % [TEXT_SCRIPTS.size(), _scanned],
			hits.is_empty() and _scanned > 2000)
	check("de scan zelf: Nederlandse zin scoort >= 2, Engelse 0, Nederlandse naam wordt herkend",
			_nl_score("Een groei-plaat. Stap erop.") >= 2 and _nl_score("A growth plate. Step on it.") == 0
			and _nl_score("Sleep well? The save book is on the lectern, if you want to write.") == 0
			and _has_nl_name("Welkom in Wilgendal") and not _has_nl_name("Welcome to Willowdale"))
	var scene_hits: Array = _scan_scenes()
	for h in scene_hits:
		print("INFO  Nederlands (scene): %s" % h)
	check("scene-scan: map_name, npc_name en lines in .tscn zijn Engels", scene_hits.is_empty())
	var back: Array = []
	for path in REMOVED_DUTCH:
		var src := _code_only(FileAccess.get_file_as_string(path))
		check("bestand gelezen: %s" % path.get_file(), src != "")
		for lit in REMOVED_DUTCH[path]:
			if src.contains(str(lit)):
				back.append("%s: %s" % [path.get_file(), lit])
	check("gerepareerde Nederlandse regels zijn niet teruggekomen %s" % [back], back.is_empty())
	var pinned_ok := true
	for path in KNOWN_DUTCH_PINNED:
		var still := FileAccess.get_file_as_string(path).contains(str(KNOWN_DUTCH_PINNED[path]))
		if not still:
			print("INFO  bekende uitzondering is opgelost, haal hem uit KNOWN_DUTCH_PINNED: %s" % path)
		pinned_ok = pinned_ok and still
	check("bekende vastgepinde Nederlandse regels: lijst klopt (%d) en groeit niet" % KNOWN_DUTCH_PINNED.size(), pinned_ok)
	check("SaveScreen: vragen zijn Engels", SaveScreenS.Q_NEW == "Save here?" and SaveScreenS.Q_OVERWRITE == "Overwrite?")
	var effect_texts: Array = []
	for sid in GD.SPELLS:
		effect_texts.append(PartyActions.spell_effect_text({"level": 1, "id": "dennis"}, str(sid)))
	var dutch_effect := effect_texts.filter(func(t): return _nl_score(str(t)) >= 1 or str(t).contains("Geneest") or str(t).contains("Versterkt"))
	check("spell_effect_text: %d spreuken, geen Nederlandse effectregel %s" % [effect_texts.size(), dutch_effect], effect_texts.size() > 10 and dutch_effect.is_empty())
	var hero_ids: Array = GD.HEROES.map(func(h): return str(h["id"]))
	check("heldenids blijven Nederlands, spelersnamen Dax/Vesper/Seren via migrate_name (CANON 18)",
			hero_ids.has("dennis") and hero_ids.has("noor") and hero_ids.has("lotte")
			and GameState.OUDE_NAMEN == {"Dennis": "Dax", "Lotte": "Seren", "Noor": "Vesper"})


## Bron zonder commentaar (doc-regels en '# ...' achter code); doc-commentaar blijft Nederlands.
func _code_only(src: String) -> String:
	var out: Array = []
	for line in src.split("\n"):
		var l: String = line
		if l.strip_edges().begins_with("#"):
			continue
		var at := l.find(" # ")
		if at >= 0 and l.substr(0, at).count("\"") % 2 == 0:
			l = l.substr(0, at)
		out.append(l)
	return "\n".join(out)


## Recursief: strings in data. Alleen zinnen (spatie) of naamvelden tellen; id-sleutels worden overgeslagen.
func _scan(v, path: String, key: String, hits: Array) -> void:
	if v is String:
		var s: String = v
		_scanned += 1
		if key in ID_KEYS or s.begins_with("res://") or s.begins_with("%") or not s.contains(" "):
			if not (key in ["naam", "name", "title", "keeper_naam", "map_naam"] and _has_nl_name(s)):
				return
		if _nl_score(s) >= 2 or _has_nl_name(s):
			hits.append("%s = '%s'" % [path, s.substr(0, 80)])
	elif v is Dictionary:
		for k in v:
			_scan(v[k], "%s.%s" % [path, k], str(k), hits)
	elif v is Array:
		for i in (v as Array).size():
			_scan(v[i], "%s[%d]" % [path, i], key, hits)


func _nl_score(s: String) -> int:
	var n := 0
	for w in s.to_lower().split(" ", false):
		var clean := w.strip_edges().trim_prefix("(").trim_suffix(")").trim_suffix(".").trim_suffix(",").trim_suffix("?").trim_suffix("!")
		if NL_STOP.has(clean):
			n += 1
	return n


func _has_nl_name(s: String) -> bool:
	for nm in NL_NAMES:
		if s.contains(nm):
			return true
	return false


func _scan_scenes() -> Array:
	var out: Array = []
	var rx := RegEx.new()
	rx.compile("^(map_name|npc_name) = \"([^\"]*)\"")
	var rl := RegEx.new()
	rl.compile("\"((?:[^\"\\\\]|\\\\.)*)\"")
	for base in ["res://scenes", "res://world_warper"]:
		for f in _files(base, ".tscn"):
			for line in FileAccess.get_file_as_string(f).split("\n"):
				var m := rx.search(line)
				if m != null:
					var s := m.get_string(2)
					if _has_nl_name(s) or _nl_score(s) >= 2:
						out.append("%s: %s" % [f.get_file(), s])
				elif line.begins_with("lines = Array[String]("):
					for lm in rl.search_all(line):
						var t := lm.get_string(1)
						if _nl_score(t) >= 2 or _has_nl_name(t):
							out.append("%s: %s" % [f.get_file(), t])
	return out


func _files(dir: String, ext: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_files(dir.path_join(sub), ext))
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	return out


# ================================================================ deel B: tikdoelen (maatstok = UiTouch van #219)
func _touch_math_tests() -> void:
	check("tikmaat: UiTouch.TOUCH_MIN = %s eenheden = %.1f dp op 412dp (S25 Ultra); ROW_TOUCH gelijk" % [UiTouch.TOUCH_MIN, UiTouch.TOUCH_MIN * 412.0 / 216.0],
			UiTouch.TOUCH_MIN == 25.0 and UiTouch.TOUCH_MIN * 412.0 / 216.0 >= 47.5 and UiTouch.ROW_TOUCH == UiTouch.TOUCH_MIN)
	var r := UiTouch.hit_rect(Rect2(10, 10, 38, 14))
	check("hit_rect: 38x14 -> 38x25 om hetzelfde midden", r.size == Vector2(38, 25) and r.get_center().is_equal_approx(Rect2(10, 10, 38, 14).get_center()))
	check("big_enough: 25x25 ja, 24x25 nee", UiTouch.big_enough(Rect2(0, 0, 25, 25)) and not UiTouch.big_enough(Rect2(0, 0, 24, 25)))
	check("Action-knoppen (Swap/Ring/Codex) %s hoog >= TOUCH_MIN" % SomDataT.TOP_BUTTON_SIZE, SomDataT.TOP_BUTTON_SIZE.y >= UiTouch.TOUCH_MIN)
	UiTouch.insets_override = Vector4(99, 0, 3, 0)
	check("insets: rare waarden worden begrensd op INSET_MAX", UiTouch.insets(get_viewport()) == Vector4(UiTouch.INSET_MAX, 0, 3, 0))
	UiTouch.insets_override = null
	check("insets: headless/PC zonder override = nul", UiTouch.insets(get_viewport()) == Vector4.ZERO)


func _touch_screen_tests() -> void:
	# ---- titelscherm (niet in uipolishtest)
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
	await wait_until(_is_title, 10.0)
	await pframes(12)
	var t := scene()
	check("titel: elke knop >= 25 hoog (%s)" % small_names(t), small_targets(t).is_empty())
	var st: Rect2 = t.stage.get_global_rect()
	var cr: Rect2 = t.card.get_global_rect()
	cr.position -= st.position
	check("titel: kaartje blijft rechtsonder (x 240..372, y 148..201): %s" % cr,
			absf(cr.position.x - 240.0) <= 1.0 and absf(cr.end.x - 372.0) <= 1.0 and cr.end.y <= 201.0 and cr.position.y >= 148.0)
	check("titel: geen afgekapte knoptekst %s" % [clipped_buttons(t)], clipped_buttons(t).is_empty())
	check("titel: save-info staat boven het kaartje, binnen beeld", t.save_info.get_global_rect().end.y <= t.card.get_global_rect().position.y + 0.5
			and vp_rect().encloses(t.beta_info.get_global_rect()))
	await shot("ux_title")
	# ---- kaart, HUD en veldmenu
	var map := await open_map()
	check("kaart Wilgendal geladen", map != null)
	if map == null:
		return
	var tc: Control = map.get_node("TouchControls/Control")
	await _hud_tests(tc)
	await close_field_menu(map)
	var fm := await open_field_menu(map)
	check("veldmenu open", fm != null)
	if fm == null:
		return
	check("veldmenu: alle knoppen >= 25 hoog (%s)" % small_names(fm), small_targets(fm).is_empty())
	await shot("ux_field_menu")
	# opslaan, prompt, slotlijst
	fm.open_save()
	await pframes(12)
	if fm.sub != null:
		check("opslagscherm: Yes/No >= 25 hoog (%s)" % small_names(fm.sub.content), small_targets(fm.sub.content.get_parent()).filter(
				func(c): return c == fm.sub.yes_button or c == fm.sub.no_button).is_empty())
		await shot("ux_save")
		fm.sub.close()
		await pframes(6)
	var sp := SavePromptS.new()
	fm.add_child(sp)
	await pframes(8)
	check("opslag-prompt: Yes/No >= 25 hoog (%s)" % small_names(sp), small_targets(sp).is_empty())
	sp.queue_free()
	await pframes(3)
	var sl := SaveSlotListS.new()
	fm.add_child(sl)
	await pframes(10)
	check("slotlijst: slots, autosave en Back >= 25 hoog (%s)" % small_names(sl), small_targets(sl).is_empty() and outside(sl, vp_rect()).is_empty())
	sl.queue_free()
	await pframes(3)
	await close_field_menu(map)
	await _dialog_choice_tests()
	await _battle_tests(map)


func _hud_tests(tc: Control) -> void:
	var rects := {"MENU": UiTouch.hit_rect(tc.menu_rect(), 4.0), "RUN": UiTouch.hit_rect(tc.run_rect(), 2.0), "CORE": UiTouch.hit_rect(tc.kern_rect(), 4.0)}
	tc.show_run = true
	tc.show_kern = true
	tc.show_menu = true
	await pframes(2)
	var ok := true
	for k in rects:
		ok = ok and UiTouch.big_enough(rects[k])
	check("HUD: tikvlak van MENU, RUN en CORE >= 25x25 (%s)" % [rects], ok)
	var mr: Rect2 = tc.menu_rect()
	var ev := InputEventScreenTouch.new()
	ev.index = 7
	ev.pressed = true
	ev.position = tc.get_global_transform_with_canvas() * (mr.get_center() + Vector2(0, -10))
	tc._input(ev)
	check("HUD: tik 10 eenheden boven het MENU-plaatje = MENU", tc._touch_owner.get(7, "") == "menu")
	ev = ev.duplicate()
	ev.pressed = false
	tc._input(ev)
	tc.release_all()
	await pframes(2)


func _dialog_choice_tests() -> void:
	for n in [2, 3, 4]:
		var opts: Array = []
		for i in n:
			opts.append("Choice %d" % (i + 1))
		Dialog.ask("Question for %d choices?" % n, opts, "")
		await wait_until(_choices_visible, 3.0)
		await pframes(3)
		var labels: Array = Dialog._choice_labels
		check("dialoog met %d keuzes: %d regels" % [n, labels.size()], labels.size() == n)
		if n <= 3:
			check("dialoog met %d keuzes: elke keuze >= 25 hoog" % n, labels.all(func(l): return (l as Control).size.y >= UiTouch.TOUCH_MIN - 0.01))
		check("dialoog met %d keuzes: vak en keuzes binnen beeld (%s)" % [n, Dialog.panel.get_global_rect()],
				vp_rect().encloses(Dialog.panel.get_global_rect()) and vp_rect().encloses(Dialog._choice_box.get_global_rect()))
		if n == 2:
			await shot("ux_dialog_choices")
		var tap_i: int = n - 1
		var ev := InputEventScreenTouch.new()
		ev.pressed = true
		Dialog._on_choice_input(ev, tap_i)
		await pframes(3)
		check("dialoog met %d keuzes: tik op de laatste kiest hem (%d)" % [n, Dialog.choice_result], Dialog.choice_result == tap_i and not Dialog.is_open)
		await pframes(2)


func _battle_tests(map: Node) -> void:
	var p: Node = map.get_node_or_null("Objects/Player")
	if p == null:
		check("gevecht: speler gevonden", false)
		return
	GameState.start_battle(["mosslijm"], p.get_tile(), p.facing, "archief", false, 0)
	var ok := await wait_until(_is_battle, 15.0)
	check("gevecht gestart", ok)
	if not ok:
		return
	var b := scene()
	await wait_until(func() -> bool: return b.cross.active, 15.0)
	await pframes(4)
	var cross: Node = b.cross
	var ok_hit := true
	var ok_art := true
	for i in 5:
		var hr: Rect2 = cross.hit_rect(i)
		ok_hit = ok_hit and UiTouch.big_enough(hr)
		ok_art = ok_art and (cross.buttons[i] as Control).size == Vector2(24, 24)
	check("gevecht: elk kruisknopje heeft een tikvlak >= 25x25", ok_hit)
	check("gevecht: het plaatje (art van RPG ART) blijft 24x24, afstand 25", ok_art
			and cross.button_rect(1).get_center().is_equal_approx(cross.button_rect(0).get_center() + Vector2(0, -25)))
	var edge_ok := true
	for i in 5:
		var btn: Control = cross.buttons[i]
		edge_ok = edge_ok and btn._has_point(Vector2(-0.9, 12.0)) and btn._has_point(Vector2(24.9, 12.0)) \
				and not btn._has_point(Vector2(-1.5, 12.0)) and not btn._has_point(Vector2(26.0, 12.0))
	check("gevecht: tikvlak is 1 eenheid ruimer dan het plaatje (CrossButton)", edge_ok)
	check("gevecht: kruis blijft binnen beeld", vp_rect().encloses(cross.cross_rect()))
	await shot("ux_battle")
	GameState.in_battle = false
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
	await wait_until(_is_title, 10.0)
	await pframes(5)
	check("na het gevecht: weergave weer 384x216 (%s)" % get_viewport().get_visible_rect().size, vp_rect().size.y == 216.0)


# ================================================================ deel C: tutorials
func _tutorial_data_tests() -> void:
	var tut_ids: Array = []
	var roots: Array = []
	for id in SD.EVENTS:
		if str(id).begins_with("tutorial"):
			tut_ids.append(str(id))
			if not str(id).get_slice("_", str(id).count("_")).is_valid_int():
				roots.append(str(id))
	tut_ids.sort()
	roots.sort()
	check("tutorials: %d ketens (%s), elk 4 pagina's: %s" % [roots.size(), roots, tut_ids], roots.has(EV) and roots.size() >= 2 and tut_ids.size() == roots.size() * 4)
	var chain_ok := true
	var skip_ok := true
	var once_ok := true
	for id in tut_ids:
		var cmds: Array = (SD.EVENTS[id][0]["do"] as Array)
		for c in cmds:
			var ca: Array = c
			if ca[0] == "choice":
				var opts: Array = ca[2]
				var targets: Array = ca[3]
				skip_ok = skip_ok and opts == ["Next", "Skip"] and str(targets[1]) == ""
				chain_ok = chain_ok and SD.EVENTS.has(str(targets[0]))
	check("elke tutorial-pagina met keuze heeft Next -> bestaande volgende pagina en Skip -> stoppen", chain_ok and skip_ok)
	GameState.new_game("Dax")
	for root_id in roots:
		var variants: Array = SD.EVENTS[root_id]
		var first: Array = variants[0]["do"]
		var flag := str(first[0][1])
		once_ok = once_ok and first[0][0] == "flag" and flag.ends_with("_gezien") and (variants[1]["do"] as Array).is_empty()
		GameState.story_flags.erase(flag)
		var v1: Dictionary = Story.pick(root_id)
		GameState.story_flags[flag] = true
		var v2: Dictionary = Story.pick(root_id)
		once_ok = once_ok and not (v1["do"] as Array).is_empty() and (v2["do"] as Array).is_empty()
		GameState.story_flags.erase(flag)
	check("elke tutorial zet zijn 'gezien'-vlag als eerste (ook bij Skip of afsluiten halverwege); met vlag speelt Story.pick niets (eenmalig)", once_ok)
	# menupaden in alle spelertekst: MENU > X > Y bestaat echt
	var top: Array = FieldMenuS.COMMANDS.map(func(c): return str(c[1]))
	var opt_names: Array = OptionsScreenS.ROWS.map(func(r): return str(r[1]))
	var slot_names: Array = EquipmentS.slots().map(func(sl): return EquipmentS.slot_name(sl))
	var paths := 0
	var bad: Array = []
	for line in _all_strings(SD.EVENTS) + _all_strings(SD.TUT_INKT_PAGES) + _all_strings(SD.TUT_CODEX_PAGES):
		var rest: String = str(line)
		while rest.contains("MENU > "):
			rest = rest.substr(rest.find("MENU > ") + 7)
			var parts: Array = _menu_path(rest)
			paths += 1
			var a1: String = parts[0]
			var b1: String = parts[1] if parts.size() > 1 else ""
			if not top.has(a1):
				bad.append("MENU > %s (menu bestaat niet)" % a1)
			elif a1 == "Settings" and b1 != "" and not opt_names.has(b1):
				bad.append("MENU > Settings > %s (instelling bestaat niet)" % b1)
			elif a1 == "Equipment" and b1 != "" and not slot_names.has(b1):
				bad.append("MENU > Equipment > %s (vak bestaat niet)" % b1)
	check("tutorialtekst: %d 'MENU > ...'-paden bestaan in het echte menu %s" % [paths, bad], paths >= 4 and bad.is_empty())
	# prologue: oefengevecht en uitrusting-tutorial komen niet terug
	var replay := false
	for step in [SD.AVOND, SD.NACHT]:
		GameState.story_step = step
		var v: Dictionary = Story.pick("opa")
		var text := JSON.stringify(v.get("do", []))
		replay = replay or text.contains("\"les\"") or text.contains("\"battle\"")
	check("prologue: na het oefengevecht (stap AVOND/NACHT) start Opa de les niet opnieuw", not replay)
	GameState.story_step = SD.UITRUSTING
	GameState.inventory.erase(SD.TUTORIAL_ARMOR)
	var v3: Dictionary = Story.pick("opa")
	check("prologue: mantel kwijt tijdens de uitrusting-stap -> Opa geeft een nieuwe (geen soft-lock)",
			JSON.stringify(v3.get("do", [])).contains(SD.TUTORIAL_ARMOR))
	var les_events := 0
	for id in SD.EVENTS:
		for variant in SD.EVENTS[id]:
			if JSON.stringify(variant.get("do", [])).contains("\"tutorial\":true"):
				les_events += 1
	check("er is precies 1 oefengevecht-event (les)", les_events == 1)
	GameState.new_game("Dax")


## "Settings > Battle Style:\nClassic is ..." -> ["Settings", "Battle Style"]: woorden met een hoofdletter, gescheiden door ' > '.
func _menu_path(rest: String) -> Array:
	var cut := rest
	for stop in [":", ".", "\n", ","]:
		var i := cut.find(stop)
		if i >= 0:
			cut = cut.substr(0, i)
	var out: Array = []
	for seg in cut.split(" > "):
		var words: Array = []
		for w in seg.strip_edges().split(" ", false):
			if w.substr(0, 1) != w.substr(0, 1).to_upper() or w == "&":
				break
			words.append(w)
		if not words.is_empty():
			out.append(" ".join(words))
	return out


func _all_strings(v) -> Array:
	var out: Array = []
	if v is String:
		out.append(v)
	elif v is Array:
		for x in v:
			out.append_array(_all_strings(x))
	elif v is Dictionary:
		for k in v:
			out.append_array(_all_strings(v[k]))
	return out


func _tutorial_runtime_tests() -> void:
	var map := await open_map()
	if map == null:
		check("tutorial-runtime: kaart geladen", false)
		return
	GameState.story_flags.erase(FLAG)
	Story.run(EV)
	var open1 := await wait_until(_page_ready, 5.0)
	await pframes(3)
	check("tutorial pagina 1: keuzes Next/Skip, vlag meteen gezet", open1 and Dialog.choices == ["Next", "Skip"] and GameState.story_flags.has(FLAG))
	check("tutorial pagina 1: Next en Skip zijn tikdoelen >= 25", Dialog._choice_labels.all(func(l): return (l as Control).size.y >= UiTouch.TOUCH_MIN - 0.01))
	Dialog.cancel()   # B = laatste keuze = Skip
	var done := await wait_until(_tut_done, 4.0)
	check("B op pagina 1 = Skip: tutorial stopt, speler vrij", done)
	Story.run(EV)
	await pframes(30)
	check("tweede keer: niets (geen dialoog, niets draait)", not Dialog.is_open and not Story.running)
	# Next -> pagina 2 -> Skip door te tikken
	GameState.story_flags.erase(FLAG)
	Story.run(EV)
	await wait_until(_page_ready, 5.0)
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	Dialog._on_choice_input(ev, 0)
	var p2 := await wait_until(_page2_ready, 5.0)
	check("tik op Next: pagina 2", p2)
	Dialog._on_choice_input(ev, 1)
	var done2 := await wait_until(_tut_done, 4.0)
	check("tik op Skip halverwege: klaar, geen pagina 3", done2 and not Story.history.slice(-2).has(EV + "_3"))
	GameState.new_game("Dax")


# ================================================================ deel D: ratio's + veilige zone (UiTouch.insets_override)
func _aspect_tests() -> void:
	var win := get_window()
	var old_size := win.size
	var ratios := {"19.5:9": Vector2i(1170, 540), "20:9": Vector2i(1200, 540)}
	for name in ratios:
		win.size = ratios[name]
		await pframes(6)
		var vs := get_viewport().get_visible_rect().size
		var want_w := 216.0 * float(ratios[name].x) / float(ratios[name].y)
		check("%s: kijkvenster is %.0fx216 (is %s)" % [name, want_w, vs], absf(vs.x - want_w) < 1.0 and absf(vs.y - 216.0) < 0.5)
		if absf(vs.x - want_w) >= 1.0:
			continue
		UiTouch.insets_override = Vector4(30.0, 0.0, 30.0, 0.0)
		var safe := UiTouch.safe_rect(vs, get_viewport())
		check("%s: veilige zone = (30,0)-(%.0f,216)" % [name, vs.x - 30.0], safe == Rect2(30, 0, vs.x - 60.0, 216))
		get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
		await wait_until(_is_title, 10.0)
		await pframes(14)
		var t := scene()
		var st: Rect2 = t.stage.get_global_rect()
		check("%s titel: stage 384x216 gecentreerd, kaartje en knoppen binnen de veilige zone, knoppen >= 25 hoog, niets afgekapt" % name,
				st.size == Vector2(384, 216) and absf(st.get_center().x - vs.x / 2.0) <= 1.0
				and safe.encloses(t.card.get_global_rect()) and outside(t, safe).is_empty()
				and small_targets(t).is_empty() and clipped_buttons(t).is_empty())
		await shot("ux_title_" + name.replace(":", "x").replace(".", "_"))
		var map := await open_map()
		if map == null:
			check("%s: kaart geladen" % name, false)
			continue
		var tc: Control = map.get_node("TouchControls/Control")
		tc.show_run = true
		tc.show_kern = true
		tc.show_menu = true
		tc.refit()
		await pframes(2)
		var rects: Array = tc.button_rects()
		check("%s HUD: joystick, A, B, MENU, RUN en CORE binnen de veilige zone (notch 30 links/rechts), %d vlakken" % [name, rects.size()],
				rects.all(func(r): return safe.encloses(r)) and rects.size() >= 5)
		var fm := await open_field_menu(map)
		if fm != null:
			check("%s veldmenu: knoppen >= 25 hoog, binnen de veilige zone (%s), niets afgekapt" % [name, outside(fm, safe)],
					small_targets(fm).is_empty() and outside(fm, safe).is_empty() and clipped_buttons(fm).is_empty())
			await shot("ux_menu_" + name.replace(":", "x").replace(".", "_"))
			await close_field_menu(map)
		Dialog.ask("Ready for the next part?", ["Yes", "No"], "")
		await wait_until(_choices_visible, 3.0)
		await pframes(3)
		check("%s dialoog: vak en keuzes binnen de veilige zone" % name, safe.encloses(Dialog.panel.get_global_rect())
				and safe.encloses(Dialog._choice_box.get_global_rect()))
		await shot("ux_dialog_" + name.replace(":", "x").replace(".", "_"))
		Dialog.choose(0)
		await pframes(3)
		UiTouch.insets_override = null
		GameState.new_game("Dax")
	UiTouch.insets_override = null
	win.size = old_size
	await pframes(6)


# ================================================================ deel E: geluid
func _open_into(map: Node, into: Array) -> void:
	into.append(await open_field_menu(map))


## Stick omlaag (zoals de touch-joystick: in de physics-stap) en daarna de focus verplaatsen.
func _focus_after_stick(target: Control) -> void:
	await get_tree().physics_frame
	Input.action_press("move_down")
	await pframes(2)
	target.grab_focus()
	await pframes(1)
	Input.action_release("move_down")


func heard(cue: String, action: Callable) -> bool:
	_am._sfx_last_played_ms.erase(cue)
	await action.call()
	return _am._sfx_last_played_ms.has(cue)


func settle() -> void:
	await get_tree().create_timer(0.25, true, false, true).timeout


func _audio_tests() -> void:
	check("AudioManager aanwezig", _am != null)
	if _am == null:
		return
	var files_ok := true
	var missing: Array = []
	for cue in UiSfx.ALL:
		if not _am.has_sfx(cue):
			files_ok = false
			missing.append(cue)
			continue
		for f in _am._sfx[cue].get("bestanden", []):
			if not FileAccess.file_exists("res://assets/audio/sfx/" + str(f)):
				files_ok = false
				missing.append(str(f))
	check("alle %d UI-cues staan in het manifest en hun bestanden bestaan %s" % [UiSfx.ALL.size(), missing], files_ok)
	check("auto_ui_sounds (hover overal) blijft UIT; knopdruk en cursor staan AAN", not _am.auto_ui_sounds and _am.ui_press_sounds and _am.ui_cursor_sounds)
	var box := VBoxContainer.new()
	add_child(box)
	var plain := Button.new()
	var cancel := Button.new()
	var grey := Button.new()
	var quiet := Button.new()
	UiSfx.tag(cancel, UiSfx.CANCEL)
	grey.set_meta("greyed", true)
	quiet.set_meta("no_ui_sound", true)
	for b in [plain, cancel, grey, quiet]:
		box.add_child(b)
	check("cue-keuze: gewone knop = menu_click, tag = menu_cancel, grijs = menu_error",
			_am.ui_cue_for(plain) == "menu_click" and _am.ui_cue_for(cancel) == "menu_cancel" and _am.ui_cue_for(grey) == "menu_error")
	await settle()
	check("knopdruk speelt menu_click", await heard("menu_click", func() -> void: plain.pressed.emit()))
	await settle()
	check("Back-knop speelt menu_cancel", await heard("menu_cancel", func() -> void: cancel.pressed.emit()))
	await settle()
	check("grijze regel geeft menu_error", await heard("menu_error", func() -> void: grey.pressed.emit()))
	await settle()
	check("knop met no_ui_sound is stil", not await heard("menu_click", func() -> void: quiet.pressed.emit()))
	await settle()
	# cursor: alleen na een stick-/pijltjesdruk
	var a := Button.new()
	var b2 := Button.new()
	box.add_child(a)
	box.add_child(b2)
	a.grab_focus()
	await pframes(2)
	await settle()
	check("focus zonder stickdruk (scherm opbouwen) is stil", not await heard("menu_hover", func() -> void:
			b2.grab_focus()
			await pframes(1)))
	await settle()
	a.grab_focus()
	await pframes(2)
	await settle()
	check("cursor na een stickdruk (move_down) speelt menu_hover", await heard("menu_hover", _focus_after_stick.bind(b2)))
	box.queue_free()
	await pframes(2)
	# UI-acties met een echt scherm
	var map := await open_map()
	if map == null:
		check("geluid: kaart geladen", false)
		return
	await settle()
	var opened: Array = []
	check("veldmenu openen speelt menu_open", await heard("menu_open", _open_into.bind(map, opened)))
	var fm: Node = opened[0] if not opened.is_empty() else null
	check("veldmenu is open", fm != null)
	if fm == null:
		return
	await settle()
	check("B in het veldmenu speelt menu_close", await heard("menu_close", func() -> void: await tap("cancel")))
	await settle()
	fm = await open_field_menu(map)
	fm.choose("scenes")
	await pframes(10)
	await settle()
	check("B in een subscherm speelt menu_cancel", await heard("menu_cancel", func() -> void: await tap("cancel")))
	await close_field_menu(map)
	await settle()
	fm = await open_field_menu(map)
	check("opslaan speelt save_game", await heard("save_game", func() -> void: fm.save_now()))
	await close_field_menu(map)
	await settle()
	check("dialoog doorklikken speelt dialogue_advance", await heard("dialogue_advance", func() -> void:
			Dialog.show_lines(["One.", "Two."], "")
			await wait_until(func() -> bool: return not Dialog._is_typing(), 3.0)
			Dialog.advance()))
	Dialog.close()
	await settle()
	check("dialoogkeuze speelt menu_confirm", await heard("menu_confirm", func() -> void:
			Dialog.ask("Sure?", ["Yes", "No"], "")
			await wait_until(func() -> bool: return Dialog.has_choices(), 3.0)
			Dialog.choose(0)))
	await settle()
	# bedrading van acties die een eigen spelstand nodig hebben: aanwezig in de bron
	var wired := {
		"res://scripts/ui/items_screen.gd": "UiSfx.USE_ITEM", "res://scripts/ui/equipment_screen.gd": "UiSfx.EQUIP",
		"res://scripts/ui/shop_screen.gd": "UiSfx.COINS", "res://scripts/ui/koopman_winkel_scherm.gd": "UiSfx.COINS",
		"res://scripts/ui/title_screen.gd": "UiSfx.LOAD", "res://scripts/ui/load_screen.gd": "UiSfx.LOAD",
		"res://scripts/battle/command_cross.gd": "UiSfx.COMMAND", "res://scripts/battle/battle.gd": "UiSfx.TARGET",
		"res://scripts/battle/battle_menu.gd": "UiSfx.CURSOR", "res://scripts/touch_controls.gd": "UiSfx.CLICK",
		"res://scripts/book_point.gd": "UiSfx.SAVE", "res://world_warper/kamers/prop.gd": "UiSfx.SAVE",
	}
	var unwired: Array = []
	for path in wired:
		if not FileAccess.get_file_as_string(path).contains(str(wired[path])):
			unwired.append(path.get_file())
	check("UI-geluid is bedraad in items, uitrusten, winkels, laden, gevecht, HUD en opslagpunten %s" % [unwired], unwired.is_empty())
	await _volume_tests(map)


func _volume_tests(map: Node) -> void:
	var path := "user://ux_settings_test.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var s1: Node = SettingsS.new()
	s1.path = path
	add_child(s1)
	check("Settings (nieuw bestand): standaard muziek 8, effecten 8, mute uit", s1.get_value("music_volume") == 8 and s1.get_value("sfx_volume") == 8
			and s1.get_value("audio_mute") == false)
	s1.set_value("music_volume", 3)
	s1.set_value("sfx_volume", 6)
	s1.set_value("audio_mute", true)
	s1.set_value("text_speed", 2)
	check("Settings schrijft meteen naar het bestand", FileAccess.file_exists(path))
	s1.free()
	var s2: Node = SettingsS.new()
	s2.path = path
	add_child(s2)
	await pframes(3)
	check("na herstart: muziek 3, effecten 6, mute aan, tekstsnelheid 2 blijven bewaard",
			s2.get_value("music_volume") == 3 and s2.get_value("sfx_volume") == 6 and s2.get_value("audio_mute") == true and s2.get_value("text_speed") == 2)
	var mi := AudioServer.get_bus_index("Music")
	var si := AudioServer.get_bus_index("SFX")
	check("na herstart: bussen volgen het bewaarde volume en staan gedempt (mute)",
			is_equal_approx(AudioServer.get_bus_volume_db(mi), SettingsS.volume_db(3)) and is_equal_approx(AudioServer.get_bus_volume_db(si), SettingsS.volume_db(6))
			and AudioServer.is_bus_mute(mi) and AudioServer.is_bus_mute(si))
	s2.set_value("audio_mute", false)
	check("mute uit: bussen weer hoorbaar", not AudioServer.is_bus_mute(mi) and not AudioServer.is_bus_mute(si))
	s2.set_value("music_volume", 0)
	check("volume 0 = bus gedempt, en dat blijft zo na herstart", AudioServer.is_bus_mute(mi))
	s2.free()
	var s3: Node = SettingsS.new()
	s3.path = path
	add_child(s3)
	await pframes(3)
	check("volume 0 bewaard (muziek 0, bus gedempt)", s3.get_value("music_volume") == 0 and AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
	s3.free()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[instellingen]\nmusic_volume=99\nsfx_volume=-5\ntouch_opacity=7\naudio_mute=\"ja\"\n")
	f.close()
	var s4: Node = SettingsS.new()
	s4.path = path
	add_child(s4)
	check("kapot/handmatig bestand wordt begrensd (99 -> %d, -5 -> %d, 7 -> %d)" % [s4.get_value("music_volume"), s4.get_value("sfx_volume"), s4.get_value("touch_opacity")],
			s4.get_value("music_volume") == SettingsS.VOLUME_STEPS and s4.get_value("sfx_volume") == 0 and s4.get_value("touch_opacity") == SettingsS.OPACITY_MIN)
	check("tekst in plaats van een bool (audio_mute=\"ja\") breekt het laden niet meer (was: scriptfout, latere waarden kwijt)",
			s4.get_value("audio_mute") == true and SettingsS._to_bool("uit", true) == false and SettingsS._to_bool("???", true) == true
			and SettingsS._to_bool(0, true) == false and SettingsS._to_bool(2, false) == true)
	s4.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# de echte autoload: opties-scherm -> bestand
	var keep_m: int = Settings.get_value("music_volume")
	var keep_s: int = Settings.get_value("sfx_volume")
	var keep_mute: bool = Settings.get_value("audio_mute")
	var fm := await open_field_menu(map)
	fm.choose("options")
	await pframes(10)
	var opt: Node = fm.sub
	check("Options openen", opt != null)
	if opt != null:
		opt.kies_tab("music")
		await pframes(6)
		(opt.music_sliders["music_volume"] as HSlider).value = 4
		(opt.music_sliders["sfx_volume"] as HSlider).value = 9
		await pframes(2)
		var cfg := ConfigFile.new()
		var err := cfg.load(Settings.path)
		check("schuif muziek op 4 en effecten op 9: Settings en bestand volgen (%s)" % Settings.path, err == OK
				and Settings.get_value("music_volume") == 4 and Settings.get_value("sfx_volume") == 9
				and int(cfg.get_value(Settings.SECTION, "music_volume", -1)) == 4 and int(cfg.get_value(Settings.SECTION, "sfx_volume", -1)) == 9)
		opt.call("_toggle_mute")
		await pframes(2)
		cfg.load(Settings.path)
		check("Mute all audio: aan in Settings en in het bestand", Settings.get_value("audio_mute") == true and bool(cfg.get_value(Settings.SECTION, "audio_mute", false)))
		Settings.load_settings()
		Settings.apply_all()
		check("Settings.load_settings() (= herstart) behoudt 4 / 9 / mute", Settings.get_value("music_volume") == 4 and Settings.get_value("sfx_volume") == 9
				and Settings.get_value("audio_mute") == true and AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
		opt.close()
	await close_field_menu(map)
	_am.set_music_volume(0.5)
	check("AudioManager.set_music_volume(0.5) = muziek 5 in Settings", Settings.get_value("music_volume") == 5)
	Settings.set_value("music_volume", keep_m)
	Settings.set_value("sfx_volume", keep_s)
	Settings.set_value("audio_mute", keep_mute)
	GameState.new_game("Dax")
