# Gamez — original lane tower defense (prototype)

Working title. A Kingdom-Rush-class tower defense with an original design (see `docs/`). **Status: M0 vertical slice** — one map, 3 tower types, blocking soldiers, waves, economy, reinforcements spell, speed/pause controls, perf HUD and stress benchmark. Art is **procedural placeholder** until real art is generated (see `docs/FREE-ART-PLAN.md`, `docs/TOOLS-PLAN.md`).

## Run on your Mac
```bash
git clone <this repo> && cd gamez && git checkout claude/kingdom-rush-research-j0oxbc
npm install            # downloads Electron for macOS
npm run dev            # open the printed URL (Chrome/Safari), or:
npm run build && npm run electron
```
Controls: click a stone pad to build · click a tower to upgrade/sell/set rally · `1` reinforcements (then click the road) · `Space` call next wave early (bonus gold) · `P` pause & plan (you can still build while paused) · `F` speed 1×/2×/3× · `B` **15 s stress benchmark** · `F3` toggle perf HUD.

### Please run the benchmark and send me the result
Press **B**, wait 15 s, and send the JSON from the banner. Do it twice: `http://localhost:5173/` (WebGL2, default) and `http://localhost:5173/?renderer=webgpu` (WebGPU). Target: `msP99 <= 8.4` (120 fps). Test headlessly here is software-GL only, so it cannot predict your M4 Pro.

## Develop
`npm test` (sim + balance gates) · `npm run typecheck` · `npm run shot` (headless screenshots) · `node scripts/bench.mjs` (benchmark in headless Chromium).

## Architecture
- `src/sim/` deterministic fixed-step (60 Hz) simulation, seeded RNG, command list in / events out, no rendering imports. A scripted bot (`src/sim/bot.ts`) plays it in tests to gate balance.
- `src/render/` Pixi v8 renderer (WebGL2 default, WebGPU opt-in with automatic fallback on device loss), sprite pools, interpolation, particles.
- `src/main.ts` loop, input, HUD (DOM), benchmark. `electron/` desktop shell.
- `tools/art/` AI art generation/review/video→sprite tooling. `data/` reference data (research only, CC-BY-SA, do not ship).

## Known limits (honest list)
- WebGPU could **not** be verified here (the container's software WebGPU loses its device). WebGL2 is verified. Default is WebGL2 until your Mac benchmark says otherwise.
- All art is placeholder; no audio yet; one map; hero, upgrade branches, bestiary UI not implemented yet.
- Balance is tuned only against a greedy bot (`tests/sim.test.ts`), not human playtests.
