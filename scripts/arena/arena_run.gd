extends Node
## Colosseum-run: lobby -> wave 1..5 -> keuze -> results -> lobby.
## Praat met SomArenaWaves alleen via start_wave en de drie signalen.
## Hele party neer: results, verdiende rewards blijven, terug naar de lobby.
## Geen game over.
## Co-op (LAN of online): de runfase wordt niet gesynct, dus de arena start dan niet
## (review #487, punt D). Echte co-op-arena-sync is een latere klus.

const WavesScript := preload("res://scripts/arena/som_arena_waves.gd")
const Rewards := preload("res://scripts/data/arena_rewards.gd")
const WorldSfx := preload("res://scripts/audio/world_sfx.gd")

const PHASE_LOBBY := "lobby"
const PHASE_WAVE := "wave"
const PHASE_CHOICE := "choice"
const PHASE_RESULTS := "results"
const PHASES: Array[String] = [PHASE_LOBBY, PHASE_WAVE, PHASE_CHOICE, PHASE_RESULTS]
## Speler-tekst als de poort dicht blijft tijdens co-op.
const COOP_CLOSED_LINE := "The arena is closed during co-op."

signal phase_changed(phase: String)

var phase: String = PHASE_LOBBY
var wave := 0
var waves_cleared := 0
var earned_xp := 0
var earned_tokens := 0
var wiped := false
var last_started := 0
var level_notes: Array[String] = []
var waves: Node
## Door de host gezet vóór begin(); 0 = kies bij begin().
var run_seed := 0

var _paid: Dictionary = {}


func _ready() -> void:
	var w := WavesScript.new()
	w.name = "Waves"
	add_child(w)
	waves = w
	w.wave_started.connect(_on_wave_started)
	w.wave_cleared.connect(_on_wave_cleared)
	w.party_wiped.connect(_on_party_wiped)


## True zolang er een co-op-sessie loopt (host of gast, LAN of online).
static func coop_blocked() -> bool:
	return GameState.coop_in_session()


func begin() -> void:
	if phase != PHASE_LOBBY:
		return
	if coop_blocked():
		push_warning("ArenaRun: begin() geweigerd tijdens co-op (geen arena-sync).")
		return
	earned_xp = 0
	earned_tokens = 0
	waves_cleared = 0
	wiped = false
	level_notes = []
	_paid = {}
	wave = 0
	if run_seed == 0:
		run_seed = hash("arena_run|%d" % Time.get_ticks_usec())
	_start_wave()


func choose_continue() -> void:
	if phase != PHASE_CHOICE:
		return
	_start_wave()


func choose_leave() -> void:
	if phase != PHASE_CHOICE:
		return
	_to_results(false)


func acknowledge() -> void:
	if phase != PHASE_RESULTS:
		return
	if wiped:
		Rewards.revive_after_wipe()
	wave = 0
	_set_phase(PHASE_LOBBY)


func summary() -> Dictionary:
	return {
		"waves": waves_cleared,
		"xp": earned_xp,
		"tokens": earned_tokens,
		"wiped": wiped,
		"wallet": GameState.arena_tokens,
		"notes": level_notes.duplicate(),
	}


func _start_wave() -> void:
	wave += 1
	_set_phase(PHASE_WAVE)
	if waves != null and waves.has_method("start_wave"):
		waves.start_wave(wave)


func _on_wave_started(n: int) -> void:
	if phase != PHASE_WAVE or n != wave:
		return
	last_started = n


func _on_wave_cleared(n: int) -> void:
	if phase != PHASE_WAVE or n != wave:
		return
	# Review #487 punt C: overgeslagen golf (timeout / 0 spawns) = niets verslagen = geen beloning.
	var skipped: bool = waves != null and waves.has_method("wave_was_skipped") and waves.wave_was_skipped(n)
	if not skipped:
		_grant(n)
		Rewards.restore_between_waves()
	if n >= Rewards.WAVE_COUNT:
		_to_results(false)
		return
	_set_phase(PHASE_CHOICE)


func _on_party_wiped() -> void:
	# Alleen tijdens een wave. Een los 'één speler neer' komt hier niet binnen.
	if phase != PHASE_WAVE:
		return
	_to_results(true)


func _grant(n: int) -> void:
	if _paid.has(n):
		return
	_paid[n] = true
	var row := Rewards.for_wave(n)
	var xp := int(row.get("xp", 0))
	var tokens := int(row.get("tokens", 0))
	for raw in GameState.party:
		if typeof(raw) != TYPE_DICTIONARY or xp <= 0:
			continue
		var hero: Dictionary = raw
		var msgs: Array[String] = GameState.give_exp(hero, xp)
		for m in msgs:
			level_notes.append(m)
		if not msgs.is_empty():
			WorldSfx.play(WorldSfx.LEVEL_UP)
	var before := GameState.arena_tokens
	GameState.add_arena_tokens(tokens)
	earned_tokens += GameState.arena_tokens - before
	earned_xp += xp
	waves_cleared = maxi(waves_cleared, n)


func _to_results(down: bool) -> void:
	wiped = down
	_set_phase(PHASE_RESULTS)


func _set_phase(next: String) -> void:
	if phase == next:
		return
	phase = next
	phase_changed.emit(phase)
