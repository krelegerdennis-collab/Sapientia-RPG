extends "res://scripts/npc.gd"
## Rekruut in de World Warper-hal (Kael Voss, Orion). Praten: "Join the party?". Ja -> sluit zich aan
## (GameState.join_member op het gemiddelde partylevel), de NPC verdwijnt; dat zit in de save omdat de
## held dan in party/party_bank staat. Groep vol (PartyLimiet.MAX_HELDEN) -> duidelijke melding, blijft staan.

const PartyLimiet := preload("res://scripts/party_limiet.gd")
const VRAAG := "Join the party?"
const JA := "Yes"
const NEE := "No"
const VOL := "Your party is full (4 heroes). Make room via Menu > Party first."
const WELKOM := "%s joins the party!"
const LATER := "I'll be here if you change your mind."

@export var hero_id := ""
## Voor de tests: "joined", "nee", "vol", "".
var uitkomst := ""


func _ready() -> void:
	super._ready()
	_ververs()


func story_refresh() -> void:
	super.story_refresh()
	_ververs()


func _ververs() -> void:
	var weg := hero_id == "" or not GameState.member(hero_id).is_empty()
	set_story_visible(not weg)


func interact(player: Node2D) -> void:
	if not visible:
		return
	if "facing" in player:
		facing = -player.facing
		_update_sprite()
	await vraag()


## Het hele gesprek (ook los aan te roepen vanuit tests).
func vraag() -> String:
	var keuze: int = await Dialog.ask(VRAAG, [JA, NEE], npc_name)
	if keuze != 0:
		uitkomst = "nee"
		Dialog.show_lines([LATER], npc_name, self)
		return uitkomst
	uitkomst = sluit_aan()
	if uitkomst == "vol":
		Dialog.show_lines([VOL], npc_name, self)
	else:
		Dialog.show_lines([WELKOM % npc_name], npc_name, self)
	return uitkomst


## Zonder dialoog: "joined" of "vol" (of "" als het niet kan).
func sluit_aan() -> String:
	if not GameState.member(hero_id).is_empty():
		return ""
	if GameState.party.size() >= PartyLimiet.MAX_HELDEN:
		return "vol"
	if not GameState.join_member(hero_id, gemiddeld_level()):
		return ""
	_ververs()
	return "joined"


static func gemiddeld_level() -> int:
	var s := 0
	for h in GameState.party:
		s += int(h.get("level", 1))
	return maxi(1, roundi(float(s) / float(maxi(1, GameState.party.size()))))
