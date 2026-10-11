#!/usr/bin/env python3
"""Generate art candidates from tools/art/prompts.json using free online backends.

Backends: horde (AI Horde, anonymous key works, slow queue; set HORDE_API_KEY for priority),
          pollinations (no key; weaker quality), hf (needs HF_TOKEN; tiny free GPU quota).
Usage: generate.py --backend horde --model "AlbedoBase XL (SDXL)" --ids enemy_goblin,tower_archer --n 2
Outputs: assets/ai/_candidates/<id>/<seed>.<ext> + <seed>.json (prompt/model/seed for reproducibility).
"""
import argparse, base64, json, os, sys, time, urllib.parse, urllib.request, urllib.error, concurrent.futures as cf
ROOT = os.path.dirname(os.path.abspath(__file__))
PACK = json.load(open(os.path.join(ROOT, "prompts.json")))
OUT = os.path.abspath(os.path.join(ROOT, "..", "..", "assets", "ai", "_candidates"))

def full_prompt(a):
    parts = [a["prompt"], PACK["style"]]
    if a["kind"] == "sprite": parts.append(PACK["sprite_suffix"])
    return ", ".join(parts)

def horde(a, model, seed, steps):
    key = os.environ.get("HORDE_API_KEY", "0000000000")
    H = {"apikey": key, "Client-Agent": "gamez-art:1:personal", "Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}
    flux = "Flux" in model or "Z-Image" in model
    body = {"prompt": full_prompt(a) + ("" if flux else " ### " + PACK["negative"]),
            "params": {"width": a["w"], "height": a["h"], "steps": steps or (6 if flux else 28), "cfg_scale": 3.5 if flux else 6.5,
                       "sampler_name": "k_euler" if flux else "k_dpmpp_2m", "seed": str(seed), "n": 1, "karras": True},
            "models": [model], "nsfw": False, "censor_nsfw": True, "r2": False, "shared": False, "slow_workers": True}
    def call(u, data=None):
        r = urllib.request.Request("https://aihorde.net/api/v2/" + u, data=json.dumps(data).encode() if data else None, headers=H)
        return json.load(urllib.request.urlopen(r, timeout=60))
    j = call("generate/async", body); t0 = time.time()
    while time.time() - t0 < 3600:
        c = call("generate/check/" + j["id"])
        if c.get("done") or c.get("faulted"): break
        time.sleep(10)
    g = call("generate/status/" + j["id"]).get("generations", [])
    if not g: raise RuntimeError("horde returned no generation")
    img = g[0]["img"]
    data = base64.b64decode(img) if not img.startswith("http") else urllib.request.urlopen(urllib.request.Request(img, headers={"User-Agent": "Mozilla/5.0"}), timeout=60).read()
    return data, "webp", {"worker": g[0].get("worker_name"), "model": g[0].get("model")}

def pollinations(a, model, seed, steps):
    q = urllib.parse.quote(full_prompt(a))
    u = f"https://image.pollinations.ai/prompt/{q}?width={a['w']}&height={a['h']}&seed={seed}&nologo=true&model={model or 'flux'}&negative_prompt={urllib.parse.quote(PACK['negative'])}"
    return urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"}), timeout=180).read(), "jpg", {}

BACKENDS = {"horde": horde, "pollinations": pollinations}

def one(backend, a, model, seed, steps):
    d = os.path.join(OUT, a["id"]); os.makedirs(d, exist_ok=True)
    try:
        data, ext, extra = BACKENDS[backend](a, model, seed, steps)
    except Exception as e:
        return f"FAIL {a['id']} seed={seed}: {e}"
    open(os.path.join(d, f"{seed}.{ext}"), "wb").write(data)
    json.dump({"id": a["id"], "backend": backend, "model": model, "seed": seed, "steps": steps, "prompt": full_prompt(a), "negative": PACK["negative"], **extra},
              open(os.path.join(d, f"{seed}.json"), "w"), indent=1)
    return f"ok {a['id']} seed={seed} ({len(data)//1024} KB)"

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--backend", default="horde", choices=BACKENDS); ap.add_argument("--model", default="AlbedoBase XL (SDXL)")
    ap.add_argument("--ids", default="all"); ap.add_argument("--n", type=int, default=2); ap.add_argument("--seed0", type=int, default=100)
    ap.add_argument("--steps", type=int, default=0); ap.add_argument("--parallel", type=int, default=4)
    a = ap.parse_args()
    items = [x for x in PACK["assets"] if a.ids == "all" or x["id"] in a.ids.split(",")]
    jobs = [(a.backend, x, a.model, a.seed0 + i, a.steps) for x in items for i in range(a.n)]
    with cf.ThreadPoolExecutor(a.parallel) as ex:
        for r in ex.map(lambda j: one(*j), jobs): print(r, flush=True)
