class_name SomSignature
extends RefCounted
## F3 pure helpers (testbaar zonder nodes).

const SomSignatureData := preload("res://scripts/data/som_signature_data.gd")
const SomChainData := preload("res://scripts/data/som_chain_data.gd")


static func backstab_hit(monster_facing: Vector2i, strike_dir: Vector2i) -> bool:
	if strike_dir == Vector2i.ZERO:
		return false
	var ef := Vector2(monster_facing)
	if ef.length_squared() < 0.01:
		return false
	var sd := Vector2(strike_dir)
	return ef.normalized().dot(sd.normalized()) > SomSignatureData.BACKSTAB_DOT


static func icd_ready(icd: Dictionary, hero_id: String) -> bool:
	return int(icd.get(hero_id, 0)) <= 0


static func dax_knockback_tiles(step: int, heavy: int) -> int:
	if heavy >= 2:
		return SomSignatureData.DAX_KNOCK_HEAVY2
	if heavy == 1:
		return SomSignatureData.DAX_KNOCK_HEAVY1
	if step >= 0 and SomChainData.is_finisher(step):
		return SomSignatureData.DAX_KNOCK_FIN
	return -1


static func dax_stagger_fill_mult(step: int, heavy: int) -> float:
	if heavy > 0 or (step >= 0 and SomChainData.is_finisher(step)):
		return SomSignatureData.DAX_STAGGER_MULT
	return 1.0