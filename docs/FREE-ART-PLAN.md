# Free Art & Visuals Plan (zero budget, personal project)

Supersedes the paid routes in `ART-SOURCES.md` (kept as reference). Decision (2026-10-11): **no spend; personal, non-commercial; free AI and free platforms are fine.**
Conventions: **[src]** = read from a source; **[inference]** = my conclusion; **[unverified]** = community/vendor claim, test on your Mac.

## 1. Reality check (so expectations are right)
- Free AI is excellent at **single still images** (backgrounds, props, icons, concept art, UI plates) and weak at **consistent animated characters** (frame-to-frame drift) [src: ComfyUI/AnimateDiff guides — "sprites vary significantly from each other", needs ControlNet/LoRA and clean-up].
- So the plan splits the work by what each tool does best, instead of asking AI to animate.
- I cannot generate images here (no image tool, no GPU). **You run the AI on your M4 Pro; I build everything around it** (prompts, folder contract, import pipeline, lighting, animation runtime).

## 2. The split

| Layer | Made by | Cost | Why |
|---|---|---|---|
| Characters & towers (animated) | **Procedural vector rigs drawn in code by me** — layered parts (body/head/arms/weapon) with skeletal-style animation I write (idle, walk, attack, hit, death) | Free | Perfectly consistent, fully animatable, tiny memory, resolution-independent (crisp on Retina), restylable by changing a palette. Kingdom Rush's own backgrounds were vectors authored in Adobe Animate [src, secondary], so this style is on-target. Ceiling: polished stylized vector, not hand-painted |
| Maps / backgrounds | **Local AI stills** (you generate) + my layered treatment (parallax, fog, water, foliage sway, lighting) | Free | Stills are AI's strength; I split into layers and animate |
| Icons, UI plates, portraits | AI stills + my UI code | Free | Same |
| Concept/reference for rigs | AI stills; I rebuild the design as a vector rig | Free | Gets AI's design quality + code's animation consistency |
| VFX (hits, spells, fire, lightning, dust) | **Shaders + GPU particles by me** | Free | Code-native, cheap at 120 fps |
| Placeholder fill | **Kenney (CC0)** packs [src: kenney.nl/support] | Free | Only if I need quick stand-ins |

Optional upgrade path for hero characters: AI character sheet → cut into parts (background removal + manual/auto segmentation) → rig in my runtime. [inference: doable but labor-heavy; evaluate after M1.]

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
