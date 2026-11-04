#!/usr/bin/env python3
"""SFX genereren met de offline AI-stack: ComfyUI + Stable Audio Open 1.0.

Draait op Dennis' laptop in WSL (daar staat ComfyUI op http://127.0.0.1:8188).
Agents in de cloud kunnen ComfyUI niet bereiken; dit script is bedoeld om zelf te draaien.

Per cue uit een cue-bestand (bv. tools/sfx/cues_wm1_batch1.json):
  1. API-workflow (Stable Audio Open) naar ComfyUI: POST /prompt
  2. wachten op /history/<id>, bestand ophalen via /view
  3. ffmpeg: stilte aan het begin wegknippen, trimmen op max_s, fade-out, normaliseren,
     mono 22050 Hz 16-bit wav (het formaat dat tools/check_algemene_sfx.py eist)
  4. wegschrijven in de uitvoermap met de bestandsnaam uit audio_manifest.json

Gebruik (repo-root, in WSL):
  python3 tools/sfx/gen_sfx.py                       # alles uit batch 1 -> tools/sfx/out/
  python3 tools/sfx/gen_sfx.py --cue sword_swing     # een cue
  python3 tools/sfx/gen_sfx.py --seeds 4             # 4 kandidaten per bestand (kiezen = Dennis)
  python3 tools/sfx/gen_sfx.py --install             # gekozen wavs uit out/kies/ naar assets/audio/sfx/
                                                     # en de regels uit tools/placeholders_algemene_sfx.txt halen

Werkwijze: eerst genereren (out/<cue>/<bestand>_s<seed>.wav), dan kies je per bestand
een kandidaat en kopieer je die naar out/kies/<bestandsnaam>.wav, dan --install.

ONVERIFIED (5 nov 2026): de node-namen en invoervelden van de Stable Audio-workflow zijn
uit de ComfyUI-voorbeelden overgenomen maar nog niet op deze laptop gedraaid. Faalt POST /prompt,
dan print ComfyUI welk veld niet klopt; pas WORKFLOW hieronder aan.
Eisen: ffmpeg in PATH, modellen uit ai-stack/scripts/audio_modellen.sh aanwezig.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.request
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST = os.path.join(ROOT, "assets", "audio", "audio_manifest.json")
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
PLACEHOLDER_LIST = os.path.join(ROOT, "tools", "placeholders_algemene_sfx.txt")
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")

COMFY = os.environ.get("COMFY_URL", "http://127.0.0.1:8188")
CKPT = "stable-audio-open-1.0.safetensors"
T5 = "t5-base.safetensors"
SR = 22050


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


def run_prompt(wf: dict) -> str:
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
                    tmp = os.path.join(OUT, "_raw", a["filename"])
                    os.makedirs(os.path.dirname(tmp), exist_ok=True)
                    open(tmp, "wb").write(raw)
                    return tmp
            raise RuntimeError("geen audio-uitvoer in history voor %s" % pid)
    raise TimeoutError("ComfyUI klaar-wachten duurde te lang (%s)" % pid)


def convert(src: str, dst: str, max_s: float) -> None:
    """ffmpeg: stilte vooraan weg, trim, fade-out, normaliseer, mono 22050 16-bit."""
    fade_start = max(0.0, max_s - 0.05)
    af = ",".join([
        "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.02",
        "atrim=0:%.3f" % max_s,
        "afade=t=out:st=%.3f:d=0.05" % fade_start,
        "loudnorm=I=-16:TP=-1.0",
        "aresample=%d" % SR,
    ])
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-af", af,
                    "-ac", "1", "-ar", str(SR), "-sample_fmt", "s16", dst], check=True)


def load_cues(path: str) -> tuple[dict, str, str]:
    d = json.load(open(path))
    style = d.pop("_style", "")
    neg = d.pop("_negative", "")
    d.pop("_doc", None)
    return d, style, neg


def generate(args: argparse.Namespace) -> None:
    man = json.load(open(MANIFEST))["sfx"]
    cues, style, neg = load_cues(args.cues)
    todo = [args.cue] if args.cue else list(cues)
    for cue in todo:
        if cue not in man:
            print("SKIP %s: niet in manifest" % cue); continue
        spec = cues[cue]
        files = man[cue]["bestanden"]
        for i, fname in enumerate(files):
            for s in range(args.seeds):
                seed = 1000 + i * 100 + s
                prompt = "%s, %s" % (spec["prompt"], style)
                prefix = "sapientia_sfx/%s_%d_s%d" % (cue, i + 1, seed)
                dst_dir = os.path.join(OUT, cue)
                os.makedirs(dst_dir, exist_ok=True)
                dst = os.path.join(dst_dir, fname.replace(".wav", "_s%d.wav" % seed))
                if os.path.exists(dst) and not args.force:
                    print("skip (bestaat) %s" % dst); continue
                print("gen %s seed %d (%.1fs) ..." % (fname, seed, spec["seconds"]))
                raw = run_prompt(workflow(prompt, neg, spec["seconds"], seed, prefix))
                convert(raw, dst, spec.get("max_s", 0.6))
                print("  -> %s" % os.path.relpath(dst, ROOT))
    print("\nKlaar. Kies per bestand een kandidaat en kopieer naar %s/kies/<bestandsnaam>.wav, dan --install." % os.path.relpath(OUT, ROOT))


def install(args: argparse.Namespace) -> None:
    kies = os.path.join(OUT, "kies")
    if not os.path.isdir(kies):
        sys.exit("geen map %s" % kies)
    man = json.load(open(MANIFEST))["sfx"]
    known = {f for v in man.values() for f in v["bestanden"]}
    lines = open(PLACEHOLDER_LIST).read().splitlines()
    done = []
    for f in sorted(os.listdir(kies)):
        if f not in known:
            print("SKIP %s: geen manifest-bestand" % f); continue
        shutil.copy2(os.path.join(kies, f), os.path.join(SFX_DIR, f))
        rel = "assets/audio/sfx/" + f
        lines = [l for l in lines if not l.startswith(rel + " ")]
        done.append(f)
    open(PLACEHOLDER_LIST, "w").write("\n".join(lines) + "\n")
    print("geinstalleerd: %d bestanden; regels uit placeholders_algemene_sfx.txt gehaald." % len(done))
    print("Nu: python3 tools/check_algemene_sfx.py  en  godot --headless --import")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cues", default=os.path.join(HERE, "cues_wm1_batch1.json"))
    ap.add_argument("--cue", help="een enkele sfx-id")
    ap.add_argument("--seeds", type=int, default=2, help="kandidaten per bestand")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--install", action="store_true")
    args = ap.parse_args()
    if args.install:
        install(args)
    else:
        if not shutil.which("ffmpeg"):
            sys.exit("ffmpeg ontbreekt: sudo apt install ffmpeg")
        try:
            comfy("/system_stats")
        except Exception as e:  # noqa: BLE001
            sys.exit("ComfyUI niet bereikbaar op %s (%s). Start: C:\\Users\\krele\\Tools\\start_comfyui.bat" % (COMFY, e))
        generate(args)


if __name__ == "__main__":
    main()
