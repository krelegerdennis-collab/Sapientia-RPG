class_name PartyBench
extends RefCounted
## Bank van de Rustkamer. Maximaal 4 actieve helden (v0.22 partylimiet, scripts/party_limiet.gd).
## Wisselen is gratis en alleen hier. Dennis en tijdelijke Codex-gasten
## gaan niet op de bank. De molen houdt zijn eigen "zet vooraan".

const MAX_ACTIEF := preload("res://scripts/party_limiet.gd").MAX_HELDEN
const RUSTKAMER := "res://world_warper/kamers/rustkamer.tscn"

const DENNIS_BLIJFT := "Dennis stays in the party."
const GAST_BLIJFT := "Temporary guests can't go on the bench."
const VOL := "The party is full."
const ALLEEN_HIER := "You can only switch in the Rest Room."
const OP_BANK := "%s is on the bench."
const IN_GROEP := "%s is in the party."


static func in_rustkamer(pad: String) -> bool:
	return pad == RUSTKAMER or pad.ends_with("/rustkamer.tscn")


static func is_dennis(held: Dictionary) -> bool:
	return str(held.get("id", "")) == GameState.MAIN_HERO


static func is_codex_gast(held: Dictionary) -> bool:
	if bool(held.get("tijdelijk", false)) or bool(held.get("codex", false)):
		return true
	if str(held.get("species", "")) != "":
		return true
	if str(held.get("uid", "")) != "":
		return true
	return false


static func mag_naar_bank(held: Dictionary) -> bool:
	if held.is_empty() or is_dennis(held) or is_codex_gast(held):
		return false
	return GameState.hero_exists(str(held.get("id", "")))


## Teveel actieve helden (niet Dennis, niet een gast) gaan op de bank.
static func normaliseer() -> void:
	var i := GameState.party.size() - 1
	while GameState.party.size() > MAX_ACTIEF and i >= 0:
		var held: Dictionary = GameState.party[i]
		if mag_naar_bank(held):
			GameState.party.remove_at(i)
			GameState.party_bench.append(held)
		i -= 1


static func naar_bank(index: int, pad: String) -> String:
	if not in_rustkamer(pad):
		return ALLEEN_HIER
	if index < 0 or index >= GameState.party.size():
		return ""
	var held: Dictionary = GameState.party[index]
	if is_dennis(held):
		return DENNIS_BLIJFT
	if not mag_naar_bank(held):
		return GAST_BLIJFT
	GameState.party.remove_at(index)
	GameState.party_bench.append(held)
	return OP_BANK % str(held.get("name", ""))


static func naar_groep(index: int, pad: String) -> String:
	if not in_rustkamer(pad):
		return ALLEEN_HIER
	if index < 0 or index >= GameState.party_bench.size():
		return ""
	if GameState.party.size() >= MAX_ACTIEF:
		return VOL
	var held: Dictionary = GameState.party_bench[index]
	if is_codex_gast(held):
		return GAST_BLIJFT
	GameState.party_bench.remove_at(index)
	GameState.party.append(held)
	return IN_GROEP % str(held.get("name", ""))
