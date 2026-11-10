class_name EmoteGate
extends RefCounted
## Anti-spam voor emotes: 1,5 s per stoel. De host is de enige die dit afdwingt.
## now_sec komt van de aanroeper, zodat tests de grens zonder wachten kunnen zetten.

const Protocol := preload("res://scripts/net/net_protocol.gd")

var _last_sec: Dictionary = {}


func allow(seat: int, now_sec: float) -> bool:
	var prev := float(_last_sec.get(seat, -1.0e9))
	if now_sec - prev < Protocol.EMOTE_COOLDOWN_SEC:
		return false
	_last_sec[seat] = now_sec
	return true


func reset() -> void:
	_last_sec.clear()
