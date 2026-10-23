# Fase B — Action-co-op sync (track 2)

Host-autoritaire gameplay in de Action-sandbox. Gasten sturen input; de host
simuleert (`ActionSandboxSim`, 60 Hz) en broadcast snapshots (20 Hz). Gasten
interpoleren met ~100 ms buffer (`ActionCoopSession`).

## Ingang

```gdscript
const Session := preload("res://scripts/net/action_coop_session.gd")

# Na een geslaagde lobby (LanLobby, fase B):
var peer: ENetMultiplayerPeer = lobby._peer  # zelfde peer als join/host
var roster: Array = lobby.slots              # {peer_id, slot, character_id, display_name}
var sess := Session.start_session(get_tree(), peer, roster, lobby.local_slot)
sess.attach_arena(map.som)                   # SomArena in de sandbox-kamer
```

Parameters van `start_session`:

| # | Naam | Betekenis |
|---|---|---|
| 1 | `tree` | Actieve `SceneTree` (sandbox-scène) |
| 2 | `peer` | Bestaande `ENetMultiplayerPeer` (lobby) |
| 3 | `roster` | Stoelen zoals `LanLobby.slots` |
| 4 | `local_slot` | `0` = host (Dax), `1..3` = gast |
| 5 | `use_tree_mp` | `true` in de echte scène (zet `SceneTree.multiplayer`); `false` in headless tests |

`shutdown()` maakt de peer op de boom los en sluit de sessie.

## Input (gast → host)

- Joystick als genormaliseerde vector (`set_local_input(stick, attack, ring, lock_tap, lock_idx)`).
- Onbetrouwbaar, ~30 Hz (`NetCodec.pack_wire_input`).
- Host behandelt stille gasten als stick nul (geen laatste richting vasthouden).

## Snapshots (host → gasten)

Binair formaat: `scripts/net/net_codec.gd` (kop + 11 bytes/speler + 9 bytes/vijand).
Vijanden jagen de host (stoel 0). Target lock: één lock per stoel (tap + auto ~6 tegels).

## Ring

In co-op zet `attach_arena` `SomArena.coop_ring_no_pause = true`: het ringmenu is lokale UI
en zet `get_tree().paused` niet.

## Tests

```bash
godot --path . -- --netsynctest
```

Simuleert host+gast op `127.0.0.1:38424` (losse poort, geen lobby-UI).
