class_name PuzzleLogic
extends RefCounted
## Puur rooster-model van een puzzelkamer (GEEN nodes, dus ook te testen zonder scène).
## Gebouwd uit de kamer-data in scripts/data/puzzle_rooms.gd (zie docs/PUZZELS.md).
##
## Houdt bij: muren, vaste kasten, duwbare kasten (id -> tile), drukplaten, hendels,
## poorten, herstelstenen, de signalen (id -> bool) en waar de speler staat.
## Na elke verandering rekent update() alles opnieuw uit:
##   platen (ingedrukt door een kast, of door de speler als de plaat niet 'heavy' is)
##   -> signalen -> poorten (all/any, invert, latch). Daarna 'changed' met de ids die
##   veranderd zijn, zodat de nodes zich kunnen bijwerken.
## Regels voor duwen: het doel moet in de kamer liggen en vrij zijn: geen muur/vaste kast,
## geen andere kast, geen hendel of herstelsteen, GEEN poorttegel (open of dicht: zo kan een
## kast nooit een poort vastzetten), geen ingang/uitgang en niet de speler.
## Een poort gaat nooit dicht terwijl de speler erin staat (hij wacht tot de speler weg is).
##
## v0.15 (ARCHIEF1) erbij:
##   ','     verborgen vloer: gewone vloer, maar bedekt (ziet eruit als muur) tot een geheime
##           deur in de kamer opengaat. Voor de nis achter een geheime deur.
##   book    los boek in een kast (A ervoor = terugduwen, 'klik'). Eenmalig: blijft ingedrukt,
##           ook na herstellen/terugkomen (onthouden net als vergrendelde poorten). Geeft een signaal.
##   secret  geheime deur in de achterwand, 2 tegels hoog (zijn tegel + de tegel erboven): dicht
##           beide massief, open beide beloopbaar. Een poort die er dicht uitziet als muur en altijd
##           open-vergrendelt (latch). "needs"/"mode"/"invert" net als bij een poort. Ook te schrijven
##           als {"type": "gate", "style": "geheim"} (zo staat het in Forge's ontwerp).
##   plate   v0.15: "hidden": true = verborgen runeplaat (ziet eruit als een runetegel).
##   chest   schatkist (massief). Eenmalig via een story-vlag: zie PuzzleRoom.request_chest.

## Ids van objecten waarvan de toestand veranderde (kasten, platen, hendels, poorten).
signal changed(ids: Array)

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
## Vaste tekens in de plattegrond.
const FIXED_CHARS := "#.EXB,"
const TYPES := ["block", "plate", "lever", "gate", "reset", "hook", "book", "secret", "chest"]
## Typen die een signaal geven (mogen in "needs" staan).
const SIGNAL_TYPES := ["plate", "lever", "gate", "book", "secret"]
const GameData := preload("res://scripts/data/game_data.gd")
const NOWHERE := Vector2i(-9999, -9999)

## Tegels van assets/tiles/binnen.png (tile n staat op x = n*16).
const T_FLOOR_A := 0
const T_FLOOR_B := 1
const T_WALL_TOP := 2
const T_WALL_FRONT := 3
const T_DOOR := 5
const T_SHELF_TOP := 6
const T_SHELF_BOTTOM := 7
const T_SIDE_LEFT := 23
const T_SIDE_RIGHT := 24

var room_id := ""
var size := Vector2i.ZERO
var walls := {}          # Vector2i -> true  ('#')
var statics := {}        # Vector2i -> true  ('B' vaste boekenkast)
var exits := {}          # Vector2i -> "E" of "X"
var entrance_tile := NOWHERE
var spawn_tile := NOWHERE      # binnenkant naast E
var spawn_facing := Vector2i.UP
var blocks := {}         # id -> Vector2i
var block_start := {}    # id -> Vector2i
## v0.15 ZWARE kasten ({"type": "block", "heavy": true}): id -> nodige wereldvaardigheid
## (standaard "zware_blokken", uit een kernfragment). Zonder die vaardigheid: niet te duwen.
var heavy_blocks := {}
## Wereldvaardigheden van de party (gezet door PuzzleRoom uit GameState; dit model blijft los).
var abilities := {}
const DEFAULT_HEAVY_ABILITY := "zware_blokken"
var plates := {}         # id -> {"tile": Vector2i, "heavy": bool, "pressed": bool}
var levers := {}         # id -> {"tile": Vector2i, "on": bool, "start": bool}
var gates := {}          # id -> {"tile", "needs", "mode", "invert", "latch", "latched", "open"}
var resets := {}         # id -> Vector2i
var books := {}          # id -> {"tile": Vector2i, "pressed": bool}   (v0.15)
var chests := {}         # id -> {"tile", "item", "n", "flag"}          (v0.15)
var hidden := {}         # Vector2i -> true  (',' verborgen vloer)      (v0.15)
var door_tops := {}      # Vector2i -> id van de geheime deur eronder     (v0.15)
## v0.14 haakjes/placeholders voor componenten van RPG CODE: id -> {"tile", "hook", "solid"}
var hooks := {}
var signals := {}        # id -> bool
var types := {}          # id -> "block"/"plate"/...
var player_tile := NOWHERE
var player_target := NOWHERE   # tile waar de speler naartoe loopt (= player_tile als hij stil staat)

var _block_at := {}      # Vector2i -> block-id (index, bijgewerkt bij elke duw)
var _static_obj_at := {} # Vector2i -> id van plaat/hendel/poort/steen


## Bouw een model uit de kamer-data. latched_ids = poorten die al eerder open-vergrendeld zijn.
static func from_room(room: Dictionary, id := "", latched_ids: Array = []) -> PuzzleLogic:
	var l := PuzzleLogic.new()
	l.build(room, id, latched_ids)
	return l


func build(room: Dictionary, id := "", latched_ids: Array = []) -> void:
	room_id = id
	var rows: Array = room.get("layout", [])
	var objs: Dictionary = room.get("objects", {})
	size = Vector2i(str(rows[0]).length() if rows.size() > 0 else 0, rows.size())
	for y in rows.size():
		var row := str(rows[y])
		for x in row.length():
			var t := Vector2i(x, y)
			var c := row[x]
			match c:
				"#":
					walls[t] = true
				".":
					pass
				",":
					hidden[t] = true
				"B":
					statics[t] = true
				"E", "X":
					exits[t] = c
					if c == "E":
						entrance_tile = t
				_:
					if objs.has(c):
						_add_object(objs[c], t)
	if entrance_tile != NOWHERE:
		spawn_facing = inward_dir(entrance_tile)
		spawn_tile = entrance_tile + spawn_facing
	for g in latched_ids:
		if gates.has(g) and gates[g]["latch"]:
			gates[g]["latched"] = true
		elif books.has(g):
			books[g]["pressed"] = true
	_evaluate()


func _add_object(d: Dictionary, t: Vector2i) -> void:
	var id := str(d.get("id", ""))
	var type := _type_of(d)
	types[id] = type
	match type:
		"block":
			blocks[id] = t
			block_start[id] = t
			_block_at[t] = id
			if bool(d.get("heavy", false)):
				heavy_blocks[id] = str(d.get("ability", DEFAULT_HEAVY_ABILITY))
		"plate":
			plates[id] = {"tile": t, "heavy": bool(d.get("heavy", false)), "pressed": false,
					"hidden": bool(d.get("hidden", false))}
			_static_obj_at[t] = id
			signals[id] = false
		"lever":
			var on := bool(d.get("on", false))
			levers[id] = {"tile": t, "on": on, "start": on}
			_static_obj_at[t] = id
			signals[id] = on
		"gate":
			var needs: Array = []
			for n in d.get("needs", []):
				needs.append(str(n))
			gates[id] = {"tile": t, "needs": needs, "mode": str(d.get("mode", "all")),
					"invert": bool(d.get("invert", false)), "latch": bool(d.get("latch", false)),
					"latched": false, "open": false}
			_static_obj_at[t] = id
			signals[id] = false
		"reset":
			resets[id] = t
			_static_obj_at[t] = id
		"book":
			books[id] = {"tile": t, "pressed": false}
			_static_obj_at[t] = id
			signals[id] = false
		"secret":
			# geheime deur = poort die altijd vergrendelt
			var sneeds: Array = []
			for n in d.get("needs", []):
				sneeds.append(str(n))
			gates[id] = {"tile": t, "needs": sneeds, "mode": str(d.get("mode", "all")),
					"invert": bool(d.get("invert", false)), "latch": true,
					"latched": false, "open": false, "secret": true, "top": t + Vector2i.UP}
			_static_obj_at[t] = id
			door_tops[t + Vector2i.UP] = id
			signals[id] = false
		"chest":
			chests[id] = {"tile": t, "item": str(d.get("item", "")), "n": maxi(1, int(d.get("n", 1))),
					"flag": chest_flag(d)}
			_static_obj_at[t] = id
		"hook":
			# v0.14 placeholder: geen signaal, alleen massief of niet (zie puzzle_rooms.gd)
			hooks[id] = {"tile": t, "hook": str(d.get("hook", "")), "solid": bool(d.get("solid", true))}
			_static_obj_at[t] = id


## Story-vlag van een kist (eenmalig openen). Standaard "kist:<id>", net als DungeonChest in v14;
## een eigen "flag" in de data mag ook.
static func chest_flag(d: Dictionary) -> String:
	var f := str(d.get("flag", ""))
	return f if f != "" else "kist:" + str(d.get("id", ""))


## Type van een object; {"type": "gate", "style": "geheim"} telt als "secret".
static func _type_of(d: Dictionary) -> String:
	var type := str(d.get("type", ""))
	if type == "gate" and str(d.get("style", "")) == "geheim":
		return "secret"
	return type


## Richting vanaf een randtegel de kamer in (E onderin -> omhoog, enz.).
## v0.14: staat de deur binnenin (in een muur, bv. X in de puzzelkamer van het Eerste Archief),
## dan de richting naar de enige buur die geen muur is.
func inward_dir(t: Vector2i) -> Vector2i:
	var border := t.x == 0 or t.y == 0 or t.x == size.x - 1 or t.y == size.y - 1
	if not border:
		for d in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
			if inside(t + d) and not walls.has(t + d):
				return d
	if t.y == size.y - 1:
		return Vector2i.UP
	if t.y == 0:
		return Vector2i.DOWN
	if t.x == 0:
		return Vector2i.RIGHT
	return Vector2i.LEFT


# ---------------------------------------------------------------- vragen
func inside(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < size.x and t.y < size.y


func block_at(t: Vector2i) -> String:
	return _block_at.get(t, "")


## Id van de plaat/hendel/poort/steen op deze tile ("" = niets).
func object_at(t: Vector2i) -> String:
	return _static_obj_at.get(t, "")


func gate_open(id: String) -> bool:
	return gates.has(id) and bool(gates[id]["open"])


func plate_pressed(id: String) -> bool:
	return plates.has(id) and bool(plates[id]["pressed"])


func lever_on(id: String) -> bool:
	return levers.has(id) and bool(levers[id]["on"])


func book_pressed(id: String) -> bool:
	return books.has(id) and bool(books[id]["pressed"])


## Is er een geheime deur open? (dan is de verborgen vloer zichtbaar)
func any_secret_open() -> bool:
	for id in gates:
		if gates[id].get("secret", false) and gates[id]["open"]:
			return true
	return false


func signal_value(id: String) -> bool:
	return bool(signals.get(id, false))


## Kan de SPELER hier niet staan? (muur, vaste kast, kast, hendel, steen, dichte poort,
## buiten de kamer). Platen, open poorten en deuren zijn begaanbaar.
func is_solid(t: Vector2i) -> bool:
	if not inside(t) or walls.has(t) or statics.has(t) or _block_at.has(t):
		return true
	if door_tops.has(t) and not gates[door_tops[t]]["open"]:
		return true      # bovenste tegel van een dichte geheime deur
	var o := object_at(t)
	if o == "":
		return false
	match types.get(o, ""):
		"lever", "reset", "book", "chest":
			return true
		"gate", "secret":
			return not gates[o]["open"]
		"hook":
			return bool(hooks[o]["solid"])
	return false


func _player_on(t: Vector2i) -> bool:
	return t == player_tile or t == player_target


## Waarom kan deze kast niet die kant op? "" = het kan wel.
func push_block_reason(id: String, dir: Vector2i) -> String:
	if not blocks.has(id):
		return "onbekende kast"
	if not dir in DIRS:
		return "geen richting"
	if heavy_blocks.has(id) and not abilities.has(heavy_blocks[id]):
		return "te zwaar"      # v0.15: eerst de kracht van een kern nodig
	var t: Vector2i = blocks[id] + dir
	if not inside(t):
		return "buiten de kamer"
	if walls.has(t) or statics.has(t):
		return "muur"
	if _block_at.has(t):
		return "kast"
	if exits.has(t):
		return "deur"
	if door_tops.has(t):
		return "poort"
	match types.get(object_at(t), ""):
		"lever":
			return "hendel"
		"reset":
			return "herstelsteen"
		"gate", "secret":
			return "poort"
		"book":
			return "boek"
		"chest":
			return "kist"
		"hook":
			if hooks[object_at(t)]["solid"]:
				return "haakje"
	if _player_on(t):
		return "speler"
	return ""


func can_push(id: String, dir: Vector2i) -> bool:
	return push_block_reason(id, dir) == ""


# ---------------------------------------------------------------- acties
## Duw kast 'id' één tile in richting dir. true = gelukt (en alles is bijgewerkt).
func try_push(id: String, dir: Vector2i) -> bool:
	if not can_push(id, dir):
		return false
	var from: Vector2i = blocks[id]
	_block_at.erase(from)
	blocks[id] = from + dir
	_block_at[from + dir] = id
	var ids := _evaluate()
	ids.push_front(id)
	changed.emit(ids)
	return true


## Hendel omzetten. Geeft de nieuwe stand terug.
func toggle_lever(id: String) -> bool:
	if not levers.has(id):
		return false
	levers[id]["on"] = not levers[id]["on"]
	var ids := _evaluate()
	if not id in ids:
		ids.push_front(id)
	changed.emit(ids)
	return levers[id]["on"]


## Los boek terugduwen (eenmalig). true = nu ingedrukt (false = was al ingedrukt / bestaat niet).
func press_book(id: String) -> bool:
	if not books.has(id) or books[id]["pressed"]:
		return false
	books[id]["pressed"] = true
	var ids := _evaluate()
	ids.push_front(id)
	changed.emit(ids)
	return true


## Waar staat de speler (en waar loopt hij heen)? Werkt platen/poorten bij als dat verandert.
func set_player_tile(t: Vector2i, target := NOWHERE) -> Array:
	if target == NOWHERE:
		target = t
	if t == player_tile and target == player_target:
		return []
	player_tile = t
	player_target = target
	return update()


## Alles opnieuw uitrekenen; zendt 'changed' als er iets veranderde.
func update() -> Array:
	var ids := _evaluate()
	if not ids.is_empty():
		changed.emit(ids)
	return ids


## Terug naar het begin: kasten en hendels naar hun startplek/-stand. Vergrendelde (latch)
## poorten blijven open. Alle ids worden als 'veranderd' gemeld (nodes springen terug).
func reset() -> Array:
	_block_at.clear()
	for id in block_start:
		blocks[id] = block_start[id]
		_block_at[block_start[id]] = id
	for id in levers:
		levers[id]["on"] = levers[id]["start"]
	_evaluate()
	var ids: Array = []
	ids.append_array(blocks.keys())
	ids.append_array(plates.keys())
	ids.append_array(levers.keys())
	ids.append_array(gates.keys())
	ids.append_array(books.keys())
	changed.emit(ids)
	return ids


func latched_ids() -> Array:
	var out: Array = []
	for id in gates:
		if gates[id]["latched"]:
			out.append(id)
	for id in books:      # v0.15: ingedrukte losse boeken worden net zo onthouden
		if books[id]["pressed"]:
			out.append(id)
	return out


## Toestand als Dictionary (JSON-veilig: tiles als [x, y]). Voor een tijdelijke kopie
## (bv. tijdens een gevecht) of later voor de save.
func get_state() -> Dictionary:
	var b := {}
	for id in blocks:
		b[id] = [blocks[id].x, blocks[id].y]
	var lv := {}
	for id in levers:
		lv[id] = levers[id]["on"]
	return {"blocks": b, "levers": lv, "latched": latched_ids()}


func set_state(st: Dictionary) -> Array:
	var b: Dictionary = st.get("blocks", {})
	_block_at.clear()
	for id in blocks:
		if b.has(id):
			blocks[id] = Vector2i(int(b[id][0]), int(b[id][1]))
		_block_at[blocks[id]] = id
	var lv: Dictionary = st.get("levers", {})
	for id in levers:
		if lv.has(id):
			levers[id]["on"] = bool(lv[id])
	for id in gates:
		gates[id]["latched"] = gates[id]["latch"] and (id in st.get("latched", []))
	for id in books:
		books[id]["pressed"] = id in st.get("latched", [])
	_evaluate()
	var ids: Array = []
	ids.append_array(blocks.keys())
	ids.append_array(plates.keys())
	ids.append_array(levers.keys())
	ids.append_array(gates.keys())
	ids.append_array(books.keys())
	changed.emit(ids)
	return ids


# ---------------------------------------------------------------- rekenen
## platen -> signalen -> poorten. Geeft de ids terug die veranderd zijn (zonder te zenden).
func _evaluate() -> Array:
	var ids: Array = []
	for id in plates:
		var p: Dictionary = plates[id]
		var pressed: bool = _block_at.has(p["tile"]) or (not p["heavy"] and p["tile"] == player_tile)
		if pressed != p["pressed"]:
			p["pressed"] = pressed
			ids.append(id)
		signals[id] = pressed
	for id in levers:
		signals[id] = levers[id]["on"]
	for id in books:
		signals[id] = books[id]["pressed"]
	# Poorten mogen van elkaar afhangen: herhaal tot er niets meer verandert.
	for i in gates.size() + 1:
		var any := false
		for id in gates:
			var g: Dictionary = gates[id]
			var want := _condition(g)
			if want and g["latch"] and not g["latched"]:
				g["latched"] = true
			var open: bool = want or g["latched"]
			if not open and g["open"] and _player_on(g["tile"]):
				open = true   # blijft open tot de speler uit de poort is
			if open != g["open"]:
				g["open"] = open
				any = true
				if not id in ids:
					ids.append(id)
			signals[id] = open
		if not any:
			break
	return ids


func _condition(g: Dictionary) -> bool:
	var needs: Array = g["needs"]
	var res: bool
	if g["mode"] == "any":
		res = false
		for n in needs:
			if signals.get(n, false):
				res = true
				break
	else:
		res = true
		for n in needs:
			if not signals.get(n, false):
				res = false
				break
	return not res if g["invert"] else res


# ---------------------------------------------------------------- data: controle + tegels
## Controleer een kamer uit puzzle_rooms.gd. Geeft een lijst fouten (leeg = goed).
static func validate(room: Dictionary) -> Array[String]:
	var err: Array[String] = []
	var rows: Array = room.get("layout", [])
	if rows.is_empty():
		err.append("geen layout")
		return err
	var w := str(rows[0]).length()
	var h := rows.size()
	for y in h:
		if str(rows[y]).length() != w:
			err.append("rij %d is %d breed i.p.v. %d (niet rechthoekig)" % [y, str(rows[y]).length(), w])
	if not err.is_empty():
		return err
	var objs: Dictionary = room.get("objects", {})
	var count := {}
	var e_count := 0
	var x_count := 0
	var e_tile := NOWHERE
	for y in h:
		for x in w:
			var c := str(rows[y])[x]
			var border := x == 0 or y == 0 or x == w - 1 or y == h - 1
			if c == "E" or c == "X":
				if c == "E":
					e_count += 1
					e_tile = Vector2i(x, y)
				else:
					x_count += 1
				var corner := (x == 0 or x == w - 1) and (y == 0 or y == h - 1)
				if corner:
					err.append("'%s' op (%d,%d) moet in de rand staan (niet in een hoek)" % [c, x, y])
				elif not border:
					# v0.14: binnenin mag, als de deur in een muur zit met precies 1 open buur
					var open_n := 0
					for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
						if str(rows[y + d.y])[x + d.x] != "#":
							open_n += 1
					if open_n != 1:
						err.append("'%s' op (%d,%d) moet in de rand staan, of in een muur met precies 1 open buur" % [c, x, y])
			elif c == "B":
				if y == 0 or str(rows[y - 1])[x] != "#":
					err.append("vaste kast 'B' op (%d,%d) heeft geen muur erboven" % [x, y])
				if border:
					err.append("vaste kast 'B' op (%d,%d) staat in de rand" % [x, y])
			elif c == "#" or c == "." or c == ",":
				if c != "#" and border:
					err.append("vloer in de rand op (%d,%d): de kamer is niet dicht" % [x, y])
			elif not objs.has(c):
				err.append("teken '%s' op (%d,%d) staat niet in objects" % [c, x, y])
			else:
				count[c] = int(count.get(c, 0)) + 1
				if border:
					err.append("object '%s' op (%d,%d) staat in de rand" % [c, x, y])
	if e_count != 1:
		err.append("precies 1 'E' nodig, gevonden: %d" % e_count)
	var ids := {}
	for c in objs:
		var d: Dictionary = objs[c]
		if str(c).length() != 1 or FIXED_CHARS.contains(str(c)):
			err.append("objectteken '%s' moet 1 teken zijn en geen vast teken (%s)" % [c, FIXED_CHARS])
		var id := str(d.get("id", ""))
		var type := _type_of(d)
		if id == "":
			err.append("object '%s' heeft geen id" % c)
		elif ids.has(id):
			err.append("id '%s' komt dubbel voor" % id)
		ids[id] = type
		if not type in TYPES:
			err.append("object '%s' heeft onbekend type '%s'" % [c, type])
		if int(count.get(c, 0)) != 1:
			err.append("object '%s' (%s) staat %d keer in de layout (moet 1)" % [c, id, int(count.get(c, 0))])
	var flags := {}
	for c in objs:
		var d: Dictionary = objs[c]
		var dtype := _type_of(d)
		var t := _find_char(rows, str(c))
		if t == NOWHERE:
			continue
		if dtype == "book" and (t.y == 0 or str(rows[t.y - 1])[t.x] != "#"):
			err.append("los boek '%s' op (%d,%d) heeft geen muur erboven (het is een kast)" % [d.get("id", c), t.x, t.y])
		if dtype == "secret" and t.y > 0 and t.y < h - 1:
			var up := str(rows[t.y - 1])[t.x]
			var down := str(rows[t.y + 1])[t.x]
			if not up in [",", "."] or down == "#" or down == "B":
				err.append("geheime deur '%s' op (%d,%d) is 2 tegels hoog: erboven ',' of '.', eronder een doorgang" % [d.get("id", c), t.x, t.y])
		if dtype == "chest":
			var item := str(d.get("item", ""))
			if not GameData.ITEMS.has(item) and not GameData.EQUIPMENT.has(item):
				err.append("kist '%s': item '%s' bestaat niet (ITEMS/EQUIPMENT)" % [d.get("id", c), item])
			var flag := chest_flag(d)
			if flags.has(flag):
				err.append("kist-flag '%s' komt dubbel voor" % flag)
			flags[flag] = true
	for c in objs:
		var d: Dictionary = objs[c]
		if not _type_of(d) in ["gate", "secret"]:
			continue
		var needs: Array = d.get("needs", [])
		if needs.is_empty():
			err.append("poort '%s' heeft geen needs" % d.get("id", c))
		for n in needs:
			if not ids.has(str(n)):
				err.append("poort '%s' wacht op '%s', maar dat bestaat niet" % [d.get("id", c), n])
			elif str(n) == str(d.get("id", "")):
				err.append("poort '%s' wacht op zichzelf" % n)
			elif not ids[str(n)] in SIGNAL_TYPES:
				err.append("poort '%s': '%s' geeft geen signaal (alleen %s)" % [d.get("id", c), n, "/".join(SIGNAL_TYPES)])
		if not str(d.get("mode", "all")) in ["all", "any"]:
			err.append("poort '%s': mode moet 'all' of 'any' zijn" % d.get("id", c))
	if e_tile != NOWHERE:
		var l := PuzzleLogic.new()
		l.size = Vector2i(w, h)
		var s: Vector2i = e_tile + l.inward_dir(e_tile)
		if str(rows[s.y])[s.x] != ".":
			err.append("de tegel naast 'E' (%d,%d) moet vrije vloer '.' zijn (daar verschijn je)" % [s.x, s.y])
	# v0.14: "look" (dungeon-stijl) moet even groot zijn als de layout
	if room.has("look"):
		var look: Array = room["look"]
		if look.size() != h:
			err.append("look heeft %d rijen i.p.v. %d" % [look.size(), h])
		for y in mini(h, look.size()):
			if str(look[y]).length() != w:
				err.append("look-rij %d is %d breed i.p.v. %d" % [y, str(look[y]).length(), w])
	var ent: Dictionary = room.get("entrance", {})
	if str(ent.get("map", "")) == "" or str(ent.get("spawn", "")) == "":
		err.append("entrance heeft map + spawn nodig")
	if x_count > 0:
		var ex: Dictionary = room.get("exit", {})
		if str(ex.get("map", "")) == "" and (ex.get("lines", []) as Array).is_empty():
			err.append("exit heeft map + spawn of lines nodig")
		if str(ex.get("map", "")) != "" and str(ex.get("spawn", "")) == "":
			err.append("exit met map heeft ook spawn nodig")
	return err


static func _find_char(rows: Array, c: String) -> Vector2i:
	for y in rows.size():
		var x := str(rows[y]).find(c)
		if x >= 0:
			return Vector2i(x, y)
	return NOWHERE


## Welke tegel uit binnen.png komt op elke plek? Vector2i -> tegelnummer.
## Rand boven/onder = muurtop (2), linker-/rechterrand = zijmuur (23/24), behalve naast
## een muurband (dan 3, net als in het huis). Muur binnenin: muur eronder = muurtop (2),
## vloer eronder = muurvoorkant (3). 'B' = kastonderkant (7) met kastbovenkant (6) erboven.
## E/X = deur (5). Alle andere tegels (ook onder objecten) = vloer 0/1 (vast patroon).
static func autotile(rows: Array) -> Dictionary:
	var out := {}
	var h := rows.size()
	var w := str(rows[0]).length()
	var wall := func(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= w or y >= h:
			return true
		return str(rows[y])[x] == "#"
	for y in h:
		for x in w:
			var c := str(rows[y])[x]
			var t := Vector2i(x, y)
			if c == "E" or c == "X":
				out[t] = T_DOOR
			elif c == "B":
				out[t] = T_SHELF_BOTTOM
			elif c == "#":
				if y == 0 or y == h - 1:
					out[t] = T_WALL_TOP
				elif x == 0 or x == w - 1:
					var inner := 1 if x == 0 else w - 2
					if wall.call(inner, y):
						out[t] = T_WALL_TOP if wall.call(inner, y + 1) else T_WALL_FRONT
					else:
						out[t] = T_SIDE_LEFT if x == 0 else T_SIDE_RIGHT
				elif wall.call(x, y + 1):
					out[t] = T_WALL_TOP
				else:
					out[t] = T_WALL_FRONT
			else:
				out[t] = T_FLOOR_B if (x * 3 + y * 5 + x * y) % 7 < 3 else T_FLOOR_A
	# Vaste kast: bovenkant in de muur erboven.
	for y in h:
		for x in w:
			if str(rows[y])[x] == "B" and y > 0 and str(rows[y - 1])[x] == "#":
				out[Vector2i(x, y - 1)] = T_SHELF_TOP
	return out
