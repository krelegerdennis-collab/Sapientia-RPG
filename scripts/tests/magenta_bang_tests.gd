extends Node
## Magenta telegraaf-"!" via SomGameFeelData.TELEGRAPH_BANG_COLOR.
## Start: godot --headless --path . -- --magentabangtest

const SomGameFeelData := preload("res://scripts/data/som_gamefeel_data.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")

const EXPECTED := Color("#E040C0")
const ENEMY_READ_PATH := "res://scripts/som/som_enemy_read.gd"
const OLD_BANG_RGB := "Color(1, 0.3, 0.3)"

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


func _finish() -> void:
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _run() -> void:
	check("TELEGRAPH_BANG_COLOR == #E040C0", SomGameFeelData.TELEGRAPH_BANG_COLOR.is_equal_approx(EXPECTED))
	var src := FileAccess.get_file_as_string(ENEMY_READ_PATH)
	check("som_enemy_read geen oude rood-kleur", not src.contains(OLD_BANG_RGB))
	check("som_enemy_read gebruikt TELEGRAPH_BANG_COLOR", src.contains("SomGameFeelData.TELEGRAPH_BANG_COLOR"))
	_label_fallback_if_mogelijk()
	_finish()


func _label_fallback_if_mogelijk() -> void:
	if ResourceLoader.exists(str(SomData.FX_TELEGRAPH)):
		check("label-fallback (sprite-art aanwezig, overgeslagen)", true)
		return
	var root := Node2D.new()
	add_child(root)
	SomFx.number(root, Vector2.ZERO, "!", SomGameFeelData.TELEGRAPH_BANG_COLOR, 0.05)
	var holder: Node = root.get_node_or_null("SomNumber")
	if holder == null:
		check("label-fallback node", false)
		root.queue_free()
		return
	var l: Label = holder.get_child(0) as Label if holder.get_child_count() > 0 else null
	var ok := l != null and l.get_theme_color("font_color").is_equal_approx(EXPECTED)
	check("label-fallback font_color magenta", ok)
	root.queue_free()