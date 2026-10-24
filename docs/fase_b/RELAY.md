# Fase B — online co-op via de relay (stap 1)

De host-telefoon blijft autoritair; de relay (`relay/`, Node + `ws`) geeft alleen berichten door tussen
de peers van een kamer. Server, protocol, limieten en deploy: [`relay/README.md`](../../relay/README.md).
Dit document gaat over de game-kant.

## Hoe het past (geen tweede sync)

`LanLobby` en `ActionCoopSession` praten al tegen een `MultiplayerPeer` (`set_target_peer`, `put_packet`,
`get_packet`, `get_packet_peer`, `peer_connected`, `peer_disconnected`). Voor de relay is er een tweede peer:

- `scripts/net/relay_peer.gd` — `RelayPeer extends MultiplayerPeerExtension`, WebSocket naar de relay.
  Host = peer 1; gasten krijgen een peer-id van de relay. Gedrag zoals ENet: `get_packet_peer()` geeft de
  afzender van het **volgende** pakket, `peer_disconnected` komt pas nadat alle ontvangen pakketten zijn gelezen
  (een REFUSE of SESSION_END vlak voor het sluiten blijft leesbaar), `disconnect_peer` = kick via de relay.
- `LanLobby.host_relay(url, naam)` en `LanLobby.join_relay(url, code, held, naam)` naast `host_session` / `join_session`.
  Daarna is alles hetzelfde: HELLO/WELCOME/ROSTER/START_GAME/SESSION_END, binaire INPUT/SNAPSHOT-pakketten,
  `ActionCoopSession.start_session(tree, lobby.enet_peer(), ...)`. `enet_peer()` houdt zijn naam en geeft nu de
  open `MultiplayerPeer` (ENet of Relay). Nieuw op de lobby: `transport` (`LAN`/`RELAY`), `room_code`,
  `relay_reason`, signal `room_ready(code)`.
- Relay-fouten komen binnen als `refused` met een `NetProtocol.Refuse` (`ROOM_NOT_FOUND` is nieuw, 5;
  vol = `FULL`; onbereikbaar = `TIMEOUT` met `relay_reason == "unreachable"`). Een host die de relay verliest
  (kamer verlopen, server weg) krijgt `link_lost`, net als een gast die de host verliest.
- Wachttijd: `RELAY_JOIN_TIMEOUT_SEC` / `RelayPeer.CONNECT_TIMEOUT_SEC` = 60 s (gratis hosts slapen).

## Lobby-UI (`scripts/ui/coop_lobby_screen.gd`)

Zonder relay-URL verandert er niets (alleen Host / Join over LAN). Met een URL komen er twee knoppen bij:

- **Host online** — toont "Room code: ABC234" zodra de relay de kamer opent; daarna zoals de LAN-host (roster, Start).
- **Join online** — invoervak voor de code (hoofdletters, alleen toegestane tekens, max 6), knop Join.

Relay-URL: project-instelling `sapientia/net/relay_url` (sectie `[sapientia]`, standaard leeg = alleen LAN);
de omgevingsvariabele `SAPIENTIA_RELAY_URL` wint (dev/test). Alleen `ws://` of `wss://` telt, alles anders = leeg.
Helpers staan in `NetProtocol`: `relay_url()`, `filter_room_code()`, `is_room_code()`, `relay_error_text()`.

## Test

```bash
GODOT=/pad/naar/Godot_v4.3-stable_linux.x86_64 .github/scripts/run_suite.sh relaytest
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --relaytest     # met de hand
```

`scripts/tests/relay_tests.gd` start de relay lokaal (vrije poort, `node` nodig) en doet: kamercode, 1 host + 3 gasten
joinen, vijfde gast geweigerd, verkeerde versie, onbekende code, onbereikbare relay, UI-flow (code tonen en intikken),
START_GAME, Action-sync (input van drie gasten, posities gelijk op alle vier, aanval van gasten raakt de vijand op de host),
een gast die wegvalt en terugkomt, host die afsluit (SESSION_END) en host die zonder bericht weggaat. De test zit
bewust niet in `.github/workflows/tests.yml`; relay-unittests: `cd relay && npm test`.
