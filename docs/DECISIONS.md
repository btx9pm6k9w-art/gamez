# Decisions log

Each entry records what was decided, why, and who decided it. Newest last.
Change a decision by adding a new entry that supersedes the old one, never by
deleting it.

| # | Date | Decision | Why | By |
| --- | --- | --- | --- | --- |
| 1 | 2026-10-09 | Engine: Godot 4 (latest stable, now 4.7.2), Forward+ on Metal | Free and open source (MIT), native Apple Silicon and Metal, high-end renderer (SDFGI, volumetric fog, SSR), small installs | Owner, with Claude's recommendation |
| 2 | 2026-10-09 | 3D with a fixed isometric camera (45-degree rotation steps) | Modern lighting and destruction while keeping classic C&C readability | Owner |
| 3 | 2026-10-09 | Two factions plus a third unlocked mid-campaign, 10 missions with an AI difficulty ramp | Scope of a classic C&C campaign | Owner |
| 4 | 2026-10-09 | New ideas: destructible terrain, commander with abilities, a tech tree that changes between missions | Stand out from classic RTS | Owner |
| 5 | 2026-10-09 | Setting: present-day (2028) Gulf war, US-led coalition (US, UAE, Saudi) against Iran (IRGC and armed forces); the enemy is the regime and military, never civilians | Owner asked for a realistic modern war with Iran as the enemy | Owner |
| 6 | 2026-10-09 | Third faction: ORACLE, the coalition's battlefield AI gone rogue (revealed in mission 6, playable from 7) | Modern AI and robot theme; lets enemies become reluctant allies in Act 3 | Claude, accepted |
| 7 | 2026-10-09 | Other countries: Israel (lasers, Act 3), Iraq (corridor), Russia and China (background suppliers), Oman (mediator), Qatar (host) | Owner asked for more countries and a story | Claude, accepted |
| 8 | 2026-10-09 | Real military tech plus believable sci-fi (railgun, active camo, exosuits, humanoid robots, orbital strike) | Owner asked for the latest tech and some sci-fi | Owner |
| 9 | 2026-10-09 | Descriptive unit names ("Abrams-class", "Shahed-style"); no manufacturer trademarks; names in one data file | Avoid licensing problems; store builds can rename | Claude |
| 10 | 2026-10-09 | Maximum graphics: Ultra on the M4 (SDFGI, SSIL, SSR, volumetric fog, 8K shadows, TAA, HDR output on XDR, AgX), scaled down by presets so the 4 GB ThinkPad runs Medium | Owner wants the best possible graphics on the MacBook screen, while the ThinkPad must still run | Owner |
| 11 | 2026-10-09 | No large binaries in git. Procedural meshes, textures, VFX and sounds for the prototype; real assets later as compressed files | The owner's machines are low on disk; keeps clones small | Owner |
| 12 | 2026-10-09 | Reuse of open-source code and ideas is allowed; every source and licence is logged in `docs/SOURCES.md` | Owner allowed it; licence hygiene | Owner |
| 13 | 2026-10-09 | Audio: layered 3D SFX, adaptive three-stem music, bus mixing. Final SFX from free commercial libraries (Sonniss GDC, Freesound, Kenney); music and voice commissioned | Owner asked for top-quality sound and music | Owner |
| 14 | 2026-10-09 | VFX: layered, film-style explosions built from shaders and GPU particles, scaling with presets | Owner asked for top-quality effects | Owner |
| 15 | 2026-10-09 | Varied terrain and naval play: sea, creek, island, salt flat, wadi, dunes, oil field, boats; terrain affects tactics | Owner asked for diverse, creative battlefields | Owner |
| 16 | 2026-10-09 | Continuity: everything (code, design doc copy, decisions, changelog, handoff, setup scripts) lives in git so work can continue from any platform | Owner requirement | Owner |
| 17 | 2026-10-09 | Economy resource is oil (tanker trucks, refineries), not a fictional crystal | Fits the Gulf setting | Claude, accepted |
