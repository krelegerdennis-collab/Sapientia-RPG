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
			"cast": "res://assets/sprites/som/combat/vesper_cast.png"},
	"lotte": {"hurt": "res://assets/sprites/som/combat/seren_hurt.png", "ko": "res://assets/sprites/som/combat/seren_ko.png",
			"cast": "res://assets/sprites/som/combat/seren_cast.png"},
}
const HURT_TIME := 0.25
const CAST_MS: Array[int] = [200, 120, 120, 120, 120]
## Vijand-sheets (assets/sprites/som/monsters/<enemy>_attack|hurt|death.png, 16x16 frames):
## attack 3 kolommen (opladen, uithaal, terug) x 4 rijen; hurt 4 kolommen (richtingen); death 4 frames.
## Duur aanval: opladen = de telegraaf (TELEGRAPH), uithaal 110 ms, terug 300 ms. Dood: 4 x 100 ms.
const MONSTER_SHEET_DIR := "res://assets/sprites/som/monsters/"
const MONSTER_STRIKE_MS := 110
const MONSTER_RETURN_MS := 300
const MONSTER_DEATH_MS := 100
## FX/UI (assets/sprites/som/fx|ui). Ontbreekt een bestand: de placeholder in code.
const FX_SLASH := "res://assets/sprites/som/fx/fx_slash.png"          # 128x32, 4 frames 32x32
const FX_SPARK := "res://assets/sprites/som/fx/fx_hit_spark.png"      # 64x16, 4 frames 16x16
const FX_TELEGRAPH := "res://assets/sprites/som/fx/fx_telegraph.png"  # 8x8
const UI_DIGITS := "res://assets/sprites/som/ui/dmg_digits.png"       # 50x21: rijen wit, rood, groen; cijfers 5x7
const UI_GAUGE_BAR := "res://assets/sprites/som/ui/gauge_bar.png"     # 18x4
const UI_GAUGE_FILL := "res://assets/sprites/som/ui/gauge_fill.png"   # 16x2 (op (1,1))
const UI_GAUGE_GLINT := "res://assets/sprites/som/ui/gauge_full_glint.png"  # 36x4, 2 frames
const UI_HUD_FRAME := "res://assets/sprites/som/ui/hud_frame.png"     # 72x20 per held
const UI_RING_BG := "res://assets/sprites/som/ui/ring_bg.png"         # 180x110
const UI_RING_ICONS := "res://assets/sprites/som/ui/ring_icons.png"   # 112x16, 7 iconen
## Icoon-index in ring_icons.png per item/spreuk-id.
const RING_ICON := {"drankje": 0, "kruid": 1, "toverwater": 2, "genees": 4, "vuur": 5, "bliksem": 6}
const RING_ICON_DAMAGE := 3      # 'spark': elke andere aanvalsspreuk
## Seconden om de wapenmeter van 0 tot 100% te vullen.
const CHARGE_TIME := 0.5
## Schade bij 0% lading (lineair naar 1.0 bij 100%).
const CHARGE_MIN_MULT := 0.25
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
const TELEGRAPH := 0.55
const ATTACK_COOLDOWN := 1.6
## Afstand (px, middelpunten) waarop een vijand kan aanvallen/raken.
const ENEMY_REACH := 22.0
const HIT_FLASH := 0.12

## Speler-tekst (Engels).
const TXT_RING := "Ring"
const TXT_ITEMS := "Items"
const TXT_SKILLS := "Skills"
const TXT_NO_MP := "Not enough MP."
const TXT_NO_TARGET := "No enemy in range."
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
