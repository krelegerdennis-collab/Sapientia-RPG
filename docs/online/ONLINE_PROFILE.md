# Online profiel (M1)

Lokaal co-op-profiel voor rang en cosmetica. Los van de verhaal-saves
(`save_N.json`, `autosave.json`, `som_save_1.json`, `coop_guest_*.json`).
Geen UI in M1. API: `OnlineProfile` in `scripts/online/online_profile.gd`.

## Bestand

`user://online_profile.json`, versie 1. Drie slots, index 0..2. Een leeg slot is `null`.
Een bestand met 0..3 slots wordt bij het laden aangevuld tot drie. Meer dan drie slots,
kapotte JSON of een andere `version` wordt niet gelezen: de bytes gaan naar
`user://online_profile.json.bak` (of `user://online_profile.<tijd>_<n>.bak` als `.bak`
er al is) en het spel gaat verder met een leeg profiel. Geen crash, en het kapotte
bestand wordt niet over de reservekopie heen geschreven.

```json
{
  "version": 1,
  "slots": [
    {
      "uid": "a1b2c3d4",
      "name": "Mira",
      "class": "priest",
      "look": {"body": 0, "skin": 2, "hair": 3, "hair_color": 5, "top": 1, "top_color": 0, "bottom": 2, "bottom_color": 4, "head": 0},
      "profile_exp": 0,
      "unlocks": ["hair_3"],
      "stats_seen": {"best_floor": 0, "runs": 0},
      "applied_grants": []
    },
    null,
    null
  ]
}
```

`uid` is 8 hex-tekens (kleine letters), eenmalig binnen het profiel. `name` is 1 tot 5 letters A–Z.
`class` is `warrior`, `mage`, `priest`, `psytech` of `archer`. Twee slots mogen dezelfde klasse hebben.

| class | base_hero | rol |
|---|---|---|
| warrior | dennis | Tank |
| mage | noor | Control |
| priest | lotte | Heal |
| psytech | kael | Dps |
| archer | orion | Dps |

`base_hero` en `role` worden niet opgeslagen. `OnlineProfile.base_hero_for()` en `role_for()` leiden ze af.
Stats en items uit `game_data.gd` horen niet in dit bestand.

Look-velden (index, inclusief), uit de v1-aantallen in het ontwerp:

| veld | max | betekenis |
|---|---|---|
| body | 0 | één lichaam |
| skin | 3 | 4 huidtinten |
| hair | 5 | 6 kapsels |
| hair_color | 7 | 8 haarkleuren |
| top | 3 | 4 bovenkleding |
| top_color | 5 | 6 kleuren |
| bottom | 2 | 3 broeken |
| bottom_color | 5 | 6 kleuren |
| head | 2 | 0 = geen, 1 en 2 = hoofddeksel |

`profile_exp` 0..999999. `stats_seen.best_floor` 0..100, `runs` 0..9999.
`unlocks`: hoogstens 16 id's, `applied_grants` hoogstens 8. Een id is 1..16 tekens `a-z`, `0-9` of `_`, zonder dubbelen.

## Look-bytes (voor HELLO, later)

`encode_look()` / `decode_look()` geven exact 16 bytes. Niet het exportformaat.

| byte | inhoud |
|---|---|
| 0 | versie `1` |
| 1..9 | de negen look-velden, in de volgorde hierboven |
| 10..14 | gereserveerd, moet 0 zijn |
| 15 | checksum: som van byte 0..14, modulo 256 |

Een verkeerde lengte, versie, checksum, gereserveerd byte of waarde geeft een lege `Dictionary` terug.
`encode_look()` geeft dan een lege `PackedByteArray`. Byte 10 blijft vrij voor een latere `head_color`.

## Exportcode

Eén code voor het hele profiel (alle drie de slots). Verhaal-saves zitten er niet in.

1. UTF-8 JSON van het document, compact (`JSON.stringify` zonder inspringen).
2. `PackedByteArray.compress` met `FileAccess.COMPRESSION_DEFLATE` (Godot 4.3, niet een losse zlib-stream van buitenaf).
3. Envelop, big-endian:

```
[0]     u8   versie = 1
[1..4]  u32  lengte van de JSON in bytes
[5..n]  deflate(JSON)
[n+1..n+4]  CRC32-IEEE (ISO-HDLC) over alles vóór de checksum
```

4. Die bytes als base31 met het alfabet van `relay/src/codes.js`:
   `23456789ABCDEFGHJKMNPQRSTUVWXYZ`.
   Geen `0`, `O`, `1`, `I` of `L`. Het alfabet heeft 31 tekens, daarom base31 en niet RFC-4648-base32.
   Het eerste envelop-byte is nooit 0, zodat de lengte bij het terugrekenen behouden blijft.

Bij het importeren worden spaties, regeleinden en koppeltekens genegeerd en letters hoofdletters.
CRC32 van de ASCII-tekst `123456789` is `CBF43926`.
Controlevoorbeeld base31: de bytes `01 00` worden `AA`.

Grenzen: JSON hoogstens 3072 bytes, code na normaliseren hoogstens 4096 tekens, ruwe invoer hoogstens 16384 tekens.

### Weigering

`import_code` laat het lokale profiel staan en geeft `ok = false` plus een `reason`:

| reason | wanneer |
|---|---|
| empty | leeg, of alleen spaties |
| too_long | langer dan de grens |
| alphabet | teken buiten het alfabet (ook `0`, `O`, `1`, `I`, `L`) |
| checksum | CRC32 klopt niet |
| version | envelop of JSON-versie is niet 1 |
| corrupt | niet uit te pakken, of geen JSON-object |
| schema | JSON is geen geldig profiel |
| io | schrijven lukte niet |

`message` is een korte Nederlandse zin voor een later scherm. M1 toont die nog nergens.

## API

Geen autoload. `var profiel := OnlineProfile.new()` en daarna `load_profile()`.
Signals: `profile_loaded(recovered)`, `profile_changed(index)` (`-1` = het hele profiel), `import_refused(reason)`.

`create_slot`, `clear_slot`, `set_progress`, `export_code`, `import_code`.
Elke geslaagde wijziging schrijft meteen het bestand (eerst `.tmp`, daarna rename).

## Afwijking van het ontwerp

- Het voorbeeld in §5.1 toont alleen gevulde slots. Op schijf staan altijd drie plekken, met `null` voor een leeg slot, zodat wissen de andere indexen niet verschuift. Een korter bestand (0..3) laadt nog wel.
- §5.1 liet het codeformaat open. Gekozen: één code voor alle slots, deflate, CRC32, alfabet gelijk aan de kamercode. Base31 in plaats van base32, omdat dat alfabet 31 tekens heeft en `0/O/1/I/L` er niet in mogen.
- De versiebyte en de JSON-lengte staan vóór de deflate, niet erin. Een oude versie is dan te weigeren nadat de checksum klopt, zonder de inflate te vertrouwen. De JSON heeft zelf ook `"version": 1`.
- `head_color` uit §5.3 staat niet in het §5.1-model. Byte 10 van de look is daarvoor gereserveerd.
