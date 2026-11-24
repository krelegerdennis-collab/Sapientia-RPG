extends RefCounted
## F6-27: als de TCP/WSS-handshake in CONNECTING blijft steken (Godot 4.3 meldt een geweigerde
## connect niet), moet RelayPeer binnen CONNECT_DEADLINE_SEC (4 s) 'unreachable' geven — onder
## relay_tests.gd STEP (5.0 s), ver onder de engine-timeout van 30 s. Succesvolle open blijft
## het werk van relaytest; hier alleen het vastzittende CONNECTING-pad, via de testhook.


func run(t: Node) -> void:
	var peer := RelayPeer.new()
	peer.debug_stuck_connecting = true
	var got := [""]
	var emits := [0]
	peer.failed.connect(func(reason: String) -> void:
		got[0] = reason
		emits[0] += 1
	)
	var err := peer.create_host("ws://127.0.0.1:1")
	t.check("F6-27 stuck-connect start OK", err == OK)
	var t0 := Time.get_ticks_msec()
	while got[0] == "" and Time.get_ticks_msec() - t0 < 5500:
		peer.poll()
		await t.get_tree().process_frame
	var elapsed := Time.get_ticks_msec() - t0
	t.check("F6-27 unreachable binnen de connect-deadline (reden='%s', %d ms)" % [got[0], elapsed],
			got[0] == "unreachable")
	t.check("F6-27 vuurde rond 4 s, niet de engine-timeout van 30 s (%d ms)" % elapsed,
			elapsed >= 3500 and elapsed <= 5000)
	# Late poll na _fail mag niet opnieuw failed emitten of crashen.
	peer.poll()
	peer.poll()
	t.check("F6-27 late poll na _fail is onschuldig (emits=%d)" % emits[0], emits[0] == 1)
	peer.close()
