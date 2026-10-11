# Free Art & Visuals Plan (zero budget, personal project)

Supersedes the paid routes in `ART-SOURCES.md` (kept as reference). Decision (2026-10-11): **no spend; personal, non-commercial; free AI and free platforms are fine.**
Conventions: **[src]** = read from a source; **[inference]** = my conclusion; **[unverified]** = community/vendor claim, test on your Mac.

## 1. Reality check (so expectations are right)
- Free AI is excellent at **single still images** (backgrounds, props, icons, concept art, UI plates) and weak at **consistent animated characters** (frame-to-frame drift) [src: ComfyUI/AnimateDiff guides — "sprites vary significantly from each other", needs ControlNet/LoRA and clean-up].
- So the plan splits the work by what each tool does best, instead of asking AI to animate.
- I cannot generate images here (no image tool, no GPU). **You run the AI on your M4 Pro; I build everything around it** (prompts, folder contract, import pipeline, lighting, animation runtime).

## 2. The plan (revised: quality bar = at least Kingdom Rush; free)

You asked for art that is **not worse than Kingdom Rush**, still free. That changes the approach: **painted AI art is the primary source for everything players see** (characters, towers, backgrounds, icons, UI), and my code (procedural vectors) is only a fallback and a rig helper. I am not going to promise what I can't verify: the quality bar is reachable for stills; **animated characters are the one hard part**, so the plan is built around de-risking exactly that.

| Layer | Made by | How quality is protected |
|---|---|---|
| Backgrounds / maps | Local AI stills (FLUX/SDXL + style LoRA), 4K, you pick the best of N | Style bible + fixed model/seed families; I split into parallax layers, add animated water/fog/foliage/god-rays and lighting that KR's flat backgrounds lack |
| Towers, props, icons, UI | AI stills + my processing | Same style LoRA; auto cutout, trim, outline/palette unification, normal maps |
| Characters (enemies, heroes, soldiers) | **AI-generated sprites + animation by one of three methods, cheapest first** | See below |
| VFX | Shaders + GPU particles (me) | Real-time; beyond KR's sprite VFX |

**Why this is plausible for characters [inference]:** KR units are small on screen (tens of pixels to ~100 px tall at 1080p), with short, punchy animations. At that size, AI character art rendered at 512–1024 px and downscaled hides most inconsistency, and animations need only ~6–12 frames per cycle.

**Character animation methods (try in order, per unit):**
1. **Puppet rig from one AI image** — AI generates a character in a neutral pose ("A-pose" turnaround prompt); background removal + part cutting (head/torso/arms/legs/weapon, semi-automatic with segmentation + my editor page); I animate with a skeletal-style runtime I write (idle/walk/attack/hit/death). Fully consistent, tiny memory. Hand-painted look preserved because the pixels *are* the AI paint.
2. **AI frame cycles** — one approved keyframe + ControlNet/OpenPose + character LoRA in ComfyUI → 8–16 frames [src: ComfyUI/AnimateDiff guides; consistency is the known problem]; my pipeline aligns feet/anchor, fixes palette drift, rejects off-model frames; you approve in a review page.
3. **Code-driven motion on a single sprite** — bob, lean, squash/stretch, shadow, hit-flash, trails. Good enough for small swarm enemies (goblins, wolves, spiders).
Bosses/heroes get method 1 or 2 with extra curation; swarm units get 3.

**Quality gate (go/no-go before production):** a **style test** — you generate ~10 assets with the prompt pack in `docs/art/STYLE-BIBLE.md` (1 background, 1 tower, 1 enemy + 2 animation attempts, 1 hero, 4 icons); we compare side by side with Kingdom Rush screenshots at game scale. If it doesn't clear the bar, we adjust model/LoRA/prompt or the character method *before* spending more time.

**Honest risks:** (a) multi-frame consistency may need many re-rolls — it costs your time and GPU minutes (about 20–50 s per image on your Mac, community-reported [unverified]); (b) a style LoRA trained on *your own approved outputs* is the main consistency tool; (c) I cannot see or run your AI tools — you are the eyes on quality, and I will build review pages so judging 50 candidates takes minutes.

## 3. Your free AI toolbox (run on the M4 Pro)

- **Draw Things** (free Mac app, native Metal, unlimited local generation, SD 1.5 → SDXL → FLUX) — commonly recommended for Apple Silicon. Community benchmark: ~50 s for a 1024² FLUX image on a 24 GB M4-class Mac; ~20–40 s for SDXL [unverified, small sample]. **Recommended starting point.**
- **ComfyUI** (free, node-based, more control: ControlNet, LoRA, batch workflows). Slower than Draw Things on Mac per one community test (~20 %; another claims ~3× — conflicting) [unverified].
- **Models:** FLUX.1 **schnell** is Apache-2.0 (any use); FLUX.1 **dev** is non-commercial (fine for a personal project) [src: Wikipedia / localaimaster]. SDXL-family models + style LoRAs are plentiful. Use a 24 GB-friendly quantized build (e.g. Q6/Q4 GGUF) [unverified guidance].
- **Free online tiers** (limits vary by source; check the site): Leonardo (~100–150 credits/day, good for game art), Ideogram (~10–25 images/day, good at text), Microsoft Copilot/Bing Image Creator (generous standard mode), Recraft (~30 credits/day, vector-friendly) [src: 2026 comparison blogs, unverified].
- **Background removal / cleanup:** `rembg` (open source) and Aseprite-alternatives LibreSprite/Piskel for pixel tweaks [src: guides].

## 4. Free animation tooling (if you ever want hand-animation)
- **DragonBones** — free Spine-like skeletal tool (Tencent); the Pro editor is no longer developed, some sources say it rebranded to LoongBones [src: 2026 comparison guides]. Web runtime for PixiJS v8 is **unverified**.
- **Spriter** (free tier), **Synfig** (open source), **Blender Grease Pencil** (GPL; no web runtime found).
- **Spine** is *not* needed: official spine-pixi-v8 exists but the editor costs $69–$379; my own animation runtime replaces it for free.

## 5. Asset contract (how your AI outputs get into the game)
Drop files into `assets/ai/` using this naming; my pipeline imports them automatically:
```
assets/ai/backgrounds/<map-id>/{sky,far,mid,near,ground}.png   # 4096 px wide; transparent where layered, or one full image `full.png`
assets/ai/props/<name>.png                                      # transparent PNG, ≥ 512 px
assets/ai/icons/<name>.png                                      # 256 px, transparent
assets/ai/concepts/<unit-id>.png                                # reference only (I redraw as rigs)
```
- The pipeline will: remove stray backgrounds, trim, pack texture atlases, generate **normal/height maps** for 2D lighting, compress textures, and enforce a memory budget.
- Prompts: I'll write a **style bible + prompt pack** (one file per asset with seed/model/negative-prompt/size so results are reproducible). First deliverable after M0.
- Until you provide stills, the game uses my procedural backgrounds, so nothing blocks development.

## 6. Visual targets to beat Kingdom Rush-latest where code can
Real-time lighting (day/dusk/torchlight) with soft shadows, rim light, bloom; animated parallax; living environments (water, foliage, fog, embers); juicy hit-stop/squash-stretch; readable silhouettes; smooth 120 fps.

## 7. Risks
- Vector-rig characters may feel "cleaner but less painterly" than KR; mitigate with textured gradients/outline shaders and painterly overlays (AI-generated texture overlays are a good use of AI stills).
- AI background style consistency across maps: fix by one shared style bible + same model/LoRA/seed families.
- Anything shared publicly later should be re-checked for licenses/AI disclosure (you said not needed now).

## 8. Sources
- Draw Things / FLUX on Mac: https://www.heyuan110.com/posts/ai/2026-02-15-mac-mini-local-image-generation/ · https://insiderllm.com/guides/stable-diffusion-mac-mlx/ · https://www.bitdoze.com/ai-images-mac/
- FLUX licensing: https://en.wikipedia.org/wiki/Flux_(text-to-image_model) · https://localaimaster.com/blog/flux-local-image-generation
- Free image tools compared: https://www.aitoolsbridge.com/blog/ai-image-generators-with-free-daily-credits-2026
- ComfyUI sprite workflows: https://comfy.org/workflows/use-cases/sprite-sheet-generator/ · https://tawusgames.itch.io/ai-gen-sprite-tutorial · https://www.strayspark.studio/blog/comfyui-game-asset-pipeline-indie-2026
- Free skeletal tools: https://www.armanimation.com/post/best-2d-skeletal-animation-software-in-2026-free-paid-options-compared · https://kaliko.com/blog/2d-skeletal-animation-tools/
- Kenney CC0: https://kenney.nl/support
