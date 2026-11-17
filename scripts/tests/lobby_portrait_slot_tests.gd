extends Node
## Lobby portrait slot (co-op seats). Start: godot --path . -- --lobbyportraitslottest

const Slot := preload("res://scripts/ui/lobby_portrait_slot.gd")
const Roles := preload("res://scripts/coop/seat_controller.gd")

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	_assets_exist()
	await _texture_binding()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _assets_exist() -> void:
	for hero in Slot.HEROES:
		check("portret %s bestaat" % hero, ResourceLoader.exists("res://assets/ui/lobby/portret_%s.png" % hero))
	for role in Slot.ROLES:
		check("lijst %s achter" % role, ResourceLoader.exists("res://assets/ui/lobby/lijst_%s_achter.png" % role))
		check("lijst %s voor" % role, ResourceLoader.exists("res://assets/ui/lobby/lijst_%s_voor.png" % role))


func _texture_binding() -> void:
	var slot := Slot.new()
	add_child(slot)
	await get_tree().process_frame
	for hero in Slot.HEROES:
		var role := Roles.role_of(hero)
		slot.set_seat(hero, role)
		await get_tree().process_frame
		var back := slot.frame_back_texture()
		var front := slot.frame_front_texture()
		var face := slot.portrait_texture()
		check("%s/%s achter" % [hero, role], back != null and back.get_path().ends_with("lijst_%s_achter.png" % role))
		check("%s/%s voor" % [hero, role], front != null and front.get_path().ends_with("lijst_%s_voor.png" % role))
		check("%s portret" % hero, face != null and face.get_path().ends_with("portret_%s.png" % hero))
	slot.set_seat("", "tank")
	await get_tree().process_frame
	check("lege stoel: geen portret", slot.portrait_texture() == null)
	check("lege stoel: tank-achter", slot.frame_back_texture() != null)
	check("lege stoel: tank-voor", slot.frame_front_texture() != null)
	slot.set_seat("unknown_hero", "heal")
	await get_tree().process_frame
	check("onbekende id: geen portret", slot.portrait_texture() == null)
	check("onbekende id: heal-lijst", slot.frame_back_texture() != null and slot.frame_front_texture() != null)
	slot.queue_free()