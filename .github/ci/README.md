# CI-workflow (nog te activeren)

`tests.yml` hoort in `.github/workflows/tests.yml`. Hij kon niet automatisch gepusht worden:
de gh-token van de bot heeft geen `workflow`-scope (GitHub weigert dan bestanden onder `.github/workflows/`).

Activeren (één van beide):
- In de GitHub-app/web: maak `.github/workflows/tests.yml` aan met de inhoud van dit bestand; of
- lokaal: `gh auth refresh -s workflow`, dan `git mv .github/ci/tests.yml .github/workflows/tests.yml` en pushen.

Daarna kan deze map weg.
