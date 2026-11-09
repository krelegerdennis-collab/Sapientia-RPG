# Toestandsmachines in SAPIENTIA — audit en besluit

Dit document hoort bij de suite `--statemachinetest` (`scripts/tests/state_machine_tests.gd`, 75 PASS) en bij
`scripts/core/flow_state.gd`. Het is de inventaris van **alle** toestandsmachines in de code: welke al expliciet
waren, welke impliciet (losse booleans, losse strings) en wat er met elke is gedaan.

## Het besluit in één alinea

Niets van de bestaande buitenkant verandert: elke vlag (`GameState.in_battle`, `changing_map`, `Dialog.is_open`,
`Story.running`, `player.input_locked` ...), elke string (`battle.state == "command"`, `vesper.state == "ko"`,
`shop.mode == "koop"`) en elk signaal blijft precies wat het was, dus de ~90 bestaande suites blijven werken en
een save van gisteren laadt vandaag nog. De machines worden expliciet gemaakt **om de vlaggen heen**:

1. één afgeleide veldflow-toestand (`FlowState`) met één signaal, in plaats van ~20 met de hand herhaalde guards;
2. benoemde constanten + een `STATES`/`MODES`/`PHASES`-set per string-machine, met een test die faalt zodra iemand
   weer een losse `"..."`-toestand introduceert;
3. alleen-lezen `*_state()`/`phase()`-queries voor de machines die uit losse booleans bestaan.

Waarom zo en niet een `enum` + echte FSM-klasse per systeem: dat zou tientallen test-regels (`b.state == "command"`)
en de sessielog breken voor nul winst voor de speler. De winst zit in één naam per toestand (DX), één plek om te
zoeken en een vangrail die meteen faalt (AX), en minder kans op een vergeten guard die een gevecht tijdens een
mapwissel start (UX).

## Inventaris

| # | Systeem | Bestand | Was | Toestanden | Nu |
|---|---|---|---|---|---|
| 1 | **Veldflow** | `scripts/game_state.gd` + `scripts/story.gd` + `scripts/dialog_box.gd` | 4 losse vlaggen, in ~20 guards herhaald | `field`, `dialog`, `cutscene`, `map_change`, `battle` | `FlowState` (puur) + `GameState.flow_state()`, `scene_busy()`, `field_free()`, signaal `flow_changed` |
| 2 | **Gevecht** | `scripts/battle/battle.gd` | `state` als losse strings, 3x dezelfde lijst `["command", ...]` | `intro`, `command`, `target_enemy`, `target_ally`, `busy`, `message_wait` | `ST_*`, `STATES`, `CHOOSING_STATES`, `choosing()`, `prev_state`, `_set_state` controleert |
| 3 | **SoM-bondgenoot AI** | `scripts/som/som_ally.gd` | `state` als losse strings | `follow`, `engage`, `flee`, `ko` | `ST_*`, `STATES` |
| 4 | **Kern-absorptie** | `scripts/kern/kern_absorption.gd` | `phase` als losse strings | `""`, `effect`, `bericht`, `klaar` | `PHASE_*`, `PHASES` |
| 5 | **UI-schermen** | `shop_screen.gd`, `equipment_screen.gd`, `save_slot_list.gd`, `codex_screen.gd` | `mode` als losse strings (Codex had al 3 van de 4) | zie hieronder | `MODE_*`, `MODES` |
| 6 | **Spelerbeweging** | `scripts/player.gd` | 5 booleans (`is_moving`, `input_locked`, `_scripted`, `analog_input`, …) | `idle`, `stepping`, `analog`, `locked`, `scripted` | `movement_state()` (alleen lezen), `MOVE_*` |
| 7 | **Tekstvak** | `scripts/dialog_box.gd` | `is_open` + `_is_typing()` + `has_choices()` los gecombineerd | `closed`, `typing`, `waiting`, `choosing` | `phase()` (alleen lezen), `PHASE_*` |
| 8 | Map-monster | `scripts/dungeon/map_monster.gd` | `is_moving`, `_pause`, `stun_steps` | zwerven/pauze, stap, verdoofd | **gelaten** (orthogonaal: `is_stunned()` bestaat al; sim-driven pad is deterministisch) |
| 9 | Verhaal | `scripts/story.gd` | `running` + `current_event` + `scheduled` | idle, running | **gelaten** (`idle()` bestaat; de flow zit in #1) |
| 10 | Touch | `scripts/touch_controls.gd` | per vinger `_touch_owner`/`_touch_action` | per vinger: joy/a/b/kern/run/menu | **gelaten** (geen machine, een tabel per vinger) |
| 11 | Overgang | `scripts/transition.gd` | geen eigen toestand (tweens) | — | **gelaten**; de "bezig"-toestand is `changing_map` (#1) |

Al expliciet vóór deze audit (ter referentie, niet aangeraakt): `TelegraphState.State` (`scripts/som/telegraph_state.gd`),
`BossPhaseMachine` (`scripts/som/boss_phase_machine.gd`), `GolemFight.Step`, `LanLobby.Phase`/`Transport`,
`RelayPeer.Role`, `CoopLobbyScreen.Screen`, `GardenCreatures.Mode`, `WarperBrain.State` (world_warper).

## §1 Veldflow — `FlowState`

```
prioriteit:  BATTLE  >  MAP_CHANGE  >  CUTSCENE  >  DIALOG  >  FIELD
bron:        in_battle   changing_map   Story.running  Dialog.is_open  (geen van alle)
```

- `GameState.flow_state() -> String` — de afgeleide toestand, altijd een van `FlowState.STATES`.
- `GameState.scene_busy() -> bool` — precies de oude guard `changing_map or in_battle`. Alle guards in
  `game_state.gd`, `story.gd`, `map.gd`, `player.gd`, `dungeon_room.gd`, `dungeon100_room.gd`, `archief2_room.gd`,
  `worldmap_cutscene.gd`, `kern_kracht_veld.gd` en `sessie_log.gd` gebruiken hem nu; extra voorwaarden
  (`Dialog.is_open`, `menu_open()`, `player.is_moving`) staan er nog gewoon achter.
- `GameState.field_free() -> bool` — `flow_state() == FIELD`: de speler mag vrij handelen.
- `signal flow_changed(from_state, to_state)` — uit de setters van `in_battle` en `changing_map`; zelfde waarde
  opnieuw zetten geeft geen signaal. (Story/Dialog wisselen buiten GameState; lees die via `flow_state()`.)

Gebruik in nieuwe code: `if GameState.scene_busy(): return` voor "mag ik iets starten dat de scène wisselt",
`GameState.field_free()` voor "mag de speler nu vrij handelen". Niet nog een keer de vier vlaggen uittypen.

## §2 Gevecht — `battle.gd`

```
intro ──► command ◄──► target_enemy
             ▲ │  ◄──► target_ally
             │ ▼
          busy ◄──► message_wait          (say(wait) / _victory_page)
```

`_set_state()` is de enige schrijver; hij vult `prev_state`, ververst de statusvakken en zendt `state_changed`.
Een onbekende toestand geeft `push_error` (nooit een crash). `choosing()` = `state in CHOOSING_STATES`; gebruik
die in plaats van de lijst nog eens uit te schrijven. Tests mogen `b.state == "command"` blijven schrijven;
nieuwe code gebruikt `Battle.ST_COMMAND`.

Bekende losse eindjes (bewust niet veranderd): `"win"`/`"lose"` zijn **geen** battle-toestanden maar het
`result` van `GameState.end_battle`; `codex_tests.gd` vergelijkt `b.state != "lose"` (altijd waar).

## §3 SoM-bondgenoot — `som_ally.gd`

Per tick opnieuw bepaald (geen geheugen behalve KO): `niet alive → ko`; `laag HP én vijand → flee`;
`vijand → engage`; anders `follow`. KO is de enige toestand met in/uit-werk (grijs/plat zetten).

## §4 Kern-absorptie — `kern_absorption.gd`

Lineair: `"" (wacht op start-vertraging, Story, Dialog) → effect → bericht → klaar`. Afbreken door een
mapwissel laat `pending_kern_absorb` staan, zodat het moment op de volgende kaart alsnog speelt.

## §5 UI-schermen

| Scherm | Constanten | Volgorde |
|---|---|---|
| `shop_screen.gd` | `MODE_KOOP`, `MODE_VERKOOP`, `MODE_HELD` | tabbladen, vrij wisselen |
| `equipment_screen.gd` | `MODE_COMMAND`, `MODE_SLOT`, `MODE_ITEM`, `MODE_CONFIRM` | command → slot → item → confirm → slot |
| `save_slot_list.gd` | `MODE_LOAD`, `MODE_NEW` | gezet vóór het vullen (titelscherm) |
| `codex_screen.gd` | `MODE_BROWSE` (`""`), `MODE_A`, `MODE_B`, `MODE_PREVIEW` | browse → A → B → preview → browse |

## §6 Spelerbeweging — `player.movement_state()`

Prioriteit `scripted > locked > analog > stepping > idle`. Alleen lezen: Story zet `_scripted`/`input_locked`,
SomArena zet `analog_input`, de loop zelf zet `is_moving`. Handig in de sessielog en in tests
(`player.movement_state() == player.MOVE_LOCKED` leest beter dan drie booleans).

## §7 Tekstvak — `Dialog.phase()`

`closed → typing → waiting | choosing → (volgende regel) … → closed`. `Dialog.is_open` blijft de bron;
`phase()` is de leesbare samenvatting voor guards en tests.

## Regels voor wie hieraan verder werkt (mens of agent)

1. **Nieuwe toestand** in een van de bestanden uit de inventaris: constante erbij **en** in de set
   (`STATES`/`MODES`/`PHASES`). De suite `--statemachinetest` faalt anders op "geen letterlijke strings" of
   "alle constanten staan in de set". Oude strings niet hernoemen (saves, tests, sessielog).
2. **Nieuwe guard** op de kaart: `GameState.scene_busy()` of `GameState.field_free()`, niet de vlaggen los.
3. **Nieuwe machine** (meer dan twee toestanden, of toestanden die elkaar uitsluiten): kies meteen de expliciete
   vorm. Puur en deterministisch zoals `TelegraphState` als het in de combat-stap meedraait; anders constanten +
   set zoals hier, en een regel in de tabel hierboven.
4. Spelerzichtbare tekst blijft Engels; de toestand-strings hier ziet de speler nooit.
