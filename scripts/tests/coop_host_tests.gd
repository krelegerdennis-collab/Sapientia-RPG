extends Node
## Headless suite: co-op host-fout op Android (INTERNET-permissie) en de melding bij een mislukte host.
## Start: godot --path . -- --coophosttest

const Protocol := preload("res://scripts/net/net_protocol.gd")
const CoopLobbyScreen := preload("res://scripts/ui/coop_lobby_screen.gd")
const Lobby := preload("res://scripts/net/lan_lobby.gd")
const Discovery := preload("res://scripts/net/lan_discovery.gd")

## Zonder deze vier permissies kan een release-APK geen socket openen (ENet: ERR_CANT_CREATE).
const NET_PERMISSIONS: Array[String] = [
	"permissions/internet",
	"permissions/access_network_state",
	"permissions/access_wifi_state",
	"permissions/change_wifi_multicast_state",
]

var failures := 0
var passes := 0
var _left_to_title := false
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	_preset_tests()
	_text_tests()
	await _host_failure_tests()
	_discovery_failure_tests()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _preset_tests() -> void:
	var cfg := ConfigFile.new()
	var load_err := cfg.load("res://export_presets.cfg")
	check("export_presets.cfg laadt", load_err == OK)
	var android := 0
	for sec in cfg.get_sections():
		var name := str(sec)
		if name.ends_with(".options") or str(cfg.get_value(name, "platform", "")) != "Android":
			continue
		android += 1
		var opt := name + ".options"
		for perm in NET_PERMISSIONS:
			check("%s (%s): %s = true" % [name, str(cfg.get_value(name, "name", "")), perm],
					bool(cfg.get_value(opt, perm, false)))
		check("%s: signing-velden leeg (niet aangeraakt)" % name,
				str(cfg.get_value(opt, "keystore/release", "")) == ""
				and str(cfg.get_value(opt, "keystore/release_password", "")) == "")
	check("minstens één Android-preset", android >= 1)


func _text_tests() -> void:
	check("error_name ERR_CANT_CREATE", Protocol.error_name(ERR_CANT_CREATE) == "ERR_CANT_CREATE (20)")
	check("error_name onbekende code", Protocol.error_name(999) == "ERR_? (999)")
	var text := Protocol.net_error_text("Could not host", ERR_CANT_CREATE, Protocol.ENET_PORT)
	check("melding: eerste zin blijft 'Could not host'", text.begins_with("Could not host"))
	check("melding: foutnaam", text.contains("ERR_CANT_CREATE"))
	check("melding: poort", text.contains(str(Protocol.ENET_PORT)))
	check("melding: permissie-hint bij CANT_CREATE", text.contains("network permission"))
	var other := Protocol.net_error_text("Could not connect", ERR_TIMEOUT, Protocol.ENET_PORT)
	check("melding: geen permissie-hint bij timeout", not other.contains("permission"))


func _host_failure_tests() -> void:
	var blocker := ENetMultiplayerPeer.new()
	var block_err := blocker.create_server(Protocol.ENET_PORT, 1)
	check("blokkade: poort %d bezet gemaakt" % Protocol.ENET_PORT, block_err == OK)

	var lobby: LanLobby = Lobby.new()
	add_child(lobby)
	var err := lobby.host_session("Tester")
	check("host op bezette poort faalt", err != OK)
	check("lobby onthoudt de fout", lobby.last_error == err and lobby.last_error_port == Protocol.ENET_PORT)
	check("lobby blijft idle na mislukte host", lobby.phase == LanLobby.Phase.IDLE and not lobby.is_host and lobby.enet_peer() == null)
	lobby.queue_free()

	var ui: CoopLobbyScreen = CoopLobbyScreen.new()
	ui.name = "CoopUi"
	add_child(ui)
	await get_tree().process_frame
	ui.leave_requested.connect(func() -> void: _left_to_title = true)
	ui._show_host()
	await get_tree().process_frame
	check("UI toont het berichtscherm", ui._screen == CoopLobbyScreen.Screen.MESSAGE)
	check("UI-bericht begint met 'Could not host'", ui._message.begins_with("Could not host"))
	check("UI-bericht bevat de foutnaam", ui._message.contains(Protocol.error_name(ui.lobby.last_error)))
	check("UI-bericht bevat de poort", ui._message.contains(str(Protocol.ENET_PORT)))
	check("UI: geen host-rol na mislukte host", not GameState.coop_in_session())
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
		await get_tree().process_frame
		var img: Image = ui.get_viewport().get_texture().get_image()
		img.save_png(shots.path_join("coop_host_error.png"))
		print("INFO  screenshot: ", shots.path_join("coop_host_error.png"))
	print("INFO  melding: ", ui._message.replace("\n", " | "))
	var back: Button = null
	for b in ui.all_touch_buttons():
		if str(b.get_meta("label", b.text)) == "Back to title":
			back = b
	check("UI: knop 'Back to title' aanwezig", back != null)
	if back != null:
		back.pressed.emit()
	check("UI: 'Back to title' geeft leave_requested", _left_to_title)
	check("UI: lobby en baken opgeruimd", ui.lobby.phase == LanLobby.Phase.IDLE and ui.lobby.enet_peer() == null)
	ui.queue_free()

	blocker.close()
	await get_tree().process_frame
	var again: LanLobby = Lobby.new()
	add_child(again)
	check("host lukt weer zodra de poort vrij is", again.host_session("Tester") == OK)
	again.close()
	again.queue_free()


func _discovery_failure_tests() -> void:
	var blocker := PacketPeerUDP.new()
	var block_err := blocker.bind(Protocol.DISCOVERY_PORT)
	check("blokkade: UDP-poort %d bezet" % Protocol.DISCOVERY_PORT, block_err == OK)
	var d: LanDiscovery = Discovery.new()
	add_child(d)
	var err := d.start_listen()
	check("luisteren op bezette poort faalt of deelt de poort", err != OK or d.last_error == OK)
	if err != OK:
		check("discovery onthoudt fout en poort", d.last_error == err and d.last_error_port == Protocol.DISCOVERY_PORT)
	d.stop()
	d.queue_free()
	blocker.close()
