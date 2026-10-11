extends RefCounted
## Zuivere regels voor het kijk-scherm Gezelschap. Geen node, geen GameState, geen load().
##
## lines(members) leest alleen de meegegeven Array.
## Elke Dictionary wordt "Naam, niveau N".
## Lege array -> lege lijst.
## Ontbrekend naamveld, null of lege tekst -> "Onbekend".
## Ontbrekend niveau of geen getal -> 1 (startniveau van een nieuwe held).
## Alles wat geen Dictionary is, slaat de functie over.


const ONBEKEND := "Onbekend"


static func lines(members: Array) -> Array[String]:
	var out: Array[String] = []
	for entry in members:
		if entry is Dictionary:
			var row: Dictionary = entry
			out.append("%s, niveau %d" % [_naam(row), _niveau(row)])
	return out


static func _naam(row: Dictionary) -> String:
	if not row.has("name") or row["name"] == null:
		return ONBEKEND
	var naam := str(row["name"]).strip_edges()
	if naam == "":
		return ONBEKEND
	return naam


static func _niveau(row: Dictionary) -> int:
	if not row.has("level") or row["level"] == null:
		return 1
	var raw = row["level"]
	if raw is int:
		return raw
	if raw is float:
		return int(raw)
	if raw is String and (raw as String).is_valid_int():
		return (raw as String).to_int()
	return 1
