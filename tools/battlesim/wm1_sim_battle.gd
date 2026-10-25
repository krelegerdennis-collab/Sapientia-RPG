extends "res://tools/battlesim/sim_battle.gd"
## WM1-balansmeting (tools/battlesim/wm1_balans.gd). Zelfde gevechtssimulator als sim_battle.gd,
## alleen met extra tellers: echte schade aan de party (en aan de vijand) en de EXP/goud-buit bij
## winst. GEEN gameplay: elke override roept eerst/ook de originele functie aan.
##
## De tellers staan in Engine-meta "wm1_extra" (de wrapper in wm1_balans.gd zet ze per gevecht terug),
## omdat de gevechtsscène na afloop al is opgeruimd voordat de wrapper de uitkomst leest.

const META := "wm1_extra"


static func nieuwe_tellers() -> Dictionary:
	return {"dmg_taken": 0, "dmg_dealt": 0, "exp": 0, "gold": 0}


func _tellers() -> Dictionary:
	if not Engine.has_meta(META):
		Engine.set_meta(META, nieuwe_tellers())
	return Engine.get_meta(META)


## Directe schade (aanval, vaardigheid, spreuk). DoT-ticks lopen niet via _hit en tellen dus niet mee.
func _hit(t: Dictionary, amount: int) -> void:
	var voor := int(t["s"]["hp"])
	super._hit(t, amount)
	var echt := maxi(0, voor - int(t["s"]["hp"]))
	var tel := _tellers()
	if bool(t.get("is_hero", false)):
		tel["dmg_taken"] = int(tel["dmg_taken"]) + echt
	else:
		tel["dmg_dealt"] = int(tel["dmg_dealt"]) + echt


## Zelfde som als battle.gd _victory: alle vijanden die niet gevangen zijn geven EXP en goud.
func _victory() -> void:
	var tel := _tellers()
	for e in enemies:
		if e.get("captured", false):
			continue
		tel["exp"] = int(tel["exp"]) + int(e["s"]["exp"])
		tel["gold"] = int(tel["gold"]) + int(e["s"]["gold"])
	super._victory()
