extends RefCounted
## Pure spawn-lijst voor de World Warper-hal.
## Geen node, geen GameState, geen load(), geen engine-run.
##
## descriptors(party, codex) leest alleen de meegegeven arrays en geeft
## { "id": String, "naam": String } terug. Lege invoer -> lege array.
## Party-velden (zoals GameState.party): "id", "name" (displaynaam).
## Codex-pagina (zoals GameState.codex_pages): "uid", anders "id", anders "species";
## displaynaam uit "name". Een namaaklijst mag ook "naam" gebruiken.


static func descriptors(party: Array, codex: Array) -> Array[Dictionary]:
	var uit: Array[Dictionary] = []
	for lid in party:
		var d := _uit_party(lid)
		if not d.is_empty():
			uit.append(d)
	for pagina in codex:
		var d := _uit_codex(pagina)
		if not d.is_empty():
			uit.append(d)
	return uit


static func _uit_party(lid) -> Dictionary:
	if not (lid is Dictionary):
		return {}
	var id := _tekst(lid, ["id"])
	var naam := _tekst(lid, ["name", "naam"])
	return _paar(id, naam)


static func _uit_codex(pagina) -> Dictionary:
	if not (pagina is Dictionary):
		return {}
	# uid is het exemplaar (twee dezelfde soorten blijven twee rondlopers).
	var id := _tekst(pagina, ["uid", "id", "species"])
	var naam := _tekst(pagina, ["name", "naam"])
	return _paar(id, naam)


static func _paar(id: String, naam: String) -> Dictionary:
	if id == "" and naam == "":
		return {}
	if id == "":
		id = naam
	if naam == "":
		naam = id
	return {"id": id, "naam": naam}


static func _tekst(bron: Dictionary, sleutels: Array) -> String:
	for sleutel in sleutels:
		var waarde = bron.get(sleutel, "")
		if waarde == null:
			continue
		var s := str(waarde).strip_edges()
		if s != "":
			return s
	return ""
