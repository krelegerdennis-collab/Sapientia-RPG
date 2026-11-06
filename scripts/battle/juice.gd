class_name BattleJuice
extends Node
## Juice / game-feel van het gevecht (HANDOFF_JUICE, stap 1: kapstok).
##
## Child van de gevechtsscène ($Juice), geen autoload. Eén ingang: feedback(tier, pos).
## Tiers (skill game-feel §4): "small" gewone aanval · "medium" vaardigheid/spreuk/Kernkracht of
## schade >= 25 % max-HP · "large" KO, treffer op open boss-kern, overwinning.
## Stap 1 doet nog niets zichtbaars: hij telt alleen en logt (debug). Stap 2-4 hangen hier aan.
##
## Headless/test: feedback() is een no-op (GameState.test_modus of DisplayServer "headless"),
## zodat geen enkele test door juice verandert.

const TIERS := ["small", "medium", "large"]

## Alleen voor tests/debug: hoeveel keer per tier aangeroepen sinds de scène begon.
var counts := {"small": 0, "medium": 0, "large": 0}
var last_tier := ""
var last_pos := Vector2.ZERO


func _ready() -> void:
	set_process(false)   # stap 3 (trauma) zet dit aan


## Is juice uitgeschakeld (tests, headless)?
func is_muted() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	var gs := get_node_or_null("/root/GameState")
	return gs != null and bool(gs.get("test_modus"))


## Eén treffer/gebeurtenis. pos = positie in de gevechtsscène (voor latere particles/pop).
func feedback(tier: String, pos: Vector2 = Vector2.ZERO) -> void:
	if not TIERS.has(tier):
		push_warning("BattleJuice: onbekende tier '%s'" % tier)
		tier = "small"
	counts[tier] = int(counts[tier]) + 1
	last_tier = tier
	last_pos = pos
	if is_muted():
		return
	# Stap 2: hit_stop(...)  · stap 3: add_trauma(...)  · stap 4: pop/flash via battle.gd
