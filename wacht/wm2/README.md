# WM2 – in de wacht

In de wacht op verzoek van Dennis (20 okt 2026); niet lezen of gebruiken tot hij het terugzet.

Inhoud (oorspronkelijke paden, zelfde structuur onder deze map):
- `assets/sprites/som/kaart/dax_wm2.png` – kaartsheet Dax WM2 (72x128, 24x32 frames)
- `assets/sprites/som/kaart/seren_wm2.png` – kaartsheet Seren WM2 (oude look)

`wacht/.gdignore` zorgt dat Godot deze map niet importeert. De game draait volledig op WM1:
`scripts/data/kaart_stijl.gd` valt terug op `<naam>_wm1.png` in plaats van `<naam>_wm2.png`.
Terugzetten: `git mv` terug naar de oude paden, Godot opnieuw laten importeren, terugval in kaart_stijl.gd herstellen.

Niet geparkeerd (andere betekenis van "WM2"): World 2 in de World Warper (`world_warper/`, `archief2.gd`), dat is wereldkaart 2, geen kaartsprite.
