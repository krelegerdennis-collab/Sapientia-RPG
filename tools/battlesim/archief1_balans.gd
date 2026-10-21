extends "res://tools/battlesim/action_sim.gd"
## Meting Archief 1 (archief_v1..v4) in Action: volle slagen per gewone vijand voor een verse Dax (alleen
## Dax, beginuitrusting van een nieuw spel) op level 1-5, en HP die Dax per kamer verliest (fight_room van
## action_sim, zelfde speler-model). Draait twee keer: "voor" (factoren 1.0) en "na" (SomData.ACTION_AREAS).
##   xvfb-run -a godot --rendering-driver opengl3 --path . -- --archief1balans [--fights=N] [--out=pad.md]

const AREA := "archief1"
const LEVELS := [1, 2, 3, 4, 5]
const SWINGS := 2000


func _ready() -> void:
	standalone = false
	fights = 150
	out_path = "res://BALANS_ARCHIEF1_meting.md"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fights="):
			fights = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--out="):
			out_path = arg.get_slice("=", 1)
	if OS.get_cmdline_user_args().has("--tune"):
		_tune.call_deferred()
	else:
		_meet.call_deferred()


## Rooster per tier: atk x cooldown -> winst/verlies per kamer op het verwachte level. Alleen ter afstemming.
func _tune() -> void:
	var a: Dictionary = SomData.ACTION_AREAS[AREA]
	var basis := kamers(false)
	for tier in [1, 2, 3, 4]:
		var lv := int(a["tier_level"].get(tier, 1))
		var h := dax(lv)
		var atks: Array = [0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3]
		var cds: Array = [1.0, 1.3, 1.6, 2.0, 2.4, 2.8, 3.2]
		if OS.get_cmdline_user_args().has("--fijn"):
			atks = []
			cds = []
			for i in 17:
				atks.append(0.5 + 0.05 * i)
			for i in 16:
				cds.append(1.0 + 0.2 * i)
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--tiers="):
				if not (str(tier) in arg.get_slice("=", 1).split(",")):
					atks = []
		for atk_f in atks:
			for cd_f in cds:
				var regel := "TUNE t%d atk %.2f cd %.1f:" % [tier, atk_f, cd_f]
				var ws := []
				for r in basis:
					if int(r["tier"]) != tier:
						continue
					var en: Array = []
					for d in r["enemies"]:
						en.append(SomData.apply_action_area(d, str(r["id"]), tier))
					var o := kamer(h, en, cd_f, params_base()["dodge_player"], str(r["id"]), lv, atk_f)
					regel += " %s %d%%/%d%%" % [str(r["id"]).trim_prefix("archief_"), roundi(o["win"] * 100.0), roundi(o["loss"] * 100.0)]
					ws.append(o["win"])
				print(regel + " | gem %d%%" % roundi(_mean(ws) * 100.0))
	get_tree().quit(0)


## Gewone vijanden per kamer (zoals action_sim.setup), zonder of met de gebiedsfactoren.
static func kamers(met_gebied: bool) -> Array:
	var uit: Array = []
	for rid in DungeonRooms.ROOMS:
		if SomData.action_area(str(rid)) != AREA:
			continue
		var r: Dictionary = DungeonRooms.room(rid)
		var tier := int(r.get("tier", 0))
		var list: Array = []
		for m in r.get("monsters", []):
			if m.get("boss", false):
				continue
			var d: Dictionary = (GameData.ENEMIES.get(str(m["enemy"]), {}) as Dictionary).duplicate(true)
			if d.is_empty() or d.get("unique", false):
				continue
			if tier > 0:
				d = GameData.apply_archief_tier(d, tier)
			if met_gebied:
				d = SomData.apply_action_area(d, str(rid), tier)
			d["id"] = str(m["enemy"])
			list.append(d)
		if not list.is_empty():
			uit.append({"id": str(rid), "tier": tier, "enemies": list})
	return uit


## Verse Dax op level L (nieuw spel: alleen Dax, beginuitrusting).
static func dax(level: int) -> Dictionary:
	GameState.new_game(GameState.DEFAULT_NAME)
	var h: Dictionary = GameState.party[0]
	GameState.give_exp(h, GameData.exp_for_level(level) - int(h["exp"]))
	h["hp"] = h["max_hp"]
	return h


## Gemiddeld aantal volle slagen tot de vijand op 0 HP staat (echte formule incl. 0.85-1.15 spreiding).
static func slagen(atk: float, d: Dictionary) -> float:
	var tot := 0
	for i in SWINGS:
		var hp := int(d["max_hp"])
		var n := 0
		while hp > 0:
			hp -= SomArena.physical_damage(atk, float(d.get("def", 0)), 1.0)
			n += 1
		tot += n
	return float(tot) / float(SWINGS)


## Dax (h) solo tegen deze kamer, 'fights' keer, vol HP: {"win": fractie, "loss": gemiddeld verlies als fractie}.
func kamer(h: Dictionary, enemies: Array, cd_factor: float, dodge: float, rid: String, lv: int, dmg_factor := 1.0) -> Dictionary:
	party_base = [h.duplicate(true)]
	var p := params_base()
	p["enemy_cd"] = float(p["enemy_cd"]) * cd_factor
	p["enemy_dmg"] = float(p["enemy_dmg"]) * dmg_factor
	p["dodge_player"] = dodge
	var l := 0.0
	var wins := 0
	for i in fights:
		seed(hash([base_seed, rid, i, lv, dodge]))
		var o := fight_room(enemies, p)
		l += float(o["loss"])
		wins += 1 if o["win"] else 0
	return {"win": float(wins) / float(fights), "loss": l / float(fights)}


## Elke kamer op het verwachte level (tier_level), met de huidige data: [{id, tier, lv, win, loss}].
func verwacht() -> Array:
	var a: Dictionary = SomData.ACTION_AREAS[AREA]
	var uit: Array = []
	for r in kamers(true):
		var lv := int(a["tier_level"].get(int(r["tier"]), 1))
		var h := dax(lv)
		var o := kamer(h, r["enemies"], SomData.area_rule(str(r["id"]), int(r["tier"]), "cooldown"), params_base()["dodge_player"], str(r["id"]), lv,
				SomData.area_rule(str(r["id"]), int(r["tier"]), "atk"))
		uit.append({"id": r["id"], "tier": int(r["tier"]), "lv": lv, "win": o["win"], "loss": o["loss"]})
	return uit


## {level: {"hits": {enemy_id: x}, "min":, "max":, "loss": {room: hp}}}
func meet(met_gebied: bool) -> Dictionary:
	seed(base_seed)
	var ks := kamers(met_gebied)
	var uit := {}
	for lv in LEVELS:
		var h := dax(lv)
		var atk := float(GameState.effective_stat(h, "atk"))
		var hits := {}
		for r in ks:
			for d in r["enemies"]:
				if not hits.has(d["id"] + "@" + str(r["tier"])):
					hits[d["id"] + "@" + str(r["tier"])] = slagen(atk, d)
		var vals: Array = hits.values()
		var loss := {}
		for r in ks:
			var cdf := SomData.area_rule(str(r["id"]), int(r["tier"]), "cooldown") if met_gebied else 1.0
			var dmf := SomData.area_rule(str(r["id"]), int(r["tier"]), "atk") if met_gebied else 1.0
			var o := kamer(h, r["enemies"], cdf, params_base()["dodge_player"], str(r["id"]), lv, dmf)
			var o2 := kamer(h, r["enemies"], cdf, float(SomData.ACTION_AREAS[AREA].get("dodge_skill", 0.6)), str(r["id"]), lv, dmf)
			loss[r["id"]] = {"hp": o["loss"] * float(h["max_hp"]), "win": o["win"], "frac": o["loss"],
					"hp2": o2["loss"] * float(h["max_hp"]), "win2": o2["win"]}
		uit[lv] = {"hits": hits, "min": vals.min(), "max": vals.max(), "mean": _mean(vals), "loss": loss,
				"max_hp": int(h["max_hp"]), "atk": atk, "def": float(GameState.effective_stat(h, "def"))}
	return uit


func _meet() -> void:
	var voor_f: Dictionary = SomData.ACTION_AREAS[AREA]
	var voor := meet(false)
	var na := meet(true)
	var md := tabel(voor, na, voor_f)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(md)
		f.close()
	print(md)
	print("ARCHIEF1BALANS report: ", out_path)
	get_tree().quit(0)


## Verwacht Dax-level voor "vijand@tier" (SomData.ACTION_AREAS tier_level).
static func ref_level(key: String) -> int:
	var tl: Dictionary = SomData.ACTION_AREAS[AREA]["tier_level"]
	return int(tl.get(int(key.get_slice("@", 1)), 1))


func tabel(voor: Dictionary, na: Dictionary, a: Dictionary) -> String:
	var s := "## Archief 1 (Action) - meting, %d gevechten per kamer per level\n\n" % fights
	s += "Regels nu (SomData.ACTION_AREAS.archief1): HP geklemd op %s x volle slag van verse Dax op tier-level %s; per tier schade (atk) / cooldown: %s.\n\n" % [str(a["hp_hits"]), str(a["tier_level"]), str(a["tiers"])]
	s += "### Volle slagen per gewone vijand (gemiddeld; min-max over de vijanden)\n\n| Dax lv | Dax HP/ATK/DEF | voor | na |\n|---|---|---|---|\n"
	for lv in LEVELS:
		s += "| %d | %d / %d / %d | %.2f (%.2f-%.2f) | %.2f (%.2f-%.2f) |\n" % [lv, na[lv]["max_hp"], na[lv]["atk"], na[lv]["def"],
				voor[lv]["mean"], voor[lv]["min"], voor[lv]["max"], na[lv]["mean"], na[lv]["min"], na[lv]["max"]]
	s += "\n### Per vijand: volle slagen bij Dax lv 1 en op het verwachte level van de tier\n\n| vijand@tier | lv1 voor | lv1 na | verwacht lv | voor | na |\n|---|---|---|---|---|---|\n"
	for k in na[1]["hits"]:
		var lv := ref_level(k)
		s += "| %s | %.2f | %.2f | %d | %.2f | %.2f |\n" % [k, voor[1]["hits"][k], na[1]["hits"][k], lv, voor[lv]["hits"][k], na[lv]["hits"][k]]
	s += "\n### HP die Dax (alleen, vol HP per kamer) per kamer verliest: gemiddeld (winst%)\n\nontwijkt = kans dat de speler een getelegrafeerde klap ontwijkt (sim-model action_sim: 35%; geoefend: dodge_skill).\n\n| kamer | lv | voor (35%) | na (35%) | voor (geoefend) | na (geoefend) |\n|---|---|---|---|---|---|\n"
	for r in na[1]["loss"]:
		for lv in LEVELS:
			var v: Dictionary = voor[lv]["loss"][r]
			var n: Dictionary = na[lv]["loss"][r]
			s += "| %s | %d | %.1f (%d%%) | %.1f (%d%%) | %.1f (%d%%) | %.1f (%d%%) |\n" % [r, lv, v["hp"], roundi(v["win"] * 100.0),
					n["hp"], roundi(n["win"] * 100.0), v["hp2"], roundi(v["win2"] * 100.0), n["hp2"], roundi(n["win2"] * 100.0)]
	s += "\n### Doel per tier (Dax solo op het verwachte level, 35% ontwijken)\n\n| tier | Dax lv | kamers (winst/verlies) | gem. winst | doel winst | gem. verlies | doel verlies |\n|---|---|---|---|---|---|---|\n"
	var per := {}
	for r in verwacht():
		var t := int(r["tier"])
		if not per.has(t):
			per[t] = {"w": [], "l": [], "ids": [], "lv": r["lv"]}
		per[t]["w"].append(r["win"])
		per[t]["l"].append(r["loss"])
		per[t]["ids"].append("%s %d%%/%d%%" % [str(r["id"]).trim_prefix("archief_"), roundi(r["win"] * 100.0), roundi(r["loss"] * 100.0)])
	for t in [1, 2, 3, 4]:
		var d: Dictionary = per[t]
		var doel: Dictionary = a["targets"][t]
		s += "| %d | %d | %s | %d%% | %d-%d%% | %d%% | %s |\n" % [t, d["lv"], ", ".join(d["ids"]), roundi(_mean(d["w"]) * 100.0),
				roundi(doel["win"][0] * 100.0), roundi(doel["win"][1] * 100.0), roundi(_mean(d["l"]) * 100.0),
				("%d-%d%%" % [roundi(doel["loss"][0] * 100.0), roundi(doel["loss"][1] * 100.0)]) if doel.has("loss") else "-"]
	return s
