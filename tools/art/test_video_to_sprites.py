"""Self-test on a synthetic green-screen walker with known period (12 frames) and horizontal drift."""
import json, math, os, subprocess, sys, tempfile, unittest
import numpy as np
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__))
PERIOD, N, W, H = 12, 60, 320, 240

def make_video(path):
    tmp = tempfile.mkdtemp()
    for i in range(N):
        im = Image.new("RGB", (W, H), (0, 177, 64)); d = ImageDraw.Draw(im)   # imperfect green like real footage
        ph = 2 * math.pi * i / PERIOD; cx = 80 + i * 2.5     # character drifts right (root motion)
        d.ellipse((cx - 22, 60 - 3 * math.sin(2 * ph), cx + 22, 110 - 3 * math.sin(2 * ph)), fill=(200, 60, 50), outline=(40, 20, 10), width=3)  # body bobs
        for s in (0, math.pi):                                # legs swing
            fx = cx + 18 * math.sin(ph + s)
            d.line((cx, 108, fx, 170), fill=(60, 40, 120), width=9)
        im.save(os.path.join(tmp, f"g{i:04d}.png"))
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", "24", "-i", os.path.join(tmp, "g%04d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "28", path], check=True)

class T(unittest.TestCase):
    def test_pipeline(self):
        d = tempfile.mkdtemp(); v = os.path.join(d, "walk.mp4"); make_video(v)
        out = os.path.join(d, "walk")
        subprocess.run([sys.executable, os.path.join(HERE, "video_to_sprites.py"), v, "--out", out, "--cell", "128", "--min-loop", "6", "--max-loop", "30"], check=True, capture_output=True)
        meta = json.load(open(out + ".json")); strip = Image.open(out + ".png")
        L = meta["loop"]["length"]
        self.assertEqual(L % PERIOD, 0, f"loop length {L} must be a multiple of the true period {PERIOD}")
        self.assertLess(meta["loop"]["seam_error"], 6.0)
        self.assertEqual(strip.size, (128 * meta["frames"], 128))
        a = np.asarray(strip)[..., 3]
        self.assertTrue((a[:4, :4] == 0).all(), "corner must be transparent (key removed)")
        first = a[:, :128]; self.assertGreater((first > 128).sum(), 800, "character must remain opaque")
        # feet anchored: lowest opaque row is stable across frames despite horizontal drift
        lows = [np.where(a[:, i * 128:(i + 1) * 128].max(1) > 128)[0].max() for i in range(meta["frames"])]
        self.assertLessEqual(max(lows) - min(lows), 3, f"feet jitter {lows}")
        green = np.asarray(strip)[..., :3].astype(int); op = a > 200
        spill = ((green[..., 1] - np.maximum(green[..., 0], green[..., 2])) > 40) & op
        self.assertLess(spill.sum(), 0.01 * op.sum(), "no green fringe in opaque pixels")
if __name__ == "__main__": unittest.main(verbosity=2)
