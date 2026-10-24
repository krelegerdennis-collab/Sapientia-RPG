## SoM-PROEF (Secret of Mana-stijl realtime gevecht) — alle instellingen/content op één plek.
## Schakelaar: ENABLED (hoofdschakelaar) + ROOMS (alleen deze WM1-kamers). Daarbuiten, en als
## GameState.som_mode uit staat (het gewone spel), blijven de turn-based gevechten precies zoals ze waren.
## Bazen (monster met "boss": true) blijven ALTIJD turn-based, ook in een SoM-kamer en ook bij Battle Style = Action
## (Dennis, 21 okt 2026). De Action-baasvermenigvuldiger (ACTION_BOSS_MULT) wordt daarom NIET meer gebruikt.
extends RefCounted

## Hoofdschakelaar. false = de proef bestaat niet (geen realtime, knop op het titelscherm doet niets).
const ENABLED := true
## Kamers (room_id uit dungeon_rooms.gd, alleen WM1) waar realtime geldt bij Battle Style = Action
## (Settings) of GameState.som_mode (knop "SoM" op het titelscherm).
const ROOMS: Array[String] = ["archief_v1_gang", "archief_v2_kastenzaal", "archief_v2_leeszaal",
		"archief_v2_trapzaal", "archief_v3_gang", "archief_v3_zuilenhal"]
## Startpunt van de knop "SoM" op het titelscherm.
const START_MAP := "res://scenes/maps/archief_v1_gang.tscn"
const START_SPAWN := "zuid"
const SAVE_PATH := "user://som_save_1.json"
const AUTOSAVE_PATH := "user://som_autosave.json"

## Standaard-party van de proef (Dax + Vesper/Seren voor spreuken in het ringmenu).
const START_LEVEL := 3
const START_MEMBERS: Array[String] = ["noor", "lotte"]
const START_GEAR: Array[String] = ["vonkzwaard", "houten_schild", "leren_kap"]
const START_ITEMS := {"drankje": 5, "kruid": 3, "toverwater": 2, "feniksveer": 2}
const START_GOLD := 50

## --- speler ---
## Analoge beweging (Action): topsnelheid (px/s) en dode zone van de joystick (deel van de straal).
const MOVE_SPEED := 80.0
const JOY_DEADZONE := 0.2
## Kaartsprites per held-id in Action (24x32, MapSprite.NIEUW; voeten op de tegelrand = offset (0,-8)).
## Seren/Vesper: goedgekeurde final_trio-sheets van RPG ART (seren_wm1.png / vesper.png); Dax: slanke WM1-sheet.
const SHEETS := {
	"dennis": "res://assets/sprites/som/kaart/dax_wm1_slim.png",
	"noor": "res://assets/sprites/som/kaart/vesper.png",
	"lotte": "res://assets/sprites/som/kaart/seren_wm1.png",
	"kael": "res://assets/sprites/som/kaart/kael_wm1_slim.png",
	"orion": "res://assets/sprites/som/kaart/orion_wm1_slim.png",
}
## Wisselvolgorde (SWITCH-knop / toets C): Dax -> Seren -> Vesper; KO wordt overgeslagen.
const SWITCH_ORDER: Array[String] = ["dennis", "lotte", "noor", "kael", "orion"]
## Camera glijdt naar de nieuwe held (Camera2D position_smoothing_speed).
const CAMERA_SMOOTH := 7.0
## Lichaamsmidden t.o.v. de node (voeten op +8, 24x32-frame -> midden op -8). Slag/raakpunt rekent hiervandaan.
const BODY_Y := -6.0
## AANVALSANIMATIES van RPG ART (assets/sprites/som/combat/, README van combat_som):
## sheet 288x192 = 6 kolommen x 4 rijen (onder, links, rechts, boven), frames 48x48; het 24x32-loopframe
## zit op (12,16) in elke cel, dus de voeten liggen op de onderrand (= de voetlijn van de loopsheet).
## "ms" = duur per frame; de treffer valt aan het BEGIN van frame "hit_frame" (1-based).
## Ontbreekt de sheet: magenta placeholder-boog en de treffer valt meteen.
const ATTACK_FRAME := [48, 48]
const ATTACK_MS: Array[int] = [120, 180, 50, 110, 90, 160]
const ATTACK_HIT_FRAME := 4
const ATTACK_ANIMS := {
	"dennis": {"sheet": "res://assets/sprites/som/combat/dax_attack.png", "frame": ATTACK_FRAME, "frames": 6, "ms": ATTACK_MS, "hit_frame": ATTACK_HIT_FRAME},
	"noor": {"sheet": "res://assets/sprites/som/combat/vesper_attack.png", "frame": ATTACK_FRAME, "frames": 6, "ms": ATTACK_MS, "hit_frame": ATTACK_HIT_FRAME},
	"lotte": {"sheet": "res://assets/sprites/som/combat/seren_attack.png", "frame": ATTACK_FRAME, "frames": 6, "ms": ATTACK_MS, "hit_frame": ATTACK_HIT_FRAME},
	# Rekruten (World Warper): RPG ART wm1_combat 8.5 (Kael prisma-straal, Orion boog)
	"kael": {"sheet": "res://assets/sprites/som/combat/kael_attack.png", "frame": ATTACK_FRAME, "frames": 6, "ms": ATTACK_MS, "hit_frame": ATTACK_HIT_FRAME},
	"orion": {"sheet": "res://assets/sprites/som/combat/orion_attack.png", "frame": ATTACK_FRAME, "frames": 6, "ms": ATTACK_MS, "hit_frame": ATTACK_HIT_FRAME},
}
## Langer bereik per held (px, i.p.v. ATTACK_REACH/ATTACK_OFFSET): Kael's prisma-straal en Orion's pijl.
const ATTACK_RANGE_BY_HERO := {"kael": {"offset": 18.0, "reach": 20.0}, "orion": {"offset": 30.0, "reach": 26.0}}


static func attack_offset(id: String) -> float:
	return float(ATTACK_RANGE_BY_HERO.get(id, {}).get("offset", ATTACK_OFFSET))


static func attack_reach(id: String) -> float:
	return float(ATTACK_RANGE_BY_HERO.get(id, {}).get("reach", ATTACK_REACH))
## Overige held-poses (48x48, zelfde anker): hurt = 4 kolommen (onder, links, rechts, boven) x 1 rij,
## ko = 1 frame, cast = 3 kolommen x 4 rijen (frame 1 200 ms, daarna 2-3 in een lus van 120 ms).
const HERO_POSES := {
	"dennis": {"hurt": "res://assets/sprites/som/combat/dax_hurt.png", "dodge": "res://assets/sprites/som/combat/dax_dodge.png", "ko": "res://assets/sprites/som/combat/dax_ko.png"},
	"noor": {"hurt": "res://assets/sprites/som/combat/vesper_hurt.png", "dodge": "res://assets/sprites/som/combat/vesper_dodge.png", "ko": "res://assets/sprites/som/combat/vesper_ko.png",
			"cast": "res://assets/sprites/som/combat/vesper_cast6.png"},
	"lotte": {"hurt": "res://assets/sprites/som/combat/seren_hurt.png", "dodge": "res://assets/sprites/som/combat/seren_dodge.png", "ko": "res://assets/sprites/som/combat/seren_ko.png",
			"cast": "res://assets/sprites/som/combat/seren_cast6.png"},
	"kael": {"hurt": "res://assets/sprites/som/combat/kael_hurt.png", "dodge": "res://assets/sprites/som/combat/kael_dodge.png", "ko": "res://assets/sprites/som/combat/kael_ko.png",
			"cast": "res://assets/sprites/som/combat/kael_cast.png"},
	"orion": {"hurt": "res://assets/sprites/som/combat/orion_hurt.png", "dodge": "res://assets/sprites/som/combat/orion_dodge.png", "ko": "res://assets/sprites/som/combat/orion_ko.png",
			"cast": "res://assets/sprites/som/combat/orion_cast.png"},
}
const HURT_TIME := 0.25
## Ontwijk-pose (<held>_dodge.png 192x48, 4 richtingen zoals hurt): een vijandelijke klap die tijdens de
## onkwetsbaarheid (iframes) binnenkomt, wordt zichtbaar ontweken in plaats van stil genegeerd.
const DODGE_TIME := 0.22
const CAST_MS: Array[int] = [200, 120, 120, 120, 120]      # oude 3-frame cast-sheet (fallback)
## Magiër-cast (RPG ART pass 7): <held>_cast6.png 288x192, cellen 48x48, 6 frames x 4 richtingen.
## De spreuk komt vrij aan het begin van frame 4 (hit_frame): dan pas schade/genezing + effect.
const CAST6 := {"frame": [48, 48], "frames": 6, "ms": [160, 180, 200, 120, 160, 200], "hit_frame": 4}
## Cirkel onder de caster tijdens het casten (lus, achter de held, midden op de voeten).
const CAST_CIRCLE := {
	"lotte": "res://assets/sprites/som/fx/cast_circle_seren.png",
	"noor": "res://assets/sprites/som/fx/cast_circle_vesper.png",
}
const CAST_CIRCLE_CELL := [48, 16]
## Kaart-cast (RPG ART art_cast v9): 24x32-cellen zoals de loopsheet (zelfde anker), 4 frames
## (verzamelen, gloed, loslaten, herstel) x 4 rijen (omlaag, links, rechts, omhoog). Gaat voor op cast6:
## de held blijft zijn eigen kaartfiguur. De spreuk komt vrij aan het begin van frame 2 ('release'),
## dan verschijnt ook de cast-gloed (castfx, 4 x 24x24, midden op de staf).
const MAP_CAST := {
	"lotte": {"sheet": "res://assets/sprites/som/cast/seren_cast.png", "fx": "res://assets/sprites/som/cast/seren_castfx.png"},
	"noor": {"sheet": "res://assets/sprites/som/cast/vesper_cast.png", "fx": "res://assets/sprites/som/cast/vesper_castfx.png"},
}
const MAP_CAST_CELL := [24, 32]
const MAP_CAST_MS := [150, 170, 130, 170]
const MAP_CAST_RELEASE := 2
const MAP_CAST_FX_CELL := [24, 24]
const MAP_CAST_FX_MS := 80
## Midden van de cast-gloed t.o.v. de held-node (voeten op +8): boven het hoofd, iets naar de kijkrichting.
const MAP_CAST_FX_POS := Vector2(0, -18)
const MAP_CAST_FX_SIDE := 7.0
const CAST_CIRCLE_MS := 90
## Spreuk-effecten, onderkant-midden op de voeten van het doel. Aantal frames = breedte / cel (uit de sheet).
const SPELL_FX := {
	"vuur": {"sheet": "res://assets/sprites/som/fx/spell_vuur.png", "cell": [32, 48]},
	"bliksem": {"sheet": "res://assets/sprites/som/fx/spell_bliksem.png", "cell": [32, 48]},
	"vonk": {"sheet": "res://assets/sprites/som/fx/spell_vonk.png", "cell": [32, 32]},
	"genees": {"sheet": "res://assets/sprites/som/fx/spell_genees.png", "cell": [32, 48]},
}
const SPELL_FX_MS := 90
## Andere spreuken: per element, anders per type (damage -> vonk, heal -> genees).
const SPELL_FX_BY_ELEMENT := {"vuur": "vuur", "bliksem": "bliksem", "licht": "genees"}
const SPELL_FX_BY_TYPE := {"damage": "vonk", "heal": "genees"}
## Vijand-sheets (assets/sprites/som/monsters/<enemy>_attack|hurt|death.png, 16x16 frames):
## attack 3 kolommen (opladen, uithaal, terug) x 4 rijen; hurt 4 kolommen (richtingen); death 4 frames.
## Duur aanval: opladen = de telegraaf (TELEGRAPH), uithaal 110 ms, terug 300 ms. Dood: 4 x 100 ms.
const MONSTER_SHEET_DIR := "res://assets/sprites/som/monsters/"
## Monster-sheets (RPG ART pass 9). cell = framegrootte, cols x rows (rij = richting), offset = waar de cel
## t.o.v. de 16x16-mapsprite getekend wordt (linksboven), ms = duur per kolom.
const MONSTER_SHEETS := {
	"attack": {"cell": [32, 24], "cols": 3, "rows": 4, "offset": [-8, -8]},
	"hurt": {"cell": [16, 16], "cols": 2, "rows": 4, "offset": [0, 0], "ms": [70, 220]},
	"death": {"cell": [24, 24], "cols": 4, "rows": 1, "offset": [-4, -8], "ms": [100, 100, 100, 100]},
}
const MONSTER_STRIKE_MS := 110
const MONSTER_RETURN_MS := 300
const MONSTER_DEATH_MS := 100
## FX/UI (assets/sprites/som/fx|ui). Ontbreekt een bestand: de placeholder in code.
const FX_SLASH := "res://assets/sprites/som/fx/fx_slash.png"          # 128x32, 4 frames 32x32
const FX_SPARK := "res://assets/sprites/som/fx/fx_hit_spark.png"      # 64x16, 4 frames 16x16
## Eenmalige effecten: sheet, celgrootte, frames, ms per frame, anker (voeten) in de cel.
const FX_HEAL_GLOW := {"sheet": "res://assets/sprites/som/fx/fx_heal_glow.png", "cell": [16, 16], "frames": 4, "ms": 100, "anchor": [8, 16]}
const FX_SPELL_IMPACT := {"sheet": "res://assets/sprites/som/fx/fx_spell_impact.png", "cell": [24, 24], "frames": 4, "ms": 70, "anchor": [12, 24]}
const FX_TELEGRAPH := "res://assets/sprites/som/fx/fx_telegraph.png"  # 8x8
const UI_DIGITS := "res://assets/sprites/som/ui/dmg_digits.png"       # 50x21: rijen wit, rood, groen; cijfers 5x7
const UI_GAUGE_BAR := "res://assets/sprites/som/ui/gauge_bar.png"     # 18x4
const UI_GAUGE_FILL := "res://assets/sprites/som/ui/gauge_fill.png"   # 16x2 (op (1,1))
const UI_GAUGE_GLINT := "res://assets/sprites/som/ui/gauge_full_glint.png"  # 36x4, 2 frames
const UI_HUD_FRAME := "res://assets/sprites/som/ui/hud_frame.png"     # 72x20 per held
const UI_RING_BG := "res://assets/sprites/som/ui/ring_bg.png"         # 180x110
const UI_RING_ICONS := "res://assets/sprites/som/ui/ring_icons_9.png"  # 144x16, 9 iconen (7 = Phoenix Feather, 8 = Codex)
const UI_RING_ICONS_8 := "res://assets/sprites/som/ui/ring_icons_8.png"  # 128x16 (vorige batch; terugval)
const UI_RING_ICONS_FALLBACK := "res://assets/sprites/som/ui/ring_icons.png"   # 112x16, 7 iconen (eerste batch)
const UI_BTN := {   # 38x14, normaal / ingedrukt (RPG ART ui2)
	"swap": ["res://assets/sprites/som/ui/btn_swap.png", "res://assets/sprites/som/ui/btn_swap_pressed.png"],
	"ring": ["res://assets/sprites/som/ui/btn_ring.png", "res://assets/sprites/som/ui/btn_ring_pressed.png"],
	"codex": ["res://assets/sprites/som/ui/btn_codex.png", "res://assets/sprites/som/ui/btn_codex_pressed.png"],
}
const UI_JOY_RING := "res://assets/sprites/som/ui/joystick_ring.png"            # 60x60, midden (30,30)
const UI_JOY_KNOB := "res://assets/sprites/som/ui/joystick_knob.png"            # 24x24, midden (12,12)
const UI_JOY_KNOB_PRESSED := "res://assets/sprites/som/ui/joystick_knob_pressed.png"
const JOY_ART_RADIUS := 30.0     # straal van joystick_ring in art-pixels
const JOY_KNOB_TRAVEL := 18.0    # knopuitslag in art-pixels
## v3 HUD (feedback Dennis): joystick kleiner (x D-pad-straal) en hoger (midden-links, fractie van de hoogte).
const JOY_SCALE := 0.75
const JOY_CENTER_Y := 0.6
## Vinger telt binnen zoveel x de joystickstraal (ruim touch-doel, ook als de ring klein is).
const JOY_TOUCH_REACH := 2.2
## Bovenste rij rechts: [RUN][Swap][Ring][MENU]. Knop-art is 38x14; het touch-vak is groter (de art staat erin gecentreerd).
const TOP_BUTTON_SIZE := Vector2(46, 26)   # 48dp (UiTouch.MIN_UNITS): minimaal tikvlak
const TOP_BUTTON_GAP := 3.0
## Icoon-index in ring_icons.png per item/spreuk-id.
const RING_ICON := {"drankje": 0, "kruid": 1, "toverwater": 2, "genees": 4, "vuur": 5, "bliksem": 6, "feniksveer": 7, "codex": 8}
const RING_ICON_DAMAGE := 3
## Magie-ring (RPG ART batch 3): spell_icons.png 64x16, icoon n op x = 16n (vuur, bliksem, vonk, genezing).
const UI_SPELL_ICONS := "res://assets/sprites/som/ui/spell_icons.png"
const SPELL_ICON := {"vuur": 0, "bliksem": 1, "vonk": 2, "genees": 3}
## Andere spreuken: per type (damage -> vonk, heal -> genezing).
const SPELL_ICON_BY_TYPE := {"damage": 2, "heal": 3}
## Wapenmeter vol: gauge_ready_glow.png 72x4, 4 frames 18x4 van 90 ms (lus), zelfde anker als gauge_bar.
const UI_GAUGE_READY := "res://assets/sprites/som/ui/gauge_ready_glow.png"
const GAUGE_READY_MS := 90      # 'spark': elke andere aanvalsspreuk
## Seconden om de wapenmeter van 0 tot 100% te vullen.
const CHARGE_TIME := 1.0     # v3: --actionsim iteratie 7 (was 0.5)
## Slag onder 100%: schade x max(CHARGE_MIN_MULT, lading) (SoM: spammen loont niet).
const CHARGE_MIN_MULT := 0.1
## SoM-stijl: de meter vult pas weer als de slag-animatie klaar is (lading 0 tijdens de animatie).
const CHARGE_AFTER_ANIM := true
## Vijandschade in realtime x deze factor (zelfde formule als turn-based; balans via --actionsim).
const ENEMY_DAMAGE_MULT := 2.2     # v3: --actionsim iteratie 7
## Balans per gebied, ALLEEN in Action (som_arena.gd enemy_stats en --archief1balans). Classic (battle.gd) en
## bazen/unieke vijanden blijven ongemoeid. Zie BALANS_ARCHIEF1.md (meting met --archief1balans).
##   rooms      = room_id-voorvoegsels van het gebied
##   tier_level = verwacht level van Dax per archief-tier (kamer-tier uit dungeon_rooms.gd)
##   hp_hits    = vijand-HP wordt geklemd tussen [lo, hi] x de gemiddelde volle slag van een verse Dax op dat
##                level (nieuw spel, geen uitrusting) -> 3-4 volle slagen per gewone vijand
##   hits       = doelbereik (gemiddeld aantal volle slagen), bewaakt door de balanstest
##   atk        = standaardfactor op de realtime vijandschade (ENEMY_DAMAGE_MULT x atk). Bewust NIET op de
##                atk-stat: die is bij tier-1-vijanden zo klein (5-6) dat een factor op de stat in hele stappen
##                springt (0.9 -> 100% winst, 0.95 -> 45%); op de schade is hij fijn instelbaar.
##   cooldown   = standaardfactor op ATTACK_COOLDOWN
##   tiers      = per kamer-tier eigen "atk"/"cooldown" (overschrijft de standaard). Forge 21 okt: tier 1 mag
##                geen progressieblokkade zijn; daarna loopt het geleidelijk op.
##   targets    = doel per tier voor Dax solo op het verwachte level (sim, --archief1balans): "win" = [min, max]
##                winstkans, "loss" = [min, max] gemiddeld HP-verlies als fractie van max HP (optioneel).
##                Bewaakt door --balansarchief1test.
##   dodge_skill = ontwijkkans van een speler die de telegraaf leest (alleen meting, --archief1balans)
const ACTION_AREAS := {
	"archief1": {"rooms": ["archief_v1_", "archief_v2_", "archief_v3_", "archief_v4_"],
			"tier_level": {0: 1, 1: 1, 2: 2, 3: 3, 4: 4}, "hp_hits": [2.5, 3.0], "hits": [3.0, 3.5], "atk": 1.15, "cooldown": 1.6, "dodge_skill": 0.6,
			"tiers": {1: {"atk": 1.1, "cooldown": 3.0}, 2: {"atk": 1.0, "cooldown": 2.8},
					3: {"atk": 0.7, "cooldown": 2.8}, 4: {"atk": 0.7, "cooldown": 2.8}},
			# loss tier 1: Forge (21 okt): 89% winst / 77% verlies geaccepteerd, grens = gemiddeld verlies <= 80%.
			# Herstel: het opslagboek in archief_ingang (vlak voor archief_v1_gang) geneest de party vol.
			"targets": {1: {"win": [0.80, 0.90], "loss": [0.0, 0.80]}, 2: {"win": [0.70, 0.85]},
					3: {"win": [0.65, 0.80]}, 4: {"win": [0.60, 0.75]}}},
}


## Gebied-sleutel uit ACTION_AREAS voor deze kamer ("" = geen).
static func action_area(room_id: String) -> String:
	for k in ACTION_AREAS:
		for pre in ACTION_AREAS[k]["rooms"]:
			if room_id.begins_with(str(pre)):
				return k
	return ""


## ATK van een verse Dax (GameData.HEROES "dennis": basis + groei, geen uitrusting) op dit level.
static func fresh_dax_atk(level: int) -> float:
	var GD: Script = load("res://scripts/data/game_data.gd")
	for h in GD.HEROES:
		if str(h["id"]) == "dennis":
			return float(h["atk"]) + float(h["growth"]["atk"]) * float(maxi(0, level - 1))
	return 14.0


## Schadefactor van vijandaanvallen in realtime voor deze kamer (ENEMY_DAMAGE_MULT x gebieds-/tierfactor).
static func enemy_damage_mult(room_id: String, tier := 0) -> float:
	return ENEMY_DAMAGE_MULT * area_rule(room_id, tier, "atk")


## Regel "atk"/"cooldown" voor deze kamer en tier: tiers[tier] > gebiedsstandaard > 1.0.
static func area_rule(room_id: String, tier: int, key: String) -> float:
	var k := action_area(room_id)
	if k == "":
		return 1.0
	var a: Dictionary = ACTION_AREAS[k]
	var t: Dictionary = a.get("tiers", {}).get(tier, {})
	return float(t.get(key, a.get(key, 1.0)))


## Wachttijd tussen vijandaanvallen in deze kamer (ATTACK_COOLDOWN x gebieds-/tierfactor).
static func attack_cooldown(room_id: String, tier := 0) -> float:
	return ATTACK_COOLDOWN * area_rule(room_id, tier, "cooldown")


## Vijand-data met de Action-gebiedsregels (kopie). Bazen en unieke vijanden: ongewijzigd.
static func apply_action_area(d: Dictionary, room_id: String, tier := 0) -> Dictionary:
	var k := action_area(room_id)
	# NB: "boss" in de vijand-data (kennis_beest) is de config van het baasgevecht (turn-based); als gewone
	# vijand in de kamer telt hij gewoon mee. Baas-monsters op de kaart komen nooit in de arena (register).
	if k == "" or d.get("unique", false) or not d.has("max_hp"):
		return d
	var a: Dictionary = ACTION_AREAS[k]
	var out := d.duplicate(true)
	var lv := int(a["tier_level"].get(tier, a["tier_level"].get(0, 1)))
	var slag := maxf(1.0, fresh_dax_atk(lv) - float(d.get("def", 0)) / 2.0)
	var hh: Array = a["hp_hits"]
	out["max_hp"] = maxi(1, roundi(clampf(float(d["max_hp"]), slag * float(hh[0]), slag * float(hh[1]))))
	return out


## Bereik van een slag (px, vanaf een punt 10 px voor de speler).
const ATTACK_REACH := 14.0
const ATTACK_OFFSET := 12.0
## Knockback van een geraakte vijand (px) en duur (s).
const KNOCKBACK_PX := 12.0
const KNOCKBACK_TIME := 0.15
## Onkwetsbaar na een treffer (s).
const PLAYER_IFRAMES := 0.8
## Vertraging tussen sluiten van het ringmenu en het effect (s): de keuze "landt" in realtime.
const RING_CAST_DELAY := 0.35

## --- bondgenoten (AI, SoM-stijl): Vesper en Seren vechten mee ---
## Formatie: plekken achter Dax (in px, t.o.v. zijn kijkrichting: x = opzij, y = erachter).
const FORMATION := [Vector2(-10, 18), Vector2(10, 18), Vector2(0, 32)]
const ALLY_SPEED := 78.0
## Dichter bij het doel dan dit = stilstaan.
const ALLY_ARRIVE := 5.0
## Verder dan dit van Dax (px) = meteen bijteleporteren (buiten beeld).
const ALLY_TELEPORT_DIST := 170.0
## Zo lang (s) geen voortgang terwijl hij wil lopen = vast -> bijteleporteren.
const ALLY_STUCK_TIME := 1.5
## Vijanden binnen deze afstand van Dax worden aangevallen.
const ALLY_ENGAGE_RANGE := 72.0
## Onder dit deel HP: afstand houden (weg van de dichtstbijzijnde vijand).
const ALLY_LOW_HP := 0.3
const ALLY_FLEE_DIST := 40.0
## Spreuk-ritme (s) en genezen als een partylid onder dit deel HP zit (eerst genezen).
const ALLY_SPELL_CD := 2.5
const ALLY_HEAL_BELOW := 0.4
## Kans per spreuk-moment op een aanvalsspreuk (als er MP en een vijand is).
const ALLY_DAMAGE_SPELL_CHANCE := 0.5

## --- vijanden ---
## Elke zoveel seconden een stap richting de speler (binnen CHASE_RANGE tiles).
const CHASE_INTERVAL := 0.45
const CHASE_RANGE := 7
## Aanval: telegraaf (knipperen + "!") en daarna cooldown.
const TELEGRAPH := 0.45     # v3: --actionsim iteratie 7 (was 0.55)
const ATTACK_COOLDOWN := 1.2     # v3: --actionsim iteratie 7 (was 1.6)
## Afstand (px, middelpunten) waarop een vijand kan aanvallen/raken.
const ENEMY_REACH := 22.0
const HIT_FLASH := 0.12

## --- Skill-ring: technieken per held-id (vragen een volle wapenmeter). radius > 0 = rondom.
const SKILLS := {
	"dennis": [{"id": "wervelslag", "name": "Whirl Slash", "mult": 0.9, "radius": 30.0}],
	"lotte": [{"id": "staafstoot", "name": "Staff Smash", "mult": 1.5, "radius": 0.0}],
	"noor": [{"id": "vonkstoot", "name": "Arc Jab", "mult": 1.3, "radius": 0.0}],
	"kael": [{"id": "prismaring", "name": "Prism Ring", "mult": 0.8, "radius": 32.0}],
	"orion": [{"id": "scherpschot", "name": "Piercing Shot", "mult": 1.6, "radius": 0.0}],
}

## --- B = toveren (alleen Seren/Vesper als bestuurde held) ---
## Snelspreuk per held-id: heal -> partylid met het laagste HP-deel; damage -> dichtstbijzijnde vijand.
const B_MAGIC := {"lotte": "genees", "noor": "vuur", "kael": "vonk"}
## Minimale tijd (s) tussen twee B-spreuken.
const B_CAST_COOLDOWN := 1.0
## Bereik (px) waarbinnen een spreuk een vijand kan kiezen.
const SPELL_RANGE := 160.0

## Speler-tekst (Engels).
const TXT_RING := "Ring"
const TXT_ITEMS := "Items"
const TXT_SKILLS := "Skills"
## ONGEBRUIKT sinds 21 okt 2026 (alle bazen turn-based, ook in Action): data blijft voor de simulator/historie,
## battle.gd past hem niet meer toe. Oud: ACTION-MODUS BAZEN: in Action/SoM-modus (GameState.som_mode of Settings Battle Style = Action) krijgt een
## baasgevecht (niet de dungeon van 100) deze vermenigvuldigers bovenop de baas-stats. Classic blijft ongewijzigd.
## Getuned met -- --actionsim (docs/ACTION_BALANCE_REPORT.md): doel 60-80% winst op Lv 3 en Lv 5.
## Eén vaste vermenigvuldiger haalde nooit Lv 3 EN Lv 5 tegelijk (zie rapport): daarom basis (op START_LEVEL)
## plus een toename per gemiddeld partylevel boven START_LEVEL (ACTION_BOSS_PER_LEVEL, nooit onder de basis).
const ACTION_BOSS_MULT := {"max_hp": 2.3, "atk": 1.6}
const ACTION_BOSS_PER_LEVEL := {"atk": 0.35}
## Alleen voor de simulator: andere waarden proberen ({"mult": {...}, "per_level": {...}}; {} = de consts).
static var action_boss_override: Dictionary = {}


## Baas-data voor Action-modus; on == false (Classic) = exact dezelfde data terug.
static func action_boss(data: Dictionary, on: bool, party_level: float = START_LEVEL) -> Dictionary:
	if not on:
		return data
	var m := action_boss_mult(party_level)
	var out := data.duplicate(true)
	for k in m:
		if out.has(k):
			out[k] = maxi(1, roundi(float(out[k]) * float(m[k])))
	return out


## Vermenigvuldigers bij een gemiddeld partylevel.
static func action_boss_mult(party_level: float) -> Dictionary:
	var base: Dictionary = action_boss_override.get("mult", ACTION_BOSS_MULT)
	var per: Dictionary = action_boss_override.get("per_level", ACTION_BOSS_PER_LEVEL)
	var extra := maxf(0.0, party_level - float(START_LEVEL))
	var m := base.duplicate()
	for k in per:
		m[k] = float(m.get(k, 1.0)) + float(per[k]) * extra
	return m


## Ring-opmaak: max. lengte kort label (zonder icoon) en ruimte tussen ring, kop en naamregel.
const RING_SHORT_MAX := 7
const RING_LABEL_GAP := 4.0
## Halve dikte van de ringband (ring_bg.png): binnenrand = ringstraal - dit.
const RING_BAND_HALF := Vector2(12, 7)
## Minimale marge (px) tussen een aantal-label ("x3") en de binnenrand van de ring.
const RING_COUNT_MARGIN := 3.0
const TXT_MAGIC := "Magic"
const TXT_TARGET := "%s: target?"
const TXT_ALL_ENEMIES := "All enemies"
const TXT_NOT_READY := "Not ready yet!"
const TXT_NO_MP := "Not enough MP."
const TXT_NO_TARGET := "No enemy in range."
const TXT_NO_WOUNDED := "Nobody needs healing."
const TXT_FALLEN := "%s has fallen..."
const TXT_LEVEL := "%s is now level %d!"
const TXT_GOT := "Got %s!"
const TXT_EXP := "+%d EXP  +%d G"
const TXT_KO := "%s is down!"
const TXT_SWITCH := "Swap"
## Codex vangen in Action (zelfde regels als Classic, scripts/som/som_codex.gd)
const TXT_CODEX := "Codex"
const TXT_CODEX_ENTRY := "Capture Book x%d"
const TXT_CODEX_NO_BOOK := "No Blank Book left."
const TXT_CODEX_BUSY := "The Codex is still writing..."
const TXT_CODEX_GONE := "The target is gone. (The book stays whole.)"
const TXT_CODEX_DOWN := "Nobody can hold the book."
## Vang-effect (RPG ART): 6 frames van 48x48, midden (24,24); 70 ms per frame, frame 4 100 ms.
const FX_CODEX_CAPTURE := {"sheet": "res://assets/sprites/som/fx/codex_capture_fx.png", "cell": [48, 48], "frames": 6,
		"ms": [70, 70, 70, 100, 70, 70], "anchor": [24, 24]}
const TXT_NOW := "Now playing: %s"
const TXT_MISS_BUFF := "%s has no effect in real time yet."

## Doel-lock HUD (handwerk assets/ui/lock/): marker (lus) + wissel (eenmalig bij nieuw doel).
const TARGET_LOCK := {
	"marker": "res://assets/ui/lock/lock_marker.png",
	"wissel": "res://assets/ui/lock/lock_wissel.png",
	"marker_frames": 4,
	"wissel_frames": 3,
	"marker_fps": 8.0,
	"wissel_fps": 12.0,
	"marker_anchor": [8, 16],
	"wissel_anchor": [8, 16],
}


static func room_enabled(room_id: String, action: bool) -> bool:
	return ENABLED and action and is_wm1_room(room_id)


## Forge/Dennis (21 okt 2026): Action geldt in ALLE WM1-dungeons: Archief 1 (dungeon_rooms.gd), Donker Woud
## (woud_rooms.gd), Archief 2 + Leven (archief2_rooms.gd, ROOMS en rooms()), Berggrot (berggrot_data.gd).
## Niet in de dungeon van 100. ROOMS hierboven blijft de balans-set van de actie-simulator (--actionsim).
static func is_wm1_room(room_id: String) -> bool:
	if room_id == "" or room_id.begins_with("dungeon100_"):
		return false
	return wm1_rooms().has(room_id)


static func wm1_rooms() -> Array[String]:
	var out: Array[String] = []
	var DR: Script = load("res://scripts/data/dungeon_rooms.gd")
	var bronnen: Array = [DR.ROOMS, DR.woud().ROOMS, DR.archief2().ROOMS, DR.archief2().rooms(), DR.berggrot().ROOMS]
	for bron in bronnen:
		for id in (bron as Dictionary).keys():
			if not out.has(str(id)) and not str(id).begins_with("dungeon100_"):
				out.append(str(id))
	return out
