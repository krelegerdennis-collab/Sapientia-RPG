# Golem story-events na een realtime arena-winst

Akkoord Dennis (2026-11-02). Vervolg op de D3 arena-hook (PR #345/#351, `SomArena.golem_rt_enabled`,
`GOLEM_RT_ROOMS = ["archief_golemhal"]`).

## Probleem
Met de hook aan vecht de Golem (`kennis_beest`) realtime in de arena. `SomArena._defeat_enemy` zette alleen
`defeated_map_monsters`; de verhaal-beat van de turn-based winst bleef uit (geen `StoryData.GOLEM_FLAG`, dus
Esdoorn/Kas/Noor bleven dicht, geen Golemkern, geen absorptie-moment).

## Hergebruikte beat (geen nieuwe tekst)
`scripts/som/golem_story_win.gd` doet exact wat de turn-based winst doet:
1. bewaker-vlag `bewaker:archief_golemhal/golem` (= `StoryData.GOLEM_FLAG`, `DungeonRoom.guard_flag`) +
   `NaGenezer.on_guard_flag` (zoals `DungeonRoom._restore_after_battle`);
2. `GameState.grant_kern("golemkern", "kennis_beest")` + `pending_kern_absorb` (zoals `GameState` na een baaswinst);
3. het bestaande absorptie-moment `scripts/kern/kern_absorption.gd` op de kaart (zoals `map.gd`), met de
   bestaande tekst uit `KernAbsorption.lines_for`.
Daarna lopen de bestaande vlag-gestuurde events vanzelf (o.a. `noor_ontmoeting` in Esdoorn, `golemhal_uitgang`).

## Host-authoritatief en eenmalig
- Alleen solo of coop-host (`SomArena._story_authority()`, zelfde regel als zones/roots).
- Eenmalig: vlag alleen als hij nog niet staat, `grant_kern` geeft nooit dubbel; tweede aanroep = no-op.
- Her-binnenkomst / geladen save: de bewaker-vlag houdt de Golem uit de kamer, dus geen nieuwe winst.
- Absorptie onderbroken door een mapwissel: `pending_kern_absorb` blijft staan en `map.gd` speelt hem op de
  volgende kaart (bestaand gedrag).

## Test
`godot --path . -- --golemstorytest` (`scripts/tests/golem_story_tests.gd`): solo-winst, dubbele aanroep,
her-binnenkomst, save/laden, coop client (niets) en host (beat).
Nog niet in `.github/workflows/tests.yml` (bewust niet aangeraakt): `golemstorytest` toevoegen aan de matrix.

## Open punten
- Coop-clients krijgen vlag/kern niet zelf; ze komen pas mee via de bestaande state-sync/save van de host.
