# Changelog

Every change to the project, newest first. Dates are UTC. Commit hashes refer to
the `claude/prototype-foundation` branch until PR #1 is merged.

## 2026-10-09

### Strategy: counter system, anti-tank teams, multi-direction attacks
- Counter system: every unit has an armour class (infantry, light, heavy,
  naval, air) and every weapon a multiplier against it (`UnitDefs.VS_ARMOR`).
  Rifles beat infantry, anti-tank missiles and cannons beat armour,
  autocannons beat light vehicles and boats, lasers beat drones.
- New units: Coalition Javelin Team (buildable, 300) and IRGC RPG Team, firing
  slow lofted anti-tank missiles with smoke trails.
- Enemy waves rotate between three entry points (mountains, desert, ridge) and
  the HUD names the direction; on Elite each wave splits and attacks from two
  sides. Garrisons, waves and counter-attacks now include RPG teams.
- Design doc: "Strategy: how battles are won" and a mission guide for all 10
  missions (map, win and lose, enemy plan, how to win, reward). Campaign
  mission 4 renamed Port Assault, since Beachhead is now mission 1.

### Mission 1, objectives, oil economy and reinforcements
- The skirmish is now **Mission 1 "Beachhead"** with a briefing (situation typed
  out over the paused map, objectives, field notes, difficulty: Recruit, Veteran,
  Elite) and a debrief (time, kills, losses, bonus objectives).
- Objectives with live progress in a panel on the left: take and hold the
  village, hold 2 of 3 oil derricks, destroy the drone launchers (revealed by
  village intel or after 4 minutes); bonus: keep both patrol boats afloat,
  finish within 15 minutes. Spoken and on-screen notices.
- Mission framework in `scripts/missions/` (`mission.gd` base with capture,
  destroy, secure, defend and timer helpers; `mission_01_beachhead.gd`). Starting
  forces moved there from `main.gd`.
- Oil economy (`scripts/game/economy.gd`): capture derricks by standing next to
  them, 8 credits a second each, capture bars over derricks and dots on the
  minimap.
- C&C-style sidebar (`scripts/ui/sidebar.gd`): credits ticker, income, three
  production lines with queues, progress bars, right click to cancel, rally
  point. Prices and build times in `UnitDefs`.
- AI: difficulty scales garrison, waves and timing; counter-attack when the
  village falls; squads raid derricks the player holds.
- Help moved to a centred overlay (F10 or ?).

### Classic RTS controls
- Edge scrolling now works in a window: the mouse is confined to the window
  (F9 frees it), the edge band is measured in screen pixels so Retina scaling no
  longer shrinks it, a cursor that slips onto the menu bar or Dock still
  scrolls, and the speed ramps with depth into the band and time held. Panning
  glides to a stop. Scroll speed on - and =; Home resets the camera.
- Classic key layout: arrows move the camera; A attack-move, S stop, H hold
  position, P patrol (R and X still work). WASD no longer pans. Help moved to F10
  or ?.
- Shift queues move, attack-move, attack and patrol orders. Patrol walks back
  and forth attacking what it meets. Hold position never chases. Idle units now
  go after enemies in sight and walk back to where they stood.
- Ctrl/Cmd+click selects all units of that type on screen. Right click cancels
  an armed order.
- "Units under attack" alert when fire lands off screen, with a minimap ping;
  Space jumps the camera there.
- Minimap right click sends the selected units.
- Unit voice acknowledgements and alerts through the system text-to-speech
  voices until recorded lines exist (V toggles). `scripts/audio/unit_voice.gd`.
- Research and sources for all of this: `docs/DESIGN.md`, "Controls and camera".

### First run on the target Mac (M4 Pro MacBook Pro, Godot 4.7.2)

Performance, measured with the window maximised on the Retina display (3670 x 2346):

| Preset | Before | After |
|---|---|---|
| Low | 81 fps | ~105 fps |
| Medium | 46 fps | ~75 fps |
| High | 34 fps | ~65 fps |
| Ultra (was the default) | 18 fps | ~40 fps |

- The 3D scene now renders inside a per-preset pixel budget and is upscaled with MetalFX
  temporal, instead of Ultra rendering every Retina pixel natively.
- SDFGI and screen-space indirect lighting are Ultra-only; SSR and volumetric fog start at
  High; shadows top out at 4K; SSAO, SSIL, SSR and GI run at half resolution.
- M-series Macs start on High instead of Ultra (Max and Ultra chips still start on Ultra).
  Saved settings from the old presets are re-detected once.
- Frame rate capped at 60 so laptops stay cool and quiet.
- The HUD scales with the window height, so text is readable on Retina displays.

Fixes:

- Selection: a script error every frame once a selected unit had been freed
  (`filter` lambda with a typed parameter).
- Audio: script error when quitting before the placeholder sounds finished rendering.
- Removed the deprecated `environment_set_ssr_roughness_quality` call.
- Texture formats Metal does not support (RGB8 minimap, RGBFloat particle curves) no
  longer trigger conversion warnings; `hdr_2d` is set explicitly.

Added:

- `scripts/dev/benchmark.gd`: `-- --benchmark` cycles the presets, logs frame rate and
  saves screenshots; `-- --benchmark-costs` shows what each effect costs.

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
