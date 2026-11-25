extends RefCounted
## Buffs, HoT, spreuk-status en ailments-tick (uit battle.gd gehaald, gedrag ongewijzigd).
## battle.gd roept dit aan via dunne wrappers met de oude namen (sim en tests roepen die).

const SpellRules := preload("res://scripts/data/spell_rules.gd")
const Archief2Vijanden := preload("res://scripts/data/archief2_vijanden.gd")

var battle: Control


func _init(b: Control) -> void:
	battle = b


func apply_buffs(ally: Dictionary, spell: Dictionary, caster: Dictionary) -> void:
	var rows: Array = spell.get("buffs", [])
	if rows.is_empty() and str(spell.get("buff_stat", "")) != "":
		var key := "buff_" + str(spell.get("buff_stat", "def"))
		ally[key] = int(ally.get(key, 0)) + int(spell.get("buff_n", 1))
	if not ally.has("buffs"):
		ally["buffs"] = []
	var mult := SpellRules.buff_factor(spell, str(caster["s"].get("id", "")))
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		Archief2Vijanden.refresh_row(ally["buffs"], {
			"stat": str(row.get("stat", "def")),
			"pct": float(row.get("pct", 0.0)) * mult,
			"turns": int(row.get("turns", 3)),
		}, "stat")
	battle.show_message("%s is strengthened." % ally["name"])


func add_hot(ally: Dictionary, spell: Dictionary, caster: Dictionary) -> void:
	if not ally.has("hots"):
		ally["hots"] = []
	var turns := int(spell.get("hot_turns", 3))
	(ally["hots"] as Array).append({"amount": battle._spell_amount(caster, spell, {}), "turns": turns})
	battle.show_message("%s recovers slowly." % ally["name"])


func apply_spell_status(target: Dictionary, spell: Dictionary) -> void:
	if int(target["s"]["hp"]) <= 0:
		return
	var fx := SpellRules.on_hit(spell)
	if float(fx.get("dot_pct", 0.0)) > 0.0:
		if not target.has("dots"):
			target["dots"] = []
		var pct := float(fx["dot_pct"])
		var turns := int(fx.get("dot_turns", 3))
		# Brand (de niet-gif DoT) stapelt niet: een nieuwe brand ververst de bestaande entry
		# (duur en pct naar de hoogste waarde), zodat er per doel maar een brand loopt.
		var burn: Dictionary = {}
		for d in target["dots"]:
			if typeof(d) == TYPE_DICTIONARY and not bool(d.get("gif", false)):
				burn = d
				break
		if burn.is_empty():
			(target["dots"] as Array).append({"pct": pct, "turns": turns})
		else:
			burn["pct"] = maxf(float(burn.get("pct", 0.0)), pct)
			burn["turns"] = maxi(int(burn.get("turns", 0)), turns)
	# Verlamming/bevriezing: kans uit SpellRules (enkel/AoE, baas-halve kans), anti stun-lock.
	# roll altijd trekken (ook bij immune/skip) zodat de gevechts-randf()-reeks gelijk blijft.
	if int(fx.get("skip", 0)) > 0:
		var roll := randf()
		if not SpellRules.target_blocks_stun(target) and SpellRules.stun_lands(fx, spell, battle.is_boss_target(target), roll, battle.stun_boss_immune, battle.stun_chance):
			target["skip"] = maxi(int(target.get("skip", 0)), int(fx["skip"]))
			target["skip_reden"] = str(fx.get("skip_reden", "bevriezing"))
			target["stun_immune"] = true


func tick_ailments(c: Dictionary) -> void:
	var dots: Array = c.get("dots", [])
	var left_dots: Array = []
	if int(c["s"]["hp"]) > 0:
		for d in dots:
			if typeof(d) != TYPE_DICTIONARY:
				continue
			var pct := float(d.get("pct", 0.0))
			var dmg := maxi(1, roundi(float(c["s"]["max_hp"]) * pct))
			c["s"]["hp"] = maxi(0, int(c["s"]["hp"]) - dmg)
			d["turns"] = int(d.get("turns", 1)) - 1
			if int(d["turns"]) > 0 and int(c["s"]["hp"]) > 0:
				left_dots.append(d)
	c["dots"] = left_dots
	var hots: Array = c.get("hots", [])
	var left_hots: Array = []
	for h in hots:
		if typeof(h) != TYPE_DICTIONARY:
			continue
		if int(c["s"]["hp"]) > 0:
			var room := int(c["s"]["max_hp"]) - int(c["s"]["hp"])
			c["s"]["hp"] += mini(int(h.get("amount", 0)), maxi(0, room))
		h["turns"] = int(h.get("turns", 1)) - 1
		if int(h["turns"]) > 0:
			left_hots.append(h)
	c["hots"] = left_hots
	var buffs: Array = c.get("buffs", [])
	var left_buffs: Array = []
	for b in buffs:
		if typeof(b) != TYPE_DICTIONARY:
			continue
		b["turns"] = int(b.get("turns", 1)) - 1
		if int(b["turns"]) > 0:
			left_buffs.append(b)
	c["buffs"] = left_buffs
	if int(c["s"]["hp"]) <= 0 and bool(c.get("is_hero", false)) and c.get("node") != null:
		c["node"].set_ko(true)