#!/usr/bin/env python3
"""SFX genereren met de offline AI-stack: ComfyUI + Stable Audio Open 1.0.

Draait op Dennis' laptop in WSL (daar staat ComfyUI op http://127.0.0.1:8188).
Agents in de cloud kunnen ComfyUI niet bereiken; dit script is bedoeld om zelf te draaien.

Per cue uit een cue-bestand (tools/sfx/cues_*.json):
  1. API-workflow (Stable Audio Open) naar ComfyUI: POST /prompt
  2. wachten op /history/<id>, bestand ophalen via /view
  3. ffmpeg: stilte aan begin én eind wegknippen, trimmen op max_s, fade-out, piek op -1 dBFS,
     mono 22050 Hz 16-bit wav (het formaat dat tools/check_algemene_sfx.py eist)
  4. wegschrijven in out/<cuebestand>/<cue>/, met de seed in de naam; herkomst (prompt, seed, model, sha1) in
     out/<cuebestand>/herkomst.json zodat de gekozen bestanden later nog te herleiden zijn

Twee soorten cue-bestanden:
  - spel-cues (cues_wm1_batch1.json): sleutel = sfx-id uit audio_manifest.json; bestandsnamen komen uit het manifest.
  - pack-cues (cues_retroquest_vol2.json): sleutel = pack-naam, "varianten" = aantal bestanden (sfx_<sleutel>_NN.wav),
    optioneel "manifest": sfx-id om dezelfde keuze ook in het spel te installeren.

Gebruik (repo-root, in WSL):
  python3 tools/sfx/gen_sfx.py --check-cues --cues tools/sfx/cues_retroquest_vol2.json   # alleen valideren
  python3 tools/sfx/gen_sfx.py --cues tools/sfx/cues_retroquest_vol2.json --seeds 5       # 5 kandidaten per bestand
  python3 tools/sfx/gen_sfx.py --cues ... --cue magic_fire_cast                           # een cue
  python3 tools/sfx/gen_sfx.py --cues ... --install                                       # out/<cuebestand>/kies/ -> assets/audio/sfx/
  python3 tools/sfx/gen_sfx.py --cues ... --pack-export dist/retroquest_vol2 [--crush 12] [--sr 22050]
                                                   # verkooppack: WAV + OGG + README.txt + SOURCES.csv

Werkwijze: genereren -> per bestand de beste kandidaat kopiëren naar out/<cuebestand>/kies/<pack-naam>_NN.wav
(zonder _s<seed>) -> --pack-export voor itch en/of --install voor het spel.

ONVERIFIED (5 nov 2026): de node-namen en invoervelden van de Stable Audio-workflow zijn uit de ComfyUI-voorbeelden
overgenomen maar nog niet op deze laptop gedraaid. Faalt POST /prompt, dan print ComfyUI welk veld niet klopt; pas
WORKFLOW hieronder aan. Eisen: ffmpeg in PATH, modellen uit ai-stack/scripts/audio_modellen.sh aanwezig.
Licentie: Stable Audio Open 1.0 = Stability AI Community License (commercieel gratis tot 1M USD omzet/jaar);
controleer vóór verkoop de actuele voorwaarden en lever SOURCES.csv mee.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST = os.path.join(ROOT, "assets", "audio", "audio_manifest.json")
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
PLACEHOLDER_LIST = os.path.join(ROOT, "tools", "placeholders_algemene_sfx.txt")
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")

COMFY = os.environ.get("COMFY_URL", "http://127.0.0.1:8188")
CKPT = "stable-audio-open-1.0.safetensors"
T5 = "t5-base.safetensors"
MODEL_NAME = "Stable Audio Open 1.0 (ComfyUI)"
SR = 22050
GAME_MAX_S = 0.60          # tools/check_algemene_sfx.py MAX_DUR
PEAK_DBFS = -1.0


def workflow(prompt: str, negative: str, seconds: float, seed: int, prefix: str) -> dict:
    """API-formaat workflow voor Stable Audio Open 1.0 (ONVERIFIED, zie docstring)."""
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": CKPT}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": T5, "type": "stable_audio"}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": prompt}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": negative}},
        "5": {"class_type": "ConditioningStableAudio", "inputs": {
            "positive": ["3", 0], "negative": ["4", 0],
            "seconds_start": 0.0, "seconds_total": float(seconds)}},
        "6": {"class_type": "EmptyLatentAudio", "inputs": {"seconds": float(seconds), "batch_size": 1}},
        "7": {"class_type": "KSampler", "inputs": {
            "model": ["1", 0], "positive": ["5", 0], "negative": ["5", 1], "latent_image": ["6", 0],
            "seed": seed, "steps": 50, "cfg": 5.0, "sampler_name": "dpmpp_3m_sde_gpu",
            "scheduler": "exponential", "denoise": 1.0}},
        "8": {"class_type": "VAEDecodeAudio", "inputs": {"samples": ["7", 0], "vae": ["1", 2]}},
        "9": {"class_type": "SaveAudio", "inputs": {"audio": ["8", 0], "filename_prefix": prefix}},
    }


def comfy(path: str, data: dict | None = None) -> dict:
    req = urllib.request.Request(COMFY + path)
    if data is not None:
        req.data = json.dumps(data).encode()
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode())


def run_prompt(wf: dict, raw_dir: str) -> str:
    """Stuurt de workflow, wacht tot klaar, geeft het pad van het opgehaalde bestand."""
    pid = comfy("/prompt", {"prompt": wf})["prompt_id"]
    for _ in range(600):
        time.sleep(1)
        hist = comfy("/history/" + pid)
        if pid in hist:
            outs = hist[pid]["outputs"]
            for node in outs.values():
                for a in node.get("audio", []):
                    q = urllib.parse.urlencode({"filename": a["filename"], "subfolder": a.get("subfolder", ""), "type": a.get("type", "output")})
                    raw = urllib.request.urlopen(COMFY + "/view?" + q, timeout=60).read()
                    tmp = os.path.join(raw_dir, a["filename"])
                    os.makedirs(os.path.dirname(tmp), exist_ok=True)
                    open(tmp, "wb").write(raw)
                    return tmp
            raise RuntimeError("geen audio-uitvoer in history voor %s" % pid)
    raise TimeoutError("ComfyUI klaar-wachten duurde te lang (%s)" % pid)


# ---------------------------------------------------------------- ffmpeg
def ffmpeg(args: list[str]) -> None:
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *args], check=True)


def peak_db(path: str) -> float:
    """Piekniveau in dBFS via volumedetect (loudnorm is onbetrouwbaar op clips < 3 s)."""
    r = subprocess.run(["ffmpeg", "-i", path, "-af", "volumedetect", "-f", "null", "-"],
                       capture_output=True, text=True, check=False)
    m = re.search(r"max_volume:\s*(-?[\d.]+) dB", r.stderr)
    return float(m.group(1)) if m else 0.0


def convert(src: str, dst: str, max_s: float, sr: int = SR, crush_bits: int = 0) -> None:
    """ffmpeg in twee stappen: (1) stilte voor en na weg, trim, fade-out, mono, samplerate;
    (2) piek op -1 dBFS (gemeten), optioneel lichte bitcrush voor de 16-bit-klank."""
    fade_start = max(0.0, max_s - 0.05)
    tmp = dst + ".tmp.wav"
    af1 = ",".join([
        "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.02",
        "areverse",
        "silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.03",
        "areverse",
        "atrim=0:%.3f" % max_s,
        "afade=t=out:st=%.3f:d=0.05" % fade_start,
        "aresample=%d" % sr,
    ])
    ffmpeg(["-i", src, "-af", af1, "-ac", "1", "-ar", str(sr), "-sample_fmt", "s16", tmp])
    gain = PEAK_DBFS - peak_db(tmp)
    af2 = ["volume=%.2fdB" % gain]
    if crush_bits:
        # eerst crushen, dan nog eens begrenzen: acrusher kan de piek iets verhogen
        af2.append("acrusher=bits=%d:mode=log:mix=0.5" % crush_bits)
        af2.append("alimiter=limit=%.3f:level=false" % (10 ** (PEAK_DBFS / 20.0)))
    ffmpeg(["-i", tmp, "-af", ",".join(af2), "-ac", "1", "-ar", str(sr), "-sample_fmt", "s16", dst])
    os.remove(tmp)


def to_ogg(src: str, dst: str) -> None:
    ffmpeg(["-i", src, "-c:a", "libvorbis", "-q:a", "5", dst])


def sha1(path: str) -> str:
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


# ---------------------------------------------------------------- cues
def load_cues(path: str) -> tuple[dict, dict]:
    """(cues, meta). meta = _style, _negative, _pack."""
    d = json.load(open(path))
    meta = {k: d.pop(k) for k in list(d) if k.startswith("_")}
    return d, meta


def cue_files(cue: str, spec: dict, man: dict, pack_prefix: str) -> tuple[list[str], str | None]:
    """Bestandsnamen voor deze cue + manifest-id (of None).
    Spel-cue: sleutel staat in het manifest -> manifest-bestanden. Pack-cue: varianten -> sfx_<cue>_NN.wav."""
    if cue in man and "varianten" not in spec:
        return list(man[cue]["bestanden"]), cue
    n = int(spec.get("varianten", 1))
    return ["%s_%s_%02d.wav" % (pack_prefix, cue, i + 1) for i in range(n)], spec.get("manifest")


def check_cues(args: argparse.Namespace) -> int:
    """Valideert een cue-bestand: velden, lengtes, manifest-koppelingen. 0 = goed."""
    man = json.load(open(MANIFEST))["sfx"]
    cues, meta = load_cues(args.cues)
    prefix = meta.get("_pack", {}).get("prefix", "sfx")
    fouten: list[str] = []
    namen: set[str] = set()
    for cue, spec in cues.items():
        for veld in ("prompt", "seconds", "max_s"):
            if veld not in spec:
                fouten.append("%s: veld '%s' ontbreekt" % (cue, veld))
        if not re.fullmatch(r"[a-z0-9_]+", cue):
            fouten.append("%s: sleutel alleen a-z0-9_" % cue)
        if spec.get("max_s", 0) > spec.get("seconds", 0):
            fouten.append("%s: max_s > seconds" % cue)
        if spec.get("max_s", 0) < 0.09:
            fouten.append("%s: max_s < 0.09 (check_algemene_sfx MIN_DUR)" % cue)
        files, mid = cue_files(cue, spec, man, prefix)
        for f in files:
            if f in namen:
                fouten.append("%s: dubbele bestandsnaam %s" % (cue, f))
            namen.add(f)
        if mid is not None:
            if mid not in man:
                fouten.append("%s: manifest-id '%s' bestaat niet" % (cue, mid))
            elif "varianten" in spec and int(spec["varianten"]) < len(man[mid]["bestanden"]):
                fouten.append("%s: %d varianten, manifest '%s' heeft %d bestanden" % (cue, int(spec["varianten"]), mid, len(man[mid]["bestanden"])))
        if "manifest" in spec and cue in man and "varianten" not in spec:
            fouten.append("%s: 'manifest' én sleutel in manifest: kies één" % cue)
    gemapt = sum(1 for c, s in cues.items() if cue_files(c, s, man, prefix)[1] is not None)
    print("%s: %d cues, %d bestanden, %d gekoppeld aan het spel, %d fouten" % (
        os.path.relpath(args.cues, ROOT), len(cues), len(namen), gemapt, len(fouten)))
    for f in fouten:
        print("  FOUT " + f)
    return 1 if fouten else 0


def out_dir(args: argparse.Namespace) -> str:
    return os.path.join(OUT, os.path.splitext(os.path.basename(args.cues))[0])


def herkomst_path(args: argparse.Namespace) -> str:
    return os.path.join(out_dir(args), "herkomst.json")


def load_herkomst(args: argparse.Namespace) -> dict:
    p = herkomst_path(args)
    return json.load(open(p)) if os.path.exists(p) else {}


# ---------------------------------------------------------------- genereren
def generate(args: argparse.Namespace) -> None:
    man = json.load(open(MANIFEST))["sfx"]
    cues, meta = load_cues(args.cues)
    style, neg = meta.get("_style", ""), meta.get("_negative", "")
    prefix = meta.get("_pack", {}).get("prefix", "sfx")
    base = out_dir(args)
    herkomst = load_herkomst(args)
    todo = [args.cue] if args.cue else list(cues)
    for cue in todo:
        if cue not in cues:
            print("SKIP %s: niet in %s" % (cue, os.path.basename(args.cues))); continue
        spec = cues[cue]
        files, _mid = cue_files(cue, spec, man, prefix)
        for i, fname in enumerate(files):
            for s in range(args.seeds):
                seed = 1000 + i * 100 + s
                prompt = "%s, %s" % (spec["prompt"], style)
                dst_dir = os.path.join(base, cue)
                os.makedirs(dst_dir, exist_ok=True)
                dst = os.path.join(dst_dir, fname.replace(".wav", "_s%d.wav" % seed))
                if os.path.exists(dst) and not args.force:
                    print("skip (bestaat) %s" % dst); continue
                print("gen %s seed %d (%.1fs) ..." % (fname, seed, spec["seconds"]))
                raw = run_prompt(workflow(prompt, neg, spec["seconds"], seed, "sapientia_sfx/%s_%d_s%d" % (cue, i + 1, seed)),
                                 os.path.join(base, "_raw"))
                convert(raw, dst, spec.get("max_s", GAME_MAX_S))
                herkomst[sha1(dst)] = {"cue": cue, "bestand": fname, "seed": seed, "prompt": prompt,
                                       "negative": neg, "seconds": spec["seconds"], "model": MODEL_NAME}
                json.dump(herkomst, open(herkomst_path(args), "w"), indent=1, ensure_ascii=False)
                print("  -> %s" % os.path.relpath(dst, ROOT))
    print("\nKlaar. Kies per bestand een kandidaat en kopieer naar %s/kies/<bestandsnaam>.wav (zonder _s<seed>)."
          % os.path.relpath(base, ROOT))
    print("Dan: --pack-export <map> voor itch en/of --install voor het spel.")


def chosen(args: argparse.Namespace) -> tuple[str, list[str]]:
    kies = os.path.join(out_dir(args), "kies")
    if not os.path.isdir(kies):
        sys.exit("geen map %s (kopieer je keuzes daarheen)" % os.path.relpath(kies, ROOT))
    return kies, sorted(f for f in os.listdir(kies) if f.lower().endswith(".wav"))


# ---------------------------------------------------------------- installeren in het spel
def install(args: argparse.Namespace) -> None:
    """Gekozen bestanden naar assets/audio/sfx/. Pack-cues met 'manifest' krijgen de manifest-naam en worden
    op GAME_MAX_S getrimd (check_algemene_sfx.py); spel-cues gaan één op één."""
    man = json.load(open(MANIFEST))["sfx"]
    cues, meta = load_cues(args.cues)
    prefix = meta.get("_pack", {}).get("prefix", "sfx")
    kies, files = chosen(args)
    doel: dict[str, str] = {}          # gekozen bestandsnaam -> manifest-bestandsnaam
    for cue, spec in cues.items():
        names, mid = cue_files(cue, spec, man, prefix)
        if mid is None:
            continue
        for src, dst in zip(names, man[mid]["bestanden"]):
            doel[src] = dst
    lines = open(PLACEHOLDER_LIST).read().splitlines()
    done = []
    for f in files:
        if f not in doel:
            print("SKIP %s: geen spelbestand (alleen pack)" % f); continue
        dst = os.path.join(SFX_DIR, doel[f])
        convert(os.path.join(kies, f), dst, GAME_MAX_S)
        rel = "assets/audio/sfx/" + doel[f]
        lines = [l for l in lines if not l.startswith(rel + " ")]
        done.append(doel[f])
    open(PLACEHOLDER_LIST, "w").write("\n".join(lines) + "\n")
    print("geinstalleerd: %d bestanden; regels uit placeholders_algemene_sfx.txt gehaald." % len(done))
    print("Nu: python3 tools/check_algemene_sfx.py  en  godot --headless --import")


# ---------------------------------------------------------------- verkooppack
README_TXT = """{naam}
{streep}

{n_wav} sound effects, {n_cues} sounds with {n_var_note} variations each.
Format: 16-bit mono WAV at {sr} Hz (wav/) and OGG Vorbis q5 (ogg/).
Peak-normalised to -1 dBFS, dry (no reverb), trimmed, short fade-out.
Naming: {prefix}_<sound>_<variant>.wav, e.g. {voorbeeld}

Groups: {groepen}

Licence: you may use these sounds in commercial and non-commercial games and media.
You may not resell or redistribute the sounds themselves as a sound library.
Credit is appreciated, not required.

Made with {model}. Each file's prompt and seed are listed in SOURCES.csv.
"""


def pack_export(args: argparse.Namespace) -> None:
    man = json.load(open(MANIFEST))["sfx"]
    cues, meta = load_cues(args.cues)
    pack = meta.get("_pack", {})
    prefix = pack.get("prefix", "sfx")
    sr = args.sr or int(pack.get("sr", SR))
    crush = args.crush if args.crush is not None else int(pack.get("crush_bits", 0))
    kies, files = chosen(args)
    herkomst = load_herkomst(args)
    dest = os.path.abspath(args.pack_export)
    wav_dir, ogg_dir = os.path.join(dest, "wav"), os.path.join(dest, "ogg")
    os.makedirs(wav_dir, exist_ok=True)
    os.makedirs(ogg_dir, exist_ok=True)
    by_file = {}
    for cue, spec in cues.items():
        for f in cue_files(cue, spec, man, prefix)[0]:
            by_file[f] = (cue, spec)
    rows, groepen, missing = [], {}, []
    for f in files:
        if f not in by_file:
            print("SKIP %s: hoort niet bij dit cue-bestand" % f); continue
        cue, spec = by_file[f]
        src = os.path.join(kies, f)
        wav = os.path.join(wav_dir, f)
        convert(src, wav, float(spec.get("max_s", GAME_MAX_S)), sr=sr, crush_bits=crush)
        to_ogg(wav, os.path.join(ogg_dir, f[:-4] + ".ogg"))
        h = herkomst.get(sha1(src), {})
        if not h:
            missing.append(f)
        rows.append([f, cue, spec.get("groep", ""), h.get("seed", ""), h.get("prompt", spec["prompt"]), h.get("model", MODEL_NAME)])
        groepen.setdefault(spec.get("groep", "other"), 0)
        groepen[spec.get("groep", "other")] += 1
    with open(os.path.join(dest, "SOURCES.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["file", "sound", "group", "seed", "prompt", "model"])
        w.writerows(rows)
    aanwezig = {by_file[f][0] for f in files if f in by_file}
    var = sorted({int(by_file[f][1].get("varianten", len(man.get(by_file[f][0], {}).get("bestanden", [1])))) for f in files if f in by_file})
    naam = pack.get("naam", "SFX pack")
    open(os.path.join(dest, "README.txt"), "w").write(README_TXT.format(
        naam=naam, streep="=" * len(naam), n_wav=len(rows), n_cues=len(aanwezig),
        n_var_note="-".join(str(v) for v in (var[0], var[-1])) if var else "1", sr=sr, prefix=prefix,
        voorbeeld=rows[0][0] if rows else "%s_magic_fire_cast_01.wav" % prefix,
        groepen=", ".join("%s (%d)" % kv for kv in sorted(groepen.items())), model=pack.get("model", MODEL_NAME)))
    print("pack: %d wav + %d ogg in %s (%d van %d cues aanwezig)" % (len(rows), len(rows), dest, len(aanwezig), len(cues)))
    if missing:
        print("LET OP: %d bestanden zonder herkomst (seed onbekend, niet uit out/ gekozen?): %s" % (len(missing), ", ".join(missing[:5])))
    ontbreekt = sorted(set(cues) - aanwezig)
    if ontbreekt:
        print("nog te kiezen: %s" % ", ".join(ontbreekt))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cues", default=os.path.join(HERE, "cues_wm1_batch1.json"))
    ap.add_argument("--cue", help="een enkele cue-sleutel")
    ap.add_argument("--seeds", type=int, default=2, help="kandidaten per bestand")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--install", action="store_true", help="gekozen bestanden naar assets/audio/sfx/")
    ap.add_argument("--pack-export", metavar="MAP", help="verkooppack (wav/, ogg/, README.txt, SOURCES.csv) uit out/<cues>/kies/")
    ap.add_argument("--crush", type=int, default=None, help="bitcrush-bits voor de pack (0 = uit; standaard uit _pack)")
    ap.add_argument("--sr", type=int, default=None, help="samplerate voor de pack (standaard uit _pack of 22050)")
    ap.add_argument("--check-cues", action="store_true", help="alleen het cue-bestand valideren")
    args = ap.parse_args()
    if args.check_cues:
        sys.exit(check_cues(args))
    if not shutil.which("ffmpeg"):
        sys.exit("ffmpeg ontbreekt: sudo apt install ffmpeg")
    if args.install:
        install(args)
    elif args.pack_export:
        pack_export(args)
    else:
        try:
            comfy("/system_stats")
        except Exception as e:  # noqa: BLE001
            sys.exit("ComfyUI niet bereikbaar op %s (%s). Start: C:\\Users\\krele\\Tools\\start_comfyui.bat" % (COMFY, e))
        generate(args)


if __name__ == "__main__":
    main()
