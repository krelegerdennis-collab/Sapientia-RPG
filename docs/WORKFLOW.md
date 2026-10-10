# Werkwijze: Cursor-agents

## De flow
1. **Taak** — Dennis of RPG Forge maakt een GitHub-issue met template *Cursor-taak* en label `cursor-agent`.
2. **Oppakken** — een Cursor-agent start een branch `cursor/<korte-taak>` (één taak per branch).
3. **PR** — de agent opent een PR naar `main` met het PR-template ingevuld (wat, waarom, tests, screenshots).
4. **CI** — GitHub Actions draait alle testsuites headless. Rood = niet mergen.
5. **Review** — RPG Forge reviewt en merget, bouwt de APK en doet de versie.
6. **Art nodig?** — label `art-nodig`; RPG ART maakt de echte art in plaats van de placeholder.

## Wie doet wat
| Wie | Doet |
|---|---|
| Dennis | eigenaar, keuzes, verhaal (`docs/lore/CANON.md`) |
| RPG Forge | `main`, review, merge, APK, versienummers |
| RPG ART | alle echte pixel-art (`tools/handwerk.txt`) |
| RPG CODE | gameplay |
| Cursor-agent | losse taken uit issues, met tests |

## Labels
- `cursor-agent` — taak voor een Cursor-agent
- `art-nodig` — er is echte art van RPG ART nodig
- `bug` — iets werkt niet

## Niet doen
Handwerk-art aanraken · echte art tekenen · secrets/APK committen · signing of versie aanpassen · zelf mergen.

Details voor agents: `AGENTS.md`.
