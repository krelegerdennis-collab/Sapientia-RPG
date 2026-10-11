# CI-workflow

De testworkflow staat in `.github/workflows/tests.yml` (hierheen verplaatst vanuit deze map).

Hij draait bij een pull request en bij een push naar `main`. Godot is **4.3-stable**, met xvfb en `.github/scripts/run_suite.sh`. De matrix, de job `algemene-sfx` en de job `warper-runner` (`world_warper/tests/run.gd`) zijn de inhoud; er is geen tweede CI-systeem.

Een web-export vanuit Actions naar `cursor/web-build-29ec` staat hier niet: die push vraagt een token met schrijfrecht dat deze repo niet heeft. De export blijft handmatig (Godot 4.7.2, threads uit).
