# SAPIENTIA relay (online co-op, stap 1)

Kleine WebSocket-relay die berichten doorgeeft tussen de telefoons in een kamer.
Ze **simuleert niets en kijkt niet in de payload**: de host-telefoon blijft autoritair
(host = peer 1, gasten sturen alleen naar de host). Geen database, geen accounts,
geen opslag: kamers leven in het geheugen en verdwijnen bij een herstart.

De game-kant (`scripts/net/relay_peer.gd`, lobby-knoppen "Host online" / "Join online") staat in
[`docs/fase_b/RELAY.md`](../docs/fase_b/RELAY.md).

## Waarom Node + `ws`

- **Eén runtime-dependency** (`ws`, de standaard WebSocket-bibliotheek); verder alleen Node-ingebouwde modules
  (`http`, `crypto`) en de ingebouwde testrunner (`node --test`). Geen build-stap, geen framework.
- ~350 regels, makkelijk te lezen en te wijzigen door wie de repo al onderhoudt (de repo bevat al
  scripts in Python en GDScript; Node is op elke CI-runner en elk Docker-image aanwezig).
- Een relay is I/O-bound (kleine frames, 4 spelers per kamer): één Node-proces (enkele tientallen MB) draagt
  honderden kamers op de kleinste gratis instance (256 MB). Go zou een kleinere image geven, maar vraagt
  ook een WebSocket-dependency en een tweede toolchain; dat wint hier niets.
- Deploy: `node:22-alpine`, `npm ci --omit=dev`, klaar. Beide hosts (Fly, Render) bouwen de Dockerfile.

## Protocol v1

Eén WebSocket per speler (`ws://` lokaal, `wss://` online; elk pad werkt, `GET /healthz` geeft `200 ok`).

**Tekstframes = besturing (JSON).** De eerste boodschap van een client is `create` of `join`.

| Richting | Bericht | Betekenis |
|---|---|---|
| c -> r | `{"t":"create","v":1}` | maak een kamer; jij bent host (peer 1) |
| c -> r | `{"t":"join","v":1,"code":"ABC234"}` | join met de kamercode (hoofdletters/spaties worden genormaliseerd) |
| c -> r | `{"t":"kick","peer":N}` | alleen host: zet peer N eruit |
| c -> r | `{"t":"leave"}` | netjes weggaan (sluiten kan ook) |
| r -> c | `{"t":"created","code":"ABC234","peer":1,"max":4}` | kamer open |
| r -> c | `{"t":"joined","peer":N,"host":1,"max":4}` | je zit in de kamer |
| r -> host | `{"t":"peer_joined","peer":N}` / `{"t":"peer_left","peer":N}` | gast erbij / weg |
| r -> c | `{"t":"closed","reason":"host_left"\|"idle"\|"max_age"\|"kicked"\|"shutdown"}` | kamer of verbinding dicht |
| r -> c | `{"t":"error","reason":"..."}` | mislukt, daarna sluit de relay. Redenen: `bad_message`, `bad_version`, `no_room`, `room_full`, `rate_limited`, `too_many_rooms`, `busy`, `handshake_timeout` |

**Binaire frames = data**, ondoorzichtig voor de relay:

- client -> relay: `[doel u16 BE][payload]`. Doel `0` = alle anderen (alleen host), `1` = host, `N` = die gast (alleen host).
  Een gast mag alleen naar `1` sturen; gast-naar-gast en gast-broadcast worden gedropt (telt als overtreding).
- relay -> client: `[afzender u16 BE][payload]`.
- Peer-ids: host = 1, gasten 2, 3, 4, ... per kamer oplopend en **nooit hergebruikt**. Een gast die terugkomt is dus een nieuwe peer.

De relay stuurt `closed` en sluit pas ~300 ms later (`closeLingerMs`): Godots `WebSocketPeer` gooit
ontvangen berichten weg als het sluiten in dezelfde poll binnenkomt, en dan haalt de laatste reden de speler niet.

### Kamercodes

6 tekens uit `23456789ABCDEFGHJKMNPQRSTUVWXYZ` (31 tekens, **geen 0, O, 1, I, L**), gemaakt met `crypto.randomInt`.
887 miljoen mogelijkheden; raden wordt begrensd door de join-limiet per IP (zie onder). De code is geen
wachtwoord: wie hem weet, kan joinen zolang er een plek vrij is (max 4 spelers inclusief host).

### Levensduur

- **Host weg = kamer dicht** (gasten krijgen `closed: host_left`). Geen host-migratie (DECISION 5).
- Gast weg = `peer_left` naar de host; de kamer blijft open en de plek komt vrij.
- **Inactieve kamers verlopen** na `ROOM_IDLE_MS` (standaard 10 min zonder verkeer of join/leave) en na
  `ROOM_MAX_AGE_MS` (standaard 4 u), ook als er nog verkeer is.
- Ping elke 15 s; een verbinding die niet antwoordt wordt gesloten (telefoon die stil wegvalt).
- Verbinding die niet binnen 10 s `create`/`join` stuurt, wordt gesloten.

### Limieten

| Wat | Standaard | Env |
|---|---|---|
| Frame-grootte | 2048 bytes (groter = close 1009) | `MAX_MESSAGE_BYTES` |
| Berichten per verbinding | 120/s, burst 240 | (alleen in code) |
| Bytes per verbinding | 32 KiB/s, burst 64 KiB | (alleen in code) |
| Overtredingen (gedropt door limiet of verboden doel) | 20 per 5 s, daarna close 1008 | |
| Kamers aanmaken per IP | 10/min | |
| Join-pogingen per IP | 30/min (rem op code raden) | |
| Verbindingen per IP / totaal | 32 / 2000 | `MAX_CONNECTIONS_PER_IP`, `MAX_CONNECTIONS` |
| Kamers totaal | 500 | `MAX_ROOMS` |
| Trage ontvanger (>256 KiB in de wachtrij) | verbinding gesloten | |

Een snapshot is ~130 bytes bij 20 Hz en een gast-input 7 bytes bij 30 Hz, ruim onder de limieten.
Achter een proxy (Fly, Render) zet je `TRUST_PROXY_HOPS=1`, zodat de limieten per echt client-IP
werken (de relay leest de rechtse hop van `X-Forwarded-For`, niet de links die een client zelf kan zetten).
Mobiele providers delen vaak één IP over veel telefoons (CGNAT); de IP-limieten zijn daarom ruim.

### Wat de relay niet doet

Geen authenticatie, geen versleuteling buiten TLS van de host (`wss://`), geen opslag, geen logging van
IP's of kamercodes (alleen aantallen). Wie de code kent, kan joinen. Het spel zelf (lobby, versie-check,
stoelen) draait volledig tussen host en gasten bovenop deze pijp.

## Lokaal draaien

```bash
cd relay
npm ci
node server.js --port=8080          # of: PORT=8080 npm start
curl http://127.0.0.1:8080/healthz  # ok
```

Alle instellingen staan in `src/config.js` (env: `PORT`, `HOST`, `MAX_ROOMS`, `MAX_CONNECTIONS`,
`MAX_CONNECTIONS_PER_IP`, `MAX_MESSAGE_BYTES`, `ROOM_IDLE_MS`, `ROOM_MAX_AGE_MS`, `TRUST_PROXY_HOPS`, `RELAY_QUIET=1`).

## Tests

```bash
cd relay && npm ci && npm test      # 33 unit-/integratietests (codes, limieten, relay), ~3 s
```

De Godot-kant (4 spelers via de relay, in Action-modus, met disconnect/reconnect) staat in `--relaytest`:

```bash
GODOT=/pad/naar/Godot_v4.3-stable_linux.x86_64 .github/scripts/run_suite.sh relaytest
# of met de hand:
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --relaytest
```

Die test start `node relay/server.js` zelf op een vrije poort (en doet zo nodig `npm ci` in `relay/`), dus Node >= 20 is nodig.
Hij zit **niet** in de CI-matrix (`.github/workflows/tests.yml` blijft ongewijzigd); draai hem lokaal.

## Deployen (nog niet gedaan; niets is uitgerold)

Jij hebt één account nodig bij de host die je kiest. De relay heeft geen geheimen: geen API-sleutels,
geen database, geen env-variabelen die verplicht zijn.

> Controleer de actuele prijzen en gratis limieten op de sites zelf; die veranderen vaak.

### Render (echte gratis laag)

1. Account op render.com (GitHub-login volstaat), repo koppelen.
2. *New* > *Web Service* > deze repo > **Root Directory** `relay` > **Runtime** `Docker` > **Instance Type** `Free`.
3. Environment: `TRUST_PROXY_HOPS=1`. Health Check Path: `/healthz`.
4. Deploy. De URL wordt `https://<naam>.onrender.com`; in de game wordt dat `wss://<naam>.onrender.com`.

Let op: een gratis Render-service **slaapt na ~15 minuten zonder verkeer** en heeft ~1 minuut nodig om
wakker te worden. De game wacht daarom tot 60 s op de relay ("Connecting to the online server…"); de
eerste "Host online" van de dag kan dus even duren. Wie vooraf `https://<naam>.onrender.com/healthz` opent
(browser), wekt hem alvast.

### Fly.io

1. Account op fly.io (er is een creditcard of tegoed nodig; Fly heeft voor nieuwe accounts geen vaste gratis laag meer,
   een `shared-cpu-1x` met 256 MB die automatisch stopt kost een paar dollar per maand of minder).
2. `cd relay && cp fly.toml.example fly.toml`, kies een unieke `app`-naam, dan `fly launch --no-deploy --copy-config`
   en `fly deploy`. Met `auto_stop_machines` slaapt hij ook hier bij stilte (opstarten ~1-3 s).
3. URL `https://<app>.fly.dev` -> in de game `wss://<app>.fly.dev`.

### Game koppelen

In `project.godot` (door RPG Forge, bij een release):

```ini
[sapientia]
net/relay_url="wss://jouw-relay.onrender.com"
```

Leeg laten = alleen LAN (de "Host online" / "Join online"-knoppen verschijnen dan niet). Voor ontwikkelen kan
de omgevingsvariabele `SAPIENTIA_RELAY_URL` de instelling overrulen (bv. `ws://127.0.0.1:8080`).
Android heeft INTERNET al (PR #199); `ws://` zonder TLS werkt ook, maar gebruik online altijd `wss://`.

## Bekende beperkingen (stap 1)

- WebSocket = TCP: betrouwbaar en geordend. Snapshots (20 Hz) zijn dus geen UDP-achtige "laatste wint";
  bij pakketverlies op mobiel net kan de stroom even haperen (head-of-line blocking). De gast toont altijd het laatste snapshot.
- Een gast die wegvalt komt terug als nieuwe peer met de laagste vrije stoel (DECISION 6); geen sessie-hervatting.
- Host die de app pauzeert = sessie weg (zoals op LAN, DECISION 5).
- Eén relay-proces, geen clustering: kamers zijn niet gedeeld tussen meerdere instances (schalen = per kamer één instance;
  voor deze schaal is er maar één nodig).
