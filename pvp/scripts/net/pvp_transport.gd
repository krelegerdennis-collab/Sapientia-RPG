extends Node
class_name PvpTransport
## Wisselbare transportlaag. Fase 1: lokaal of LAN.
## TODO(design): relay is niet gekozen (GD-Sync / NodeTunnel / eigen VPS / TBD).

signal connected
signal disconnected(reason: String)
signal message(payload: Dictionary)
signal failed(reason: String)

var failed_reason: String = ""
var _silent_close: bool = false


func host(_code: String) -> void:
	mark_failed("Dit transport kan niet hosten.")


func join(_code: String) -> bool:
	mark_failed("Dit transport kan niet deelnemen.")
	return false


func send(_payload: Dictionary) -> void:
	pass


func close() -> void:
	pass


func close_silent() -> void:
	_silent_close = true
	close()


func is_failed() -> bool:
	return failed_reason != ""


func mark_failed(reason: String) -> void:
	failed_reason = reason
	failed.emit(reason)
