class_name WorldWarperNaGenezer
extends RefCounted
## Eenmalige warp naar het World Warper-exterieur, zodra de vlag van De Genezer
## net gezet is. Een save die de vlag al heeft, warpt niet opnieuw.
## Wacht tot een lopende kernabsorptie klaar is. Geen H-6-onthulling.

const Unlock := preload("res://world_warper/flow/unlock.gd")
const Enter := preload("res://world_warper/flow/enter.gd")

static var pending := false


static func on_guard_flag(flag: String, net_gezet: bool) -> void:
	if net_gezet and flag == Unlock.BEWAKER_VLAG:
		pending = true


static func probeer() -> bool:
	if not pending:
		return false
	if str(GameState.pending_kern_absorb) != "":
		return false
	if GameState.changing_map or GameState.in_battle:
		return false
	pending = false
	return Enter.new().enter()
