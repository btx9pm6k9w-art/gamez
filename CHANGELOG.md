# Changelog

Every change to the project, newest first. Dates are UTC. Commit hashes refer to
the `claude/prototype-foundation` branch until PR #1 is merged.

## 2026-10-10

### Base building prototype
- **Added** base structures (`scripts/data/building_defs.gd`): Forward
  Operating Base, Power Plant, Oil Refinery, Barracks, Vehicle Depot, Guard
  Post and Interceptor Battery, each with cost, build time, power and
  prerequisites. Procedural models are in `scripts/buildings/building_models.gd`.
- **Added** `Structure` (`scripts/buildings/structure.gd`), a Unit that never
  moves. Structures get health bars, selection, fog, targeting and damage
  like troops. They register as solid props, so the navmesh routes round them
  and they stop shots. They rise out of the ground when placed and collapse
  into burnt rubble when destroyed. Defences fire with the normal weapon
  code.
- **Added** base mode to the economy:
  - The FOB builds one structure at a time; a finished one waits as READY
    until placed.
  - Barracks and the Vehicle Depot open their production lines, and units
    roll out of the factory door.
  - Power supply and drain: on low power, production runs at half speed and
    defences hold fire.
  - Refineries add income.
  - Placement rules: within 14 m of the base, dry and fairly level ground,
    clear of units, props and other structures.
- **Added** placement mode (`scripts/control/base_placer.gd`): a green or red
  see-through ghost on a 1 m grid, with the reason it cannot be placed. Left
  click places; right click or Esc puts it back.
- **Added** to the sidebar in base mode: a power meter and Base and Units
  tabs. Cards show READY, build progress and what they still need (for
  example "Needs Barracks").
- **Added** building silhouettes to the unit icons.
- **Added** voice alerts: "Construction complete", "Low power" and
  "Structure lost".
- **Changed** selection: box select and select-all skip structures. Right
  click with a factory selected sets its rally point. Move orders ignore
  structures.
- **Added** a "structure" armour class: rifles do 8%, cannons 90%, missiles
  70%, autocannons 35% and lasers 15%; drones and strikes do full damage.
- **Changed** mission unit counts to skip structures.
- **Added** `-- --base-test`, a base-building trial on the Mission 1 map
  (`scripts/missions/mission_base_test.gd`).
- **Changed** the design doc (and `docs/DESIGN.md`): a base-building section,
  and derrick income corrected to 6 credits a second.

### Graphics pass: sharper image, mipmapped terrain, real scrub (from the Mac)
Owner feedback: pixelated, stair-stepped edges, poor textures and terrain objects.
- **Internal resolution** was the main cause: High rendered 2237 x 1430 (3.2 MP) and
  upscaled to the 3670 x 2342 Retina window, which showed as soft, jagged edges on
  units, outlines and shadows. Budgets are now 2.6 / 3.8 / 5.0 / 6.5 MP for
  Low / Medium / High / Ultra. Measured at mission start: Low 119 fps, Medium 89,
  **High 60 (cap)**, Ultra about 35 to 40 (native 8.7 MP was 25).
- Tested on High and not adopted: native TAA (43 fps), native MSAA 2x + FXAA (42),
  MetalFX temporal at 5 MP (47), 8K shadows (3 fps cost for little gain). MSAA 2x on
  top of the 5 MP upscale looked the same as TAA, so TAA stays.
- **Terrain textures had no mipmaps** (`mipmaps/generate=false`, uncompressed), which
  makes sand and rock shimmer and alias in motion. They are now mipmapped and
  VRAM-compressed (normal maps flagged as normals).
- Shadow distance on Medium and High is 100 m (was 130), so the same shadow map
  covers less ground and edges are about 30% finer.
- **Props**: the desert shrub scatter uses a real CC0 bush mesh (MultiMesh), ghaf
  trees are bush crowns on trunks, and 36 CC0 cacti dot the dry plain.
  `ModelLibrary.baked_mesh()` bakes a model's mesh for MultiMesh use.
- Still primitive (SetDressing): mangroves, sandstone pillars, pumpjacks, flare
  stack, platform, lighthouse, pier, containers, dhows, tankers. The map has about
  100 props left that are generated boxes and blobs.
- `--benchmark-aa` sweeps resolution, upscaler and AA combinations with screenshots.

### Mac playtest of bcd7ccc (waves paused during the hold, fifth Veteran tank)
Scripted player, speed 6, no script errors in any run:
- Recruit: wins at 5:06, 3:10, 3:20.
- Veteran: **wins at 3:58, 3:29, 4:13** (all three bonus objectives met).
- Elite: losses at 4:12 and 3:33; with the new `--autoplay-strikes` (precision strike
  and airstrike on the largest unseen-by-friendlies enemy cluster) still losses at
  4:42 and 5:10 after 5 and 2 powers.
- `--autoplay-strikes` focuses the camera on the best enemy cluster at least 16 m from
  any friendly, then calls the power on its screen position, as a player would.

### Mission 1 Veteran made winnable
The scripted player lost every Veteran run, because during the hold it faced
the leftover garrison, wave 1 and both counter-attacks at once.
- **Changed** regular enemy waves to pause while the village hold runs
  (`SimpleAI.waves_held`); the two counter-attacks are the pressure there.
- **Changed** the first wave to 60 s (was 45 s), so it no longer lands as the
  village falls, and Veteran to start with 5 tanks (Recruit and Elite keep 4).
- **Added** "No units in the village" to the hold objective when the clock
  stops because nobody is there.

### Mac playtest of the three-act Mission 1 (c024f50)
- **Fixed** `Battlefield._animate_landmarks` assigning a freed dhow to a typed
  `Node3D` once a boat prop had been destroyed (10,408 script errors in one Recruit
  run, 519 in a Veteran run).
- Autoplay now logs the hold clock, detects an empty village while an army is alive
  (`AUTO STALL`), and takes `--autoplay-max=<game seconds>`.
- Scripted player results at speed 6: Recruit wins at 3:58, 4:16, 4:17 and 4:32 (one
  600 s run ground on without finishing the launch site); **Veteran lost 4 of 4**
  (3:06, 3:43, 3:46, 4:50); Elite lost 2:17 and 2:35. The scripted player never uses
  the strike or airstrike and trickles reinforcements in one at a time.
- The hold clock counts 120 s down when we hold the village, stops while the enemy
  outnumbers us, and also stops when we have no unit in it at all (by design).

### Mission 1 retuned after the scripted playtest
The scripted player won in under 2 minutes of game time. Mission 1 now has a
middle act and a harder last objective:
- **Added** "Hold the village until the reinforcements land", revealed when
  the village falls. It is a 120 s clock that stops while the enemy outnumbers
  us there or we have nobody in it. Halfway through, a second enemy group
  attacks the village.
- **Changed** the reinforcements and the launch-site intel to arrive when the
  hold ends, not when the village falls. A unit that sees a launcher still
  reveals that objective early, and it is revealed anyway after 7 minutes
  (was 4).
- **Changed** the village garrison to 9, 12 or 15 by difficulty (was 6, 8 or
  10). The launch site now has 2 to 4 tanks and 4 to 8 infantry (was 1 to 3
  and 2 to 4).
- **Changed** the first enemy wave to 45 s (was 70 s), and derrick income to
  6 credits a second (was 8), because credits piled up past 19,000.
- **Changed** `--autoplay` to hold the village until the hold ends before it
  pushes on.
- **Changed** the Mission 1 section of the design doc (and `docs/DESIGN.md`) to
  describe the three acts and the pier rule.

### Mission 1 playtest with a scripted player (from the Mac)
`-- --autoplay [--autoplay-speed=6] [--autoplay-difficulty=0|1|2]` (scripts/dev/autoplay.gd)
buys units, sends a squad to the derricks, takes the village with the main force and
pushes on the launch site, keeping two rangers at the pier.
- Recruit: **win at 1:40**, 7 units lost. Veteran: **win at 1:55**, 13 lost.
  Elite: **loss at 3:25**, "all ground forces lost" (35 lost, 60 kills).
- The mission is much shorter than the 8 to 12 minutes planned: the village and 2
  derricks fall by about 40 s, the launch site is reached by 100 s, and the first
  wave only arrives at 70 s.
- The pier timer never fired in any run (no enemy reached the pier).
- Reinforcements land at the pier and walk to the rally point (all within 2 to 7 m of
  it 25 s later).
- **Fixed**: `Economy.derrick_position` logged "Trying to assign invalid previously
  freed instance" on every minimap redraw once a derrick had been destroyed (782 in
  one Elite run).

### Mission 1 pacing: pier defence, scouting, reinforcements, radio
- **Added** a primary "Keep the pier" objective. Enemy ground units on the
  pier with none of ours for 30 s lose the mission; the objective counts the
  seconds down and the first push sounds an alert and marks the pier for Space.
  `Mission._check_primary` now treats an active `done_on_win` primary as met.
- **Added** a scouting reward: any coalition unit that sees a drone launcher
  reveals the launch-site objective early ("Launch site spotted").
- **Added** village reinforcements: taking the village lands an Abrams, three
  Rangers and a Javelin at the pier (two more units on Easy, no tank on Elite)
  and they move to the rally point. The village intel also uncovers the launch
  site on the fog map and marks it for Space.
- **Added** radio tips that play once: scout with the K9 (20 s), no oil yet
  (75 s), spend banked credits on a strike (150 s), keep laser trucks with the
  army once the launchers are known.
- **Changed** the briefing tips: strikes cost credits and hit your own troops,
  K9s see furthest, the village opens the road for reinforcements.
### Art pass 2: outlines, anti-tank soldiers, golden hour, Mac export (from the Mac)
- **macOS export works** (`export_presets.cfg`, Godot 4.7.2 templates): about 71 MB
  zip, 173 MB app, universal binary, ad-hoc signed. It runs and holds 75 fps at High
  uncapped. The dev scripts are no longer excluded, because `main.gd` preloads them
  (excluding them broke the exported game). It is not notarised, so macOS Gatekeeper
  will ask for a right-click Open the first time.
- **Faction outlines**: every unit model gets a thin inverted-hull outline, Coalition
  blue and Iran red (`ModelLibrary.outline`, width 0.05 m), so units read against
  sand and shadow. Wrecks drop it because they replace materials.
- **Javelin Team** keeps the soldier's rocket launcher mesh; **IRGC RPG Team** carries
  the Quaternius rocket launcher (`assets/models/rocket_launcher.glb`, CC0), chosen
  from the unit id (`COALITION_WEAPON`, `IRAN_WEAPON` in `unit_models.gd`).
- **Golden hour** is a clean warm light now: sun at 33 degrees instead of 24, near
  white colour, cooler haze, lower exposure. No orange cast, short shadows.

### Mac retest of water routes and group AI
- **Fixed** the "axis must be normalized" error for good: `Vector3.slerp` loses
  precision when the hull is already nearly aligned with the ground and logged the
  error every physics tick (about 3,900 in one run). Vehicle tilt now blends and
  renormalises instead.
- **Fixed** assault groups idling at an empty target: a unit that cannot squeeze onto
  the exact spot never returns to idle, so the "everyone idle" test never passed.
  Units within 14 m of the target with nothing to shoot now count.
- `--field-test` gained a boat route check (harbour to behind the island) and logs
  the fast-boat swarm's distance to the harbour.

### Water routes for boats
- Boats now plan a route over open water (`Battlefield.water_path`) on a
  navigation layer of their own: a 2 m grid of sea cells kept two cells clear
  of the shore, built directly from the terrain (no bake). They follow it
  point by point and still feel ahead for the coast, so they go round the
  island instead of nosing along the shoreline. Falls back to steering
  straight if no route exists.

## 2026-10-09

### Follow-ups to the Mac field test
- AI: groups of fewer than three no longer retreat the moment they arrive; a
  group that reaches an empty target forgets the stale sighting and moves on
  instead of standing still.
- Navmesh radii are now multiples of the 0.5 m cell (infantry 0.5 m,
  vehicles 2.0 m), so Godot stops rounding them up with a warning on every bake.
- Main menu fade drawn with per-corner colours, without the faint vertical bands.
- `tools/check.sh`: a missing gdparse is a warning when Godot runs the scripts,
  and a failure only when neither is available.

### Mac field test of fog of war, group AI, line of fire and navmeshes
- **Fixed** a script error in `SimpleAI._alive` once a grouped unit had been freed
  (typed loop variable over freed instances).
- **Fixed** "axis must be normalized" errors from vehicle tilt in
  `Unit._integrate_ground` (83 in one short run).
- **Fixed** stuck flank groups: the north wave entry at (112, 8) is land but vehicles
  cannot drive from it to the beachhead. `SimpleAI._land_entries` now skips entries
  with no vehicle path, so that group no longer stands at its spawn.
- Village houses are scaled to the footprint the layout planned for (they were up
  to 15% wider than the old boxes).
- `export_presets.cfg`: macOS preset, universal, ad-hoc signed, no credentials,
  `scripts/dev` excluded. `import_etc2_astc` is on, which macOS export requires. The
  export itself has not run: this Mac has no Godot export templates installed.
- `scripts/dev/field_test.gd` (`-- --field-test`): scripted checks of pathfinding on
  both navigation layers, line of fire across a house, drawn-speed smoothness capped
  and uncapped, fog consistency and cost, and a 5x-speed log of what each AI group does.

### Fog of war and an AI that fights in groups
- **Fog of war** (`scripts/world/vision.gd`): a 2 m grid with unexplored,
  explored and visible cells. Enemy units outside your sight are hidden, are
  left off the tactical map and cannot be picked or auto-targeted. The world
  darkens through one map-sized decal (no screen-space pass); the tactical map
  shows the same fog. High ground sees up to 20% further. The landing beach
  starts explored; fog is off on the main menu. The K9 robot dog is now the
  scout (vision 46 m).
- **AI groups with roles** (`scripts/ai/simple_ai.gd`): the AI only knows what
  its units have seen in the last 30 s, plus who holds each derrick. Waves
  gather at a staging point short of the target and attack together; from
  Veteran up a third of each wave flanks from another entry and joins once
  the assault is engaged. Beaten groups fall back and their survivors join
  the next wave. Raids on derricks and the mission's counter-attack use the
  same groups; idle defenders go to help neighbours under fire.

### UI fixes from the Mac screenshots
- Main menu and briefing now fill the window (they kept an empty size once in
  the tree), so the briefing is centred and the menu dims the map behind it.
  Menu buttons are solid panels and the tagline has an outline.
- Sidebar: build progress shows as a tag in the corner instead of over the
  silhouette; "Patrol Boat" no longer clips.
- Unit card: "+N more" moved to the header so it no longer covers portraits;
  "Can't hit air" is shown apart from real weaknesses.
- Merged the Mac's performance pass 2 with the decoded terrain normals: sand
  uses one top-down normal sample, rock keeps triplanar where it shows.

### UI tour for screenshots (from the Mac)
- `scripts/dev/ui_tour.gd`: `-- --ui-tour=/some/folder` walks the main menu, briefing
  and in-game HUD states (selection, mixed selection, build queue, strike armed,
  golden hour) and saves a native-resolution screenshot of each, then quits.
- The first Mac run of the UI overhaul (623a25a) had no script errors.

### Fixes from the external code review
- **Line of fire:** walls, houses, containers, fuel tanks and rocks, and ridges in
  the terrain, now block direct fire. Units only pick targets they can see
  (`Battlefield.find_target`, `Unit.has_line_of_fire`), close in when a wall is
  in the way, and rifle rounds stop at the obstacle. Shells and missiles sweep
  each physics step against the ground and solid props
  (`Battlefield.line_blocked`), so they burst on the wall instead of passing
  through. Drone launchers still fire over everything.
- **Fixed-step movement:** ground and boat positions now advance in
  `_physics_process` with navigation; the model is drawn between the last two
  ticks, so motion stays smooth at any frame rate. Boat bobbing stays visual.
- **Two navmeshes:** infantry (0.6 m clearance) and vehicles (1.8 m, gentler
  slopes) on separate navigation layers of one map, so tanks are not routed
  through gaps only soldiers fit while everyone still avoids everyone.
- **Orders by domain:** boats ignore land points and ground units ignore water
  points; an order nobody can reach buzzes.
- **Commander powers** cost credits ($300 strike, $600 airstrike) on top of the
  recharge and now hurt anyone under them, own troops included. While aiming,
  the ground they will hit is outlined.
- **Shaders:** water and terrain normal maps are decoded before blending
  (whiteout blend; triplanar normals built in world space).
- **Post effects:** film grain, lens fringe and depth of field are off by
  default (depth of field on Ultra only).
- **Checks:** `tools/check.sh` fails when gdparse is missing, when the import
  or the run exits with an error, and on more error patterns.
- `export_presets.cfg` is no longer ignored, so a macOS export preset can be
  committed (credentials stay in the ignored `.godot/`).
- Checked: the stop key no longer stops enemy units (orders go through
  `_only_own`).

### UI overhaul: tactical-glass HUD, sidebar, briefing and main menu
- Art and UI direction added to the design doc (`docs/DESIGN.md`).
- **One visual language** (`scripts/ui/ui_theme.gd`): dark translucent glass
  panels with a cyan accent edge, Rajdhani for text and headers, Share Tech
  Mono for numbers, fixed colours for each faction and for good, warning and
  danger. Applied to every Control through a theme.
- **HUD rebuilt from components:** a thin top bar (mission, mission clock,
  force balance, waves, time of day, preset, fps); an objective tracker
  (diamond = primary, circle = bonus, flashes on change); an event feed that
  slides notices in and fades them; a selection card with unit silhouette
  portraits, segmented health, weapon, armour and what the unit is strong and
  weak against (or a portrait grid for mixed selections, click to narrow); a
  command bar with the two commander powers (cooldown sweep, ready pulse,
  hotkey badges) and the attack-move, stop, hold and patrol orders; a tactical
  map with a grid, radar sweep, derrick markers, unit blips and the camera
  footprint; and a centre banner with a subtitle for big moments only.
- **In-world overlay:** segmented health bars, a corner-bracket selection box,
  oil-derrick capture bars, and a spinning targeting reticle labelled with the
  armed order.
- **Sidebar** is now a grid of build cards with unit silhouettes, cost, a
  queue badge and a shutter that lifts as the unit is built, a credits ticker
  with thousands separators, and a details strip for the hovered unit.
- **Briefing and debrief** use two columns (situation typed out on the left,
  objectives and field notes on the right), a classified header strip, the
  same objective icons as in game, and a highlighted Begin button.
- **Main menu** over the live battlefield with a slowly circling camera:
  Campaign, Unit showcase, Graphics preset, HDR and Quit. Shown at launch only;
  restarts go straight to the briefing. The AI, economy and orders wait until
  the mission starts. `RTSCamera.cinematic` drives the orbit.
- Fonts are SIL OFL, logged in `docs/SOURCES.md`.
### Performance pass 2: back above 60 fps on the larger map (from the Mac)
Measured on the M4 Pro, window maximised on the Retina display (3670 x 2342), Mission 1 start:

| Preset | Before | After |
|---|---|---|
| Low | 81 fps | 120 fps (display limit) |
| Medium | 52 fps | ~100 fps |
| High (default) | 38 fps | ~69 fps, at a higher internal resolution |
| Ultra | 29 fps | ~38 fps |

- **MetalFX temporal upscaling was the main cost**: about 8 ms a frame at this output
  size. Metal now uses MetalFX spatial plus TAA (about 2.5 ms), which also removed
  the stair-stepped edges the temporal upscaler was producing. Internal resolution
  budgets went up to 2.6 / 3.2 / 4.2 MP for Medium / High / Ultra.
- **The post-process pass** copied the whole Retina frame every frame (about 2 ms) for
  a vignette. It now only shows while a blast flash plays; sharpening, lens fringe,
  grain and vignette default to off.
- **Terrain textures**: sand uses one top-down sample and rock is triplanar only where
  rock shows (was 18 samples per pixel; about 3 ms saved).
- Volumetric fog is Ultra-only; distance haze comes from the depth fog.
- Merging props (db692b6) halved draw calls from about 1,500 to about 800 but did not
  change the frame rate: the game was never draw-call bound. That earlier diagnosis
  from the Mac was wrong.
- Benchmark additions: object census, `--benchmark-high-costs`, `--benchmark-hide`,
  `--benchmark-scripts`, `--benchmark-only=N`.

### Fixes after the Mac's art-pass run
- Draw calls: SetDressing props (ghaf trees, mangroves, pillars, pier,
  containers, dhows, ships, rig, lighthouse, pumpjacks) now merge their static
  meshes into one mesh per material (`SetDressing.bake`). Animated pivots stay.
- Sea: removed the straight seam across the water at the map edge west of the
  pier (depth now blends into deep water over 12 m).
- `UnitModels.build()` takes the unit id (stored as meta `unit_id`) so Javelin
  and RPG teams can get their own models.
- `tools/shadow_check.py` (run by `tools/check.sh`) catches the local variable
  redeclarations that stopped the RTS-controls commit from loading.

### Art pass 1: real models, terrain textures, daylight (from the Mac)
- **Units use real CC0 models** instead of generated boxes: Quaternius tanks with
  separate turrets and animated tracks, rigged and animated soldiers (idle, run,
  shoot) with weapons, a walking mech for the K9, an armoured pickup with a turret
  for the laser truck, a pickup carrying drones, a delta-wing drone, a patrol boat
  and a rigid inflatable. Each faction has its own tank and infantry model.
  `UnitModels.build()` falls back to the old primitives if a file is missing and
  keeps the `Turret`, `Muzzle`, `Engine` and `Wake` pivots; animation is driven by
  `UnitModels.set_state(model, "idle" | "move" | "shoot")`.
- **Props**: palms, rocks, village houses (Kenney, repainted as plaster) and
  striped concrete barriers come from models too.
- **Terrain** blends Poly Haven sand and rock scans (1K) into the biome colours.
- **Lighting**: the battle starts at midday under a clear sky; golden hour is
  brighter and less orange. Press T to cycle.
- **Unit showcase** (`scenes/unit_showcase.tscn`): every unit on a turntable. F8 in
  game, or `-- --showcase`.
- New `scripts/world/model_library.gd`; assets and licences are listed in
  `docs/SOURCES.md` (25 models and 4 textures, all CC0, about 10 MB).
- Fixed a parse error in `scripts/ui/hud.gd` from the RTS-controls commit (a loop
  variable named `k` shadowed another `k`) that stopped the game from loading.
- Performance: lower presets use two shadow splits and shrubs no longer cast
  shadows. **Known regression**: with the larger battlefield the M4 Pro runs High
  at about 40 fps (Low about 80), with or without the new models; the scene is now
  limited by draw calls (about 1,600 to 2,400 a frame), not by pixels.

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
