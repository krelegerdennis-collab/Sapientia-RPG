extends RefCounted
class_name PvpModes
## Drie modi. Alleen de host kiest.
## TODO(design): level 8 is een placeholder binnen de band 5-10.
## TODO(design): de lengte in minuten is een richtlijn, nog geen klok.


const MODES := {
	"early": {
		"name": "Vroeg", "level": 8, "band_min": 5, "band_max": 10, "pace": "kort",
	},
	"mid": {
		"name": "Midden", "level": 18, "band_min": 15, "band_max": 20, "pace": "middel",
	},
	"high": {
		"name": "Hoog", "level": 25, "band_min": 20, "band_max": -1, "pace": "lang",
	},
}

const ORDER: Array[String] = ["early", "mid", "high"]


static func has_mode(id: String) -> bool:
	return MODES.has(id)


static func level_of(id: String) -> int:
	return int(MODES[id]["level"])


static func band_min(id: String) -> int:
	return int(MODES[id]["band_min"])


static func band_max(id: String) -> int:
	return int(MODES[id]["band_max"])


static func display_name(id: String) -> String:
	return str(MODES[id]["name"])


static func in_band(id: String) -> bool:
	var level := level_of(id)
	if level < band_min(id):
		return false
	var top := band_max(id)
	if top < 0:
		return true
	return level <= top
