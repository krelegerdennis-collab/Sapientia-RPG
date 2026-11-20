extends RefCounted
## Post-RC item-iconen: uitrusting buiten GameData (grade_gear.gd, arena_shop_data.gd) krijgt een eigen
## icoon via scripts/data/item_icon_overrides.gd. Controleert: elke gekoppelde id bestaat in de itemdata,
## wijst naar icons16/<naam>.png en icons32/<naam>.png, laadt op 16x16 en 32x32; ook de zes *_benen
## hebben een eigen icoon (bestandsnaam = id). Registratie: scripts/tests/f6_ux2_tests.gd (map-scan).

const ItemIcons := preload("res://scripts/data/item_icons.gd")
const Overrides := preload("res://scripts/data/item_icon_overrides.gd")
const GradeGear := preload("res://scripts/data/grade_gear.gd")
const ArenaGear := preload("res://scripts/data/arena_shop_data.gd")


func needs_game() -> bool:
	return true


func run(t: Node) -> void:
	var geen_data: Array = []
	var fout: Array = []
	for oid in Overrides.ICONS:
		var id := str(oid)
		var naam := str(Overrides.ICONS[oid])
		if not (GradeGear.has_item(id) or ArenaGear.has_gear(id)):
			geen_data.append(id)
		var p16 := ItemIcons.path16(id)
		var p32 := ItemIcons.path32(id)
		var ok := ItemIcons.has_mapping(id) \
				and p16 == ItemIcons.ROOT + "icons16/%s.png" % naam and ResourceLoader.exists(p16) \
				and p32 == ItemIcons.ROOT + "icons32/%s.png" % naam and ResourceLoader.exists(p32) \
				and ItemIcons.is_px(ItemIcons.icon_for(id, 16), 16) \
				and ItemIcons.is_px(ItemIcons.icon_for(id, 32), 32)
		if not ok:
			fout.append("%s (%s / %s)" % [id, p16, p32])
	t.check("item-iconen: %d gekoppelde ids bestaan in grade_gear/arena-data %s" % [Overrides.ICONS.size(), geen_data],
			Overrides.ICONS.size() == 39 and geen_data.is_empty())
	t.check("item-iconen: elke koppeling laadt 16x16 en 32x32 uit icons16/icons32 %s" % [fout], fout.is_empty())

	# alle grade-gear-uitrusting is gedekt: gekoppeld of bewust categorie-icoon
	var open: Array = []
	for id in GradeGear.ITEMS:
		if not Overrides.ICONS.has(id):
			open.append(id)
	for id in ArenaGear.GEAR:
		if not Overrides.ICONS.has(id):
			open.append(id)
	t.check("item-iconen: alle grade-gear en arena-uitrusting gekoppeld %s" % [open], open.is_empty())

	# *_benen: eigen icoon, bestandsnaam = id, niet meer het categorie-icoon
	var benen_fout: Array = []
	for id in ["bg_g1_benen", "bg_g2_benen", "bg_g3_benen", "bg_g4_plated_benen", "bg_g4_robes_benen",
			"bg_g4_natuur_benen"]:
		var p16 := ItemIcons.path16(id)
		var p32 := ItemIcons.path32(id)
		if not GradeGear.has_item(id) or p16 != ItemIcons.ROOT + "icons16/%s.png" % id \
				or p32 != ItemIcons.ROOT + "icons32/%s.png" % id or p16 == ItemIcons.CAT_HARNAS \
				or not ItemIcons.is_px(ItemIcons.icon_for(id, 16), 16) \
				or not ItemIcons.is_px(ItemIcons.icon_for(id, 32), 32):
			benen_fout.append("%s (%s)" % [id, p16])
	t.check("item-iconen: 6 *_benen tonen hun eigen icoon 16/32 %s" % [benen_fout], benen_fout.is_empty())

	# MAPPING.csv wint: een id uit de csv krijgt nooit een override-pad
	t.check("item-iconen: csv-id blijft csv (drankje)", ItemIcons.path16("drankje").ends_with("icons16/drankje.png"))

	# knop in een lijst krijgt het nieuwe 16px-icoon
	var b := Button.new()
	ItemIcons.apply16(b, "bg_g1_zwaard")
	t.check("item-iconen: lijstknop bg_g1_zwaard toont sword_bronze 16px", b.icon != null
			and b.icon.resource_path.ends_with("icons16/sword_bronze.png") and ItemIcons.is_px(b.icon, 16))
	b.free()
