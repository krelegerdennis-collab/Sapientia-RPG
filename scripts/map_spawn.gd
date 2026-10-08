@tool
class_name MapSpawn
extends Marker2D
## Spawnpunt: hier komt de speler binnen als hij via een uitgang naar deze map gaat.
## Zet de node midden op een tile. De NAAM van de node is de naam die je bij een
## MapExit invult (target_spawn), bv. "zuid_ingang".

## Kijkrichting bij binnenkomst: (0,1) = omlaag, (0,-1) = omhoog, (-1,0) = links, (1,0) = rechts.
@export var facing := Vector2i.DOWN


func get_tile() -> Vector2i:
	return Vector2i((position / 16.0).floor())
