extends RefCounted
## Toetsenbord-hulpregels -> touch-variant wanneer TouchControls.touch_mode (F6-T11).
## hint_text op menu_screen blijft altijd de oude toetsenbordstring; alleen het label wisselt.

const TouchControls := preload("res://scripts/touch_controls.gd")

const TOUCH: Dictionary = {
	"A: choose   B: back": "Tap: choose   Back: close",  # VOORSTEL - Dennis kiest de tekst
	"A: craft   B: back": "Tap: craft   Back: close",  # VOORSTEL - Dennis kiest de tekst
	"A: choose   <  >: hero   B: back": "Tap: choose   Swipe: hero   Back: close",  # VOORSTEL - Dennis kiest de tekst
	"Which slot?   A: choose   B: back": "Which slot?   Tap: choose   Back: close",  # VOORSTEL - Dennis kiest de tekst
	"Remove what?   A: remove   B: back": "Remove what?   Tap: remove   Back: close",  # VOORSTEL - Dennis kiest de tekst
	"Drop what?   A: choose   B: back": "Drop what?   Tap: choose   Back: close",  # VOORSTEL - Dennis kiest de tekst
	"A: use   <  >: other hero   B: back": "Tap: use   Swipe: hero   Back: close",  # VOORSTEL - Dennis kiest de tekst
	"A: use   B: back": "Tap: use   Back: close",  # VOORSTEL - Dennis kiest de tekst
	"On whom?   A: use   B: other choice": "On whom?   Tap: use   Back: other choice",  # VOORSTEL - Dennis kiest de tekst
	"A: pick, then pick who swaps in   B: back": "Tap: pick, then tap who swaps in   Back: close",  # VOORSTEL - Dennis kiest de tekst
	"A: ally   >: fusion   B: back": "Tap: ally   Fusion: fuse   Back: close",  # VOORSTEL - Dennis kiest de tekst
	"Fusion: pick page 1   B: back": "Fusion: pick page 1   Back: close",  # VOORSTEL - Dennis kiest de tekst
	"Fusion: pick page 2   B: back": "Fusion: pick page 2   Back: close",  # VOORSTEL - Dennis kiest de tekst
	"A: fuse (both pages are used up)   B: back": "Tap: fuse (both pages are used up)   Back: close",  # VOORSTEL - Dennis kiest de tekst
	"Left/Right: tab   B: back": "Swipe: tab   Back: close",  # VOORSTEL - Dennis kiest de tekst
	"A: watch   Left/Right: tab   B: back": "Tap: watch   Swipe: tab   Back: close",  # VOORSTEL - Dennis kiest de tekst
	"A: play/stop   Left/Right: tab   B: back": "Tap: play/stop   Swipe: tab   Back: close",  # VOORSTEL - Dennis kiest de tekst
	"A: play/stop   Tap Music tab   B: back": "Tap: play/stop   Tap Music tab   Back: close",  # VOORSTEL - Dennis kiest de tekst
	"<  >: other hero   B: back": "Swipe: other hero   Back: close",  # VOORSTEL - Dennis kiest de tekst
	"B: back": "Back: close",  # VOORSTEL - Dennis kiest de tekst
}


static func display(keyboard_hint: String) -> String:
	if not TouchControls.touch_mode:
		return keyboard_hint
	return str(TOUCH.get(keyboard_hint, keyboard_hint))