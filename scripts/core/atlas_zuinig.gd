class_name AtlasZuinig
extends RefCounted
## Geheugen (WM1-meting, tools/geheugen): zet `use_texture_padding` uit op de tegelatlassen van een kaart.
##
## Godot (4.3) maakt voor elke TileSetAtlasSource met padding een tweede, opgevulde kopie van de hele atlas
## als ImageTexture (+1 pixel rand per tegel) naast het geimporteerde origineel. Voor Wilgendal is dat ~8 MB
## extra textuurgeheugen (de originele atlas blijft ook staan), voor elke kamer meer dan 100 KB.
## De padding voorkomt alleen "bleeding" bij schalen, draaien of lineaire filtering. Dit spel tekent met
## Nearest, zonder camerazoom, op een gesnapte 1:1-viewport (stretch mode viewport): elke tegel-texel landt
## precies op een schermpixel. Het beeld blijft bit-voor-bit gelijk (tools/geheugen/beeldcheck.py).
##
## Wie een kaart ooit met zoom of een niet-gesnapte schaal wil tekenen, kan dit per atlas weer aanzetten.


## Zet de padding uit voor alle TileSets onder `wortel` (TileMapLayer en TileMap). Geeft het aantal
## atlasbronnen terug dat veranderd is. Veilig om vaker aan te roepen (tweede keer: 0).
static func toepassen(wortel: Node) -> int:
	var gedaan := {}
	var n := 0
	var stapel: Array[Node] = [wortel]
	while not stapel.is_empty():
		var node: Node = stapel.pop_back()
		stapel.append_array(node.get_children())
		var ts: TileSet = null
		if node is TileMapLayer:
			ts = (node as TileMapLayer).tile_set
		elif node is TileMap:
			ts = (node as TileMap).tile_set
		if ts == null or gedaan.has(ts.get_instance_id()):
			continue
		gedaan[ts.get_instance_id()] = true
		n += tileset_zuinig(ts)
	return n


## Zelfde voor een los TileSet.
static func tileset_zuinig(ts: TileSet) -> int:
	var n := 0
	for i in ts.get_source_count():
		var src := ts.get_source(ts.get_source_id(i))
		if src is TileSetAtlasSource and (src as TileSetAtlasSource).use_texture_padding:
			(src as TileSetAtlasSource).use_texture_padding = false
			n += 1
	return n
