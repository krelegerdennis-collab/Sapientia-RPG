extends RefCounted
## v0.14 (RPG CODE) De ROZE KERN van de Golem-baas (Het Kennis-Beest in een baasgevecht).
## Alleen de regels (geen beeld): los te testen. battle.gd vraagt hier per ronde wat er
## gebeurt; boss_core_view.gd tekent het pantser / de roze gloed.
##
## Regels (getallen in game_data.gd, ENEMIES.kennis_beest.boss.core):
##   - De kern zit meestal DICHT (pantser): alle schade op de Golem x closed_mult (0,4).
##   - Elke 'cycle'-de ronde (3, 6, 9, ...) laadt de Golem op: aan het begin van die ronde
##     het bericht 'De kern gloeit roze!' en de kern gaat OPEN: schade x open_mult (2,0).
##     In die ronde valt de Golem niet gewoon aan; hij is als LAATSTE aan de beurt.
##   - Kreeg de kern in die ronde minstens break_damage schade, dan barst de lading: geen
##     aanval ('De Golem wankelt'). Anders: Hamerslag = aanval x slam_power (verdedigen halveert).
##   - Daarna gaat de kern weer dicht. Zo is er nooit een vastloper: elke derde ronde is er
##     een venster, en verdedigen of genezen blijft altijd mogelijk.

## Standaardwaarden (als de data iets mist).
const DEFAULTS := {
	"cycle": 3,              # elke 3e ronde gaat de kern open
	"closed_mult": 0.4,      # schade op het pantser
	"open_mult": 2.0,        # schade op de open roze kern
	"break_damage": 20,      # zoveel schade in het open venster = lading kapot, geen Hamerslag
	"slam_power": 2.2,       # Hamerslag = ATK x 2,2 (normale formule, verdedigen = helft)
	"slam_name": "Hamerslag",
	# kern in de pixels van het baas-plaatje (golem_boss_v2.png, 196x182): x, y, b, h
	"rect": [82, 52, 30, 30],
}

## Berichten (de naam van de baas wordt ingevuld).
const MSG_HINT := "Pantser op de kern! Wacht op het roze licht."
const MSG_OPEN := "De kern gloeit roze! %s laadt op..."
## blijft in beeld zolang je kiest en de kern open is
const MSG_WINDOW := "Roze kern open! Val nu aan!"
const MSG_BREAK := "Raak! De lading barst. %s wankelt."
const MSG_SLAM := "%s: %s!"
const MSG_CLOSE := "De kern sluit zich weer."

var cycle := 3
var closed_mult := 0.4
var open_mult := 2.0
var break_damage := 20
var slam_power := 2.2
var slam_name := "Hamerslag"
var rect := Rect2(82, 52, 30, 30)

## true = kern open (roze, kwetsbaar)
var open := false
## schade op de kern in het huidige open venster
var dealt := 0
## tellers (voor tests en de HANDOFF)
var opened_count := 0
var broken_count := 0
var slam_count := 0

signal changed(is_open: bool)


func _init(cfg: Dictionary = {}) -> void:
	var c := DEFAULTS.duplicate()
	c.merge(cfg, true)
	cycle = maxi(1, int(c["cycle"]))
	closed_mult = float(c["closed_mult"])
	open_mult = float(c["open_mult"])
	break_damage = maxi(1, int(c["break_damage"]))
	slam_power = float(c["slam_power"])
	slam_name = str(c["slam_name"])
	var r: Array = c["rect"]
	rect = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


## Baas-versie van een vijand: de waarden uit data["boss"] over de gewone heen, "core" apart.
## Zonder "boss"-blok: de data ongewijzigd terug.
static func apply_boss(data: Dictionary) -> Dictionary:
	if not data.has("boss"):
		return data
	var out := data.duplicate(true)
	var b: Dictionary = out["boss"]
	for k in b:
		out[k] = b[k]
	out.erase("boss")
	return out


## Is ronde round_no (1, 2, 3, ...) een oplaad-ronde?
static func is_charge_round(round_no: int, every: int) -> bool:
	return every > 0 and round_no > 0 and round_no % every == 0


## Begin van een ronde. true = de kern gaat NU open (laat dan MSG_OPEN zien).
func start_round(round_no: int) -> bool:
	if not is_charge_round(round_no, cycle):
		return false
	open = true
	dealt = 0
	opened_count += 1
	changed.emit(true)
	return true


func damage_mult() -> float:
	return open_mult if open else closed_mult


## Schade op de Golem door de kern heen (min. 1). Telt mee voor het open venster.
func scale_damage(amount: int) -> int:
	var d := maxi(1, roundi(float(amount) * damage_mult()))
	if open:
		dealt += d
	return d


func is_broken() -> bool:
	return open and dealt >= break_damage


## Einde van de oplaad-ronde (de actie van de Golem): "break" (geen aanval) of "slam".
## Daarna is de kern weer dicht.
func resolve() -> String:
	var result := "break" if is_broken() else "slam"
	if result == "break":
		broken_count += 1
	else:
		slam_count += 1
	open = false
	dealt = 0
	changed.emit(false)
	return result


## Kern meteen dicht (bv. als de Golem in de open ronde verslagen is).
func close() -> void:
	if open:
		open = false
		dealt = 0
		changed.emit(false)
