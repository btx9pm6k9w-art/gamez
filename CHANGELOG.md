# Changelog

Every change to the project, newest first. Dates are UTC. Commit hashes refer to
the `claude/prototype-foundation` branch until PR #1 is merged.

## 2026-10-09

### Public repo
- Confirmed the repo is public. Added `LICENSE` (all rights reserved; third-party
  licences in `docs/SOURCES.md`). Scanned the history for secrets and personal
  data and found none.

### Continuity and handoff
- Added `HANDOFF.md` (state, setup on Mac and Windows, controls, code map, next
  steps, open questions), this changelog, `docs/DECISIONS.md`,
  `docs/SOURCES.md`, a Markdown copy of the design doc in `docs/DESIGN.md`,
  and `CLAUDE.md` with working rules for AI sessions.
- Added `tools/setup_mac.sh`, `tools/setup_windows.ps1`, `tools/run.sh` and
  `tools/check.sh`.
- Fixed stale lines in the design doc (oil economy, R/X controls, AgX
  tonemapper, prototype scope).

### Diverse battlefield and naval combat (7c8e127)
- Terrain biomes: sea, rocky island, mangrove creek, salt flats, gravel wadi,
  dune sea, oil field. The terrain shader paints dune sand, gravel and salt crust.
- Landmarks: offshore rig with a flare, lighthouse, pier with containers, dhows,
  pumpjacks, flare stack, ghaf trees, mangroves, about 2,000 instanced shrubs,
  sandstone pillars, and tankers and a destroyer in the shipping lane.
- Naval units: patrol boat (Coalition) and fast attack craft (IRGC) with
  coast-avoiding steering, circling attack runs, burst autocannons, wakes and
  sinking. The AI sends a boat swarm from wave 2.
- Dune sand slows units, and high ground extends weapon range by up to 25%.
- Design doc: new "Terrain and map design" section.

### Film-style VFX and Airstrike (df327b1)
- Layered explosions: flash, fireball shader (mushroom cap for the biggest),
  flame licks, fire-lit smoke, streak sparks, debris with smoke trails, dust
  skirt, dirt plume, shockwave and heat-haze refraction, embers, lingering fires
  and a volumetric smoke pall. Water hits throw a spray column.
- Directional muzzle flashes, a layered laser, missile thruster flames, ammo
  cook-off on dead vehicles, and a screen exposure punch.
- Airstrike ability (G) and VFX showcase (F7) with procedural jets and bombs.
- New synthesised sounds: jet (doppler), bomb whistle, fire crackle.
- Design doc: new "Visual effects" section.

### Audio system (11677c2)
- Buses (Music, SFX, Ambience, UI, Voice) with limiter, reverb, glue
  compression and music ducking.
- 3D SFX with variations, engine and drone loops, ambience, three-stem
  adaptive music. All synthesised, with Ogg overrides from `res://audio/`.
- Design doc: new "Audio" section.

### Prototype foundation (d28581b)
- Godot 4.7 project: Forward+, Metal, HDR output, MetalFX, four presets.
- Deformable terrain with navmesh re-bake, sea, props, units, orders, camera,
  HUD, minimap, simple AI, Precision Strike, time of day.

### Project start (67bd60b)
- Repo created with `.gitignore` and README. Design doc written (story,
  factions, 10 missions, tech, UX, graphics plan).
