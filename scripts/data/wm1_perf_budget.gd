class_name Wm1PerfBudget
extends RefCounted
## Vaste drempels voor --wm1budgettest (WM1). Baseline: Godot 4.3-stable headless via xvfb-run,
## opengl3, viewport 384×216, warmup 30 + 180 meetframes (scripts/perf/wm1_frametime.gd).
## Drempels = gemeten waarde + marge (proc_ms +35% +1,5 ms; draw +3; scene_nodes +8; nodes +120).
## Opnieuw gemeten 5 nov 2026 op finish/wm1 (7fce674) met --wm1frametest; Archief 2 en bibliotheek tekenen meer sinds
## walk5/1.4x-kas. Let op: --wm1budgettest zelf meet dorp_wilgendal, huis_wilgendal en woud_beek 2-4x hoger dan
## --wm1frametest (scene_nodes 1679 i.p.v. 838): ONVERIFIED of dat volgorde-lek in de suite is of echt; zie FINISH_LOG R5.
## Zie docs/perf_wm1.md. Opnieuw genereren: run_suite.sh wm1frametest | python3 tools/perf/wm1_budget_from_log.py

const WARMUP_FRAMES := 30
const SAMPLE_FRAMES := 180

const LIMITS: Dictionary = {
	# archief_2_v1_entree en archief_2_warper schommelen per run (83-100 / 72-95, sfeer-animatie): draw_avg-grens = draw_max.
	"archief_2_v1_entree": {"max_proc_ms": 2.02, "max_draw_avg": 135.0, "max_draw_max": 135, "max_scene_nodes": 49, "max_nodes": 202},
	"archief_2_v1_plaat": {"max_proc_ms": 1.912, "max_draw_avg": 129.3, "max_draw_max": 130, "max_scene_nodes": 38, "max_nodes": 191},
	"archief_2_v2_gang": {"max_proc_ms": 1.927, "max_draw_avg": 131.2, "max_draw_max": 132, "max_scene_nodes": 44, "max_nodes": 197},
	"archief_2_v2_lotte": {"max_proc_ms": 1.943, "max_draw_avg": 129.1, "max_draw_max": 130, "max_scene_nodes": 38, "max_nodes": 191},
	"archief_2_v3_ketting": {"max_proc_ms": 1.913, "max_draw_avg": 130.2, "max_draw_max": 131, "max_scene_nodes": 47, "max_nodes": 200},
	"archief_2_v3_licht": {"max_proc_ms": 1.974, "max_draw_avg": 129.2, "max_draw_max": 130, "max_scene_nodes": 38, "max_nodes": 191},
	"archief_2_v3_tegen": {"max_proc_ms": 1.887, "max_draw_avg": 129.2, "max_draw_max": 130, "max_scene_nodes": 38, "max_nodes": 191},
	"archief_2_v3_wurger": {"max_proc_ms": 1.885, "max_draw_avg": 131.2, "max_draw_max": 132, "max_scene_nodes": 44, "max_nodes": 197},
	"archief_2_v4_genezer": {"max_proc_ms": 1.896, "max_draw_avg": 131.3, "max_draw_max": 132, "max_scene_nodes": 86, "max_nodes": 239},
	"archief_2_v4_hal": {"max_proc_ms": 1.851, "max_draw_avg": 129.2, "max_draw_max": 130, "max_scene_nodes": 38, "max_nodes": 191},
	"archief_2_warper": {"max_proc_ms": 2.091, "max_draw_avg": 146.0, "max_draw_max": 146, "max_scene_nodes": 43, "max_nodes": 196},
	"archief_bibliotheek": {"max_proc_ms": 2.036, "max_draw_avg": 169.2, "max_draw_max": 170, "max_scene_nodes": 61, "max_nodes": 214},
	"archief_golemhal": {"max_proc_ms": 1.931, "max_draw_avg": 147.3, "max_draw_max": 148, "max_scene_nodes": 40, "max_nodes": 193},
	"archief_ingang": {"max_proc_ms": 2.024, "max_draw_avg": 150.1, "max_draw_max": 151, "max_scene_nodes": 48, "max_nodes": 201},
	"archief_puzzel": {"max_proc_ms": 2.017, "max_draw_avg": 156.1, "max_draw_max": 157, "max_scene_nodes": 155, "max_nodes": 308},
	"archief_v1_gang": {"max_proc_ms": 1.952, "max_draw_avg": 149.3, "max_draw_max": 150, "max_scene_nodes": 52, "max_nodes": 205},
	"archief_v2_kastenzaal": {"max_proc_ms": 1.991, "max_draw_avg": 146.3, "max_draw_max": 147, "max_scene_nodes": 36, "max_nodes": 189},
	"archief_v2_leeszaal": {"max_proc_ms": 1.962, "max_draw_avg": 146.0, "max_draw_max": 147, "max_scene_nodes": 46, "max_nodes": 199},
	"archief_v2_trapzaal": {"max_proc_ms": 1.935, "max_draw_avg": 148.3, "max_draw_max": 149, "max_scene_nodes": 44, "max_nodes": 197},
	"archief_v3_gang": {"max_proc_ms": 2.074, "max_draw_avg": 145.4, "max_draw_max": 146, "max_scene_nodes": 40, "max_nodes": 193},
	"archief_v3_zuilenhal": {"max_proc_ms": 1.958, "max_draw_avg": 149.1, "max_draw_max": 150, "max_scene_nodes": 53, "max_nodes": 206},
	"archief_v4_voorhal": {"max_proc_ms": 1.95, "max_draw_avg": 146.3, "max_draw_max": 147, "max_scene_nodes": 43, "max_nodes": 196},
	"archief_v4_wachtersgang": {"max_proc_ms": 1.844, "max_draw_avg": 149.3, "max_draw_max": 150, "max_scene_nodes": 46, "max_nodes": 199},
	"berggrot_bouwplaats": {"max_proc_ms": 1.955, "max_draw_avg": 151.2, "max_draw_max": 152, "max_scene_nodes": 57, "max_nodes": 210},
	"berggrot_geheim": {"max_proc_ms": 1.985, "max_draw_avg": 152.1, "max_draw_max": 153, "max_scene_nodes": 134, "max_nodes": 287},
	"berggrot_grendel": {"max_proc_ms": 1.952, "max_draw_avg": 148.3, "max_draw_max": 149, "max_scene_nodes": 90, "max_nodes": 243},
	"berggrot_mond": {"max_proc_ms": 2.035, "max_draw_avg": 148.3, "max_draw_max": 149, "max_scene_nodes": 46, "max_nodes": 199},
	"berggrot_nerf": {"max_proc_ms": 1.994, "max_draw_avg": 148.2, "max_draw_max": 149, "max_scene_nodes": 46, "max_nodes": 199},
	"berggrot_uitmond": {"max_proc_ms": 2.013, "max_draw_avg": 147.4, "max_draw_max": 148, "max_scene_nodes": 43, "max_nodes": 196},
	"dorp_wilgendal": {"max_proc_ms": 1.948, "max_draw_avg": 211.3, "max_draw_max": 212, "max_scene_nodes": 838, "max_nodes": 991},
	"esdoorn": {"max_proc_ms": 1.828, "max_draw_avg": 143.3, "max_draw_max": 144, "max_scene_nodes": 59, "max_nodes": 212},
	"esdoorn_herberg": {"max_proc_ms": 1.952, "max_draw_avg": 144.3, "max_draw_max": 145, "max_scene_nodes": 30, "max_nodes": 183},
	"esdoorn_huis_noor": {"max_proc_ms": 1.937, "max_draw_avg": 142.2, "max_draw_max": 143, "max_scene_nodes": 26, "max_nodes": 179},
	"huis_wilgendal": {"max_proc_ms": 1.919, "max_draw_avg": 145.2, "max_draw_max": 146, "max_scene_nodes": 39, "max_nodes": 192},
	"kamer_beeldkamer": {"max_proc_ms": 1.812, "max_draw_avg": 147.2, "max_draw_max": 148, "max_scene_nodes": 35, "max_nodes": 188},
	"kamer_echo_kamer": {"max_proc_ms": 1.885, "max_draw_avg": 154.2, "max_draw_max": 155, "max_scene_nodes": 46, "max_nodes": 199},
	"kamer_hal": {"max_proc_ms": 1.964, "max_draw_avg": 147.2, "max_draw_max": 148, "max_scene_nodes": 69, "max_nodes": 222},
	"kamer_handelskamer": {"max_proc_ms": 1.901, "max_draw_avg": 144.4, "max_draw_max": 145, "max_scene_nodes": 31, "max_nodes": 184},
	"kamer_kern": {"max_proc_ms": 1.923, "max_draw_avg": 144.2, "max_draw_max": 145, "max_scene_nodes": 31, "max_nodes": 184},
	"kamer_rustkamer": {"max_proc_ms": 1.802, "max_draw_avg": 148.2, "max_draw_max": 149, "max_scene_nodes": 39, "max_nodes": 192},
	"kamer_trainingshal": {"max_proc_ms": 1.935, "max_draw_avg": 145.3, "max_draw_max": 146, "max_scene_nodes": 31, "max_nodes": 184},
	"kamer_werkplaats": {"max_proc_ms": 1.879, "max_draw_avg": 144.4, "max_draw_max": 145, "max_scene_nodes": 31, "max_nodes": 184},
	"leven_ingang": {"max_proc_ms": 2.032, "max_draw_avg": 90.5, "max_draw_max": 133, "max_scene_nodes": 44, "max_nodes": 197},
	"leven_v1_plaat": {"max_proc_ms": 2.002, "max_draw_avg": 130.2, "max_draw_max": 131, "max_scene_nodes": 141, "max_nodes": 294},
	"leven_v2_leeszaal": {"max_proc_ms": 1.964, "max_draw_avg": 135.3, "max_draw_max": 136, "max_scene_nodes": 109, "max_nodes": 262},
	"leven_v3_combi": {"max_proc_ms": 1.95, "max_draw_avg": 132.3, "max_draw_max": 133, "max_scene_nodes": 114, "max_nodes": 267},
	"warper_exterieur": {"max_proc_ms": 1.951, "max_draw_avg": 129.2, "max_draw_max": 130, "max_scene_nodes": 28, "max_nodes": 181},
	"warper_hal": {"max_proc_ms": 1.94, "max_draw_avg": 208.4, "max_draw_max": 209, "max_scene_nodes": 111, "max_nodes": 266},
	"warper_hanger_nis": {"max_proc_ms": 1.836, "max_draw_avg": 128.4, "max_draw_max": 129, "max_scene_nodes": 23, "max_nodes": 176},
	"warper_warp_ring": {"max_proc_ms": 1.982, "max_draw_avg": 129.2, "max_draw_max": 130, "max_scene_nodes": 26, "max_nodes": 179},
	"wereldkaart": {"max_proc_ms": 1.846, "max_draw_avg": 127.3, "max_draw_max": 128, "max_scene_nodes": 46, "max_nodes": 199},
	"wilgendal": {"max_proc_ms": 1.983, "max_draw_avg": 142.4, "max_draw_max": 143, "max_scene_nodes": 80, "max_nodes": 233},
	"wilgendal_binnen": {"max_proc_ms": 1.894, "max_draw_avg": 130.3, "max_draw_max": 131, "max_scene_nodes": 30, "max_nodes": 183},
	"woud_beek": {"max_proc_ms": 1.893, "max_draw_avg": 127.1, "max_draw_max": 128, "max_scene_nodes": 33, "max_nodes": 186},
	"woud_mistpoel": {"max_proc_ms": 2.0, "max_draw_avg": 138.2, "max_draw_max": 139, "max_scene_nodes": 65, "max_nodes": 218},
	"woud_open_plek": {"max_proc_ms": 2.039, "max_draw_avg": 138.5, "max_draw_max": 140, "max_scene_nodes": 62, "max_nodes": 215},
	"woud_pad": {"max_proc_ms": 1.981, "max_draw_avg": 137.3, "max_draw_max": 138, "max_scene_nodes": 69, "max_nodes": 222},
	"woud_rand": {"max_proc_ms": 2.021, "max_draw_avg": 141.1, "max_draw_max": 142, "max_scene_nodes": 63, "max_nodes": 216},
	"woud_sporenkring": {"max_proc_ms": 1.906, "max_draw_avg": 139.3, "max_draw_max": 140, "max_scene_nodes": 61, "max_nodes": 214},
}


static func limit(room_id: String) -> Dictionary:
	return LIMITS.get(room_id, {})


static func has_room(room_id: String) -> bool:
	return LIMITS.has(room_id)
