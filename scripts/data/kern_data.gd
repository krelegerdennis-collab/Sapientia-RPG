extends RefCounted
## ============================================================
##  KERNFRAGMENTEN (v0.15, RPG CODE) – stap 1 van 3 van het Kernsysteem
## ============================================================
## Na elke archiefbaas absorbeert de hoofdheld (GameState.MAIN_HERO) de kern van die baas.
## Een kernfragment geeft één GEVECHTSVAARDIGHEID (KERN_SKILLS) en één WERELDVAARDIGHEID
## (WORLD_ABILITIES). Een nieuwe baas = alleen nieuwe regels hieronder (geen code).
##
## Velden van een kernfragment:
##   id            sleutel (zelfde als de sleutel van de tabel)
##   naam          naam op het scherm ("Golemkern")
##   beschrijving  1-2 zinnen voor het menu
##   icon          16x16-icoon (RPG ART; Forge zet de echte bestanden in v15)
##   source_boss   vijand-id in GameData.ENEMIES; alleen een BAASgevecht (pending_boss) telt
##   battle_skill  id in KERN_SKILLS (of "" = geen)
##   world_ability id in WORLD_ABILITIES (of "" = geen); v0.16 (Kernkracht): ook een LIJST van ids
##                 mag (golemkern geeft er twee). Lees dit veld altijd via abilities_of().
##   kleur         accentkleur van het absorptie-effect / de gloed
## Open voor stap 2 (archiveren / temmen) en stap 3 (glitch-fusie): extra velden mogen erbij
## (bv. "archief": {...}, "fusie": [...]); deze code negeert onbekende velden. In de save
## staat per fragment een woordenboek (GameState.kernfragmenten[id] = {"bron", "stap"}), daar
## kunnen latere stappen hun eigen toestand in kwijt (niveau, getemd, gefuseerd, ...).

const KERNFRAGMENTEN := {
	"golemkern": {
		"id": "golemkern",
		"naam": "Golem Core",
		"beschrijving": "The pink heart of the Golem. Heavy and warm; it gives you the strength of stone.",
		"icon": "res://assets/ui/icons/golemkern.png",
		"source_boss": "kennis_beest",
		"battle_skill": "kernslag",
		"world_ability": ["zware_blokken", "kernvuur"],   # v0.16: + de vuurbal in het veld
		"kleur": Color(1.0, 0.36, 0.78),
	},
}

## Gevechtsvaardigheden uit kernen. Dennis heeft geen MP: een kernvaardigheid kost geen MP
## maar moet OPLADEN ("cooldown" = om de zoveel rondes te gebruiken; 3 = ronde 1, 4, 7, ...).
##   type "physical": schade = ATK x atk_mult - DEF x def_factor, +/- 15%, verdedigen = helft
##   (gewone aanval: ATK x 1 - DEF x 0,5). Een baaskern (boss_core.gd) telt gewoon mee.
##   "fx": hoe het eruitziet ("vuurbal" = paarse vuurbal uit de hand, scripts/kern/kern_vuurbal.gd).
## v0.16 KERNKRACHT (revamp van Kernslag, wens van Dennis): de id blijft "kernslag" (stabiel: tests,
## Forge's teksten en eventuele toekomstige saves verwijzen ernaar); alleen naam/beeld zijn nieuw.
const KERN_SKILLS := {
	"kernslag": {
		"name": "Core Power",
		"fx": "vuurbal",
		"type": "physical",
		"target": "enemy",
		"atk_mult": 1.5,       # 1,5x ATK
		"def_factor": 0.25,    # de kern gaat door het pantser: maar 1/4 DEF telt (gewoon 1/2)
		"cooldown": 3,         # 1x per 3 rondes (na gebruik 2 rondes opladen)
		"desc": "A purple fireball from the hand, with the Golem Core's strength: 1.5x ATK, through armor. Charges for 3 rounds.",
	},
}

## Wereldvaardigheden uit kernen (buiten gevechten).
##   zware_blokken: zware kasten in puzzelkamers duwen ({"type": "block", "heavy": true}).
const WORLD_ABILITIES := {
	"zware_blokken": {
		"name": "Push Heavy Blocks",
		"desc": "You can now push heavy cabinets loaded with runes.",
	},
	# v0.16: KERNKRACHT in het veld (scripts/kern/kern_kracht_veld.gd): knop KERN (of toets K) =
	# paarse vuurbal 3 tegels ver in de kijkrichting; een (niet-baas) map-monster staat 10 stappen stil.
	"kernvuur": {
		"name": "Core Power",
		"desc": "Press CORE: a fireball flies 3 tiles and stuns a monster for 10 steps.",
	},
}

## v0.16 max. lengte van een kernvaardigheid in het gevechtsmenu ("Kernkracht" = 10).
const SKILL_NAME_MAX := 10

## v0.16 de wereldvaardigheid van de vuurbal in het veld.
const FIELD_FIREBALL_ABILITY := "kernvuur"

## De wereldvaardigheid die een zware kast nodig heeft.
const HEAVY_BLOCK_ABILITY := "zware_blokken"


## Kernfragment dat je krijgt na het verslaan van baas 'enemy_id' ("" = geen).
static func fragment_for_boss(enemy_id: String) -> String:
	for id in KERNFRAGMENTEN:
		if str(KERNFRAGMENTEN[id].get("source_boss", "")) == enemy_id:
			return id
	return ""


static func fragment(id: String) -> Dictionary:
	return KERNFRAGMENTEN.get(id, {})


## v0.16 Wereldvaardigheden van een fragment als lijst ("world_ability" mag een id of een lijst zijn).
static func abilities_of(f: Dictionary) -> Array:
	var v = f.get("world_ability", "")
	var out: Array = []
	if v is Array:
		for a in v:
			if str(a) != "":
				out.append(str(a))
	elif str(v) != "":
		out.append(str(v))
	return out


## Controle van de tabellen. Geeft een lijst met fouten (leeg = goed).
static func validate(enemies: Dictionary) -> Array:
	var err: Array = []
	var bosses := {}
	for id in KERNFRAGMENTEN:
		var f: Dictionary = KERNFRAGMENTEN[id]
		for k in ["id", "naam", "beschrijving", "icon", "source_boss", "battle_skill", "world_ability"]:
			if not f.has(k):
				err.append("kernfragment '%s': veld '%s' ontbreekt" % [id, k])
		if str(f.get("id", "")) != id:
			err.append("kernfragment '%s': id '%s' wijkt af van de sleutel" % [id, f.get("id", "")])
		var boss := str(f.get("source_boss", ""))
		if not enemies.has(boss):
			err.append("kernfragment '%s': baas '%s' bestaat niet in ENEMIES" % [id, boss])
		elif not (enemies[boss] as Dictionary).has("boss"):
			err.append("kernfragment '%s': '%s' heeft geen baasgevecht ('boss'-blok)" % [id, boss])
		if bosses.has(boss):
			err.append("baas '%s' geeft twee kernen (%s, %s)" % [boss, bosses[boss], id])
		bosses[boss] = id
		var sk := str(f.get("battle_skill", ""))
		if sk != "" and not KERN_SKILLS.has(sk):
			err.append("kernfragment '%s': gevechtsvaardigheid '%s' bestaat niet" % [id, sk])
		for ab in abilities_of(f):
			if not WORLD_ABILITIES.has(ab):
				err.append("kernfragment '%s': wereldvaardigheid '%s' bestaat niet" % [id, ab])
		if not ResourceLoader.exists(str(f.get("icon", ""))):
			err.append("kernfragment '%s': icoon '%s' ontbreekt" % [id, f.get("icon", "")])
	for id in KERN_SKILLS:
		var s: Dictionary = KERN_SKILLS[id]
		if str(s.get("type", "")) != "physical" or str(s.get("target", "")) != "enemy":
			err.append("kernvaardigheid '%s': alleen type physical / target enemy wordt ondersteund" % id)
		if float(s.get("atk_mult", 0.0)) <= 0.0 or int(s.get("cooldown", 0)) < 1:
			err.append("kernvaardigheid '%s': atk_mult > 0 en cooldown >= 1 nodig" % id)
		if str(s.get("name", "")).length() > SKILL_NAME_MAX:
			err.append("kernvaardigheid '%s': naam te lang voor het gevechtsmenu (max %d)" % [id, SKILL_NAME_MAX])
	return err
