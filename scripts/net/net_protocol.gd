class_name NetProtocol
extends RefCounted
## Berichten, versie en klok voor de fase-B-lobby. Geen socket en geen scène.
## Afspraak: docs/fase_b/ARCHITECTUUR.md. Vriendenmodus (pvp/) houdt 7777–7779.

const GAME_ID := "sapientia-coop"
const VERSION := 1

## Host + 3 gasten. ENet telt alleen de gasten; de host is peer 1.
const MAX_PLAYERS := 4
const MAX_REMOTE := MAX_PLAYERS - 1
## Eén extra ENet-plaats, alleen zodat een vijfde gast REFUSE FULL kan lezen.
## Zonder die plaats blijft hij in CONNECTING hangen tot de timeout. De roster blijft op 4.
const ENET_REFUSE_SLACK := 1
const HOST_SLOT := 0
const NO_SLOT := -1
const HOST_PEER_ID := MultiplayerPeer.TARGET_PEER_SERVER

## Eigen poorten, los van de Vriendenmodus, zodat beide lobby's niet op elkaar binden.
const ENET_PORT := 38421
const DISCOVERY_PORT := 38422
const ANNOUNCE_BIND_PORT := 38423
const BROADCAST_ADDR := "255.255.255.255"
const LOOPBACK := "127.0.0.1"
const PORT_MIN := 1
const PORT_MAX := 65535

const NAME_MAX := 16
const DEFAULT_GUEST_NAME := "Friend"
const MAX_PACKET_BYTES := 1024

const JOIN_TIMEOUT_SEC := 5.0
const JOIN_TICK_CAP_SEC := 0.1
const ANNOUNCE_INTERVAL_SEC := 0.5

## Simulatie-klok (de lobby simuleert zelf nog niets). 60 deelt door 20.
const SIM_HZ := 60
const SNAPSHOT_HZ := 20
const INPUT_HZ := 30
const INTERP_DELAY_MSEC := 100
## Plafond voor de bandbreedte-schatting: kop + 4 spelers + 8 vijanden.
const SNAPSHOT_HEADER_BYTES := 5
const SNAPSHOT_PLAYER_BYTES := 11
const SNAPSHOT_ENEMY_BYTES := 9
const SNAPSHOT_ENEMY_BUDGET := 8
const INPUT_BYTES := 6
## UDP/IPv4 (28) plus een ruime ENet-kop. Schatting, geen meting.
const UDP_OVERHEAD_BYTES := 48

## Host is Dax. Gasten: Seren, Vesper, Kael. Orion is bewust geen vierde (DECISION 1).
const HOST_CHARACTER := "dennis"
const ROSTER: Array[String] = ["dennis", "lotte", "noor", "kael"]

enum Kind {
	HELLO = 1,
	WELCOME = 2,
	ROSTER = 3,
	REFUSE = 4,
	LEAVE = 5,
	ANNOUNCE = 6,
	SESSION_END = 7,
	START_GAME = 8,
}

## Binaire gameplay-berichten (zelfde ENet-peer als de lobby; geen JSON).
enum BinKind {
	INPUT = 16,
	SNAPSHOT = 17,
}

## Losse poort voor headless sync-tests (geen botsing met een lopende lobby).
const SYNC_TEST_PORT := 38424

## Vlaggen per speler in snapshots (u16).
const FLAG_RING_OPEN := 1
const FLAG_ATTACK := 2
const FLAG_DOWN := 4

enum Refuse {
	NONE = 0,
	FULL = 1,
	VERSION = 2,
	BAD_PACKET = 3,
	TIMEOUT = 4,
	ROOM_NOT_FOUND = 5,
}

## Tekst voor later in de UI. Engels, zoals alle speler-tekst.
const REFUSE_TEXT := {
	Refuse.FULL: "The party is full.",
	Refuse.VERSION: "Game versions do not match.",
	Refuse.BAD_PACKET: "The join message was not understood.",
	Refuse.TIMEOUT: "Could not join the host.",
	Refuse.ROOM_NOT_FOUND: "Room not found. Check the code.",
}

## Relay (online co-op, stap 1). Leeg = alleen LAN. Zie relay/README.md.
const RELAY_URL_SETTING := "sapientia/net/relay_url"
const RELAY_URL_ENV := "SAPIENTIA_RELAY_URL"
## Zelfde alfabet als relay/src/codes.js: geen 0/O en 1/I/L.
const ROOM_CODE_ALPHABET := "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
const ROOM_CODE_LENGTH := 6
## De relay kan koud starten (gratis host slaapt); wachten we langer dan op LAN.
const RELAY_JOIN_TIMEOUT_SEC := 60.0

## Redenen uit RelayPeer.last_reason -> Engelse melding (speler-tekst).
const RELAY_ERROR_TEXT := {
	"unreachable": "Could not reach the online server.\nCheck your internet connection.",
	"timeout": "The online server did not answer in time.",
	"link_lost": "Connection to the online server lost.",
	"host_left": "The host left. Room closed.",
	"idle": "The room expired because nobody was active.",
	"max_age": "The room expired.",
	"shutdown": "The online server is restarting.",
	"kicked": "You were removed from the room.",
	"room_full": "The party is full.",
	"no_room": "Room not found. Check the code.",
	"bad_version": "Game versions do not match.",
	"rate_limited": "Too many attempts. Wait a minute and try again.",
	"too_many_rooms": "The online server is busy. Try again later.",
	"busy": "The online server is busy. Try again later.",
}

const SESSION_END_HOST_PAUSED := "host_paused"
const SESSION_END_TEXT := {
	SESSION_END_HOST_PAUSED: "The host paused the game. Session ended.",
	"ended": "The session ended.",
}


## Namen van de Godot-foutcodes, voor een leesbare melding (error_string geeft alleen de zin).
const ERROR_NAMES := {
	OK: "OK",
	FAILED: "FAILED",
	ERR_UNAVAILABLE: "ERR_UNAVAILABLE",
	ERR_UNCONFIGURED: "ERR_UNCONFIGURED",
	ERR_UNAUTHORIZED: "ERR_UNAUTHORIZED",
	ERR_PARAMETER_RANGE_ERROR: "ERR_PARAMETER_RANGE_ERROR",
	ERR_OUT_OF_MEMORY: "ERR_OUT_OF_MEMORY",
	ERR_FILE_NO_PERMISSION: "ERR_FILE_NO_PERMISSION",
	ERR_FILE_ALREADY_IN_USE: "ERR_FILE_ALREADY_IN_USE",
	ERR_CANT_OPEN: "ERR_CANT_OPEN",
	ERR_CANT_CREATE: "ERR_CANT_CREATE",
	ERR_QUERY_FAILED: "ERR_QUERY_FAILED",
	ERR_ALREADY_IN_USE: "ERR_ALREADY_IN_USE",
	ERR_LOCKED: "ERR_LOCKED",
	ERR_TIMEOUT: "ERR_TIMEOUT",
	ERR_CANT_CONNECT: "ERR_CANT_CONNECT",
	ERR_CANT_RESOLVE: "ERR_CANT_RESOLVE",
	ERR_CONNECTION_ERROR: "ERR_CONNECTION_ERROR",
	ERR_CANT_ACQUIRE_RESOURCE: "ERR_CANT_ACQUIRE_RESOURCE",
	ERR_INVALID_DATA: "ERR_INVALID_DATA",
	ERR_INVALID_PARAMETER: "ERR_INVALID_PARAMETER",
	ERR_ALREADY_EXISTS: "ERR_ALREADY_EXISTS",
	ERR_DOES_NOT_EXIST: "ERR_DOES_NOT_EXIST",
	ERR_BUSY: "ERR_BUSY",
}


## "ERR_CANT_CREATE (20)": de constante-naam plus het getal. Onbekende code: "ERR_?".
static func error_name(err: int) -> String:
	return "%s (%d)" % [str(ERROR_NAMES.get(err, "ERR_?")), err]


## Meldingtekst voor de speler: wat mislukte, met foutnaam en poort, zodat een melding
## van een telefoon genoeg zegt om de oorzaak te vinden. Engels (speler-tekst).
static func net_error_text(what: String, err: int, port: int, transport: String = "UDP") -> String:
	var text := "%s (%s).\n%s, %s port %d." % [what, error_string(err), error_name(err), transport, port]
	if err == ERR_CANT_CREATE or err == ERR_UNAUTHORIZED or err == ERR_FILE_NO_PERMISSION:
		text += "\nCheck the app's network permission and that no other app uses this port."
	return text


## Relay-URL: omgevingsvariabele (dev/test) boven project-instelling. Alleen ws:// of wss://;
## alles anders (ook leeg) = "" = alleen LAN.
static func relay_url() -> String:
	var url := OS.get_environment(RELAY_URL_ENV).strip_edges()
	if url == "":
		url = str(ProjectSettings.get_setting(RELAY_URL_SETTING, "")).strip_edges()
	return url if is_valid_relay_url(url) else ""


static func is_valid_relay_url(url: String) -> bool:
	return url.length() > 6 and (url.begins_with("ws://") or url.begins_with("wss://"))


## Hoofdletters, alleen toegestane tekens, hoogstens 6. Voor het invoervak en de join.
static func filter_room_code(raw: String) -> String:
	var out := ""
	for ch in raw.to_upper():
		if ROOM_CODE_ALPHABET.contains(ch):
			out += ch
		if out.length() >= ROOM_CODE_LENGTH:
			break
	return out


static func is_room_code(code: String) -> bool:
	return code.length() == ROOM_CODE_LENGTH and filter_room_code(code) == code


static func relay_error_text(reason: String) -> String:
	return str(RELAY_ERROR_TEXT.get(reason, "Online connection failed."))


static func clean_name(raw: String) -> String:
	var out := ""
	for i in raw.length():
		var ch := raw.substr(i, 1)
		if ch.unicode_at(0) < 32:
			continue
		out += ch
		if out.length() >= NAME_MAX:
			break
	out = out.strip_edges()
	if out == "":
		return DEFAULT_GUEST_NAME
	return out


## Vrije gast-held. Host-held en bezette ids slaat hij over. "" = de roster zit vol.
static func assign_character(taken: Array, requested: String) -> String:
	var want := requested
	if want == HOST_CHARACTER or not ROSTER.has(want):
		want = ""
	if want != "" and not _listed(taken, want):
		return want
	for id in ROSTER:
		if id == HOST_CHARACTER:
			continue
		if not _listed(taken, id):
			return id
	return ""


## Laagste vrije stoel, of NO_SLOT.
static func free_slot(used: Array) -> int:
	for slot in MAX_PLAYERS:
		if not _listed(used, slot):
			return slot
	return NO_SLOT


static func encode(kind: int, body: Dictionary, version: int = VERSION) -> PackedByteArray:
	var packet := {
		"game": GAME_ID,
		"v": version,
		"kind": kind,
		"body": body,
	}
	return JSON.stringify(packet).to_utf8_buffer()


static func encode_announce(host_name: String, players: int, port: int = ENET_PORT) -> PackedByteArray:
	return encode(Kind.ANNOUNCE, {
		"port": port,
		"name": clean_name(host_name),
		"players": players,
		"max": MAX_PLAYERS,
	})


## Leeg-niet: {ok, compatible, version, kind, body, reason}. Versieverschil is ok maar niet compatible.
static func decode(raw: PackedByteArray) -> Dictionary:
	var fail := {
		"ok": false,
		"compatible": false,
		"version": 0,
		"kind": 0,
		"body": {},
		"reason": Refuse.BAD_PACKET,
	}
	if raw.is_empty() or raw.size() > MAX_PACKET_BYTES:
		return fail
	var text := raw.get_string_from_utf8()
	if not text.begins_with("{"):
		return fail
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return fail
	var data: Dictionary = parsed
	if str(data.get("game", "")) != GAME_ID:
		return fail
	var version := int(data.get("v", 0))
	var kind := int(data.get("kind", 0))
	var body_v: Variant = data.get("body", {})
	var body: Dictionary = body_v if body_v is Dictionary else {}
	if version != VERSION:
		return {
			"ok": true,
			"compatible": false,
			"version": version,
			"kind": kind,
			"body": body,
			"reason": Refuse.VERSION,
		}
	if kind < Kind.HELLO or kind > Kind.START_GAME or not (body_v is Dictionary):
		return fail
	return {
		"ok": true,
		"compatible": true,
		"version": version,
		"kind": kind,
		"body": body,
		"reason": Refuse.NONE,
	}


static func is_binary_gameplay(raw: PackedByteArray) -> bool:
	if raw.is_empty():
		return false
	var k := int(raw[0])
	return k == BinKind.INPUT or k == BinKind.SNAPSHOT


## {ok, compatible, version, port, name, players, max_players}. Onleesbaar -> ok false.
static func parse_announce(raw: PackedByteArray) -> Dictionary:
	var empty := {
		"ok": false,
		"compatible": false,
		"version": 0,
		"port": 0,
		"name": "",
		"players": 0,
		"max_players": 0,
	}
	var msg := decode(raw)
	if not bool(msg["ok"]):
		return empty
	if int(msg["kind"]) != Kind.ANNOUNCE:
		return empty
	var body: Dictionary = msg["body"]
	var port := int(body.get("port", 0))
	var players := int(body.get("players", -1))
	var max_players := int(body.get("max", 0))
	var host_name := str(body.get("name", ""))
	if port < PORT_MIN or port > PORT_MAX:
		return empty
	if players < 0 or players > MAX_PLAYERS or max_players != MAX_PLAYERS:
		return empty
	if host_name == "" or host_name.length() > NAME_MAX:
		return empty
	return {
		"ok": true,
		"compatible": bool(msg["compatible"]),
		"version": int(msg["version"]),
		"port": port,
		"name": host_name,
		"players": players,
		"max_players": max_players,
	}


static func snapshot_payload_bytes() -> int:
	return SNAPSHOT_HEADER_BYTES + SNAPSHOT_PLAYER_BYTES * MAX_PLAYERS + SNAPSHOT_ENEMY_BYTES * SNAPSHOT_ENEMY_BUDGET


## Bytes per seconde die de host uitzendt als elk snapshot een eigen datagram is.
static func host_uplink_bytes_per_sec() -> int:
	return (snapshot_payload_bytes() + UDP_OVERHEAD_BYTES) * SNAPSHOT_HZ * MAX_REMOTE


static func host_input_bytes_per_sec() -> int:
	return (INPUT_BYTES + UDP_OVERHEAD_BYTES) * INPUT_HZ * MAX_REMOTE


static func _listed(values: Array, wanted: Variant) -> bool:
	for v in values:
		if v == wanted:
			return true
	return false
