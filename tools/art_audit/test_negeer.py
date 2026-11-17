"""Tests voor de optionele --negeer-flag. Draaien: python3 -m pytest tools/art_audit

Bestaande tests blijven onaangeroerd. De PNG's staan in een tijdelijke map.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import meet  # noqa: E402
import palet_check  # noqa: E402

NORMAAL = "**/*_n.png"
LICHT = "assets/hd2d/fx_data/light_soft_128.png"


def test_glob_ster_op_elke_diepte() -> None:
    assert meet.glob_match("assets/hd2d/x_n.png", NORMAAL)
    assert meet.glob_match("assets/a/b/c/d_n.png", NORMAAL)
    assert meet.glob_match("x_n.png", NORMAAL)
    assert meet.glob_match("assets/a/b/x_n.png", "assets/**/x_n.png")
    assert not meet.glob_match(LICHT, NORMAAL)
    assert not meet.glob_match("assets/hd2d/sub/x_n.png", "assets/hd2d/*_n.png")
    assert not meet.glob_match("assets/hd2d/x_n.png", "")


def test_lege_lijst_slaat_niets_over(tmp_path: Path) -> None:
    png = tmp_path / "x_n.png"
    png.write_bytes(b"")
    assert not meet.is_genegeerd(png, [])


def _boom(root: Path) -> Path:
    assets = root / "assets"
    for rel, kleur in (
        ("hd2d/x_n.png", (1, 2, 3, 255)),
        ("hd2d/sub/diep_n.png", (1, 2, 3, 255)),
        ("hd2d/fx_data/light_soft_128.png", (9, 9, 9, 255)),
        ("keep.png", (16, 16, 24, 255)),
    ):
        pad = assets / rel
        pad.parent.mkdir(parents=True, exist_ok=True)
        Image.new("RGBA", (1, 1), kleur).save(pad)
    return assets


def test_zonder_negeer_telt_een_bestand_een_keer(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    root = (tmp_path / "repo").resolve()
    assets = _boom(root)
    monkeypatch.setattr(meet, "REPO_ROOT", root)
    over, aantal = meet.zonder_negeer(assets, [NORMAAL])
    assert aantal == 2
    assert [p.name for p in over] == ["light_soft_128.png", "keep.png"]
    over2, aantal2 = meet.zonder_negeer(assets, [NORMAAL, "**/x_n.png"])
    assert aantal2 == 2
    assert [p.name for p in over2] == ["light_soft_128.png", "keep.png"]


def test_meet_cli_herhaalbaar(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    root = (tmp_path / "repo").resolve()
    assets = _boom(root)
    monkeypatch.setattr(meet, "REPO_ROOT", root)
    uit = tmp_path / "meting.csv"

    assert meet.main(["--assets", str(assets), "--uit", str(uit)]) == 0
    zonder = capsys.readouterr().out
    assert "genegeerd" not in zonder
    assert len(uit.read_text(encoding="utf-8").splitlines()) == 5

    assert meet.main(["--assets", str(assets), "--uit", str(uit), "--negeer", NORMAAL, "--negeer", "**/keep.png"]) == 0
    met = capsys.readouterr().out
    assert "1 PNG's gemeten" in met
    assert met.splitlines()[-1] == "3 genegeerd"
    tekst = uit.read_text(encoding="utf-8")
    assert LICHT in tekst
    assert "x_n.png" not in tekst
    assert "keep.png" not in tekst


def test_palet_cli_houdt_licht_en_exit(tmp_path: Path, monkeypatch: pytest.MonkeyPatch,
                                       capsys: pytest.CaptureFixture[str]) -> None:
    root = (tmp_path / "repo").resolve()
    assets = _boom(root)
    monkeypatch.setattr(meet, "REPO_ROOT", root)

    assert palet_check.main(["--assets", str(assets)]) == 0
    assert "genegeerd" not in capsys.readouterr().out

    assert palet_check.main(["--assets", str(assets), "--streng"]) == 1
    capsys.readouterr()

    assert palet_check.main(["--assets", str(assets), "--negeer", NORMAAL, "--streng"]) == 1
    uit = capsys.readouterr().out
    assert uit.splitlines()[1] == "2 genegeerd"
    assert LICHT in uit
    assert "x_n.png" not in uit

    assert palet_check.main(["--assets", str(assets), "--negeer", NORMAAL, "--negeer", "**/light_soft_128.png",
                             "--streng"]) == 0
    assert capsys.readouterr().out.splitlines()[1] == "3 genegeerd"
