class_name Wm1PerfBudget
extends RefCounted
## Vaste drempels voor --wm1budgettest (WM1). Baseline: Godot 4.3-stable headless via xvfb-run,
## opengl3, viewport 384×216, warmup 30 + 180 meetframes (scripts/perf/wm1_frametime.gd).
## Drempels = gemeten waarde + marge (proc_ms +35% +1,5 ms; draw +3; scene_nodes +8; nodes +120).
## Zie docs/perf_wm1.md. Opnieuw genereren: run_suite.sh wm1frametest | python3 tools/perf/wm1_budget_from_log.py

const WARMUP_FRAMES := 30
const SAMPLE_FRAMES := 180

const LIMITS: Dictionary = {
	"archief_2_v1_entree": {"max_proc_ms": 1.747, "max_draw_avg": 52.8, "max_draw_max": 77, "max_scene_nodes": 49, "max_nodes": 202},
	"archief_2_v1_plaat": {"max_proc_ms": 1.716, "max_draw_avg": 113.0, "max_draw_max": 128, "max_scene_nodes": 38, "max_nodes": 191},
	"archief_2_v2_gang": {"max_proc_ms": 1.7, "max_draw_avg": 128.2, "max_draw_max": 129, "max_scene_nodes": 39, "max_nodes": 192},
	"archief_2_v2_lotte": {"max_proc_ms": 1.697, "max_draw_avg": 127.1, "max_draw_max": 128, "max_scene_nodes": 38, "max_nodes": 191},
	"archief_2_v3_ketting": {"max_proc_ms": 1.696, "max_draw_avg": 128.4, "max_draw_max": 129, "max_scene_nodes": 47, "max_nodes": 200},
	"archief_2_v3_licht": {"max_proc_ms": 1.692, "max_draw_avg": 127.4, "max_draw_max": 128, "max_scene_nodes": 38, "max_nodes": 191},
	"archief_2_v3_tegen": {"max_proc_ms": 1.692, "max_draw_avg": 127.4, "max_draw_max": 128, "max_scene_nodes": 38, "max_nodes": 191},
	"archief_2_v3_wurger": {"max_proc_ms": 1.704, "max_draw_avg": 129.3, "max_draw_max": 130, "max_scene_nodes": 44, "max_nodes": 197},
	"archief_2_v4_genezer": {"max_proc_ms": 1.704, "max_draw_avg": 129.2, "max_draw_max": 130, "max_scene_nodes": 86, "max_nodes": 239},
	"archief_2_v4_hal": {"max_proc_ms": 1.692, "max_draw_avg": 127.2, "max_draw_max": 128, "max_scene_nodes": 38, "max_nodes": 191},
	"archief_2_warper": {"max_proc_ms": 1.719, "max_draw_avg": 70.0, "max_draw_max": 132, "max_scene_nodes": 43, "max_nodes": 196},
	"archief_bibliotheek": {"max_proc_ms": 1.743, "max_draw_avg": 139.8, "max_draw_max": 168, "max_scene_nodes": 61, "max_nodes": 214},
	"archief_golemhal": {"max_proc_ms": 1.717, "max_draw_avg": 145.4, "max_draw_max": 146, "max_scene_nodes": 40, "max_nodes": 193},
	"archief_ingang": {"max_proc_ms": 1.701, "max_draw_avg": 148.4, "max_draw_max": 149, "max_scene_nodes": 48, "max_nodes": 201},
	"archief_puzzel": {"max_proc_ms": 1.712, "max_draw_avg": 154.2, "max_draw_max": 155, "max_scene_nodes": 155, "max_nodes": 308},
	"archief_v1_gang": {"max_proc_ms": 1.698, "max_draw_avg": 147.2, "max_draw_max": 148, "max_scene_nodes": 52, "max_nodes": 205},
	"archief_v2_kastenzaal": {"max_proc_ms": 1.696, "max_draw_avg": 144.2, "max_draw_max": 145, "max_scene_nodes": 36, "max_nodes": 189},
	"archief_v2_leeszaal": {"max_proc_ms": 1.696, "max_draw_avg": 144.3, "max_draw_max": 145, "max_scene_nodes": 46, "max_nodes": 199},
	"archief_v2_trapzaal": {"max_proc_ms": 1.73, "max_draw_avg": 146.3, "max_draw_max": 147, "max_scene_nodes": 44, "max_nodes": 197},
	"archief_v3_gang": {"max_proc_ms": 1.69, "max_draw_avg": 143.4, "max_draw_max": 144, "max_scene_nodes": 40, "max_nodes": 193},
	"archief_v3_zuilenhal": {"max_proc_ms": 1.7, "max_draw_avg": 147.2, "max_draw_max": 148, "max_scene_nodes": 53, "max_nodes": 206},
	"archief_v4_voorhal": {"max_proc_ms": 1.689, "max_draw_avg": 144.2, "max_draw_max": 145, "max_scene_nodes": 43, "max_nodes": 196},
	"archief_v4_wachtersgang": {"max_proc_ms": 1.701, "max_draw_avg": 147.2, "max_draw_max": 148, "max_scene_nodes": 46, "max_nodes": 199},
	"berggrot_bouwplaats": {"max_proc_ms": 1.682, "max_draw_avg": 149.1, "max_draw_max": 150, "max_scene_nodes": 57, "max_nodes": 210},
	"berggrot_geheim": {"max_proc_ms": 1.712, "max_draw_avg": 150.1, "max_draw_max": 151, "max_scene_nodes": 134, "max_nodes": 287},
	"berggrot_grendel": {"max_proc_ms": 1.7, "max_draw_avg": 146.1, "max_draw_max": 147, "max_scene_nodes": 90, "max_nodes": 243},
	"berggrot_mond": {"max_proc_ms": 1.703, "max_draw_avg": 146.3, "max_draw_max": 147, "max_scene_nodes": 46, "max_nodes": 199},
	"berggrot_nerf": {"max_proc_ms": 1.703, "max_draw_avg": 146.4, "max_draw_max": 147, "max_scene_nodes": 46, "max_nodes": 199},
	"berggrot_uitmond": {"max_proc_ms": 1.7, "max_draw_avg": 145.5, "max_draw_max": 146, "max_scene_nodes": 43, "max_nodes": 196},
	"dorp_wilgendal": {"max_proc_ms": 1.704, "max_draw_avg": 320.4, "max_draw_max": 321, "max_scene_nodes": 1687, "max_nodes": 1840},
	"esdoorn": {"max_proc_ms": 1.693, "max_draw_avg": 141.3, "max_draw_max": 142, "max_scene_nodes": 59, "max_nodes": 212},
	"esdoorn_herberg": {"max_proc_ms": 1.701, "max_draw_avg": 143.5, "max_draw_max": 144, "max_scene_nodes": 30, "max_nodes": 183},
	"esdoorn_huis_noor": {"max_proc_ms": 1.688, "max_draw_avg": 141.6, "max_draw_max": 142, "max_scene_nodes": 26, "max_nodes": 179},
	"huis_wilgendal": {"max_proc_ms": 1.694, "max_draw_avg": 174.2, "max_draw_max": 175, "max_scene_nodes": 143, "max_nodes": 296},
	"kamer_beeldkamer": {"max_proc_ms": 1.69, "max_draw_avg": 145.3, "max_draw_max": 146, "max_scene_nodes": 35, "max_nodes": 188},
	"kamer_echo_kamer": {"max_proc_ms": 1.688, "max_draw_avg": 152.2, "max_draw_max": 153, "max_scene_nodes": 46, "max_nodes": 199},
	"kamer_hal": {"max_proc_ms": 1.678, "max_draw_avg": 145.1, "max_draw_max": 146, "max_scene_nodes": 69, "max_nodes": 222},
	"kamer_handelskamer": {"max_proc_ms": 1.678, "max_draw_avg": 142.6, "max_draw_max": 143, "max_scene_nodes": 31, "max_nodes": 184},
	"kamer_kern": {"max_proc_ms": 1.678, "max_draw_avg": 142.1, "max_draw_max": 143, "max_scene_nodes": 31, "max_nodes": 184},
	"kamer_rustkamer": {"max_proc_ms": 1.677, "max_draw_avg": 146.2, "max_draw_max": 147, "max_scene_nodes": 39, "max_nodes": 192},
	"kamer_trainingshal": {"max_proc_ms": 1.677, "max_draw_avg": 143.4, "max_draw_max": 144, "max_scene_nodes": 31, "max_nodes": 184},
	"kamer_werkplaats": {"max_proc_ms": 1.678, "max_draw_avg": 142.1, "max_draw_max": 143, "max_scene_nodes": 31, "max_nodes": 184},
	"leven_ingang": {"max_proc_ms": 1.728, "max_draw_avg": 73.7, "max_draw_max": 145, "max_scene_nodes": 44, "max_nodes": 197},
	"leven_v1_plaat": {"max_proc_ms": 1.728, "max_draw_avg": 103.1, "max_draw_max": 127, "max_scene_nodes": 141, "max_nodes": 294},
	"leven_v3_combi": {"max_proc_ms": 1.703, "max_draw_avg": 130.5, "max_draw_max": 131, "max_scene_nodes": 114, "max_nodes": 267},
	"warper_exterieur": {"max_proc_ms": 1.69, "max_draw_avg": 127.3, "max_draw_max": 128, "max_scene_nodes": 28, "max_nodes": 181},
	"warper_hal": {"max_proc_ms": 1.696, "max_draw_avg": 207.3, "max_draw_max": 208, "max_scene_nodes": 111, "max_nodes": 266},
	"warper_hanger_nis": {"max_proc_ms": 1.675, "max_draw_avg": 126.0, "max_draw_max": 127, "max_scene_nodes": 23, "max_nodes": 176},
	"warper_warp_ring": {"max_proc_ms": 1.674, "max_draw_avg": 127.1, "max_draw_max": 128, "max_scene_nodes": 26, "max_nodes": 179},
	"wereldkaart": {"max_proc_ms": 1.704, "max_draw_avg": 125.1, "max_draw_max": 126, "max_scene_nodes": 46, "max_nodes": 199},
	"wilgendal": {"max_proc_ms": 1.724, "max_draw_avg": 140.2, "max_draw_max": 141, "max_scene_nodes": 80, "max_nodes": 233},
	"wilgendal_binnen": {"max_proc_ms": 1.682, "max_draw_avg": 129.5, "max_draw_max": 130, "max_scene_nodes": 30, "max_nodes": 183},
	"woud_mistpoel": {"max_proc_ms": 1.746, "max_draw_avg": 136.2, "max_draw_max": 137, "max_scene_nodes": 65, "max_nodes": 218},
	"woud_open_plek": {"max_proc_ms": 1.77, "max_draw_avg": 136.9, "max_draw_max": 138, "max_scene_nodes": 62, "max_nodes": 215},
	"woud_pad": {"max_proc_ms": 1.73, "max_draw_avg": 135.2, "max_draw_max": 136, "max_scene_nodes": 64, "max_nodes": 217},
	"woud_rand": {"max_proc_ms": 1.752, "max_draw_avg": 139.1, "max_draw_max": 140, "max_scene_nodes": 63, "max_nodes": 216},
	"woud_sporenkring": {"max_proc_ms": 1.732, "max_draw_avg": 137.2, "max_draw_max": 138, "max_scene_nodes": 61, "max_nodes": 214},
}


static func limit(room_id: String) -> Dictionary:
	return LIMITS.get(room_id, {})


static func has_room(room_id: String) -> bool:
	return LIMITS.has(room_id)
