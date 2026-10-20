## SoM-PROEF (Secret of Mana-stijl realtime gevecht) — alle instellingen/content op één plek.
## Schakelaar: ENABLED (hoofdschakelaar) + ROOMS (alleen deze WM1-kamers). Daarbuiten, en als
## GameState.som_mode uit staat (het gewone spel), blijven de turn-based gevechten precies zoals ze waren.
## Bazen (monster met "boss": true) blijven ALTIJD turn-based, ook in een SoM-kamer.
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
const SHEETS := {
	"dennis": "res://assets/sprites/som/kaart/dax_wm1.png",
	"noor": "res://assets/sprites/som/kaart/vesper.png",
	"lotte": "res://assets/sprites/som/kaart/seren_wm1.png",
}
## Wisselvolgorde (SWITCH-knop / toets C): Dax -> Seren -> Vesper; KO wordt overgeslagen.
const SWITCH_ORDER: Array[String] = ["dennis", "lotte", "noor"]
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
}
## Overige held-poses (48x48, zelfde anker): hurt = 4 kolommen (onder, links, rechts, boven) x 1 rij,
## ko = 1 frame, cast = 3 kolommen x 4 rijen (frame 1 200 ms, daarna 2-3 in een lus van 120 ms).
const HERO_POSES := {
	"dennis": {"hurt": "res://assets/sprites/som/combat/dax_hurt.png", "ko": "res://assets/sprites/som/combat/dax_ko.png"},
	"noor": {"hurt": "res://assets/sprites/som/combat/vesper_hurt.png", "ko": "res://assets/sprites/som/combat/vesper_ko.png",
			"cast": "res://assets/sprites/som/combat/vesper_cast6.png"},
	"lotte": {"hurt": "res://assets/sprites/som/combat/seren_hurt.png", "ko": "res://assets/sprites/som/combat/seren_ko.png",
			"cast": "res://assets/sprites/som/combat/seren_cast6.png"},
}
const HURT_TIME := 0.25
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
const UI_RING_ICONS := "res://assets/sprites/som/ui/ring_icons_8.png"  # 128x16, 8 iconen (7 = Phoenix Feather)
const UI_RING_ICONS_FALLBACK := "res://assets/sprites/som/ui/ring_icons.png"   # 112x16, 7 iconen (eerste batch)
const UI_BTN := {   # 38x14, normaal / ingedrukt (RPG ART ui2)
	"swap": ["res://assets/sprites/som/ui/btn_swap.png", "res://assets/sprites/som/ui/btn_swap_pressed.png"],
	"ring": ["res://assets/sprites/som/ui/btn_ring.png", "res://assets/sprites/som/ui/btn_ring_pressed.png"],
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
const TOP_BUTTON_SIZE := Vector2(46, 22)
const TOP_BUTTON_GAP := 3.0
## Icoon-index in ring_icons.png per item/spreuk-id.
const RING_ICON := {"drankje": 0, "kruid": 1, "toverwater": 2, "genees": 4, "vuur": 5, "bliksem": 6, "feniksveer": 7}
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
const FORMATION := [Vector2(-10, 18), Vector2(10, 18)]
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
}

## --- B = toveren (alleen Seren/Vesper als bestuurde held) ---
## Snelspreuk per held-id: heal -> partylid met het laagste HP-deel; damage -> dichtstbijzijnde vijand.
const B_MAGIC := {"lotte": "genees", "noor": "vuur"}
## Minimale tijd (s) tussen twee B-spreuken.
const B_CAST_COOLDOWN := 1.0
## Bereik (px) waarbinnen een spreuk een vijand kan kiezen.
const SPELL_RANGE := 160.0

## Speler-tekst (Engels).
const TXT_RING := "Ring"
const TXT_ITEMS := "Items"
const TXT_SKILLS := "Skills"
## ACTION-MODUS BAZEN: in Action/SoM-modus (GameState.som_mode of Settings Battle Style = Action) krijgt een
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
const TXT_NOW := "Now playing: %s"
const TXT_MISS_BUFF := "%s has no effect in real time yet."


static func room_enabled(room_id: String, action: bool) -> bool:
	return ENABLED and action and ROOMS.has(room_id)
