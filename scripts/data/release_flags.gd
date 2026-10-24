extends RefCounted
## WM1-releasevlaggen (content-lock-besluiten van Dennis, 24 okt 2026: H1, H2, H3, H11).
## Alles hier is een CUT: de content blijft in de repo en in de tests, alleen de route erheen
## gaat dicht. Terugzetten = de vlag op false (of, voor de relay, een URL instellen).
##
##   hub_cut     H3  Training Hall, Workshop, Exchange en Core: deur blijft dicht (ook op level).
##               H2  hub-nissen codex_nis en sapientia_schot: deur blijft dicht.
##   online_cut  H11 PvP- en Co-op-knop op het titelscherm verborgen zolang er geen relay-URL is.
##   dev-kamers  H1  archief_test en kern_demo: geen route in een release-build (niet-debug).
##
## De vlaggen zijn static var, zodat een testsuite ze kan omzetten en terugzetten.

const HUB_ROOMS_CUT: Array[String] = ["trainingshal", "werkplaats", "handelskamer", "kern"]
const HUB_NICHES_CUT: Array[String] = ["codex_nis", "sapientia_schot"]
const DEV_SCENES: Array[String] = [
	"res://scenes/maps/archief_test.tscn",
	"res://scenes/maps/kern_demo.tscn",
]

## Waar een relay-URL vandaan komt (eerste die gevuld is): ProjectSettings, dan omgevingsvariabele.
const RELAY_SETTING := "sapientia/net/relay_url"
const RELAY_ENV := "SAPIENTIA_RELAY_URL"

static var hub_cut := true
static var online_cut := true
## Testhaak: -1 = echt (OS.is_debug_build()), 0 = doen alsof release, 1 = doen alsof debug.
static var debug_build_override := -1
## Testhaak: null = niets, anders vervangt dit de relay-URL uit de instellingen.
static var relay_url_override: Variant = null


static func is_debug_build() -> bool:
	if debug_build_override >= 0:
		return debug_build_override == 1
	return OS.is_debug_build()


## H3: deze hubkamer gaat in WM1 niet open.
static func hub_room_cut(room_id: String) -> bool:
	return hub_cut and HUB_ROOMS_CUT.has(room_id)


## H2: deze hub-nis gaat in WM1 niet open.
static func hub_niche_cut(room_id: String) -> bool:
	return hub_cut and HUB_NICHES_CUT.has(room_id)


## H1: dev-testkamers (archief_test, kern_demo) bestaan alleen in debug-builds als route.
static func dev_scene_blocked(scene_path: String) -> bool:
	return DEV_SCENES.has(scene_path) and not is_debug_build()


## Alleen debug-builds mogen naar een dev-kamer (F4 in map.gd).
static func dev_rooms_allowed() -> bool:
	return is_debug_build()


static func relay_url() -> String:
	if relay_url_override != null:
		return str(relay_url_override).strip_edges()
	var url := ""
	if ProjectSettings.has_setting(RELAY_SETTING):
		url = str(ProjectSettings.get_setting(RELAY_SETTING, "")).strip_edges()
	if url == "":
		url = OS.get_environment(RELAY_ENV).strip_edges()
	return url


## H11: PvP- en Co-op-knop zichtbaar? Met online_cut alleen als er een relay-URL is.
static func online_buttons_visible() -> bool:
	if not online_cut:
		return true
	return relay_url() != ""
