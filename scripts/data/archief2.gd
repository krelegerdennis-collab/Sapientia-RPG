extends RefCounted
class_name Archief2
## Het Levende Archief (Archief 2). Regels zonder scène, zodat de headless suite ze
## kan naspelen. Kamers: scripts/data/archief2_rooms.gd. Die kamers staan bewust niet
## in DungeonRooms.ROOMS (de glitch-grafiek van Archief 1 blijft gelijk).

const CodexData := preload("res://scripts/data/codex_data.gd")
const GameData := preload("res://scripts/data/game_data.gd")

## Zelfde vlag als StoryData.GOLEM_FLAG: het bestaande signaal dat Archief 1 klaar is.
const GOLEM_VLAG := "bewaker:archief_golemhal/golem"
const ENTREE := "archief_2_v1_entree"
const WARPER := "archief_2_warper"
const ENTREE_SCENE := "res://scenes/maps/archief_2_v1_entree.tscn"
const PLAAT_SCENE := "res://scenes/maps/archief_2_v1_plaat.tscn"
const WARPER_SCENE := "res://scenes/maps/archief_2_warper.tscn"
const WERELD := "res://scenes/maps/wereldkaart.tscn"

const STAAT_MAX := 2
## TODO(design): de canon noemt geen vermenigvuldiger. 1,5 is een conservatieve zwakte.
const ZWAK := 1.5
const OPEN_PCT := 0.30
const LEECH_MIN := 0.08
const LEECH_MAX := 0.12
## Canon: HP = level × 50, ATK = level × 3, DEF = level × 2.
## De Wurger is level 14, De Genezer level 18.
const WURGER_HP := 700
const WURGER_ATK := 42
const WURGER_DEF := 28
const GENEZER_HP := 900
const GENEZER_ATK := 54
const GENEZER_DEF := 36
const LOTTE_HP := 90
const LOTTE_ATK := 14
const LOTTE_DEF := 5

const KERN_ID := "levenskern"
const KERN_ZIN := "In silence lies peace. I correct what grows."
const START_GEAR := ["eiken_staf", "reisgewaad"]
const START_SPELLS := ["genees", "rijp"]
## TODO(design): het bestiarium noemt dit beest "Moss Slime". De soort-id is mosslijm.
## Spelertekst is "Moss Slime". Geen nieuw Codex-beest.
const MOSSLIJM_SOORT := "mosslijm"

const KETEN := [
	"The Old Humanity made the six Archives as a chain.",
	"Each core activates the next. Not an invitation: a distress signal.",
	"Archive 1 sent: Someone is inside. Archive 2 answered first.",
	"Sapientia manipulated that signal.",
	"You think you are following. Sapientia is leading you.",
]
const GEEN_CODEX := [
	"You don't have a Codex monster yet.",
	"A Moss Slime fights alongside you for this battle.",
]
const LOTTE_AANSLUIT := [
	"The glitch tears. Seren breaks it herself.",
	"I can hear the Order of the Silent Flame again.",
	"Silence is what Sapientia wants: to erase emotion.",
	"The Flame is life, warmth, emotion. That is why they sent me.",
	"The Order is divided. Sapientia corrupted me as a symbol, instead of killing me.",
	"Even those who cherish life, they wanted silenced.",
	"Seren joins. Priest, with Light and Ice, grade 1.",
]
const NA_GENEZER := [
	KERN_ZIN,
	"The greenhouse tears open. A floating high-tech building appears: the World Warper.",
	"It pulls you upward.",
]
## Kaartkamer. De Hanger-scène en de H-6-dreiging staan sinds CANON.md punt 17 in de Hal
## (world_warper/cutscene/canon_scenes.gd). Hier alleen sfeer, geen ECHO-uitleg meer.
const ECHO_REGELS := [
	"The map room is quiet. Purple light hums inside the walls.",
	"Somewhere above you, the World Warper is waiting.",
]
const EILANDEN_DICHT := [
	"The other islands are silent. ECHO cannot open them yet.",
]


static func open_na(flags: Dictionary) -> bool:
	return bool(flags.get(GOLEM_VLAG, false))


static func plaat_sleutel(room_id: String, plaat_id: String) -> String:
	return "%s:%s" % [room_id, plaat_id]


## Groei alleen bij de juiste actie. licht_magie = Lotte in de party met Licht graad 1.
static func volgende_staat(soort: String, staat: int, actie: String, licht_magie: bool) -> int:
	var s := clampi(staat, 0, STAAT_MAX)
	match soort:
		"groei":
			if actie == "stap":
				return mini(s + 1, STAAT_MAX)
		"tegen":
			if actie == "stap" or actie == "tegen":
				return maxi(s - 1, 0)
		"licht":
			if actie == "licht" and licht_magie:
				return mini(s + 1, STAAT_MAX)
		"ketting":
			if actie == "stap":
				return mini(s + 1, STAAT_MAX)
	return s


static func brug_open(staat: int) -> bool:
	return staat >= STAAT_MAX


## Ketting: plaat index laat zichzelf én de volgende één stadium groeien.
## De laatste plaat groeit niet als je er zelf op stapt; alleen de vorige activeert hem.
static func pas_ketting(staten: Array, index: int) -> Array:
	var out: Array = []
	for x in staten:
		out.append(int(x))
	if index < 0 or index >= out.size() - 1:
		return out
	out[index] = mini(int(out[index]) + 1, STAAT_MAX)
	var nxt := index + 1
	out[nxt] = mini(int(out[nxt]) + 1, STAAT_MAX)
	return out


static func lotte_heeft_licht() -> bool:
	if not GameState.has_member("lotte"):
		return false
	for h in GameState.party:
		if str(h.get("id", "")) != "lotte":
			continue
		var spells: Array = h.get("spells", [])
		for sp in spells:
			var spell: Dictionary = GameData.SPELLS.get(str(sp), {})
			if str(spell.get("element", "")) == "licht" and int(spell.get("grade", 0)) == 1:
				return true
	return false


## TODO(design): de veldparty kan één Codex-volger houden (field_follower op archief_*).
## Een tijdelijke Mosslijm wordt niet ingeschreven en loopt daarna niet mee.
## Het gekozen monster blijft de actieve bondgenoot. Geen vierde held forceren.
static func tijdelijke_mosslijm(level: int) -> Dictionary:
	var page := CodexData.make_page(MOSSLIJM_SOORT, maxi(1, level), "archief2_tijdelijk")
	page["name"] = "Moss Slime"
	page["tijdelijk"] = true
	return page


static func bondgenoot_voor(paginas: Array, level: int) -> Dictionary:
	var levend: Array = []
	for p in paginas:
		if p is Dictionary and int(p.get("hp", 0)) > 0:
			levend.append(p)
	if levend.is_empty():
		return {"page": tijdelijke_mosslijm(level), "tijdelijk": true}
	return {"page": levend[0], "tijdelijk": false}


static func zet_bondgenoot(keuze: Dictionary) -> void:
	var page: Dictionary = keuze.get("page", {})
	if bool(keuze.get("tijdelijk", false)):
		GameState.archief2_temp_ally = page.duplicate(true)
		return
	GameState.archief2_temp_ally = {}
	GameState.codex_set_active(str(page.get("uid", "")))


static func sluit_lotte_aan() -> bool:
	var lv := maxi(1, GameState.member_level("dennis"))
	if not GameState.has_member("lotte"):
		if not GameState.join_member("lotte", lv, START_GEAR):
			return false
	for h in GameState.party:
		if str(h.get("id", "")) != "lotte":
			continue
		h["spells"] = START_SPELLS.duplicate()
		h["hp"] = int(h["max_hp"])
		h["mp"] = int(h["max_mp"])
	GameState.story_flags["archief2_lotte_lid"] = true
	return GameState.has_member("lotte") and GameState.member_level("lotte") == GameState.member_level("dennis")


static func openingslag(max_hp: int) -> int:
	return maxi(1, roundi(float(maxi(0, max_hp)) * OPEN_PCT))


static func leech_pct(roll: float) -> float:
	return lerpf(LEECH_MIN, LEECH_MAX, clampf(roll, 0.0, 1.0))


static func leech_hoeveelheid(roll: float, doel_max: int) -> int:
	return maxi(1, roundi(float(maxi(1, doel_max)) * leech_pct(roll)))


## schade en heal zijn hetzelfde aantal. hp_na stopt bij genezer_max.
static func leech_resultaat(roll: float, doel_max: int, genezer_hp: int, genezer_max: int) -> Dictionary:
	var n := leech_hoeveelheid(roll, doel_max)
	return {
		"schade": n,
		"heal": n,
		"hp_na": mini(genezer_max, genezer_hp + n),
	}


static func zwakte_fysiek(attacker: Dictionary, target: Dictionary) -> float:
	var stats: Dictionary = target.get("s", {})
	if not bool(stats.get("weak_matters", false)):
		return 1.0
	var weak: Array = stats.get("weak", [])
	if "fysiek" in weak:
		return ZWAK
	var id := ""
	if bool(attacker.get("is_hero", false)) and not bool(attacker.get("ally", false)):
		id = str(attacker.get("s", {}).get("id", ""))
	if id == "dennis" and "zwaard" in weak:
		return ZWAK
	return 1.0


static func schaal_element(amount: int, target: Dictionary, element: String) -> int:
	var stats: Dictionary = target.get("s", {})
	if not bool(stats.get("weak_matters", false)):
		return amount
	if element != "" and element in stats.get("weak", []):
		return maxi(1, roundi(float(amount) * ZWAK))
	return amount


## TODO(design): WM2 en WM3 bestaan niet. Lege keuze, geen werkende warp.
static func warp_doel(keuze: String) -> Dictionary:
	match keuze:
		"wilgendal":
			return {"map": WERELD, "spawn": "van_wilgendal"}
		"archief":
			return {"map": WERELD, "spawn": "van_archief"}
		"wm2", "wm3":
			return {}
	return {}
