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
| Third-party sources and licences | `docs/SOURCES.md` |
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
- **Units:** Coalition (Abrams-class tank, Ranger, K9 robot dog, laser air
  defence, patrol boat) and Iran (Karrar-style tank, IRGC rifleman, Shahed-style
  drone launcher and drones, fast attack craft).
- **Play:** selection, move, attack, attack-move, stop, control groups, minimap,
  Precision Strike (F) and Airstrike (G), three enemy waves with a boat swarm,
  win and lose conditions.
- **Graphics:** SDFGI, SSIL, SSR, SSAO, volumetric fog, glow, AgX, HDR output on
  XDR Macs, MetalFX, four presets (F1 to F4), layered film-style VFX.
- **Audio:** buses with limiter, reverb and sidechain ducking; 3D SFX; adaptive
  three-stem music; all synthesised until real recordings are added.

**Not yet verified:** the game has never been run in Godot. The cloud
container used so far cannot download Godot, so the code has only been checked
with `gdtoolkit` (syntax) and an API-name checker against the 4.7.2 class
reference. Expect a round of small runtime fixes on the first real run,
especially in the shaders under `shaders/vfx/`.

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
| Left click / drag | Select (Shift adds, double-click selects all of a type) |
| Right click | Move, or attack the enemy under the cursor |
| R then click | Attack-move |
| X | Stop |
| Ctrl/Cmd + 1..9, then 1..9 | Set and recall control groups |
| F then click | Precision Strike |
| G then click | Airstrike |
| F7 | VFX showcase (free airstrike at the camera) |
| WASD, screen edges, trackpad | Pan; pinch or wheel to zoom; Q and E rotate |
| T | Time of day |
| F1 to F4, F5, F11 | Quality preset, HDR toggle, fullscreen |
| F6, H | Restart, hide help |

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
scripts/control/         RTSCamera, SelectionManager (orders, Precision Strike)
scripts/ai/              SimpleAI (waves, boat swarm, counter-attacks)
scripts/ui/              HUD, minimap, post-process layer
scripts/audio/           Audio manager and SoundSynth (procedural sounds and music)
scripts/data/            UnitDefs (stats and display names)
shaders/                 terrain, water, post-process; shaders/vfx/ smoke, fire,
                         fireball, distortion
docs/                    DESIGN.md, DECISIONS.md, SOURCES.md
tools/                   setup and check scripts
```

## Next steps

1. **First real run on the Mac.** Run `tools/check.sh`, then play. Fix any
   script and shader errors, then tune the visuals on the XDR screen.
2. Get PR #1 green and merged into `main`.
3. Economy and base building: oil, tanker trucks, construction, power.
4. Fog of war, the commander hero unit and the remaining abilities.
5. Art pass with CC0 assets (Kenney, Quaternius, Poly Haven, ambientCG), plus
   real audio from the Sonniss GDC bundles. Log every asset in `docs/SOURCES.md`.
6. Missions 1 to 3, then the rest of the campaign (see `docs/DESIGN.md`).

## Open questions for the owner

- The GitHub repo is public. Should it be private?
- Godot 4.7 must be installed on the Mac before the first run.
- Budget and timing for the commissioned score and voice actors.

## Working rules

- Every change updates `CHANGELOG.md`. Update this file when state, setup or
  next steps change, and `docs/DECISIONS.md` when a decision is made.
- When the Claude Doc changes, re-export it to `docs/DESIGN.md`.
- No large binaries in git. Assets go in as compressed Ogg or KTX/WebP, with
  their source and licence logged.
- Work on a branch and merge through a pull request.
