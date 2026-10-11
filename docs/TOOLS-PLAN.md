# Using All Your Subscriptions — Roles, Pipeline, Limits

Subscriptions (from you): **Claude Pro, Gemini Pro (Google AI Pro), ChatGPT Plus, SuperGrok, AWS Quick**. Budget otherwise zero; personal project.
Conventions: **[src]** = read from a source; **[unverified]** = secondary/blog claim — limits change monthly, check in-app; **[inference]** = my conclusion.

## 0. What I can and cannot do with them
- **I (this Claude Code session) cannot log into your consumer subscriptions** or drive their web apps. *You* operate Gemini / ChatGPT / Grok in your browser; I design the prompts, write the pipeline and tests, and process whatever you drop into `assets/ai/`.
- Consumer subscriptions are **not API access** (e.g. ChatGPT Plus has no API credits; the GPT-image API is billed separately and has no free tier [src: search summaries]). If you want me to generate art *inside this session*, the only realistic no-cost routes are optional **free API keys** you create and store as an environment secret (e.g. a Google AI Studio key — free-tier image limits unverified). Not required.
- I already confirmed (today) that free anonymous generators are reachable from here but weak: **Pollinations anonymous = low-res, watermarked, ignored my cartoon style**; **AI Horde anonymous = works but a ~25-minute queue** per image; **Hugging Face anonymous ZeroGPU quota = exhausted**. Your subscriptions are far better.

## 1. Role of each subscription

| Tool | Best use in this project | Notes / limits |
|---|---|---|
| **Claude Pro** (+ Claude Code) | **The builder**: engine, sim, renderer, pipeline, tests, balance bot, art tooling; also art direction in chat (style bible, prompt packs, critiquing your outputs if you paste/upload them) | Claude can't generate images. Usage is shared across claude.ai and Claude Code — heavy build sessions are the main consumer of your quota |
| **Gemini Pro** (Google AI Pro, $19.99 [src]) | **Primary image workhorse**: Nano Banana image generation/editing with **reference images → consistent characters, edit-in-place, sprite sheets**; **Veo** image-to-video for animation frames; **Flow/Whisk** (1,000 Flow credits/month shared [src: Google page]); **Gemini CLI / Jules / Code Assist** as free extra coding agents (higher limits on Pro) | Daily/monthly caps vary by source (Nano Banana "up to 1,000/day" vs Pro model "100/day" in one Jan-2026 article, later marked outdated; Veo 3.1 Fast/Lite counts differ) **[unverified]** |
| **ChatGPT Plus** | **Second image engine**: strong prompt-following, UI plates, icons, readable text, concept boards; **Codex** (if included in your plan [unverified]) as an independent code reviewer | Image cap ≈ 40–50 per rolling 3 h reported by users **[unverified]**; model names inconsistent across sources. Sora reportedly discontinued March 2026 **[unverified]** |
| **SuperGrok** | **Grok Imagine**: image generation + **image-to-video** (animate an approved character); also research/DeepSearch | Video caps/length conflict widely (6–15 s, 15–20 videos/day, or a weekly pool) **[unverified]** — check the in-app limit |
| **AWS Quick** (Amazon Quick Suite) | Agentic workspace for business research/automation (Flows, Automate, research agent, MCP connectors) [src: AWS/third-party]; **low relevance to game art**. Possible side-uses: scheduled research/summaries, automating file organisation | Agent time is metered beyond included hours [src: pricing summaries]. I would not make it part of the critical path |
| **Local Draw Things / ComfyUI** (free, your M4 Pro) | **Volume + consistency**: train a style LoRA on approved outputs, batch variations, upscaling, background textures | ~50 s per 1024² FLUX image on 24 GB M4-class Macs (community) **[unverified]** |

## 2. Division of labor by asset type

| Asset | Best tool(s) | Why |
|---|---|---|
| Style bible / reference sheet | ChatGPT + Gemini (generate several, pick one) | Fix the look once; reuse as reference image everywhere |
| Backgrounds / maps (4K stills) | Gemini (Nano Banana) → local upscale; ChatGPT as alternate | Wide scenes; keep one style reference |
| Towers, props, icons, UI | ChatGPT (icons/UI/text) + Gemini | Fast, consistent with reference |
| Character design (enemies, heroes) | Gemini Nano Banana with reference + ChatGPT | Character consistency through reference images and edit prompts |
| **Character animation** | **Video route**: approved character image → **Veo / Grok Imagine image-to-video** ("side view walk cycle, static camera, flat green background, 4 s") → frames → my pipeline (below) | Video models keep one character coherent across time — better than generating frames one by one **[inference; no source compared models]** |
| VFX | Shaders/particles by me; textures from AI | Code-native |
| Code | Claude Code (primary); Gemini CLI/Jules/Codex for parallel tasks & second-opinion review | Different model families catch different bugs |
| Balance & tests | Claude Code | Deterministic sim + headless bot |

## 3. Character animation pipeline (the hard part), concretely
1. **Lock the design:** one approved full-body image per unit (neutral side view).
2. **Animate:** feed it to Veo or Grok Imagine as image-to-video. Prompt template: *"[unit], side view facing right, [walk cycle | idle breathing | attack swing | hit reaction | death], static camera, no camera movement, flat solid green background, consistent character design, loopable"*. Generate 3–4 takes per action; keep the best. (Sources recommend ~4 s clips, 4–8 frames per cycle, chroma-key green background [src: video-to-sprite tool guides].)
3. **Export** the video file(s) to `assets/ai/video/<unit>/<action>.mp4`.
4. **My pipeline** (`tools/art/video_to_sprites.py`, built and tested in this repo): extract frames with ffmpeg → **chroma-key** (despill) → crop to a stable per-action bounding box → **find the best loop** (minimum frame difference) → **anchor-align** feet → palette-normalize toward the approved still → output a packed sprite sheet + JSON metadata. Reject off-model frames automatically by comparing to the keyframe.
5. **You review** on a contact-sheet page (`tools/art/make_review.py`) and approve.
Fallbacks if video drifts: puppet-rig from the still (cut parts, my skeleton runtime) or code-driven motion on one sprite for swarm enemies.

## 4. Quality & consistency rules (to stay ≥ Kingdom Rush)
- One **style reference sheet** attached to *every* generation; keep exact prompts, model, seed in a sidecar `.json` (my `generate.py` does this for API backends; for manual tools save the prompt in a text file next to the image).
- Generate on **flat green or light-gray backgrounds** so keying is clean.
- Resolution: stills ≥ 1024 px, backgrounds ≥ 4K after upscale; units are shown at ~64–96 px so a 512 px sprite is plenty.
- **Gate:** run the style test in `docs/art/STYLE-BIBLE.md` first (10 assets); ≥ 8/10 must pass at game scale.

## 5. What I need you to do (in order)
1. **Style test** with Gemini (Nano Banana) and ChatGPT — same prompts, two engines — put results in `assets/ai/_candidates/<asset-id>/` and run `python3 tools/art/make_review.py` to compare. Tell me which engine wins per asset type.
2. Animate **one** approved goblin with Veo *and* Grok Imagine (same prompt); drop the videos in `assets/ai/video/goblin/`. I run the pipeline and we compare.
3. Optionally create a free **Google AI Studio API key** (and/or others) and add it as an environment secret if you want me to generate/iterate art directly here — your call; skip if you prefer manual.
4. Optional: install **Draw Things** for volume/LoRA.

## 6. Risks
- Caps change monthly; image/video quotas could throttle bulk production — hence mixing four engines + local.
- Video-model loops may need many takes; the pipeline's loop-finder and reject filter reduce manual work but won't remove it.
- Different engines have different "hands": mixing them risks style drift → mitigate with the shared reference sheet and, later, a local style LoRA trained on approved outputs.
- AWS Quick adds little for art; I will not build around it unless you have a specific use.

## 7. Sources (all secondary unless noted; limits **unverified**)
- Google AI Pro official page: https://gemini.google/subscriptions/ · 9to5Google: https://9to5google.com/2025/12/24/google-ai-pro-ultra-features/
- Grok Imagine limits (blogs): https://www.sloane.world/guides/grok-imagine-limits-2026 · https://www.atlascloud.ai/blog/tips/grok-xai-image-generation-daily-limit
- ChatGPT Plus image limits (blogs): https://www.cometapi.com/how-many-images-can-i-generate-with-chatgpt-plus-%E2%80%94-a-2026-status-report/ · https://gptimg.co/blog/chatgpt-image-limits
- Amazon Quick: https://aws.amazon.com/quick/pricing/ · https://atlan.com/know/ai-agent/aws/what-is-amazon-quick-suite/
- Video→sprite workflows: https://haruka-apps-games.itch.io/video-frame-extractor-turn-ai-video-into-sprites · https://github.com/tylertroy/video2sprites · https://help.scenario.com/en/articles/create-spritesheets-with-scenario/
