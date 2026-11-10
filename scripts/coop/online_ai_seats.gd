class_name OnlineAiSeats
extends RefCounted
## Haak voor M6 (AI-stoelen, PR #421). Deze lobby kopieert die code niet.
##
## M6 zet `filler` op een Callable. Ingang: de menselijke stoelen (Array).
## Uitgang: Array van Dictionary. Een rij heeft `class` (warrior/mage/priest/
## psytech/archer) en mag `seat`, `name` en `look` meesturen.
## `controller` wordt hier altijd "ai". De hal tekent het rol-icoon;
## lopen en gevecht blijven van M6.

const Profile := preload("res://scripts/online/online_profile.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")

static var filler: Callable = Callable()


static func clear() -> void:
	filler = Callable()


static func fill(human_seats: Array) -> Array:
	if not filler.is_valid():
		return []
	var raw: Variant = filler.call(human_seats)
	if not (raw is Array):
		return []
	var out: Array = []
	for item in raw:
		if not (item is Dictionary):
			continue
		var row: Dictionary = (item as Dictionary).duplicate(true)
		var class_id := str(row.get("class", row.get("class_id", "")))
		if Profile.role_for(class_id) == "":
			continue
		row["class"] = class_id
		row["controller"] = Protocol.CTRL_AI
		row["wire_controller"] = Protocol.CTRL_AI
		out.append(row)
	return out
