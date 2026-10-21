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
## Naambordje boven het hoofd (Forge: zichtbaar wie Kael en Orion zijn).
var naam_label: Label


func _ready() -> void:
	super._ready()
	_maak_naam()
	_ververs()


func _maak_naam() -> void:
	naam_label = Label.new()
	naam_label.name = "Naam"
	naam_label.add_to_group("hub_naambord")
	naam_label.text = npc_name
	naam_label.add_theme_font_override("font", preload("res://world_warper/wander/wanderers.gd").FONT)
	naam_label.add_theme_font_size_override("font_size", 10)      # zelfde pixelfont als de rondlopers
	naam_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	naam_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	naam_label.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	naam_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	naam_label.add_theme_constant_override("outline_size", 2)
	naam_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	naam_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Breedte = tekst + 6 px ("Kael Voss" ~73, "Orion" ~40); Kael (x 200) en Orion (x 288) staan 88 px uit
	# elkaar, dus geen overlap, en Orions bordje blijft links van de RUN-knop (21 okt 2026).
	var f: Font = naam_label.get_theme_font("font")
	var bw := ceilf(f.get_string_size(npc_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x) + 6.0 if f else 80.0
	naam_label.size = Vector2(bw, 10)
	naam_label.position = Vector2(-bw / 2.0, -42)
	naam_label.z_index = 5
	add_child(naam_label)


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
