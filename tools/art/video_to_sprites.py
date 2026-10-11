#!/usr/bin/env python3
"""Turn an AI-generated green-screen video into a looping, transparent sprite strip.

  video_to_sprites.py in.mp4 --out assets/ai/sprites/goblin_walk [--fps 24] [--min-loop 6 --max-loop 24]
                      [--key auto|RRGGBB] [--reference still.png] [--cell 256]

Pipeline: ffmpeg frames -> chroma key (+despill) -> stable crop -> feet-anchor align -> best-loop search
          -> optional off-model reject vs a reference still -> packed strip PNG + JSON metadata.
Requires: ffmpeg, Pillow, numpy.
"""
import argparse, json, os, subprocess, sys, tempfile, glob
import numpy as np
from PIL import Image

def extract(video, fps, tmp):
    cmd = ["ffmpeg", "-v", "error", "-y", "-i", video] + (["-vf", f"fps={fps}"] if fps else []) + [os.path.join(tmp, "f%05d.png")]
    subprocess.run(cmd, check=True)
    return sorted(glob.glob(os.path.join(tmp, "f*.png")))

def auto_key(rgb):
    h, w, _ = rgb.shape; k = max(2, min(h, w) // 40)
    corners = np.concatenate([rgb[:k, :k].reshape(-1, 3), rgb[:k, -k:].reshape(-1, 3), rgb[-k:, :k].reshape(-1, 3), rgb[-k:, -k:].reshape(-1, 3)])
    return np.median(corners, axis=0)

def key_frame(rgb, key, t0=40.0, t1=95.0):
    """alpha from RGB distance to key color; despill reduces key-colored fringe."""
    f = rgb.astype(np.float32)
    d = np.sqrt(((f - key[None, None, :]) ** 2).sum(-1))
    a = np.clip((d - t0) / (t1 - t0), 0, 1)
    out = f.copy()
    # despill: if the key is green-dominant, clamp green toward the other channels on edge pixels
    ki = int(np.argmax(key))
    others = [i for i in range(3) if i != ki]
    lim = np.maximum(out[..., others[0]], out[..., others[1]])
    spill = (out[..., ki] > lim) & (a < 1.0) & (a > 0)
    out[..., ki] = np.where(spill, lim, out[..., ki])
    return np.dstack([np.clip(out, 0, 255), a * 255]).astype(np.uint8)

def feet_anchor(rgba):
    a = rgba[..., 3] > 128
    ys = np.where(a.any(1))[0]
    if len(ys) == 0: return None
    y1 = ys.max(); band = a[max(0, y1 - max(2, (y1 - ys.min()) // 12)):y1 + 1]
    xs = np.where(band.any(0))[0]
    return (float(xs.mean()), float(y1))

def small(rgba, n=48):
    im = Image.fromarray(rgba).resize((n, n), Image.BILINEAR)
    return np.asarray(im, dtype=np.float32)

def best_loop(frames, lo, hi):
    sm = [small(f) for f in frames]; best = None
    for L in range(lo, min(hi, len(frames) - 1) + 1):
        for s in range(0, len(frames) - L):
            d = float(np.abs(sm[s] - sm[s + L]).mean())
            # prefer smaller error; mild preference for shorter loops among near-ties
            score = d * (1.0 + 0.002 * L)
            if best is None or score < best[0]: best = (score, s, L, d)
    return best

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video"); ap.add_argument("--out", required=True); ap.add_argument("--fps", type=float, default=0)
    ap.add_argument("--min-loop", type=int, default=6); ap.add_argument("--max-loop", type=int, default=24)
    ap.add_argument("--key", default="auto"); ap.add_argument("--cell", type=int, default=256)
    ap.add_argument("--reference"); ap.add_argument("--ref-tol", type=float, default=60.0)
    ap.add_argument("--align", default="feet", choices=["feet", "none"]); ap.add_argument("--no-loop", action="store_true")
    a = ap.parse_args()
    with tempfile.TemporaryDirectory() as tmp:
        files = extract(a.video, a.fps, tmp)
        if len(files) < 4: sys.exit("too few frames")
        rgbs = [np.asarray(Image.open(f).convert("RGB")) for f in files]
    key = auto_key(rgbs[0]) if a.key == "auto" else np.array([int(a.key[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)
    rgba = [key_frame(r, key) for r in rgbs]
    # stable crop box = union of opaque bbox
    boxes = []
    for f in rgba:
        ys, xs = np.where(f[..., 3] > 16)
        if len(ys): boxes.append((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    x0 = min(b[0] for b in boxes); y0 = min(b[1] for b in boxes); x1 = max(b[2] for b in boxes); y1 = max(b[3] for b in boxes)
    pad = 4; H, W = rgba[0].shape[:2]
    x0, y0, x1, y1 = max(0, x0 - pad), max(0, y0 - pad), min(W, x1 + pad), min(H, y1 + pad)
    crops = [f[y0:y1, x0:x1] for f in rgba]
    # optional off-model reject
    rejected = []
    if a.reference:
        ref = np.asarray(Image.open(a.reference).convert("RGBA"), dtype=np.float32)
        m = ref[..., 3] > 128 if (ref[..., 3] < 250).any() else np.ones(ref.shape[:2], bool)
        rc = ref[..., :3][m].mean(0)
        keep = []
        for i, c in enumerate(crops):
            op = c[..., 3] > 128
            if op.sum() < 50: rejected.append(i); continue
            if np.linalg.norm(c[..., :3][op].mean(0) - rc) > a.ref_tol: rejected.append(i)
            else: keep.append(i)
        crops = [crops[i] for i in keep]
    # feet alignment (keeps horizontal root motion out of the loop)
    if a.align == "feet":
        anch = [feet_anchor(c) for c in crops]
        ok = [x for x in anch if x]; ax = float(np.median([p[0] for p in ok])); ay = float(np.median([p[1] for p in ok]))
        al = []
        for c, p in zip(crops, anch):
            if not p: al.append(c); continue
            dx, dy = int(round(ax - p[0])), int(round(ay - p[1]))
            canvas = np.zeros_like(c); ys, xs = c.shape[:2]
            sx0, sx1 = max(0, -dx), min(xs, xs - dx); sy0, sy1 = max(0, -dy), min(ys, ys - dy)
            canvas[sy0 + dy:sy1 + dy, sx0 + dx:sx1 + dx] = c[sy0:sy1, sx0:sx1]
            al.append(canvas)
        crops = al
    info = {"source": os.path.basename(a.video), "key_rgb": [int(v) for v in key], "frames_extracted": len(files), "rejected": rejected}
    if not a.no_loop:
        score, s, L, d = best_loop(crops, a.min_loop, a.max_loop)
        crops = crops[s:s + L]; info["loop"] = {"start": s, "length": L, "seam_error": round(d, 3)}
    # normalize to cell
    h, w = crops[0].shape[:2]; sc = a.cell / max(h, w); nw, nh = max(1, int(w * sc)), max(1, int(h * sc))
    cells = []
    for c in crops:
        im = Image.fromarray(c).resize((nw, nh), Image.LANCZOS); cell = Image.new("RGBA", (a.cell, a.cell), (0, 0, 0, 0))
        cell.paste(im, ((a.cell - nw) // 2, a.cell - nh)); cells.append(cell)   # bottom-center anchored
    strip = Image.new("RGBA", (a.cell * len(cells), a.cell), (0, 0, 0, 0))
    for i, c in enumerate(cells): strip.paste(c, (i * a.cell, 0))
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    strip.save(a.out + ".png"); info.update({"frames": len(cells), "cell": a.cell, "fps": a.fps or None, "anchor": "bottom-center", "strip": os.path.basename(a.out) + ".png"})
    json.dump(info, open(a.out + ".json", "w"), indent=1); print(json.dumps(info))

if __name__ == "__main__": main()
