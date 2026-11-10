class_name AvatarBlob
extends RefCounted
## Compacte look voor protocol v2 (ONLINE_COOP_DESIGN §5.1). Ongeveer 16 bytes.
## M1 bouwt OnlineProfile in scripts/online/; die map blijft hier onaangeroerd.
## M5 koppelt het profiel aan deze blob. Tot de paper-doll (M2) tekent de sandbox
## de bestaande held-sheet van de klasse, met een placeholder-tint uit de look.

const BYTE_COUNT := 16
const FORMAT := 1

## Optie-aantallen uit §5.3 (v1). Indexen zijn 0-based, inclusief de bovengrens.
const MAX_BODY := 0
const MAX_SKIN := 3
const MAX_HAIR := 5
const MAX_HAIR_COLOR := 7
const MAX_TOP := 3
const MAX_TOP_COLOR := 5
const MAX_BOTTOM := 2
const MAX_BOTTOM_COLOR := 5
## 0 = geen hoofddeksel, 1 en 2 = de twee opties.
const MAX_HEAD := 2

const CLASS_IDS: Array[String] = ["warrior", "mage", "priest", "psytech", "archer"]
## Brug naar de bestaande Action-sheets. Geen tweede statsysteem (HEROES blijft onaangeroerd).
const BASE_HERO := {
	"warrior": "dennis",
	"mage": "noor",
	"priest": "lotte",
	"psytech": "kael",
	"archer": "orion",
}


static func known_class(class_id: String) -> bool:
	return CLASS_IDS.has(class_id)


static func base_hero(class_id: String) -> String:
	return str(BASE_HERO.get(class_id, ""))


## Leeg bij een ongeldige look. class is een klasse-id, geen vrije tekst.
static func encode(look: Dictionary) -> PackedByteArray:
	var class_id := str(look.get("class", ""))
	var class_idx := CLASS_IDS.find(class_id)
	if class_idx < 0:
		return PackedByteArray()
	var body := int(look.get("body", -1))
	var skin := int(look.get("skin", -1))
	var hair := int(look.get("hair", -1))
	var hair_color := int(look.get("hair_color", -1))
	var top := int(look.get("top", -1))
	var top_color := int(look.get("top_color", -1))
	var bottom := int(look.get("bottom", -1))
	var bottom_color := int(look.get("bottom_color", -1))
	var head := int(look.get("head", -1))
	if not _in(body, MAX_BODY) or not _in(skin, MAX_SKIN) or not _in(hair, MAX_HAIR):
		return PackedByteArray()
	if not _in(hair_color, MAX_HAIR_COLOR) or not _in(top, MAX_TOP) or not _in(top_color, MAX_TOP_COLOR):
		return PackedByteArray()
	if not _in(bottom, MAX_BOTTOM) or not _in(bottom_color, MAX_BOTTOM_COLOR) or not _in(head, MAX_HEAD):
		return PackedByteArray()
	var buf := PackedByteArray()
	buf.resize(BYTE_COUNT)
	buf[0] = FORMAT
	buf[1] = body
	buf[2] = skin
	buf[3] = hair
	buf[4] = hair_color
	buf[5] = top
	buf[6] = top_color
	buf[7] = bottom
	buf[8] = bottom_color
	buf[9] = head
	buf[10] = class_idx
	return buf


## {ok, body, skin, hair, hair_color, top, top_color, bottom, bottom_color, head, class_id}.
static func decode(raw: PackedByteArray) -> Dictionary:
	if raw.size() != BYTE_COUNT or int(raw[0]) != FORMAT:
		return {"ok": false}
	for i in range(11, BYTE_COUNT):
		if int(raw[i]) != 0:
			return {"ok": false}
	var body := int(raw[1])
	var skin := int(raw[2])
	var hair := int(raw[3])
	var hair_color := int(raw[4])
	var top := int(raw[5])
	var top_color := int(raw[6])
	var bottom := int(raw[7])
	var bottom_color := int(raw[8])
	var head := int(raw[9])
	var class_idx := int(raw[10])
	if class_idx < 0 or class_idx >= CLASS_IDS.size():
		return {"ok": false}
	if not _in(body, MAX_BODY) or not _in(skin, MAX_SKIN) or not _in(hair, MAX_HAIR):
		return {"ok": false}
	if not _in(hair_color, MAX_HAIR_COLOR) or not _in(top, MAX_TOP) or not _in(top_color, MAX_TOP_COLOR):
		return {"ok": false}
	if not _in(bottom, MAX_BOTTOM) or not _in(bottom_color, MAX_BOTTOM_COLOR) or not _in(head, MAX_HEAD):
		return {"ok": false}
	return {
		"ok": true,
		"body": body,
		"skin": skin,
		"hair": hair,
		"hair_color": hair_color,
		"top": top,
		"top_color": top_color,
		"bottom": bottom,
		"bottom_color": bottom_color,
		"head": head,
		"class_id": CLASS_IDS[class_idx],
	}


## Tijdelijke tint tot de paper-doll-bakker (M2). Geen shader, geen nieuwe art.
static func placeholder_tint(look: Dictionary) -> Color:
	var skin := clampi(int(look.get("skin", 0)), 0, MAX_SKIN)
	var hair := clampi(int(look.get("hair_color", 0)), 0, MAX_HAIR_COLOR)
	var palette: Array[Color] = [
		Color(1.0, 0.93, 0.84),
		Color(0.95, 0.74, 0.52),
		Color(0.66, 0.46, 0.31),
		Color(0.40, 0.28, 0.22),
	]
	var c := palette[skin]
	var shift := float(hair) / float(MAX_HAIR_COLOR)
	c.r = clampf(c.r * (1.0 - 0.15 * shift), 0.0, 1.0)
	c.b = clampf(c.b * (1.0 - 0.35 * shift) + 0.22 * shift, 0.0, 1.0)
	return c


static func _in(v: int, hi: int) -> bool:
	return v >= 0 and v <= hi
