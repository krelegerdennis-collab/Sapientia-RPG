# SPEC kleurregel (magenta / goud) — RPG ART → RPG FORGE / RPG COMBAT

Status: **DECISION** op de regel zelf (Dennis: "Go alles" op de 8 game-feel-tips, 15 nov 2026, 14:03 Europe/Amsterdam). De exacte palet-slots hieronder zijn **PROPOSAL**, afgeleid uit het 73-kleuren-masterpalet en uit FX die de regel al volgen (`fx_death_glitch`, `fx_loot_pop`, Orion-finisher).

Dit is de laatste van die 8 tips: één signaalkleur voor gevaar, één voor beloning. Zo leest combat op een telefoon in één oogopslag. Geen nieuwe sheets in deze levering; bestaande FX zijn alleen gecontroleerd, niet aangepast.

Preview: `kleurregel_preview_4x.png` (268×344 bron, nearest 4× = 1072×1376, alleen masterpalet, alpha 0/255). 16×16-crops (loot, read, dodge-ring) staan 2× nearest in hun cel, met een `2X`-label in de cel, zodat ze even zwaar lezen als de 32×32-crops.

## De regel

- **Magenta** (en de glitch/ECHO-tinten) = gevaar, vijanden, glitch, vijand-telegraaf en read-flits, glitch-dood.
- **Goud** = beloning, player-finisher, loot, crit- en finisher-schadegetallen, perfecte dodge.
- **Neutraal of elementkleur** = gewone hits (fysiek, vuur, ijs, bliksem, natuur, licht).
- Nooit magenta (of glitch-paars) op held-vriendelijke feedback.
- Nooit goud op vijand-dreiging.

`#FFD24A` (COMBAT's `COL_HEAVY` voor het finisher-getal) zit **niet** in het palet. Gebruik **Gold 4 `#E0B040`** als kern, het dichtstbijzijnde paletgoud, met Gold 5 als lichtkant. Zelfde keuze als in de chain-finisher-FX.

Bron palet: `docs/art/masterpalet.gpl` (73 kleuren, 16 ramps). De JSON in `tools/som/sapientia_palette.json` mist Mint, Teal, Earth en Periwinkle; de GPL is compleet.

## Kleuren per rol

Alleen deze slots. Geen nieuwe tinten, geen half-alpha.

| Rol | Slot | Hex | RGB | Gebruik |
|---|---|---|---|---|
| Gevaar kern (primary) | Glitch Magenta 4 | `#E040C0` | 224, 64, 192 | lichaam van read, telegraaf, glitch-balken |
| Gevaar licht (highlight) | Glitch Magenta 5 | `#FFC8E8` | 255, 200, 232 | kernflits, deeltjes |
| Gevaar schaduw (shadow) | Glitch Magenta 2 | `#701C70` | 112, 28, 112 | staart, diepte |
| Gevaar lijn (outline) | Glitch Purple 1 | `#140A34` | 20, 10, 52 | 1 px donkere lijn, leest op lichte én groene vloer |
| ECHO-cyaan kern | Blue (Lotte/UI) 5 | `#40E0E8` | 64, 224, 232 | alleen als split naast magenta in glitch |
| ECHO-cyaan licht | Blue (Lotte/UI) 6 | `#C8F4FF` | 200, 244, 255 | glitch-kernpixel |
| ECHO-cyaan schaduw | Blue (Lotte/UI) 4 | `#4078C8` | 64, 120, 200 | glitch-contour |
| Beloning kern (primary) | Gold 4 | `#E0B040` | 224, 176, 64 | loot-ring, finisher-boog, crit-getal, perfect-ring |
| Beloning licht (highlight) | Gold 5 | `#F8E890` | 248, 232, 144 | lip, ster, vonkpunt |
| Beloning schaduw (shadow) | Gold 3 | `#A87020` | 168, 112, 32 | lichaam achter de kern |
| Beloning lijn (outline) | Gold 2 | `#6E3E10` | 110, 62, 16 | 1 px contour, leest op lichte vloer |

ECHO-cyaan is **geen** eigen signaalrol. Het hoort bij de RGB-split van glitch-dood en capture-FX (zelfde taal als de SAPIENTIA-titel). Nooit alleen, en nooit als beloning (dus niet op een perfecte dodge of een crit).

Ondersteuning, geen signaalkleur: White/Paper 5 `#FFFAF0` als witte flits/kern in beide rollen.

## Wanneer welke rol

| Moment | Rol | Voorbeeld (bestaande art) |
|---|---|---|
| Vijand gaat uithalen, read-flits, telegraaf "`!`" | gevaar / magenta | *moet*; `fx_death_glitch` volgt dit al, `fx_enemy_read` nog niet |
| Glitch-dood, ECHO-storing, enemy-glitch | gevaar / magenta + ECHO-cyaan als split | `fx_death_glitch.png`, `fx_death_glitch_48.png` |
| Loot-pop, goud-drop, beloning op de grond | beloning / goud | `fx_loot_pop.png` |
| Ketting-finisher, heavy treffer-burst, finisher-schadegetal | beloning / goud | `fx_chain_finisher_orion.png`, goudflits op `fx_chain_shockwave.png` |
| Perfecte dodge, counter-vonk | beloning / goud | *moet*; `fx_counter_spark` heeft al goud, `fx_perfect_ring` nog niet |
| Crit- / finisher-schadegetal | beloning / Gold 4, niet `#FFD24A` | code-kleur, geen sheet in deze audit |
| Gewone hit 1 / hit 2, fysieke spark | neutraal (Paper + Steen) | `fx_chain_hit1.png`, `fx_impact_fysiek.png` |
| Element-hit (geen finisher) | elementramp, geen goud-lichaam, geen magenta | vuur / ijs / bliksem / natuur: zie fase 1. Licht: *nog niet* |

**Elementen, gewone hits** (FACT uit fase 1, blijft staan):

- vuur: Red/Danger 2/4/5/6; Gold 5 alleen als klein hitteglimlicht (niet het lichaam).
- ijs: Blue 3/4/5/6 + Paper 5.
- bliksem: Blue 3/5/6, Gold 5 als kern (zo staat het in het palet: "Gold — FX bliksem (kern)"). De spark blijft cyaan/blauw lezen, geen beloningsflits.
- natuur: Green/Moss + Mint + Paper 4.
- licht: White/Paper 3/4/5, eventueel Blue 6 als glimlicht. **Niet** Gold 3/4 als lichaam.

## Held-kleur versus signaalkleur

De kleding, het haar en het wapen van een held zijn identiteit, geen signaal. Dax' paarse kling, Vespers paarse bol, Serens blauwe staf, Kaels ijs en Orions gouden pijl blijven zoals ze zijn, ook in de smear-v2-sheets. Die sheets zijn geen overtreding.

FX dat *feedback* is (burst, ring, vonk, read, dood, loot, schadegetal) volgt de kleurregel, ook als de held paars of goud is. Een Dax- of Vesper-finisher mag een dunne karakter-accentrand houden, maar het lichaam van de boog moet goud lezen, zoals bij Orion. Anders is "ik heb een finisher geland" niet te onderscheiden van "hier komt glitch-gevaar".

## Audit (bestaande FX, niet gewijzigd)

Gecontroleerd: alle `repo_drop`-sheets in `art_fx/chain_epic/`, `art_fx/perfect_dodge/`, `art_gamefeel/fase1/`, `art_gamefeel/fase2/` en smear v2 in `art_gamefeel/fase3_smear/`. Scratch, previews en originelen buiten die drops zijn geen levering.

**38 sheets gecontroleerd. 6 overtredingen. Niets aangepast.**

| Bestand | Wat er mis is | Wat er moet veranderen (later, niet nu) |
|---|---|---|
| `art_gamefeel/fase2/.../fx_enemy_read.png` | Read-flits is Red/Danger 1/4/5/6, dezelfde familie als het bestaande `fx_telegraph` "`!`". De regel wil magenta. | Herkleur naar Magenta 4/5/2 + Purple 1-outline, Paper 5-kern. Vorm mag blijven. Als de "`!`" meegaat, is dat een aparte, bestaande repo-sheet (buiten deze audit). |
| `art_fx/perfect_dodge/.../fx_perfect_ring.png` | De ring is volledig Blue 4/5/6 (ECHO-cyaan). Perfecte dodge is beloning, en cyaan alleen is glitch-taal. | Herkleur naar Gold 2/3/4/5 + Paper 5, zelfde ringvorm als nu, zelfde taal als `fx_loot_pop`. |
| `art_fx/perfect_dodge/.../fx_counter_spark.png` | Heeft al Gold 4/5 (goed), maar ook Blue 4/5/6 in frame 1 en in de armen. | Vervang cyaan door Gold 3 / Paper 4–5. Gouden punten en witte kern mogen blijven. |
| `art_gamefeel/fase1/.../fx_impact_licht.png` | Gewone licht-hit is 80% Gold 3/4/5. Leest als loot of finisher, niet als element. | Herkleur het lichaam naar Paper 3/4/5, hooguit Gold 5 als klein glimlicht (zoals vuur). |
| `art_fx/chain_epic/.../fx_chain_finisher_dennis.png` | 91,5% Glitch Purple, goudflits maar 5,9%. Player-finisher leest als ECHO-gevaar. | Houd een dunne paarse kling-accent als Dax-identiteit; maak de boog Gold 3/4/5 + Paper 5, zoals Orion. |
| `art_fx/chain_epic/.../fx_chain_finisher_noor.png` | 93,6% Glitch Purple, goudflits 5,0%. Zelfde probleem als Dax, voor Vesper. | Zelfde fix: paarse accentrand, gouden lichaam. |

**Geen overtreding (kort):**

- `fx_death_glitch` / `_48`: magenta + ECHO-cyaan. Juist.
- `fx_loot_pop`: Gold 3/4/5 + Paper 5. Juist.
- `fx_chain_hit1`, `fx_impact_fysiek`, ijs, natuur, alle drie de stof-sheets: geen goud, geen magenta. Juist.
- `fx_impact_vuur` (8% Gold 5) en `fx_impact_bliksem` (17% Gold 5, lichaam blauw): toegestaan element-glimlicht, geen beloningsflits.
- `fx_chain_hit2`, `fx_chain_finisher_lotte`, `fx_chain_finisher_kael`: Blue (Seren / ijs) met een gouden beloningsflits, geen magenta. Juist.
- `fx_chain_finisher_orion`, `fx_chain_shockwave`: goud op finisher. Juist.
- Smear v2 (15 sheets): goud en paars zitten in de held/het wapen (o.a. Serens haar Gold 3/5 in de originele frames, Kael 3–4 px Magenta 4 in het lijf, Dax/Vesper-wapen, Orion-pijl). Identiteit, geen signaal-FX. Niet herkleuren.

Buiten deze mappen, ter info: de bestaande `fx_telegraph.png` in de repo is ook Red/Danger. Zelfde richting als `fx_enemy_read`, geen onderdeel van deze audit.

## Open / later

De 6 sheets hierboven pas herkleuren na een kort akkoord van Dennis (of een toewijzing van Forge). Geen vorm- of timingwijziging nodig, alleen de signaalkleur. Schadegetallen in code (`COL_HEAVY` / `#FFD24A`) zijn een COMBAT-punt: Gold 4 gebruiken als ze op palet moeten.

## Levering

- `SPEC_kleurregel.md` — deze spec.
- `kleurregel_preview_4x.png` — swatches per rol + WEL/NIET-crops uit de bestaande FX (piekframes). 16×16-crops zijn 2× nearest in de cel (label `2X`); 24- en 32-crops blijven 1×. Daarna de hele sheet nearest 4×.
- `kleurregel_fixes_4x.png` — vóór/na-mock van de 6 voorgestelde herkleuringen. Alleen paletwissel, dezelfde vorm. Originelen ongewijzigd.
- `src/preview.py`, `src/fixes.py` — herbouw, wijzigen geen FX.

Geen repo- of enginebestanden aangeraakt. `wacht/wm2/` is niet gelezen.
