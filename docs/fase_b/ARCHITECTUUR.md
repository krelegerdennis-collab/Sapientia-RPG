# Fase B — architectuur (voorbereiding)

Action-co-op op lokaal wifi, maximaal 4 spelers. De telefoon van de eigenaar is de host.
Vrienden stappen in als Seren, Vesper of een andere party-held. Fase C vult lege stoelen
met AI en gaat daarna via een relay het internet op. Het relay-protocol zelf staat hier niet;
de save-eisen van fase C wel, in [Fase C requirements](#fase-c-requirements).

Dit document is gelezen tegen de Action-code zoals die nu op `main` staat (`scripts/som/som_arena.gd`
en wat daaromheen hangt). De module `scripts/net/` is nog aan geen enkele scène gekoppeld.
Fase A (target lock, Options-tab Music, ECHO-questlog, sessielog) loopt parallel: deze nota
en de lobby raken die scripts niet aan.

Vriendenmodus (`pvp/`, turn-based, 1 tegen 1, poorten 7777–7779 in `pvp/scripts/net/lan_transport.gd`)
is een ander spel. Fase B gebruikt 38421–38423 en deelt geen peer met die lobby.

## Besluiten

Dennis heeft de tien voorstellen goedgekeurd zoals ze stonden. Fase B volgt ze.
Waar fase C er later van afwijkt, staat dat onder [Fase C requirements](#fase-c-requirements).

1. **DECISION — wie speelt wie.** De host is Dax (`dennis`, stoel 0). Gasten krijgen de
   eerste vrije held uit Seren (`lotte`), Vesper (`noor`), Kael (`kael`). Orion zit niet
   in fase B. De party-limiet is 4 helden (`scripts/party_limiet.gd:10`).

2. **DECISION — lege stoelen.** Een stoel zonder gast is leeg. Geen `SomAlly`-AI tot fase C.
   Nu vechten de niet-bestuurde helden nog wél mee (`scripts/som/som_arena.gd:127`,
   `scripts/som/som_ally.gd:87`); de co-op-kamer doet dat niet.

3. **DECISION — van wie is de wereld.** Alleen de save van de host telt. Een gast neemt
   goud, EXP, items en Codex-pagina's niet mee naar zijn eigen spel.

4. **DECISION — ringmenu.** De ring is lokale UI. De host simuleert door. Openen mag
   `get_tree().paused` niet zetten (`scripts/som/som_ring.gd:83` doet dat nu wel, in solo).

5. **DECISION — host op slot.** Godot stopt met `_process` bij `NOTIFICATION_APPLICATION_PAUSED`.
   ENet valt dan na ongeveer 5–30 s weg (standaard timeout: factor 32, minimum 5000 ms,
   maximum 30000 ms). De sessie is dan weg. Geen host-wissel en geen doorgaan na die timeout.

6. **DECISION — gast weg.** Het personage is meteen vrij. Geen reservering. Rejoin krijgt
   de laagste vrije stoel en, als die nog vrij is, dezelfde held.

7. **DECISION — welke save.** De prototype-kamer is de Action-sandbox
   (`user://som_save_1.json`, `scripts/data/som_data.gd:17`), niet het verhaal
   (`story_step`, vlaggen, quests). Het verhaal blijft singleplayer.

8. **DECISION — bazen.** Geen baasgevecht in co-op. De kamer blijft Action; een baas weigert
   net als nu (`scripts/som/som_arena.gd:5`, `scripts/game_state.gd:1821`). Gasten kijken
   niet mee in een turn-based gevecht.

9. **DECISION — target lock.** Eén lock per speler (zijn doel voor aanval en spreuk).
   Het vijand-doel (`enemies[m]["target"]`, `scripts/som/som_arena.gd:52` en `_target_for`
   op regel 660) blijft van de host. Geen gedeelde party-lock. De solo-lock van fase A
   zit nog niet in deze branch.

10. **DECISION — twee LAN-ingangen.** Co-op en Vriendenmodus blijven twee ingangen en twee
    poortblokken (38421–38423 naast 7777–7779). Het titelscherm mag ze later naast elkaar zetten.

## Model: host is de baas

Eén telefoon draait de simulatie. De andere drie sturen input en tekenen wat de host zegt.
Godot 4.3 kan dat met `ENetMultiplayerPeer`. De lobby in `scripts/net/lan_lobby.gd` doet
dat al voor join/stoel, en hangt de peer expres niet aan `multiplayer.multiplayer_peer`.
ENet krijgt één plaats extra (`ENET_REFUSE_SLACK`). Een vijfde gast moet kunnen verbinden
om de tekst "The party is full." te lezen; daarna gaat de verbinding dicht. De roster
komt nooit boven 4. Zonder die plaats blijft de vijfde in `CONNECTING` tot de timeout.
Zodra je dat wél doet, gaan `@rpc` op autoloads het hele spel in. Dat is een latere PR.

### Synchronizer en Spawner passen hier niet

`MultiplayerSynchronizer` kopieert properties van een node, op een vast pad, met een
`replication_interval`. `MultiplayerSpawner` spawnt een packed scene op de peers.

De Action-arena is daar niet op gebouwd:

- `SomArena` en de bondgenoten worden in code gemaakt (`som_arena.gd:113`, `:130`), niet
  als scène met een vast pad.
- HP van vijanden zit in een `Dictionary` met de node als sleutel (`som_arena.gd:52`,
  gezet in `register` op `:213`). Een synchronizer kan die dictionary niet repliceren.
- De kaart-monsters staan al in de kamerscène. Een spawner zou ze een tweede keer maken.
- Schade en buit rollen met de globale `randf` (`som_arena.gd:405`, `:215`, `:536`).
  Dat mag alleen op de host gebeuren. Een synchronizer stuurt het resultaat niet, alleen
  properties, en elke peer zou anders rollen.

Daarom: eigen pakketten op dezelfde ENet-peer. Betrouwbaar voor gebeurtenissen (treffer,
spreuk, vangst, buit, lock, join). Onbetrouwbaar voor snapshots. Geen `@rpc` op
`SomArena` tot de sim en de tekening uit elkaar zijn.

## Wat moet mee

| Staat | Waar het nu leeft | Hoe het straks gaat |
|---|---|---|
| Positie, kijkrichting, loopframe | één `player` (`scripts/map.gd:40`, `scripts/player.gd:40`, analoge stap in `_process` `:195`) plus `SomAlly` | snapshot, 20 Hz. Lokale speler voorspelt; de rest interpoleert |
| Vijand-positie, pose, HP, doel-held | `enemies` in de arena (`som_arena.gd:213`, AI `:673`) | zelfde snapshot. Alleen de host tikt de AI |
| HP/MP van helden | `GameState.party` (`game_state.gd:203`) via `member()` (`som_arena.gd:220`) | host schrijft; snapshot stuurt hp/mp per stoel |
| Treffer en knockback | `damage_enemy` `:487`, `hit_member` `:745` | betrouwbaar event ná de host-worp. Cijfertjes zijn lokaal oog |
| Spreuk | `cast_spell` `:867`, vrijgave op het hit-frame (`spell_released`) | gast stuurt "ik cast X op doel Y"; host trekt MP af en stuurt het resultaat |
| Codex-vangst | `som_codex.gd:113` (boek −1) en `:126` (`codex_add`) | alleen de host rolt en schrijft de pagina |
| Target lock | nog geen speler-lock; vijand-doel is een held-id | lock = input van die stoel; vijand-doel zit in de snapshot |
| Buit, EXP, goud | `_defeat_enemy` `:523`–`:538` schrijft meteen `GameState` | host-event "deze ids, deze exp". Gasten tekenen de toast, schrijven niets |
| Ring / items | `resolve` `:839` past `GameState.inventory` aan | zelfde regel: verzoek van de gast, mutatie op de host |

Animatie die alleen mooi moet zijn (slash, spark, cast-gloed) gaat niet over het netwerk.
De gast speelt hem af bij het event. Mis je een pakket, dan mis je een vonkje, niet de HP.

## Klok en bandbreedte

Lopen gebeurt nu in `_process` met de frame-delta, expres niet in `_physics_process`,
omdat 90/120 Hz-telefoons anders schokken (`player.gd:116`). Peers hebben een andere
framerate. De host moet de sim daarom op een vaste stap doen: **60 Hz** (`SIM_HZ`),
delta opgeteld, ongebruikte rest bewaren. De tekening blijft op de refresh van het toestel.

Snapshots: **20 Hz**. Interpolatiebuffer: **100 ms** (twee snapshots). Input van een gast:
**30 Hz** (stick als twee bytes + knoppen). 60 deelt door 20, dus elke snapshot valt op
een sim-tick.

Schatting per snapshot, plafond 4 spelers en 8 vijanden (een WM1-kamer heeft er minder).
De getallen staan in `scripts/net/net_protocol.gd` en `--nettest` bewaakt het plafond.

| Veld | Bytes |
|---|---|
| Kop (soort, tick, aantallen) | 5 |
| Per speler: stoel, x, y, kijk+frame, hp, mp, vlaggen | 11 |
| Per vijand: index, x, y, hp, pose, doel-stoel | 9 |
| Payload 4 + 8 | 121 |
| UDP/IPv4 + ruime ENet-kop | 48 |
| Datagram | 169 |

De host stuurt dat naar 3 gasten: 169 × 20 × 3 = **10140 bytes/s** omhoog.
Input terug: (6 + 48) × 30 × 3 = **4860 bytes/s**.
Samen onder de 16 KiB/s. Wifi trekt dat zonder moeite.

De kosten zitten niet in de bytes. Een pakket elke 50 ms houdt de radio wakker
(wifi-staart is langer dan het pakket). 60 snapshots per seconde zou de radio
onnodig aan laten en de telefoon warmer maken. 20 Hz is het voorstel voor fase B.
Het baken (elke 0,5 s) stopt zodra iedereen in de kamer zit.

## LAN-vinden

`scripts/net/lan_discovery.gd`. De host bindt poort 38423 en stuurt elke 0,5 s een
JSON-baken naar `255.255.255.255:38422`. Velden: `game=sapientia-coop`, versie, ENet-poort
38421, naam, aantal spelers, max 4. Een ander spel of een andere versie wordt niet
als host getoond (`parse_announce`: wel parsen, `compatible` false).

Op één pc komt broadcast naar 255.255.255.255 vaak niet terug op 127.0.0.1.
De suite test daarom de parser, en één unicast naar de loopback. Productie blijft broadcast.

Er is nog geen veld om een IP in te tikken. Dat blijft de uitweg als multicast op een
telefoon dood blijft (zie Android): een fallback, niet de enige weg. DECISION 10 gaat
over twee LAN-ingangen, niet over dat veld.

## Android

Deze PR wijzigt `export_presets.cfg` niet. De preset heeft geen netwerkrechten aan staan;
`permissions/custom_permissions` is leeg (`export_presets.cfg:60` en `:127`). Een latere
PR moet ze expliciet aanzetten, pas als de lobby echt in de build zit:

- `INTERNET` — ENet en UDP
- `ACCESS_NETWORK_STATE` en `ACCESS_WIFI_STATE` — weten of er wifi is
- `CHANGE_WIFI_MULTICAST_STATE` — zonder dit filtert Android broadcast weg

Godot 4.3 pakt zelf geen `WifiManager.MulticastLock`. Zonder een kleine Android-plugin
(lock vast zolang de lobby open is, daarna los) zien veel telefoons het baken niet,
terwijl ENet naar een IP wél werkt. De plugin hoort bij de Android-PR, niet hier.

Batterij: zie de klok. Geen foreground-service. Het baken uit zodra de kamer loopt.
Scherm aan is duurder dan deze pakketten; we houden de radio alleen wakker tijdens het spelen.

Pauze en hervat:

- Android stuurt `NOTIFICATION_APPLICATION_PAUSED`. Godot roept dan geen `_process` meer aan,
  dus niemand pollt ENet. De andere kant ziet dat als een dode peer (5–30 s).
- `GameState._notification` (`game_state.gd:1087`) slaat bij pauze bewust niet meer op.
- `Sessielog` noteert pauze/hervat (`sessielog.gd:173`). Dat is een lokaal logboek, geen sync.
- `touch_controls.gd:369` laat alle vingers los bij focus-verlies. Een gast die wegvalt
  stuurt dus "stick nul" als hij nog één frame krijgt; daarna komt er niets. De host
  moet een stille gast als stilstaande input behandelen, niet als "laatste richting vasthouden".
- Hervat: meteen pollen. Is de peer weg, Engelse melding "Connection lost" en terug naar
  de lobby. Geen stille hervatting van een half dooie socket.
- Host weg of host-app dood: de sessie stopt. Geen host-migratie (DECISION 5).

Disconnect van een gast: stoel vrij, held weer kiesbaar, de host blijft de kamer draaien.
De verbinding van de host die sterft: iedereen eruit. De lobby doet het stoel-stuk al;
de arena nog niet.

## Saves

Alleen de host schrijft `user://`. `save_game` (`game_state.gd:1102`) en `autosave`
(`:1051`) serialiseren de ene `GameState`. Een gast die dat aanroept zou zijn eigen
solo-save overschrijven met de wereld van de host, of andersom.

Regels voor de PR die de kamer aansluit:

- Gast: geen `save_game`, geen autosave, geen checkpoint-schrijven.
- Host: opslaan mag, en de save is de zijne. Co-op-goud en Codex staan daarin.
- Een solo-save van een gast blijft onaangeroerd als hij de lobby verlaat.
- Bij een volledige disconnect is er niets te mergen. Wie opnieuw joint, ziet de
  wereld zoals de host die nú heeft, niet zoals bij zijn vertrek.

Dat is DECISION 3 en 7. De module schrijft zelf niets naar `user://`.
Fase C schrijft de gast wél terug, maar naar zijn eigen save en pas aan het eind
van de sessie. Zie [Fase C requirements](#fase-c-requirements). Fase B mag beloningen
daarom niet in één tas zonder eigenaar stoppen.

## Audit — wat multiplayer blokkeert

Acht autoloads (`project.godot:21`). Drie daarvan houden geen wereld vast en hoeven
niet gesynchroniseerd: `Transition` (fade, `scripts/transition.gd:8`), `Crt`
(shader, `scripts/ui/crt_overlay.gd:34`) en `AudioManager` (lokale spelers,
`scripts/audio_manager.gd:72`). Die blijven per toestel.

De rest blokkeert, plus een paar statische variabelen en de engine-singleton `Input`.

### 1. `GameState` is de hele wereld, en de enige save

`scripts/game_state.gd`. Eén partij, één tas, één verhaal.

| Staat | Regel | Refactor |
|---|---|---|
| `leader_id` | 48 | per stoel, niet één globale bestuurde held. De host kent de stoel→held-map |
| `party`, `party_bench` | 203, 205 | host-kopie van wie er nu in de kamer staat. Mutaties (`give_exp` `:2359`) alleen op de host. Sleutel is de stoel, niet alleen de held-id |
| `inventory`, `gold` | 210, 211 | zelfde poort. `SomArena` schrijft hier nu direct (`:529`, `:538`). Fase B: één wereld-tas. Elke grant noemt wel een stoel |
| `codex_pages`, `codex_active`, `codex_next_id` | 149–151 | vangst via `codex_add` `:2396` alleen op de host, met stoel van de vanger |
| `story_step`, `story_flags` | 186–187 | singleplayer (DECISION 7). Geen sync in fase B |
| `quest_progress` | 198 | zelfde. ECHO-log is fase A; niet aankoppelen |
| `som_mode` | 214 | de host beslist Action. Een gast met Classic mag de kamer niet lokaal omschakelen |
| `in_battle`, `pending_*`, `map_monster_battle` | 254, 248, 260 | baasgevecht is een scènewissel naar één lokaal gevecht (`start_battle` `:1821`). Co-op gaat daar niet doorheen (DECISION 8) |
| `defeated_map_monsters` | 261 | host houdt bij welke map-monsters weg zijn. Meesturen bij kamerwissel, niet per frame |
| `checkpoint` | 271 | alleen de host schrijft hem weg |
| `save_game` / pauze-hook | 1102, 1087 | vroeg `return` als dit toestel geen host is |

Voorstel: een smalle `NetWorld`-poort (volgende PR, nog zonder arena) met
`mutate(op)` die op een gast niets doet en op de host de bestaande functies aanroept.
Geen tweede inventaris verzinnen.

### 2. `Story` speelt één event voor de hele boom

`scripts/story.gd:19` `running`, `:20` `current_event`, `:26` `after_battle_event`.
`map.gd` en objecten roepen `Story.trigger` aan alsof er één speler in de kamer staat.
Een gast die lokaal een event start, desynct de vlaggen.

Refactor: in co-op roept alleen de host `Story.trigger` aan. Gasten tekenen het tekstvak
als de host de regels stuurt. In de Action-sandbox geen story-triggers (DECISION 7).

### 3. `Dialog` is één tekstvak

`scripts/dialog_box.gd:32` `is_open`. `player.gd:123` weigert te lopen zolang dat vak
open is, voor die ene speler. `can_autosave` kijkt naar hetzelfde vak (`game_state.gd:1069`).

Refactor: tekst in co-op is een host-event ("deze regels"), lokaal getekend, en blokkeert
alleen de input van de speler die in het gesprek zit. Het globale `is_open` mag de
andere drie niet bevriezen. Niet in de lobby-PR.

### 4. `Settings` ligt per toestel en stuurt het gevecht

`scripts/settings.gd:64` `values`, `:60` `battle_style` (0 Classic / 1 Action).
`DungeonRoom.wants_som` (`scripts/dungeon/dungeon_room.gd:123`) zet de arena aan op
basis van die lokale vlag of `GameState.som_mode`. Twee telefoons kunnen oneens zijn.
`battle_speed`, teksttempo en autosave zijn ook lokaal.

Refactor: bij join stuurt de host zijn Effectieve modus (Action aan/uit) in het
WELCOME, later uitgebreid. Volume, CRT en teksttempo blijven lokaal. Autosave op een
gast staat uit zolang hij guest is, ongeacht zijn eigen vlag.

### 5. De arena simuleert lokaal en schrijft meteen de wereld

`SomArena._process` (`som_arena.gd:336`) tikt lading, iframes, bondgenoten en elke vijand.
`register` zet de start-cooldown met `randf()` (`:215`). `physical_damage` rolt
`randf_range` (`:405`). `_defeat_enemy` geeft EXP aan `GameState.alive_heroes()`
(`:531`), dus aan de hele partij alsof iedereen één toestel deelt.

Refactor, pas als fase A op `main` staat: splits `tick(input_per_stoel)` (puur,
vaste stap, RNG van de host) van de nodes die sprites tekenen. Gasten sturen input.
Ze draaien `tick` niet. De bestaande signalen (`enemy_hit`, `spell_released`, …)
blijven de haak voor oog en geluid.

### 6. Eén lichaam, één vinger, één camera

- De kaart heeft één speler-node (`scripts/map.gd:40`). De arena zet daar de analoge
  provider op (`som_arena.gd:120`) en leest `touch.joy_raw` of het toetsenbord (`:324`).
- `Input` is een engine-singleton. `SomArena._ensure_actions` (`:167`) schrijft in de
  globale `InputMap`.
- De camera zit op die ene speler (`player.gd`, aangemaakt als child). In co-op moet
  elke telefoon de camera op zijn eigen stoel hebben.
- Bondgenoten zijn AI (`som_ally.gd:87`), geen tweede input.

Refactor: per stoel een body. De lokale stoel leest `TouchControls` (`joy_raw` op
`scripts/touch_controls.gd:68`). Andere stoelen krijgen hun richting uit de snapshot.
Lege stoelen krijgen in fase B geen body (DECISION 2).

### 7. De ring zet de hele SceneTree op pauze

`scripts/som/som_ring.gd:79`–`:93`. Alles met `PROCESS_MODE_PAUSABLE` stopt, inclusief
vijanden en een netwerk-tick die per ongeluk pausable is. De lobby zet zichzelf daarom
op `PROCESS_MODE_ALWAYS`. De arena doet dat niet.

Refactor: de ring tekenen zonder `get_tree().paused` (DECISION 4). Een gekozen item
blijft een verzoek aan de host.

### 8. Sessielog gaat uit van één speler

`scripts/sessielog.gd:66` onthoudt één `_speler`, `:40` één sessie, en schrijft
`user://sessielogs`. Hij leest `GameState.party` (`:475`). Hij stuurt het gevecht niet,
maar een gast die het log aanzet schrijft een tweede, misleidend boek en leest de
host-party alsof die lokaal is.

Refactor: in co-op logt alleen de host, of elk toestel logt alleen zijn eigen input
met stoel-id. Geen sync van het log. Niet aankoppelen zolang fase A het log nog wijzigt.
De pauze-regels (`:173`) blijven lokaal.

### 9. Statische sessie-staat buiten de autoloads

Niet de eerste vijf, wel kapot als twee peers of twee kamers hem delen alsof hij netwerk is:

| Staat | Regel | Refactor |
|---|---|---|
| `PuzzleRoom._session_latched`, `_battle_snapshots` | `scripts/puzzle/puzzle_room.gd:71` | hoort in `GameState` (deels al) en dus bij de host. Puzzels zitten niet in de eerste Action-kamer; niet meenemen tot een puzzelkamer co-op is |
| `DungeonRooms.current_theme` | `scripts/data/dungeon_rooms.gd:218` | per kamer gezet tijdens `_build`. Veilig zolang elke peer dezelfde kamer alleen bouwt. Niet repliceren |
| `WilgendalDorp.poorten_open` | `scripts/data/wilgendal_dorp.gd:756` | dorp-hekken, buiten fase B. Straks host-staat als het dorp meedoet |
| `SomData.action_boss_override` | `scripts/data/som_data.gd:350` | alleen de simulator. Niet in de build gebruiken |

`randf()` zonder gedeelde seed blijft verboden buiten de host. De host hoeft zijn seed
niet te sturen als alléén hij rolt en het resultaat meestuurt.

## De vijf die een kamer het hardst tegenhouden

1. Eén `GameState` voor partij, tas, goud, Codex, verhaal en save (`game_state.gd:203`, `:210`, `:149`, `:186`, `:1102`).
2. De arena simuleert lokaal en schrijft die staat meteen, met globale `randf` (`som_arena.gd:336`, `:405`, `:523`).
3. Eén speler-node, één `Input`, één camera (`map.gd:40`, `player.gd:195`, `som_arena.gd:324`).
4. De ring pauzeert de boom (`som_ring.gd:83`).
5. Baas en verhaal zijn één lokaal scherm of één event (`game_state.gd:1821`, `story.gd:19`, `dialog_box.gd:32`).

## Fase C requirements

Fase B blijft zoals de besluiten hierboven. Fase C komt daar bovenop. Drie eisen:

1. Elke gast joint met zijn **eigen** save en zijn **eigen** held, van zijn eigen telefoon, en speelt die in de wereld van de host.
2. Wat de gast in co-op verdient, gaat terug naar die eigen save: EXP, levels, items, goud en Codex-vangsten.
3. Daar hoort een save per speler bij, en een sync/merge aan het eind van de sessie, met anti-duplicaat en anti-cheat.

AI op lege stoelen en de relay komen in dezelfde fase, ná dit save-model. Het relay-protocol zelf is hier nog niet uitgewerkt.

### Wie wat bezit

De host bezit de wereld. Kamer, vijanden, geopende kisten, verslagen of gevangen map-monsters, de worpen (`randf`), en de sandbox-save. Hij is de enige die de simulatie draait.

Elke gast bezit zijn held. Dat is het personage uit zijn eigen save: niveau, EXP, HP/MP, uitrusting, zijn tas, zijn goud, zijn Codex. Die blob reist mee in de join. Hij wordt geen extra lid in `user://som_save_1.json` van de host.

Tijdens het spelen houdt de host per stoel een grootboek bij. Een regel is een grant: id, stoel, soort (EXP, goud, item, Codex-pagina of verbruik), bedrag, en of hij al terug is geschreven. Wereld-staat en grootboek blijven twee dingen. DECISION 3 (de gast neemt in fase B niets mee) betekent dan: fase B schrijft het grootboek niet terug. Het betekent niet dat de buit in één tas zonder eigenaar valt.

### Terugschrijven bij vertrek en bij een breuk

Schoon vertrek. De host sluit het grootboek van die stoel af op de laatste sim-tick en stuurt de delta. De gast past hem toe op zijn eigen save en bevestigt. De host markeert die grants als geclaimd. De gast schrijft de wereld van de host niet weg.

Breuk (app weg, ENet-timeout). De stoel gaat meteen vrij (DECISION 6). Het grootboek niet. De host bewaart de ongeclaimde delta onder het save-id van de gast. Bij de volgende join bij deze host komt die delta binnen vóór het spelen. Alleen een delta die de host heeft uitgedeeld, mag op de gast-save. Wat nog niet bevestigd was, blijft bij de host tot die join, of tot de save van de host zelf weg is.

### Geen duplicaat, en geen vertrouwen in de gast

Een wereld-item (kist, drop, uniek monster) heeft een id in de host-wereld en wordt één keer verbruikt. Een tweede speler leegt dezelfde kist niet.

Een persoonlijke grant heeft een id (sessie plus teller). De gast-save onthoudt welke ids al toegepast zijn. Dezelfde delta nog eens toepassen doet niets.

De tas van de gast wordt niet gekopieerd naar `GameState.inventory` van de host. Meenemen, gebruiken of laten vallen is een delta: min één bij de gast, en alleen als het voorwerp in de wereld blijft een nieuw wereld-item. Anders heeft het twee eigenaren.

Goud van de gast en goud van de host blijven twee beurzen. Gevechtsgoud voor de gast is een grant, geen optelling bij het goud van de host.

Een Codex-pagina krijgt één uid en gaat naar de vanger. Het monster is daarna weg uit de wereld. Een soort die die speler al had, levert geen tweede pagina.

De sleutel is stoel plus save-id, niet de held-id. Twee Serens delen geen `party`-entry.

Gasten sturen input, geen uitkomst. Schade, buit en vang-worpen bestaan alleen op de host. Een gast die lokaal items bijschrijft zonder grant-id telt niet mee in de gedeelde wereld. Na afloop kan iemand zijn eigen `user://` nog met de hand wijzigen; dat valt buiten de sessie. De gedeelde wereld en het grootboek vertrouwen de gast niet. Een latere relay kan de delta ondertekenen als online spelen dat eist. Op lokaal wifi is de host de handtekening.

### Wat fase B niet mag dichtmetselen

- DECISION 1 (Dax, Seren, Vesper, Kael) geldt voor fase B. Een stoel moet later een willekeurige held uit een gast-save kunnen dragen. `NetProtocol.ROSTER` blijft een fase-B-lijst. Gevechtsstaat sleutelt op stoel, de held-id is stats en sprite.
- DECISION 3 schrijft in fase B niets terug naar de gast. De events noemen toch al een stoel, zodat het grootboek later aan kan zonder de arena een tweede keer te splitsen.
- DECISION 7 maakt de sandbox de wereld-container van het prototype. Gast-voortgang hoort daar niet in als extra party-leden.
- DECISION 6 maakt het lichaam vrij, niet het grootboek van die stoel.
- DECISION 2 houdt de bezetting als drie standen: leeg, remote, en later AI. Geen tweede party-structuur voor de AI-vulling.
- DECISION 4: een item uit de ring blijft een verzoek aan de host, zodat verbruik in het grootboek staat.
- DECISION 9 (één lock per speler) past al op een stoel. Zo houden.

## Stap-plan (kleine PR's)

Elke PR blijft van `som_*.gd`, `touch_controls.gd`, de HUD, Settings en de fase-A-bestanden
af tot fase A op `main` staat, behalve de PR die de arena splitst. Die wacht expliciet
op die merge. Branch-namen daarna weer `cursor/<taak>`. De suite `--nettest` hoort in
de CI-matrix pas als deze voorbereiding gemerged is; deze PR laat de workflow met opzet met rust.

1. **Deze PR** — nota, lobby, baken, protocol, `--nettest`. Geen scène, geen save, geen arena.
2. **Snapshot-roundtrip** — nog steeds `scripts/net/`. Vaste 60 Hz-stap, 20 Hz-snapshot, één
   nep-positie host→gast in `--nettest`. Geen Godot-node uit het spel.
3. **Host-poort op `GameState`** — `mutate` / "alleen host schrijft". Bestaande solo-pad
   blijft de host. Tests: een gast-vlag schrijft geen `user://`. Elk belonings-event noemt
   al een stoel, ook al gooit fase B de kopie van de gast weg (zie fase C). Dit is de
   eerste PR die `game_state.gd` écht aanraakt; klein houden.
4. **Arena splitsen** — ná fase A. `tick` puur, tekening blijft in de nodes. Eén kamer,
   vijanden en HP, nog zonder menu. Headless: twee inputs, één HP-uitkomst.
5. **Debug-ingang** — niet het titelscherm. Lobby koppelen aan die kamer. Vier stoelen,
   camera op de lokale stoel.
6. **Lichamen** — gevulde stoel is een speler, geen `SomAlly`. Lege stoel is leeg (DECISION 2).
7. **Events** — slag, spreuk, Codex, buit, target-lock. Betrouwbaar. Lock pas als fase A
   de solo-lock gemerged heeft.
8. **Android** — rechten, multicast-lock-plugin, pauze/hervat, Engelse disconnect-tekst.
   Nog geen APK-versie en geen signing.
9. **Fase C** — AI op lege stoelen, per-speler-save en merge zoals hierboven, daarna een relay.
   Niet beginnen vanuit deze lobby door stiekem internet open te zetten.
