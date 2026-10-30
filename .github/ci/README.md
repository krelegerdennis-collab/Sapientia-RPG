# CI-workflow

De testworkflow staat in `.github/workflows/tests.yml` (hierheen verplaatst vanuit deze map).

Hij draait bij een pull request en bij een push naar `main`. Godot is **4.3-stable**, met xvfb en `.github/scripts/run_suite.sh`. De matrix, de job `algemene-sfx` en de job `warper-runner` (`world_warper/tests/run.gd`) zijn de inhoud; er is geen tweede CI-systeem.

Daarnaast draait `.github/workflows/proef-suites.yml` (zelfde Godot-cache en `run_suite.sh`):
- job `proef-suites`: `formuletest`, `battlesimenemytest`, `combatbugstest`, daarna een lekcontrole op hun logs
  ("ObjectDB instances leaked" / "N resources still in use"). Bekende lekken staan in `leak_baseline.txt`
  (`<suite> <objectdb 0|1> <resources N>`); alleen méér dan de baseline is nieuw. `LEAK_STRICT=1`
  (workflow_dispatch-input of repo-variabele) laat de stap dan falen, standaard alleen een waarschuwing.
- job `battlesim-determinisme`: `--battlesim --party=dennis:5,noor:5 --enemy=all --total=1000 --seed=7` twee keer,
  daarna `cmp` op de CSV en de `_per_enemy.csv`.

Een web-export vanuit Actions naar `cursor/web-build-29ec` staat hier niet: die push vraagt een token met schrijfrecht dat deze repo niet heeft. De export blijft handmatig (Godot 4.7.2, threads uit).
