class_name Wm1PerfBudget
extends RefCounted
## Vaste drempels voor --wm1budgettest (WM1). Baseline: Godot 4.3-stable headless via xvfb-run,
## opengl3, viewport 384×216, warmup 30 + 180 meetframes (scripts/perf/wm1_frametime.gd).
## Drempels = gemeten waarde + marge (proc_ms +35% +1,5 ms; draw +3; scene_nodes +8; nodes +120).
## Zie docs/perf_wm1.md. Opnieuw genereren: run_suite.sh wm1frametest | python3 tools/perf/wm1_budget_from_log.py

const WARMUP_FRAMES := 30
const SAMPLE_FRAMES := 180

const LIMITS: Dictionary = {
	"archief_2_v1_entree": {"max_proc_ms": 1.842, "max_draw_avg": 32.4, "max_draw_max": 39, "max_scene_nodes": 49, "max_nodes": 202},
	"archief_2_v1_plaat": {"max_proc_ms": 1.751, "max_draw_avg": 28.2, "max_draw_max": 29, "max_scene_nodes": 38, "max_nodes": 191},
	"archief_2_v2_gang": {"max_proc_ms": 1.774, "max_draw_avg": 29.2, "max_draw_max": 30, "max_scene_nodes": 39, "max_nodes": 192},
	"archief_2_v2_lotte": {"max_proc_ms": 1.727, "max_draw_avg": 28.2, "max_draw_max": 29, "max_scene_nodes": 38, "max_nodes": 191},
	"archief_2_v3_ketting": {"max_proc_ms": 1.716, "max_draw_avg": 29.2, "max_draw_max": 30, "max_scene_nodes": 47, "max_nodes": 200},
	"archief_2_v3_licht": {"max_proc_ms": 1.72, "max_draw_avg": 28.2, "max_draw_max": 29, "max_scene_nodes": 38, "max_nodes": 191},
	"archief_2_v3_tegen": {"max_proc_ms": 1.751, "max_draw_avg": 28.2, "max_draw_max": 29, "max_scene_nodes": 38, "max_nodes": 191},
	"archief_2_v3_wurger": {"max_proc_ms": 1.73, "max_draw_avg": 30.2, "max_draw_max": 31, "max_scene_nodes": 44, "max_nodes": 197},
	"archief_2_v4_genezer": {"max_proc_ms": 1.75, "max_draw_avg": 30.3, "max_draw_max": 31, "max_scene_nodes": 86, "max_nodes": 239},
	"archief_2_v4_hal": {"max_proc_ms": 1.736, "max_draw_avg": 28.2, "max_draw_max": 29, "max_scene_nodes": 38, "max_nodes": 191},
	"archief_2_warper": {"max_proc_ms": 1.767, "max_draw_avg": 30.9, "max_draw_max": 31, "max_scene_nodes": 43, "max_nodes": 196},
	"archief_bibliotheek": {"max_proc_ms": 1.782, "max_draw_avg": 53.2, "max_draw_max": 55, "max_scene_nodes": 61, "max_nodes": 214},
	"archief_golemhal": {"max_proc_ms": 1.747, "max_draw_avg": 34.3, "max_draw_max": 35, "max_scene_nodes": 40, "max_nodes": 193},
	"archief_ingang": {"max_proc_ms": 1.75, "max_draw_avg": 37.2, "max_draw_max": 38, "max_scene_nodes": 48, "max_nodes": 201},
	"archief_puzzel": {"max_proc_ms": 1.73, "max_draw_avg": 43.2, "max_draw_max": 44, "max_scene_nodes": 155, "max_nodes": 308},
	"archief_v1_gang": {"max_proc_ms": 1.742, "max_draw_avg": 36.2, "max_draw_max": 37, "max_scene_nodes": 52, "max_nodes": 205},
	"archief_v2_kastenzaal": {"max_proc_ms": 1.779, "max_draw_avg": 33.3, "max_draw_max": 34, "max_scene_nodes": 36, "max_nodes": 189},
	"archief_v2_leeszaal": {"max_proc_ms": 1.728, "max_draw_avg": 33.3, "max_draw_max": 34, "max_scene_nodes": 46, "max_nodes": 199},
	"archief_v2_trapzaal": {"max_proc_ms": 1.756, "max_draw_avg": 35.1, "max_draw_max": 36, "max_scene_nodes": 44, "max_nodes": 197},
	"archief_v3_gang": {"max_proc_ms": 1.727, "max_draw_avg": 32.1, "max_draw_max": 33, "max_scene_nodes": 40, "max_nodes": 193},
	"archief_v3_zuilenhal": {"max_proc_ms": 1.769, "max_draw_avg": 36.3, "max_draw_max": 37, "max_scene_nodes": 53, "max_nodes": 206},
	"archief_v4_voorhal": {"max_proc_ms": 1.748, "max_draw_avg": 33.3, "max_draw_max": 34, "max_scene_nodes": 43, "max_nodes": 196},
	"archief_v4_wachtersgang": {"max_proc_ms": 1.762, "max_draw_avg": 36.1, "max_draw_max": 37, "max_scene_nodes": 46, "max_nodes": 199},
	"berggrot_bouwplaats": {"max_proc_ms": 1.784, "max_draw_avg": 38.3, "max_draw_max": 39, "max_scene_nodes": 57, "max_nodes": 210},
	"berggrot_geheim": {"max_proc_ms": 1.761, "max_draw_avg": 39.3, "max_draw_max": 40, "max_scene_nodes": 134, "max_nodes": 287},
	"berggrot_grendel": {"max_proc_ms": 1.756, "max_draw_avg": 35.2, "max_draw_max": 36, "max_scene_nodes": 90, "max_nodes": 243},
	"berggrot_mond": {"max_proc_ms": 1.742, "max_draw_avg": 35.3, "max_draw_max": 36, "max_scene_nodes": 46, "max_nodes": 199},
	"berggrot_nerf": {"max_proc_ms": 1.725, "max_draw_avg": 35.2, "max_draw_max": 36, "max_scene_nodes": 46, "max_nodes": 199},
	"berggrot_uitmond": {"max_proc_ms": 1.748, "max_draw_avg": 34.2, "max_draw_max": 35, "max_scene_nodes": 43, "max_nodes": 196},
	"dorp_wilgendal": {"max_proc_ms": 1.777, "max_draw_avg": 209.4, "max_draw_max": 210, "max_scene_nodes": 1687, "max_nodes": 1840},
	"esdoorn": {"max_proc_ms": 1.751, "max_draw_avg": 30.1, "max_draw_max": 31, "max_scene_nodes": 59, "max_nodes": 212},
	"esdoorn_herberg": {"max_proc_ms": 1.721, "max_draw_avg": 32.5, "max_draw_max": 33, "max_scene_nodes": 30, "max_nodes": 183},
	"esdoorn_huis_noor": {"max_proc_ms": 1.734, "max_draw_avg": 30.4, "max_draw_max": 31, "max_scene_nodes": 26, "max_nodes": 179},
	"huis_wilgendal": {"max_proc_ms": 1.896, "max_draw_avg": 530.2, "max_draw_max": 531, "max_scene_nodes": 154, "max_nodes": 307},
	"kamer_beeldkamer": {"max_proc_ms": 1.747, "max_draw_avg": 34.2, "max_draw_max": 35, "max_scene_nodes": 35, "max_nodes": 188},
	"kamer_echo_kamer": {"max_proc_ms": 1.715, "max_draw_avg": 41.3, "max_draw_max": 42, "max_scene_nodes": 46, "max_nodes": 199},
	"kamer_hal": {"max_proc_ms": 1.696, "max_draw_avg": 34.1, "max_draw_max": 35, "max_scene_nodes": 69, "max_nodes": 222},
	"kamer_handelskamer": {"max_proc_ms": 1.707, "max_draw_avg": 31.2, "max_draw_max": 32, "max_scene_nodes": 31, "max_nodes": 184},
	"kamer_kern": {"max_proc_ms": 1.693, "max_draw_avg": 31.2, "max_draw_max": 32, "max_scene_nodes": 31, "max_nodes": 184},
	"kamer_rustkamer": {"max_proc_ms": 1.677, "max_draw_avg": 35.1, "max_draw_max": 36, "max_scene_nodes": 39, "max_nodes": 192},
	"kamer_trainingshal": {"max_proc_ms": 1.677, "max_draw_avg": 32.7, "max_draw_max": 33, "max_scene_nodes": 31, "max_nodes": 184},
	"kamer_werkplaats": {"max_proc_ms": 1.723, "max_draw_avg": 31.2, "max_draw_max": 32, "max_scene_nodes": 31, "max_nodes": 184},
	"leven_ingang": {"max_proc_ms": 1.778, "max_draw_avg": 30.8, "max_draw_max": 34, "max_scene_nodes": 44, "max_nodes": 197},
	"leven_v1_plaat": {"max_proc_ms": 1.746, "max_draw_avg": 28.2, "max_draw_max": 30, "max_scene_nodes": 141, "max_nodes": 294},
	"leven_v3_combi": {"max_proc_ms": 1.705, "max_draw_avg": 31.5, "max_draw_max": 32, "max_scene_nodes": 114, "max_nodes": 267},
	"warper_exterieur": {"max_proc_ms": 1.69, "max_draw_avg": 28.2, "max_draw_max": 29, "max_scene_nodes": 28, "max_nodes": 181},
	"warper_hal": {"max_proc_ms": 1.69, "max_draw_avg": 54.3, "max_draw_max": 55, "max_scene_nodes": 111, "max_nodes": 269},
	"warper_hanger_nis": {"max_proc_ms": 1.675, "max_draw_avg": 27.0, "max_draw_max": 28, "max_scene_nodes": 23, "max_nodes": 176},
	"warper_warp_ring": {"max_proc_ms": 1.674, "max_draw_avg": 28.1, "max_draw_max": 29, "max_scene_nodes": 26, "max_nodes": 179},
	"wereldkaart": {"max_proc_ms": 1.697, "max_draw_avg": 26.1, "max_draw_max": 27, "max_scene_nodes": 46, "max_nodes": 199},
	"wilgendal": {"max_proc_ms": 1.743, "max_draw_avg": 41.1, "max_draw_max": 42, "max_scene_nodes": 80, "max_nodes": 233},
	"wilgendal_binnen": {"max_proc_ms": 1.682, "max_draw_avg": 30.4, "max_draw_max": 31, "max_scene_nodes": 30, "max_nodes": 183},
	"woud_mistpoel": {"max_proc_ms": 1.756, "max_draw_avg": 37.3, "max_draw_max": 38, "max_scene_nodes": 65, "max_nodes": 218},
	"woud_open_plek": {"max_proc_ms": 1.744, "max_draw_avg": 37.8, "max_draw_max": 39, "max_scene_nodes": 62, "max_nodes": 215},
	"woud_pad": {"max_proc_ms": 1.731, "max_draw_avg": 36.2, "max_draw_max": 37, "max_scene_nodes": 64, "max_nodes": 217},
	"woud_rand": {"max_proc_ms": 1.748, "max_draw_avg": 40.2, "max_draw_max": 41, "max_scene_nodes": 63, "max_nodes": 216},
	"woud_sporenkring": {"max_proc_ms": 1.736, "max_draw_avg": 38.2, "max_draw_max": 39, "max_scene_nodes": 61, "max_nodes": 214},
}


static func limit(room_id: String) -> Dictionary:
	return LIMITS.get(room_id, {})


static func has_room(room_id: String) -> bool:
	return LIMITS.has(room_id)
