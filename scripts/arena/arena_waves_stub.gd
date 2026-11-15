extends Node
class_name SomArenaWaves
## STUB: replaced by RPG COMBAT's SomArenaWaves.
## Geen spawner. De flow praat alleen via start_wave en de signalen hieronder.
## party_wiped gaat alleen af als de HELE party neer is.
## Eén speler neer heeft hier geen signaal: dat blijft de bestaande revive.

signal wave_started(n: int)
signal wave_cleared(n: int)
signal party_wiped()

var active_wave := 0


func start_wave(n: int) -> void:
	active_wave = n
	wave_started.emit(n)
