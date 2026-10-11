# Art & Visuals — Sources, Pipeline, Budget, Legal

Compiled 2026-10-11. Goal: visuals **at least** Kingdom Rush: Vengeance/Alliance quality, running at 120 fps on an M4 Pro / 24 GB.
Conventions: **[src]** = read from a cited source (primary where noted); **[inference]** = my conclusion; **[unverified]** = vendor claim or not checked.

## 1. The honest starting point

Kingdom Rush's look is the product of a professional art team (~30-person studio overall, backgrounds authored as vectors in Adobe Animate per a former artist's portfolio [src, secondary]). Code cannot paint that. What decides final quality is **who makes the characters, backgrounds and animation**. My part (renderer, lighting, VFX, shaders, pipeline, procedural art) raises the ceiling of whatever art we feed it; it does not replace an artist.

I have **no image-generation tool in this session** and no GPU here, so I cannot produce painted art myself. I can write code that generates procedural/vector art, and I can build the pipeline that turns any artist's or AI tool's output into optimized in-game assets.

## 2. Sources, ranked for *this* project

| # | Route | Quality ceiling | Cost (see §4) | Legal clarity | Verdict |
|---|---|---|---|---|---|
| A | **Hire a lead 2D artist + animator** (Upwork, Spine freelancers on CGHERO, ArtStation, Discord/forums) | Highest (can match KR-latest) | $$$ | Clean: work-for-hire contract = you own it, copyrightable | **Recommended core** |
| B | **Hybrid: human sets the style, AI helps extend it** (custom-trained style on the artist's own work via Scenario / Leonardo Elements / local ComfyUI-LoRA) | High *if* an artist art-directs & paints over | $$ | See §5: AI output alone isn't copyrightable; Steam disclosure; community backlash risk | **Good accelerator, optional** |
| C | **Procedural / vector art generated in code** (my pipeline: SVG → atlases, shader water/foliage/fog, particle FX, lighting) | Medium (clean stylized, not hand-painted) | $ | Fully yours | **Do first: prototype + environment/FX layer even in the final game** |
| D | **CC0 / licensed asset packs** (Kenney — CC0; itch.io packs; OpenGameArt) | Low–medium, generic; styles clash | $–$$ | Check each license | **Placeholders only, not final** |
| E | **Studio outsourcing / full production house** | Highest | $$$$ | Clean | Only with a real budget |
| F | Pure AI generation, no artist | Inconsistent; animation is the weak point | $ | Weakest (no copyright; Steam disclosure) | **Not recommended as the primary source** |

### Verified details per source
- **Kenney** — all assets on asset pages are **CC0 public domain**, commercial use OK, attribution optional [src: kenney.nl/support]. Great for prototyping; generic look.
- **OpenGameArt** — mixed licenses per asset (CC0, CC-BY, CC-BY-SA, GPL, etc.); site says commercial use is allowed if you follow each license; **CC-BY-SA/GPL assets can impose obligations on your game** [src: OGA FAQ]. Avoid unless CC0/CC-BY and logged.
- **itch.io game assets** — has a Tower Defense tag with filters for sprites, tilesets, characters, UI, backgrounds; the style filters skew pixel-art/low-poly [src: itch.io tag page]. License is per-pack (read every one). Few offer painted, KR-style sets [inference].
- **Spine freelancers** — CGHERO lists Spine 2D artists at ~$150–$700/day [src: CGHERO, vendor listing].
- **Upwork** — median ~$25/h for 2D game artists (typical $15–30); character design + animation projects ~$800–3,000, senior work $3,000–10,000+ [src: Upwork pages, platform self-report].
- **Not checked**: ArtStation, Fiverr, Unity Asset Store, Fab, Craftpix, GameDev Market (no data gathered — I won't claim anything about them).

## 3. Animation toolchain (the real cost driver)

KR-class games animate every unit with idle / walk / attack / hit / death. Two approaches:
- **Skeletal (Spine)** — smaller files, smooth blending, easy variants. Official **spine-pixi-v8 runtime works with PixiJS 8 and renders on WebGL, WebGPU or Canvas** [src: Esoteric Software]. Editor pricing [src: esotericsoftware.com/spine-purchase, fetched today; shown at a discount]: **Essential $69** (list $99) — *cannot save/export projects using meshes or IK*; **Professional $379** (list $449); **Enterprise required at ≥ $500,000 USD annual revenue**. Runtime use is governed by Spine's runtime license, which requires each user of your product's content pipeline to hold an editor license [src: community mirror of the license, 2020 — re-read the current text before signing anything].
  **Takeaway:** quality work needs **Professional (~$379 per seat)**; the artist/animator usually already owns a license — confirm in the contract who holds it.
- **Frame-by-frame sprite sheets** — most KR-authentic, biggest memory cost (a budget issue at 120 fps / Retina), costlier to commission ($600–2,000 per attack cycle in one studio's table [src: innovecsgames blog, vendor]).
- **Cost bands from vendor blogs [src, rough]:** rigged attack/skill animation $250–800; rigged idle/walk cycle $150–250; full rigged character set (8–12 states) $2,500–7,000.

## 4. Budget scenarios (my arithmetic on the sourced ranges — **[inference]**)

Scope guess for a strong first release: ~12 enemy types + 3 heroes + 4–5 tower classes with 3 branches + soldiers ≈ 20–30 animated "character sets", plus ~6 painted maps, UI, VFX.

| Tier | What you get | Rough cost |
|---|---|---|
| Prototype | CC0 placeholders + my procedural art; 1 hired illustrator for 2–3 key concepts | $0–$1.5k |
| Indie-solid | 1 lead artist/animator: style bible, ~12 characters (rigged), 3 maps, UI | ~$15–40k (e.g. 12 sets × $2.5–7k = $30–84k at the sourced set rates if fully outsourced; less if you pay per-cycle/day and reuse rigs) |
| KR-latest-like | Small team (lead + animator + background artist) over many months | $100k+ and months of time |

Backgrounds: I found **no sourced rate** for painted game backgrounds — get quotes. Cheapest big win: have the artist paint **layered** backgrounds (sky/mid/fore/props) that my renderer lights and animates (parallax, fog, water, foliage sway, god-rays), which stretches fewer painted assets a long way.

## 5. AI-assisted workflows — legal and practical facts

- **Tools (vendor claims, [unverified])**: Scenario (train a custom style on your own art; from ~$15/mo), Leonardo.ai "Elements" LoRA training (from ~$12/mo), Ludo.ai (sprite sheets from a single anchor image, no custom training), or open-source ComfyUI + Flux/SDXL + LoRA run locally (an M4 Pro with 24 GB is plausible hardware for this [inference, not tested]). Style-LoRA datasets typically need 5–30+ consistent images, with several iterations over days [src: vendor guides].
- **Copyright (US) [src, secondary: law-firm summaries; Supreme Court declined review March 2026]:** purely AI-generated images are not copyrightable (human authorship required); a prompt alone is not enough; human-authored portions can be protected if AI use is disclosed. **Implication:** art you can't copyright is art competitors can copy. Using AI only as a *starting point* that an artist substantially paints over keeps your authorship claim stronger. Not legal advice — consult counsel before shipping.
- **Steam (primary source, Valve Steamworks Content Survey):** AI-generated content that ships to players (art, sound, narrative, localization) must be **disclosed** under "Pre-Generated"; Valve evaluates it like any other content and you promise it is not illegal/infringing. Dev-time coding assistance isn't player-facing content [src: Valve docs + secondary summaries of the January 2026 rewrite]. Disclosures show on the store page.
- **Community risk [inference]:** a vocal part of the gaming audience dislikes AI art; for a game marketed as "Kingdom Rush but better", visible AI art can hurt reception. Being upfront and using AI only for non-hero assets (textures, props, variations) is the lower-risk way.
- **Training-data provenance:** only train a style model on art **you own or are licensed** to use that way. Never train on Ironhide's assets.

## 6. Recommended plan

1. **Now (free):** I build the renderer + procedural environment/FX layer and prototype with Kenney CC0 placeholders *clearly flagged as non-shipping*.
2. **Hire one lead 2D artist/animator** (Upwork or a Spine specialist) for a **paid 2-week style test**: 1 hero, 1 enemy (idle/walk/attack/death), 1 tower, 1 layered background, in the target style. This is the cheapest way to prove the quality bar and get real quotes. Contract: work-for-hire, source files (layered PSD/Spine project) delivered, who-owns-the-Spine-license stated.
3. **Decide AI policy after seeing the style test:** if the artist is open to it, train a private style model on *their* approved work to speed up props/variants — disclose on Steam.
4. **Scale production** per tier in §4, keeping the pipeline (atlas packing, Spine → Pixi, lighting normal-map generation) automated by me.

## 7. What I will build to make any art look great
- Asset pipeline: texture-atlas packer (KTX2/Basis compressed where supported), Spine → runtime loader, automatic **normal/height map generation** for 2D lighting (needs the artist's layered files for best quality).
- Real-time 2D lighting with soft shadows, rim light, bloom, color grading; animated parallax backgrounds; shader water/fog/foliage; GPU particles.
- Perf guardrails: atlas size limits, per-scene memory budget (≤ 2 GB textures on M4 Pro), automated checks in CI.

## 8. Decisions needed from you
1. Budget band (§4) and timeline.
2. Hire an artist for the style test? (I can write the brief — style bible, asset list, technical specs, contract points.)
3. AI policy: none / props-only / extended with disclosure.
4. Theme (affects who you hire): medieval fantasy, or something more distinct.

## 9. Sources
- Kenney licensing: https://kenney.nl/support
- OpenGameArt license FAQ: https://opengameart.org/content/faq
- itch.io tower-defense assets: https://itch.io/game-assets/tag-tower-defense
- Spine purchase & license tiers: https://esotericsoftware.com/spine-purchase · runtimes: https://en.esotericsoftware.com/spine-pixi
- Steamworks Content Survey (AI disclosure): https://partner.steamgames.com/doc/gettingstarted/contentsurvey
- AI copyright coverage (secondary): https://www.morganlewis.com/pubs/2026/03/us-supreme-court-declines-to-consider-whether-ai-alone-can-create-copyrighted-works · https://copyrightalliance.org/ai-report-part-2-copyrightability/
- Animation cost guides (vendor blogs): https://www.innovecsgames.com/blog/2d-animation-cost/ · https://rocketbrush.com/blog/how-much-does-2d-animation-cost-a-solid-guide-for-game-developers · https://www.twine.net/blog/cost-of-2d-game-animation-and-how-to-budget-smartly/
- Freelance rates: https://www.upwork.com/hire/2d-game-art-freelancers/cost/ · https://cghero.com/software/spine-2d
- AI game-art tool overviews (vendor pages): https://ludo.ai/compare/best-ai-game-asset-generators · https://www.scenario.com/blog/ai-sprite-generator
