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
const START_ITEMS := {"drankje": 5, "kruid": 3, "toverwater": 2}
const START_GOLD := 50

## --- speler ---
## Seconden om de wapenmeter van 0 tot 100% te vullen.
const CHARGE_TIME := 1.0
## Schade bij 0% lading (lineair naar 1.0 bij 100%).
const CHARGE_MIN_MULT := 0.25
## Bereik van een slag (px, vanaf een punt 10 px voor de speler).
const ATTACK_REACH := 14.0
const ATTACK_OFFSET := 10.0
## Knockback van een geraakte vijand (px) en duur (s).
const KNOCKBACK_PX := 12.0
const KNOCKBACK_TIME := 0.15
## Onkwetsbaar na een treffer (s).
const PLAYER_IFRAMES := 0.8
## Vertraging tussen sluiten van het ringmenu en het effect (s): de keuze "landt" in realtime.
const RING_CAST_DELAY := 0.35

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
const TXT_MISS_BUFF := "%s has no effect in real time yet."


static func room_enabled(room_id: String, action: bool) -> bool:
	return ENABLED and action and ROOMS.has(room_id)
