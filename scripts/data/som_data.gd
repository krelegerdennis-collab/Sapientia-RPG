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
## AANVALSANIMATIES (RPG ART, HANDOFF_SOM.md). Komt het bestand er, dan speelt het i.p.v. de placeholder-boog.
## Sheet: 4 rijen (onder, links, rechts, boven) x "frames" kolommen, frame "frame" px, voeten op de onderrand
## (zelfde anker als de 24x32-loopsheet). Lege/ontbrekende sheet = placeholder.
const ATTACK_ANIMS := {
	"dennis": {"sheet": "res://assets/sprites/som/aanval/dax_aanval.png", "frame": [48, 48], "frames": 4, "fps": 16.0},
	"noor": {"sheet": "res://assets/sprites/som/aanval/vesper_aanval.png", "frame": [48, 48], "frames": 4, "fps": 16.0},
	"lotte": {"sheet": "res://assets/sprites/som/aanval/seren_aanval.png", "frame": [48, 48], "frames": 4, "fps": 16.0},
}
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
