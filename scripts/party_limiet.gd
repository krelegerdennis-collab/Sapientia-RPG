extends RefCounted
## v0.22 Partylimiet (spec RPG Forge, akkoord Dennis): in een gevecht vechten maximaal
## MAX_HELDEN helden + MAX_MONSTERS monster (de actieve Codex-bondgenoot) mee. De rest staat in
## de RESERVE: helden in GameState.party_bench (save-sleutel "party_bank"), monsters zijn de
## niet-actieve Codex-pagina's. Wisselen kan alleen BUITEN een gevecht (veldmenu > Party,
## scripts/ui/party_screen.gd; de Rustkamer blijft ook werken, scripts/party_bench.gd).
## Alleen logica, geen UI, zodat het scherm, het gevecht en de partytest dezelfde regels delen.
## (preload i.p.v. class_name, zoals party_actions.gd)

const MAX_HELDEN := 4
const MAX_MONSTERS := 1
const MAX_GEVECHT := MAX_HELDEN + MAX_MONSTERS

const IN_GEVECHT := "You can't switch party members during battle."
const DENNIS_BLIJFT := "Dax stays in the party."
const GAST_BLIJFT := "Temporary guests can't go to the reserve."
const VOL := "The party is full (4 heroes)."
const NAAR_RESERVE := "%s goes to the reserve."
const IN_GROEP := "%s joins the party."
const GEWISSELD := "%s swaps with %s."
const MONSTER_ACTIEF := "%s will fight with you."
const MONSTER_KO := "%s can't fight right now."
const GEEN_MONSTER := "No monster fights with you."


## Wisselen mag alleen buiten een gevecht.
static func mag_wisselen() -> bool:
	return not GameState.in_battle


static func is_dennis(held: Dictionary) -> bool:
	return str(held.get("id", "")) == GameState.MAIN_HERO


## Tijdelijke gasten (Codex-gast, verhaalgast) blijven waar ze zijn (zelfde regel als de Rustkamer).
static func is_gast(held: Dictionary) -> bool:
	if bool(held.get("tijdelijk", false)) or bool(held.get("codex", false)):
		return true
	return str(held.get("species", "")) != "" or str(held.get("uid", "")) != ""


static func mag_naar_reserve(held: Dictionary) -> bool:
	return not held.is_empty() and not is_dennis(held) and not is_gast(held)


## Teveel actieve helden gaan (van achteren af) naar de reserve. Ook voor oude saves:
## een save met 5+ helden in "party" wordt bij het laden hiermee rechtgezet (migratie).
## Geeft het aantal verplaatste helden terug.
static func normaliseer() -> int:
	var verplaatst := 0
	var i := GameState.party.size() - 1
	while GameState.party.size() > MAX_HELDEN and i >= 0:
		var held: Dictionary = GameState.party[i]
		if mag_naar_reserve(held):
			GameState.party.remove_at(i)
			GameState.party_bench.insert(0, held)    # volgorde van de oude party blijft bewaard
			verplaatst += 1
		i -= 1
	return verplaatst


## De helden die in een gevecht meevechten: de eerste MAX_HELDEN van 'groep'.
static func gevechts_helden(groep: Array) -> Array:
	return groep.slice(0, MAX_HELDEN)


## Actieve held 'index' naar de reserve. "" = ongeldige index.
static func naar_reserve(index: int) -> String:
	if not mag_wisselen():
		return IN_GEVECHT
	if index < 0 or index >= GameState.party.size():
		return ""
	var held: Dictionary = GameState.party[index]
	if is_dennis(held):
		return DENNIS_BLIJFT
	if not mag_naar_reserve(held):
		return GAST_BLIJFT
	GameState.party.remove_at(index)
	GameState.party_bench.append(held)
	return NAAR_RESERVE % str(held.get("name", ""))


## Reserve-held 'index' naar de actieve groep (als er plek is).
static func naar_groep(index: int) -> String:
	if not mag_wisselen():
		return IN_GEVECHT
	if index < 0 or index >= GameState.party_bench.size():
		return ""
	if GameState.party.size() >= MAX_HELDEN:
		return VOL
	var held: Dictionary = GameState.party_bench[index]
	GameState.party_bench.remove_at(index)
	GameState.party.append(held)
	return IN_GROEP % str(held.get("name", ""))


## Actieve held 'actief' en reserve-held 'reserve' ruilen van plek (werkt ook met een volle groep).
static func wissel(actief: int, reserve: int) -> String:
	if not mag_wisselen():
		return IN_GEVECHT
	if actief < 0 or actief >= GameState.party.size() or reserve < 0 or reserve >= GameState.party_bench.size():
		return ""
	var a: Dictionary = GameState.party[actief]
	if is_dennis(a):
		return DENNIS_BLIJFT
	if not mag_naar_reserve(a):
		return GAST_BLIJFT
	var r: Dictionary = GameState.party_bench[reserve]
	GameState.party[actief] = r
	GameState.party_bench[reserve] = a
	return GEWISSELD % [str(r.get("name", "")), str(a.get("name", ""))]


# ---------------------------------------------------------------- monster (Codex)
## Monsters in de reserve: alle Codex-pagina's behalve de actieve.
static func reserve_monsters() -> Array:
	return GameState.codex_pages.filter(func(p): return str(p.get("uid", "")) != GameState.codex_active)


## Kies het actieve monster (uid; "" = geen monster). Alleen buiten een gevecht.
static func kies_monster(uid: String) -> String:
	if not mag_wisselen():
		return IN_GEVECHT
	if uid == "":
		GameState.codex_set_active("")
		return GEEN_MONSTER
	var page: Dictionary = GameState.codex_page(uid)
	if page.is_empty():
		return ""
	if int(page.get("hp", 0)) <= 0:
		return MONSTER_KO % str(page.get("name", ""))
	GameState.codex_set_active(uid)
	return MONSTER_ACTIEF % str(page.get("name", ""))
