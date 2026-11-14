extends Node
## Pixel-pariteit voor paper-doll attack/hurt/dodge + bake-prestatie (legacy-ref).
## Start: godot --path . -- --paperdollactionstest

const Baker := preload("res://scripts/online/paper_doll_baker.gd")
const Legacy := preload("res://scripts/tests/paper_doll_baker_legacy.gd")

const FULL := {
	"skin": 2, "hair": 3, "hair_color": 5,
	"top": 1, "top_color": 0, "bottom": 2, "bottom_color": 4,
	"head": 1, "head_color": 1, "class": "priest",
}

const VOORBEELD := {
	"skin": "getint", "hair": "krul", "hair_color": "zwart",
	"top": "mantel", "top_color": "paars", "bottom": "korte_broek", "bottom_color": "nacht",
	"head": "hoed", "head_color": "leer", "cape": "nacht", "class": "mage",
}

const BARE := {
	"skin": "licht", "hair": -1, "top": -1, "bottom": -1, "head": -1, "class": "",
}

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
	_sizes()
	_legacy_hash_parity()
	_bake_perf_budget()
	print("PAPERDOLLACTIONS %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _sizes() -> void:
	Baker.clear_cache()
	Legacy.clear_cache()
	var baked: Dictionary = Baker.bake(FULL)
	var attack: Texture2D = baked["attack"]
	var hurt: Texture2D = baked["hurt"]
	var dodge: Texture2D = baked["dodge"]
	check("attack sheet 288x192", attack.get_width() == 288 and attack.get_height() == 192)
	check("hurt sheet 192x48", hurt.get_width() == 192 and hurt.get_height() == 48)
	check("dodge sheet 192x48", dodge.get_width() == 192 and dodge.get_height() == 48)


func _legacy_hash_parity() -> void:
	var looks: Array = [{"name": "full", "look": FULL}, {"name": "voorbeeld", "look": VOORBEELD}, {"name": "bare", "look": BARE}]
	var sheets: PackedStringArray = PackedStringArray(["walk", "attack", "hurt", "dodge"])
	for entry in looks:
		var look: Dictionary = entry["look"]
		var tag: String = str(entry["name"])
		Baker.clear_cache()
		Legacy.clear_cache()
		for sheet in sheets:
			var fast := Baker.image_hash(Baker.image_for(look, sheet))
			var slow := Legacy.image_hash(Legacy.image_for(look, sheet))
			check("legacy hash %s %s" % [tag, sheet], fast == slow and fast != "")


func _bake_perf_budget() -> void:
	Baker.clear_cache()
	Baker.reset_stats()
	var t0 := Time.get_ticks_usec()
	var _unused: Variant = Baker.bake(FULL)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	print("PAPERDOLLACTIONS bake_ms=%.3f" % ms)
	check("bakken < 50 ms met marge (%.2f ms)" % ms, ms < 49.5)