# GameZ handoff

Read this first. It is the single place that says where the project stands, how
to build and run it on any machine, and what to do next. Whoever changes the
project (a person or an AI session) updates this file, `CHANGELOG.md` and, for
decisions, `docs/DECISIONS.md` in the same commit.

Last updated: 2026-10-09

## Where things live

| What | Where |
| --- | --- |
| Source code, shaders, docs | This git repo: https://github.com/btx9pm6k9w-art/gamez |
| Current work | Branch `claude/prototype-foundation`, draft PR #1 (not merged yet) |
| Design document | `docs/DESIGN.md` (Markdown copy, in git) and the live Claude Doc https://claude.ai/code/artifact/3b74b31f-13ee-4ce3-a532-29f824e41721 |
| Decisions and why | `docs/DECISIONS.md` |
| History of changes | `CHANGELOG.md` and `git log` |
| Third-party sources and licences | `docs/SOURCES.md`; project licence in `LICENSE` (all rights reserved, public repo) |
| Setup and check scripts | `tools/` |

Nothing needed to continue lives only in a chat. If the claude.ai project is
gone, the repo alone is enough.

## Current state

The prototype is a playable skirmish on one map, written entirely in GDScript
with no binary assets (all meshes, textures, sounds and music are generated at
startup).

- **Engine:** Godot 4.7.2 stable, Forward+, Metal on macOS / Vulkan on Windows.
- **Map "Beachhead":** 192 x 192 m deformable terrain on the Strait of Hormuz
  with sea, an island with a lighthouse, an offshore rig, a mangrove creek, salt
  flats, a gravel wadi, an oasis village, a dune sea and an oil field.
- **Units:** Coalition (Abrams-class tank, Ranger, Javelin team, K9 robot dog,
  laser air defence, patrol boat) and Iran (Karrar-style tank, IRGC rifleman,
  RPG team, Shahed-style drone launcher and drones, fast attack craft), with a
  counter system of armour classes and weapon multipliers (`UnitDefs.VS_ARMOR`).
- **Play:** Mission 1 "Beachhead" with briefing, objectives, debrief and three
  difficulties; oil derricks to capture for income; a C&C-style sidebar that
  buys reinforcements; classic RTS controls (edge scroll, A/S/H/P, Shift queue,
  Space to alerts); Precision Strike (F) and Airstrike (G); enemy waves with a
  boat swarm, counter-attacks and derrick raids.
- **UI:** "tactical glass" style (`scripts/ui/ui_theme.gd`): main menu over
  the live map, two-column briefing, top bar, objective tracker, event feed,
  selection card with portraits and counters, command bar with cooldowns,
  radar minimap, build-card sidebar. Not yet seen on the Mac (2026-10-09).
- **Graphics:** SDFGI, SSIL, SSR, SSAO, volumetric fog, glow, AgX, HDR output on
  XDR Macs, MetalFX, four presets (F1 to F4), layered film-style VFX.
- **Audio:** buses with limiter, reverb and sidechain ducking; 3D SFX; adaptive
  three-stem music; all synthesised until real recordings are added.

**Verified on the Mac (2026-10-09):** the game imports and runs on the M4 Pro
MacBook Pro in Godot 4.7.2 with no script errors. Presets measured with the
window maximised: Low ~105 fps, Medium ~75, High ~65 (default on M-series),
Ultra ~40, capped at 60. Only the opening scene has been profiled, not heavy
combat. A few ObjectDB instances leak at exit. Change presets in
`scripts/autoload/game_settings.gd` only with measurements: run the game with
`-- --benchmark` (or `-- --benchmark-costs`) before and after.

**Owner feedback:** the graphics look poor and samey. Every model is a
generated primitive and the golden-hour grade is too dark and orange. The art
pass (real CC0 models and PBR textures) is the top priority; see Next steps.

On the owner's Mac, Godot is at `~/Downloads/Godot.app` and the clone is
`/Users/darko/gamez`:

```sh
~/Downloads/Godot.app/Contents/MacOS/Godot --path /Users/darko/gamez
```

## Set up and run

### macOS (M4 MacBook Pro, the main target)

```sh
git clone https://github.com/btx9pm6k9w-art/gamez.git
cd gamez
git checkout claude/prototype-foundation   # until PR #1 is merged
./tools/setup_mac.sh                       # installs Godot 4.7 with Homebrew if missing
./tools/run.sh                             # runs the game
```

Or open Godot, choose **Import**, pick `project.godot` and press the Play button.

#### Build the Mac app

Needs the Godot 4.7.2 export templates once (Editor > Manage Export
Templates > Download, about 1 GB). Then:

```sh
mkdir -p build
~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" build/FractureLine.zip
```

This makes `build/FractureLine.zip` (about 71 MB; the universal app inside is
about 173 MB). It is ad-hoc signed, not notarised, so the first time you open
it, right-click the app and choose **Open**. `build/` is not committed. The
preset's exclude filter is empty because `main.gd` preloads the dev hooks in
`scripts/dev/`; move those hooks out of `main.gd` before excluding them again.

### Windows (ThinkPad P1, 4 GB VRAM)

```powershell
git clone https://github.com/btx9pm6k9w-art/gamez.git
cd gamez
git checkout claude/prototype-foundation
powershell -ExecutionPolicy Bypass -File tools\setup_windows.ps1
```

Then open `project.godot` in Godot and press Play. Start on the Medium preset
(F2). The ThinkPad is low on disk: the repo is under 1 MB, and Godot itself is
about 150 MB.

### Checks without a GPU (any OS, also cloud sessions)

```sh
pip install "gdtoolkit==4.*"
./tools/check.sh
```

This parses every script and, when Godot is installed, opens the project
headless to catch script and shader compile errors.

## In-game controls

| Input | Action |
| --- | --- |
| Left click / drag | Select (Shift adds; double-click or Ctrl/Cmd+click selects all of that type on screen) |
| Right click | Move, or attack the enemy under the cursor. Shift queues waypoints. Cancels an armed order |
| A then click | Attack-move (R also works). Shift+click queues several points |
| S, H, P | Stop (X also works), hold position, patrol |
| Ctrl/Cmd + 1..9, then 1..9 | Set and recall control groups; press twice to jump the camera |
| Tab | Select the whole army |
| Space | Jump to the last "units under attack" alert |
| Mouse at screen edge, arrow keys, middle drag, trackpad | Pan; wheel or pinch zooms; Q and E rotate; Home resets |
| - and = | Scroll speed |
| F9 | Lock or free the mouse (locked by default so edge scrolling works in a window) |
| V | Unit voices on or off |
| Minimap | Left click or drag jumps; right click sends the selection |
| F then click | Precision Strike |
| G then click | Airstrike |
| F7 | VFX showcase (free airstrike at the camera) |
| T | Time of day |
| F1 to F4, F5, F11 | Quality preset, HDR toggle, fullscreen |
| F6, F10 or ? | Restart (skips the main menu), show or hide help |

## Code map

```
project.godot            engine, rendering and autoload settings
scenes/main.tscn         entry scene; everything else is built in code
scripts/main.gd          spawns the battle, win and lose checks
scripts/autoload/        GameSettings (presets, input map), VFX, Audio
scripts/world/           Battlefield (lighting, props, navigation, damage),
                         Terrain (heightmap, biomes, deformation),
                         SetDressing (trees, rigs, ships, landmarks)
scripts/units/           Unit (ground, air and naval logic), UnitModels, Projectile
scripts/abilities/       Airstrike
scripts/missions/        Mission base (objectives, briefing data), Mission 1
scripts/game/            Economy (oil derricks, credits, production queues)
scripts/control/         RTSCamera, SelectionManager (orders, Precision Strike)
scripts/ai/              SimpleAI (waves, boat swarm, counter-attacks)
scripts/ui/              ui_theme (colours, fonts, panels), HUD and its parts
                         (minimap, objective_panel, unit_card, ability_bar,
                         alert_feed, unit_icons), sidebar, briefing, main_menu
scripts/audio/           Audio manager and SoundSynth (procedural sounds and music)
scripts/data/            UnitDefs (stats and display names)
shaders/                 terrain, water, post-process; shaders/vfx/ smoke, fire,
                         fireball, distortion
docs/                    DESIGN.md, DECISIONS.md, SOURCES.md
tools/                   setup and check scripts
```

## Art pass status (2026-10-09, from the Mac)

- Real CC0 models and textures are in `assets/` and credited in `docs/SOURCES.md`.
  `scripts/world/model_library.gd` loads and fits them; `scripts/units/unit_models.gd`
  has one `_asset_*` builder per unit with hand-measured scales at the top of that section.
- Judge units with F8 (showcase) or `godot --path . -- --showcase --showcase-shot=/tmp/units`
  (a folder saves one close-up per unit; a `.png` path saves the overview).
- The models are low-poly and stylised (the best CC0 military set available); the
  Ranger is chunkier than the IRGC rifleman, whose rifle sits loosely in the hand.
- Frame rate on the M4 Pro at High is about 69 fps at mission start (see CHANGELOG,
  performance pass 2). The costs were full-screen passes at Retina size (MetalFX
  temporal, the post-process screen copy) and terrain texture samples, not draw
  calls. Before adding any full-screen effect, measure it with
  `-- --benchmark --benchmark-high-costs`. Heavy combat is still unprofiled.
- An unattended run with the cursor parked at a screen edge scrolls the camera away;
  the benchmark switches edge panning off for that reason.

## Next steps

Folded in the external review (`/mnt/project-files/external-review-plan.md`,
which read commit 9dfc06c) in its priority order; see DECISIONS #23.

1. **Mac export works** (art pass 2, 75 fps on High uncapped in the exported
   app); see "Build the Mac app". Next: a Mac playtest of the full Mission 1
   with a scripted coalition auto-play.
2. **Check fog of war and the group AI on the Mac** (both new, untested in
   the engine): decal orientation and darkness, the cost of rebuilding the
   decal atlas when fog changes, waves staging and flanking. Later: fog on the
   sea surface (the decal skips transparent water), commander powers needing a
   spotted target, AI protecting its launchers.
3. Polish the group AI: retreat thresholds, launcher escorts, harbour assault.
4. Check the boats' water routes on the Mac (round the island, into the harbour).
5. **Polish Mission 1 to a complete 8 to 12 minute mission** before adding
   units. Done: pier loss condition, scouting reveal, village hold act
   (DECISIONS #24), reinforcements, radio tips, `--autoplay` scripted player
   (`-- --autoplay --autoplay-speed=6 --autoplay-difficulty=0|1|2`). To do:
   rerun the autoplay (target about 5 minutes of game time), a human Elite
   test, a road or dune flank choice, more cover on the approach.
6. **Refactor as it grows:** split `unit.gd` into movement, weapon, vision and
   command parts; typed resources for unit defs; a spatial grid for target
   searches before armies get bigger.
7. Art pass 2: one consistent model style (see "Art and UI direction" in the
   design doc), unit portraits from the models, veterancy.
8. Base building on the slice economy, then missions 2 and 3. Each mission is
   specified in `docs/DESIGN.md` under "Mission guide"; extend
   `scripts/missions/mission.gd`.
9. Real audio from the Sonniss GDC bundles. Log every asset in `docs/SOURCES.md`.

## Open questions for the owner

- The Mac is signed in to GitHub as a read-only account, so Mac commits reach
  the repo as patches pushed from a cloud session.
- Budget and timing for the commissioned score and voice actors.

## Working rules

- Every change updates `CHANGELOG.md`. Update this file when state, setup or
  next steps change, and `docs/DECISIONS.md` when a decision is made.
- When the Claude Doc changes, re-export it to `docs/DESIGN.md`.
- No large binaries in git. Assets go in as compressed Ogg or KTX/WebP, with
  their source and licence logged.
- Work on a branch and merge through a pull request.
