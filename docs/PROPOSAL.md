# Proposal — a better Kingdom-Rush-style tower defense

Status: **draft for your decision.** Built on `docs/RESEARCH.md`. Working title: *TBD* (suggestions welcome). It must use original art, names, lore and numbers — we take lessons from Kingdom Rush, not its assets.

## 1. Pillars

1. **Always doing something.** Keep KR's founding insight (the player is a commander, not a spectator): blocking units, steerable heroes, cooldown powers, early wave calls.
2. **Every choice matters.** No dominant-two-towers meta. Balance is *measured*, not guessed (see §5).
3. **Fair difficulty.** Challenge from decisions and information, never from out-of-bounds enemies, hidden rules, or "die once to learn the gimmick".
4. **Looks and feels premium on a Mac.** 120 fps on ProMotion, crisp on Retina, real lighting and particles — still readable at a glance.
5. **Respect the player's time.** Fast-forward, pause-to-plan, in-combat bestiary, skill review, no drip-feed or paywalled heroes.

## 2. Gameplay — what we keep, fix, add

| Area | Kingdom Rush | Ours |
|---|---|---|
| Blocking | Barracks soldiers lock enemies | **Keep**, plus formations/"stances" (hold, advance, guard-tower) and soldier targeting rules the player can set |
| Tower depth | 4 types × 2 L4 branches (3 → 2 in recent games) | **4–5 classes × 3 upgrade branches**, each branch changes the tower's *role* (BTD6-style), with a small shared-keyword synergy system (e.g. Wet → Shock chains, Burn + Oil, Armor Shred → Artillery) |
| Heroes | Auto-cast abilities; uneven power | **Manual abilities with targeting**, 2 heroes optional, per-hero kit tuned by sim win-rate |
| Spells | Rain of Fire (80 s) + Reinforcements (10 s) | Loadout of 3 from a pool; cooldown-only (no gold), early-call recharge retained |
| Map | Fixed points, fixed single paths | Fixed build points **plus** per-map mechanics: forks with player-toggled gates, destructible bridges, shifting tides, day/night. Every mechanic telegraphed before it hits |
| Levels | ~26 authored | Authored campaign + **seeded endless/roguelite mode** (draft towers, relics) for replay depth |
| Difficulty | HP ×0.8/1.0/1.2 | Tiered **modifiers** (more waves, tougher armor mix, faster casters), always visible in pre-level briefing; no hidden wave sizes outside an explicit "fog" challenge |
| QoL | No fast-forward (on Steam), no in-combat bestiary | Fast-forward 1×/2×/3×, pause-and-place, in-combat bestiary & upgrade review, hero-voice mute, colour-blind modes, remappable keys, full gamepad/trackpad support |
| Economy | Wave income + bounty | Same core, plus per-wave **risk offers** (take a harder wave for a relic/gold) |
| Monetisation | Premium + hero IAP | None assumed — premium single purchase |

Damage model (kept because it is good, and simple to read): physical vs magic, % armor / % resist, true damage, ignore-armor artillery, boss immunity to instakills. We add *armor shred* and *vulnerability* as visible debuffs with icons.

Enemy design rules (from KR's strengths): every enemy has one readable role and one clear counter; silhouettes distinct at 24 px; telegraph every special ability (≥ 0.5 s wind-up VFX); bosses reward preparation and are never soft-lockouts for most towers.

### 2b. Lessons folded in from similar games (see `docs/SIMILAR-GAMES.md`)
- **Cap the roster**: ~5 classes × 3 branches, one clear job each (X-Morph shipped after cutting 58 towers/92 add-ons down).
- **Mistakes are cheap**: sell refund ≥ 80 % (KR: 60 %), free soldier repositioning, checkpoint revert in campaign, optional redeploy cooldown (Arknights/Defense Grid).
- **Waves as parametric data** (Mindustry's `begin/end/spacing/amount/scaling/shields/effect`), hand-tuned income per wave for the campaign, seeded generator for endless; scale **shields/armor**, not just HP.
- **Balance from first principles** (Goal Defense): derive creep HP from tower DPS × covered path time; aim for a new tower every 1–2 waves and ~60–70 % of slots used at win.
- **Forced movement** (knockback into blockers, pulls, traps) as the signature synergy with blocking (Dungeon Warfare).
- **Bot-testable by construction**: deterministic sim, seeded RNG, action journal, exact state, action receipts, snapshot/branch replay — the four gates the Kingdom Rush ML-agent project had to retrofit via a bridge.
- Honest risk: no open-source reference implements KR-quality melee-blocking AI; it is our core R&D item.

## 3. Technology — the decision I need from you

I can build and *test* in this Linux container: Node 22, Rust 1.97, Python, headless Chromium. I cannot run Swift/Xcode/Metal here, so anything native-Mac cannot be verified by me.

| Option | Mac performance/graphics | Verifiable here | Cost |
|---|---|---|---|
| **A. TypeScript + WebGPU (WebGL 2 fallback), packaged with Electron** | Safari 26 / WKWebView has WebGPU → Metal underneath. 120 fps for 2D+lighting is comfortable | **Yes** (headless Chromium, screenshots, perf traces) | Low–medium; also runs in a browser for instant sharing |
| B. Rust + `wgpu` native (Metal backend) | Best: native, no JS GC; also compiles to WASM/WebGPU | Partly (sim + software GPU; not Metal) | Higher; slower iteration |
| C. Native Swift + Metal | Best-in-class on Mac, Mac-only | **No** | Highest risk without a Mac in the loop |
| D. Godot / Unity | Good, mature tooling | Limited (no editor automation here) | Engine lock-in; editor-bound workflow |

**Recommendation: A, revised on 2026-10-11 to use Electron (not Tauri) as the shell** — after you asked me to be sure this is the best path. Reasoning:
- Tauri renders in the *system* WKWebView. WebGPU shipped in Safari 26 / WebKit for macOS (WebKit blog), so whether a Tauri game gets WebGPU depends on the player's macOS version [inference: WKWebView tracks the OS WebKit, not the Safari app]. Electron bundles its own Chromium, so the WebGPU/WebGL2 behavior is identical on every Mac and every update is under our control.
- Headless Chromium in this container is the same engine family as Electron's renderer, so **I can actually test and profile what your Mac will run**; I cannot test WKWebView.
- Precedent: Core Defense, a commercial TD, shipped on custom JS + Pixi.js + Electron (see `docs/SIMILAR-GAMES.md`).
- Cost: larger download and RAM than Tauri — irrelevant for a game with multi-GB art. Steam packaging is more common with Electron too.
- **Honest limit:** this is the best path *for what I can build and verify and for 2D at 120 fps on an M4 Pro*; a native Metal/Rust renderer would win on raw efficiency and avoid JS garbage-collector pauses, but costs iteration speed and testability. M0 therefore includes a **stress benchmark you run on your Mac** (500+ animated units, lights, particles, 4K): if p99 frame time exceeds 8.3 ms, we move the hot loops (sim and/or batching) to Rust → WASM or switch the renderer to Rust + wgpu, keeping the deterministic sim contract unchanged. Godot/Unity were rejected mainly on testability-from-here and determinism control, not because they are weak.

Architecture (keeps option B open):
- **Deterministic simulation core** (fixed 60 Hz tick, data-driven, no rendering imports) — unit-testable, replayable, and portable to Rust later.
- **Renderer** behind a thin interface: instanced sprite batches, texture atlases, 2D dynamic lights with normal maps, GPU particles, post-FX (bloom, soft shadow), resolution scaling for Retina.
- **Headless balance bot**: plays levels against the sim thousands of times to flag dominant towers/heroes and dead levels (this directly addresses KR's biggest balance complaint).

## 4. Performance budget (targets, to be verified by measurement)

**Reference machine: MacBook/Mac with Apple M4 Pro, 24 GB unified memory** (your hardware). This is far above anything Kingdom Rush targets, so we spend the headroom on visual quality, not on slack. Caveat: I cannot run on a Mac from this container, so every number below is a *target* until you run the perf HUD on your machine and send me the readout.

- **120 fps locked on ProMotion** (frame ≤ 8.3 ms, p99 ≤ 10 ms); 60 fps floor on an 8 GB M1 as a compatibility tier (auto-selected quality preset).
- Native Retina output (2× device pixels) with dynamic resolution scaling that only kicks in under load; MSAA/FXAA-class edge smoothing.
- ≤ 300 draw calls (batched/instanced), 0 per-frame allocations in the hot path (object pools / typed arrays), sim tick ≤ 1.5 ms at 500 active units; sim and render decoupled (fixed 60 Hz sim, interpolated render) so 120 Hz is smooth.
- **Memory: ≤ 3 GB total, textures ≤ 2 GB** (24 GB unified memory allows high-res atlases; KR's mobile ports fought memory limits, we budget it from day one anyway). Compressed GPU textures where supported to cut bandwidth.
- Thermals/battery: frame limiter option, pause-when-unfocused, no busy loops, so it stays cool and quiet on a laptop.
- Load level ≤ 2 s; startup ≤ 3 s.
- CI perf gate: headless run with a standard stress scene; fail on regression. A built-in perf HUD (fps, frame-time graph, draw calls, GPU/JS memory) so you can verify on your M4 Pro.

## 5. Quality & balance process
- Data-driven content in JSON (`data/` seeds the economy ranges: e.g. HP spans ≈ 20 → 18,000 and bounty ≈ HP/ few; L1–L4 tower cost ladder ≈ 70/110/160/230).
- Simulation test suite (vitest) + balance sweeps + visual regression screenshots.
- Playtest telemetry hooks (local only) to find drop-off levels, as Ironhide did.

## 6. Art direction
Original stylised-painterly fantasy; hand-readable silhouettes; 2D skeletal + sprite-sheet animation with rim-light/normal-map lighting for depth KR's flat sprites lack; layered parallax backgrounds with animated ambience (water, foliage, fog); strong colour coding by damage type; juicy but bounded VFX (hit-stop, squash/stretch, screen-shake options).
**Quality bar:** at least Kingdom Rush: Vengeance / Alliance — rich painted backgrounds, richly animated characters, lively VFX — plus lighting and effects they don't have.

**Honest constraint — art is the bottleneck, not the renderer.** The renderer (lighting, particles, post-FX, 120 fps) is something I can build and measure. But KR-latest *looks* the way it does because of a professional art team (~30-person studio) producing hand-painted backgrounds and per-character animation. I cannot hand-paint that by writing code. What I can do:
1. Build the renderer and a content pipeline (atlas packer, skeletal-animation runtime, normal-map lighting, palette/grading) so any art dropped in looks its best.
2. Generate **procedural/vector art in code** (SVG→high-res atlases, procedural terrain/foliage/water shaders). This can look clean and stylised, but will not equal hand-painted KR-latest quality on its own.
3. For true top-tier visuals you need **real art assets**: a commissioned artist, a licensed asset pack, or an AI image workflow you approve (I have no image-generation tool in this session). Tell me which route, and I'll design the pipeline around it.

## 7. Milestones
1. **M0 – Vertical slice engine** (≈ first build): sim core, one map, 3 towers, barracks blocking, hero, waves, WebGL2/WebGPU renderer with lighting, perf HUD, headless tests + screenshots.
2. **M1 – Systems:** upgrade branches, synergies, spells, early-call, fast-forward, UI/UX, bestiary.
3. **M2 – Content:** 6-map campaign, 12 enemy types, 2 bosses, 3 heroes; balance bot tuning.
4. **M3 – Polish & Mac packaging:** Electron build, ProMotion tuning, audio, accessibility, settings, save data.
5. **M4 – Endless/roguelite mode.**

## 8. Decisions needed
1. **Tech path:** A (recommended), B, or C?
2. **Name/theme:** keep the medieval-fantasy lane, or differentiate (e.g. sci-fantasy, steampunk, mythic)? Avoiding Kingdom Rush's IP is required either way.
3. **Scope of first build:** just the vertical slice (M0), or push through M1?
4. **Art source (this decides final visual quality):** commissioned artist, licensed pack, AI-assisted workflow you approve, or procedural placeholders first?

*Update 2026-10-11:* target machine confirmed as **M4 Pro / 24 GB**; graphics bar = at least Kingdom Rush latest; performance = smooth 120 fps on that machine (see §4, §6).
