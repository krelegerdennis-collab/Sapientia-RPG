extends RefCounted
class_name PvpTeams
## Drie vaste teams. Nog niet definitief.
## TODO(design): teams herzien zodra er meer main characters zijn.
## Dubbele helden zijn aparte vechters (id-suffix), geen gedeelde tas.


const TEAMS := {
	"team_klassiek": {
		"name": "De Klassieke Drie",
		"blurb": "Gebalanceerd.",
		"members": ["dennis", "noor", "lotte"],
	},
	"team_aanval": {
		"name": "De Aanvalsdriehoek",
		"blurb": "Hoog risico, hoge schade.",
		"members": ["dennis", "dennis", "lotte"],
	},
	"team_verdediging": {
		"name": "De Verdedigingslinie",
		"blurb": "Traag, dubbele genezing.",
		"members": ["lotte", "lotte", "dennis"],
	},
}

const ORDER: Array[String] = ["team_klassiek", "team_aanval", "team_verdediging"]


static func has_team(id: String) -> bool:
	return TEAMS.has(id)


static func members(id: String) -> Array:
	return (TEAMS[id]["members"] as Array).duplicate()


static func display_name(id: String) -> String:
	return str(TEAMS[id]["name"])


static func blurb(id: String) -> String:
	return str(TEAMS[id]["blurb"])


static func member_line(id: String) -> String:
	var names: PackedStringArray = PackedStringArray()
	for raw in members(id):
		var cid := str(raw)
		if PvpCharacters.has_character(cid):
			names.append(str(PvpCharacters.HEROES[cid]["name"]))
		else:
			names.append(cid)
	return ", ".join(names)
