# Style Bible & Prompt Pack (v0 — for the free AI style test)

Goal: hand-painted, bold-outline, saturated, readable-at-small-size cartoon fantasy, in the genre tradition of mobile tower-defense (clear silhouettes, chunky shapes, warm rim light). Original IP: **do not** put game or studio names in prompts; describe the look instead. Personal project.

## Look rules
- **Silhouette first:** every unit identifiable as a black shape at 48 px.
- **Palette:** saturated mid-tones, warm light from upper-left, cool shadows; limited palette per asset (≤ 12 main colors).
- **Line:** thick dark-brown outline (not pure black), slightly varied weight.
- **Shading:** 2–3 value steps + soft rim light; avoid photoreal textures and fine noise.
- **Proportions:** chunky, big heads (≈ 1:2.5 head:body), oversized hands/weapons.
- **Camera:** 3/4 top-down for map; characters side/three-quarter view facing right.

## Tools & settings (run on your Mac; Draw Things recommended)
- Model: FLUX.1 schnell (Apache-2.0) for speed or FLUX.1 dev (non-commercial OK for personal) for quality; SDXL + a cartoon/"game asset" LoRA as an alternative.
- Sizes: characters/props 1024×1024; backgrounds 1536×1024 then upscale 2× (4K wide); icons 512×512.
- Always save the **prompt + seed + model + steps + cfg** next to each result (`name.json`) so I can reproduce and train a LoRA later.
- Generate 8–16 candidates per asset; keep the best 1–3; put them in `assets/ai/...` (see `docs/FREE-ART-PLAN.md` §5).

## Prompt template
`[subject], [pose/view], hand-painted cartoon fantasy game art, bold dark-brown outline, saturated colors, soft rim light, simple 3-step shading, chunky proportions, clean silhouette, isolated on plain light-gray background, high detail, 2D game sprite`
Negative: `photo, realistic, 3d render, blurry, text, watermark, extra limbs, deformed hands, busy background, thin lines, low contrast`
For transparent-background assets: generate on flat light gray or magenta, remove background afterwards (my pipeline does it).

## Style-test pack (10 assets)
1. **Background (map)** — `top-down three-quarter view of a sunny medieval farmland valley with a winding dirt road, wooden fences, haystacks, small river, stone bridge, tall grass, hand-painted cartoon fantasy game map background, vibrant colors, soft light, wide landscape, no characters, no text` (1536×1024)
2. **Archer tower** — `stone and wood archer tower with thatched roof and two small archers, front three-quarter view, …template…`
3. **Barracks tower** — `small stone barracks with banner flags and shield rack, …template…`
4. **Mage tower** — `slender blue stone wizard tower with glowing crystal on top and floating runes, …template…`
5. **Enemy swarm — goblin** — `small green goblin with a rusty dagger and wooden shield, snarling, walking pose facing right, full body, …template…`
6. **Enemy heavy — orc brute** — `big armored orc brute with spiked club and iron shoulder plates, facing right, full body, …template…`
7. **Hero knight** — `heroic knight in polished steel armor with red cape and large sword, confident stance facing right, full body, …template…`
8. **Animation test (goblin)** — `character turnaround sheet, same goblin, 4 walk-cycle key poses (contact, down, passing, up), facing right, evenly spaced on a single row, consistent design, …template…`
9. **Icons ×4** — `game UI icon: [sword | shield | gold coin | fireball], hand-painted, bold outline, centered, 512×512, …template…`
10. **UI plate** — `ornate wooden panel frame with iron corners and parchment center, game UI, front view, empty center, …template…`

## Review checklist (what "not worse than Kingdom Rush" means for us)
- At 100 % game scale (units ~64–96 px tall) can you read each unit's role in 0.3 s?
- Do all 10 assets look like they belong in one game?
- Are outlines/colors consistent between towers, enemies and background?
- Walk-cycle test: do 4 key poses keep the same design (face, colors, gear)?
If ≥ 8/10 pass → proceed to full production with a style LoRA; else adjust and repeat.
