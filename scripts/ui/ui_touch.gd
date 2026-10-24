extends RefCounted
## UX-polish (fase 6): tikdoelen van minstens 48dp (Android-richtlijn) in logische 384x216-eenheden.
##
## Het venster is 216 eenheden hoog (stretch viewport, aspect expand). Een eenheid is dus
## korte_zijde_dp / 216 dp groot. Referentietoestel: Galaxy S25 Ultra, 1440 px bij schaal 3,5 =
## 412dp korte zijde, dus 1 eenheid = 1,91dp en 48dp = 25,2 eenheden -> MIN_UNITS 26.
## (Op een telefoon met 360dp korte zijde is 48dp 28,8 eenheden: units_for_dp() rekent dat uit.)
## Gebruik: UiTouch.ensure(knop) in een lijst/menu; UiTouch.hit_rect(r) voor een getekende knop
## (HUD) waarvan het tikvlak groter is dan het plaatje.

const MIN_DP := 48.0
const VIEW_H := 216.0
const REF_SHORT_SIDE_DP := 412.0
const MIN_UNITS := 26.0


## 'dp' in logische eenheden bij een toestel met deze korte zijde (in dp).
static func units_for_dp(dp: float, short_side_dp: float = REF_SHORT_SIDE_DP) -> float:
	return dp * VIEW_H / maxf(short_side_dp, 1.0)


## Het minimum voor een toestel (naar boven afgerond op hele eenheden).
static func min_units(short_side_dp: float = REF_SHORT_SIDE_DP) -> float:
	return ceilf(units_for_dp(MIN_DP, short_side_dp))


## Vergroot een Control (alleen als hij kleiner is) tot het tikminimum. w/h = welke kant.
static func ensure(c: Control, width := false, height := true, min_size: float = MIN_UNITS) -> void:
	var m := c.custom_minimum_size
	if height:
		m.y = maxf(m.y, min_size)
	if width:
		m.x = maxf(m.x, min_size)
	c.custom_minimum_size = m


## Tikvlak van een getekende knop: het plaatje, maar nooit kleiner dan min_size (om het midden).
static func hit_rect(r: Rect2, min_size: float = MIN_UNITS) -> Rect2:
	var w := maxf(r.size.x, min_size)
	var h := maxf(r.size.y, min_size)
	return Rect2(r.get_center() - Vector2(w, h) / 2.0, Vector2(w, h))


## Is dit tikdoel groot genoeg? (Rect2 of Vector2 grootte)
static func is_big_enough(size: Vector2, min_size: float = MIN_UNITS) -> bool:
	return size.x >= min_size - 0.01 and size.y >= min_size - 0.01


## Alle zichtbare tikdoelen onder 'root' die te klein zijn: [{"node", "size", "path"}].
## Meegerekend: knoppen, TextureButtons, schuifregelaars en Controls met de metadata "touch_target".
## Overgeslagen: onzichtbare/uitgeschakelde knoppen en knoppen met de metadata "touch_exempt".
## Een knop in een rij telt met zijn eigen hoogte; de breedte telt alleen onder width_min.
static func small_targets(root: Node, min_size: float = MIN_UNITS, width_min: float = 0.0) -> Array:
	var out: Array = []
	_walk(root, min_size, width_min, out)
	return out


static func _walk(n: Node, min_size: float, width_min: float, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if _is_target(n):
		var c := n as Control
		if not bool(c.get_meta("touch_exempt", false)) and not (c is BaseButton and (c as BaseButton).disabled):
			var s := c.size if c.size.y > 0.0 else c.get_combined_minimum_size()
			if s.y < min_size - 0.01 or (width_min > 0.0 and s.x < width_min - 0.01):
				out.append({"node": c, "size": s, "path": str(c.get_path()), "text": str(c.get("text")) if "text" in c else ""})
	for ch in n.get_children():
		_walk(ch, min_size, width_min, out)


static func _is_target(n: Node) -> bool:
	if n is BaseButton or n is Slider:
		return (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE
	return n is Control and bool((n as Control).get_meta("touch_target", false))
