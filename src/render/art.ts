// Procedural PLACEHOLDER art (vector, drawn in code). Replaced by AI/hand-painted atlases later via the asset pipeline.
import { Container, Graphics, Rectangle, Texture, type Renderer } from 'pixi.js';
import { Rng } from '../sim/rng';
import type { MapDef, Vec } from '../sim/data';

export interface Art { texture: Texture; ax: number; ay: number }
const OUT = 0x3a2412; // outline brown (never pure black)

function bake(r: Renderer, g: Graphics | Container, res = 2): Art {
  const b = g.getLocalBounds(); const pad = 3;
  const texture = r.generateTexture({ target: g, resolution: res, antialias: true });
  void pad; return { texture, ax: -b.x / b.width, ay: -b.y / b.height };
}
const poly = (g: Graphics, pts: number[], fill: number, stroke = OUT, w = 2.5) => g.poly(pts).fill(fill).stroke({ width: w, color: stroke, join: 'round' });
const circ = (g: Graphics, x: number, y: number, rad: number, fill: number, stroke = OUT, w = 2.5) => g.circle(x, y, rad).fill(fill).stroke({ width: w, color: stroke });
const rect = (g: Graphics, x: number, y: number, w: number, h: number, fill: number, rr = 3, stroke = OUT, sw = 2.5) => g.roundRect(x, y, w, h, rr).fill(fill).stroke({ width: sw, color: stroke });

function stoneBlock(g: Graphics, x: number, y: number, w: number, h: number, base = 0x9a9aa5) {
  rect(g, x, y, w, h, base, 4);
  g.rect(x + 2, y + 2, w - 4, h * 0.35).fill({ color: 0xffffff, alpha: 0.16 });
  for (let i = 1; i < 3; i++) g.moveTo(x + 3, y + (h * i) / 3).lineTo(x + w - 3, y + (h * i) / 3).stroke({ width: 1.2, color: OUT, alpha: 0.45 });
  g.moveTo(x + w * 0.35, y + 3).lineTo(x + w * 0.35, y + h / 3).stroke({ width: 1.2, color: OUT, alpha: 0.4 });
  g.moveTo(x + w * 0.7, y + h / 3).lineTo(x + w * 0.7, y + (h * 2) / 3).stroke({ width: 1.2, color: OUT, alpha: 0.4 });
}

function archerTower(level: number): Graphics {
  const g = new Graphics(); const floors = level + 1;
  g.ellipse(0, 2, 38, 11).fill({ color: 0x000000, alpha: 0.22 });
  for (let i = 0; i < floors; i++) stoneBlock(g, -24 + i * 1.5, -30 - i * 28, 48 - i * 3, 30);
  const top = -30 - (floors - 1) * 28;
  rect(g, -30, top - 10, 60, 12, 0x8a5a2b, 3); // wooden platform
  for (let i = -2; i <= 2; i++) rect(g, i * 12 - 4, top - 18, 8, 9, 0x9a9aa5, 1.5, OUT, 2); // merlons
  poly(g, [-34, top - 18, 0, top - 62, 34, top - 18], 0xd7a63a); // thatched roof
  g.moveTo(-20, top - 24).lineTo(-6, top - 50).moveTo(-8, top - 22).lineTo(8, top - 54).moveTo(6, top - 22).lineTo(20, top - 46).stroke({ width: 1.6, color: 0x8a5d18, alpha: 0.7 });
  for (const x of [-12, 12]) { circ(g, x, top - 22, 6, 0xf0c9a0); rect(g, x - 5, top - 17, 10, 9, 0x2f7d3b, 2); }
  if (level >= 1) { g.rect(-1.5, top - 62, 3, -16).fill(OUT); poly(g, [1.5, top - 76, 18, top - 70, 1.5, top - 64], 0xc0392b); }
  if (level >= 2) circ(g, 0, top + 6, 5, 0xffd24a);
  return g;
}
function barracks(level: number): Graphics {
  const g = new Graphics(); g.ellipse(0, 2, 46, 12).fill({ color: 0x000000, alpha: 0.22 });
  stoneBlock(g, -38, -34, 76, 36, 0x8f8fa0); poly(g, [-44, -34, 0, -66, 44, -34], 0x9b2f2a);
  g.moveTo(-30, -38).lineTo(0, -60).moveTo(30, -38).lineTo(0, -60).stroke({ width: 1.5, color: 0x5c1a17 });
  rect(g, -9, -22, 18, 24, 0x5b3a1c, 8); // door
  rect(g, -34, -24, 10, 12, 0x5b3a1c, 2); circ(g, -29, -18, 4, 0xcfd3dd); // shield rack
  for (let i = 0; i <= level; i++) { const x = -26 + i * 26; g.rect(x - 1.5, -58, 3, -22).fill(OUT); poly(g, [x + 1.5, -80, x + 20, -73, x + 1.5, -66], i === 0 ? 0x2e6bd1 : i === 1 ? 0xf0c040 : 0xc0392b); }
  return g;
}
function mageTower(level: number): Graphics {
  const g = new Graphics(); const floors = level + 2; g.ellipse(0, 2, 34, 10).fill({ color: 0x000000, alpha: 0.22 });
  for (let i = 0; i < floors; i++) { const w = 38 - i * 4; stoneBlock(g, -w / 2, -26 - i * 24, w, 26, i % 2 ? 0x7f8fd0 : 0x7686c4); }
  const top = -26 - (floors - 1) * 24;
  poly(g, [-26, top, 0, top - 50, 26, top], 0x4b3fa8); g.moveTo(-14, top - 6).lineTo(0, top - 40).stroke({ width: 1.6, color: 0x2b2370, alpha: 0.7 });
  g.circle(0, top - 58, 16).fill({ color: 0x7fe6ff, alpha: 0.3 }); circ(g, 0, top - 58, 8, 0x9ff3ff, 0x1c6f9a, 2);
  for (let i = 0; i <= level; i++) { const a = (i / (level + 1)) * Math.PI * 2; circ(g, Math.cos(a) * 22, top - 30 + Math.sin(a) * 6, 3, 0xbaf6ff, 0x1c6f9a, 1.5); }
  rect(g, -6, -18, 12, 18, 0x4a2f16, 6);
  return g;
}

function goblin(): Graphics {
  const g = new Graphics(); g.ellipse(0, 1, 13, 5).fill({ color: 0x000000, alpha: 0.25 });
  rect(g, -7, -9, 5, 9, 0x4d7a2b, 2); rect(g, 2, -9, 5, 9, 0x4d7a2b, 2); // legs
  g.ellipse(0, -18, 10, 11).fill(0x7bb53d).stroke({ width: 2.5, color: OUT });
  rect(g, -9, -20, 18, 8, 0x8a5a2b, 2); // belt
  poly(g, [-9, -34, -20, -39, -11, -27], 0x7bb53d); poly(g, [9, -34, 20, -39, 11, -27], 0x7bb53d); // ears
  circ(g, 0, -33, 9, 0x8ac949); circ(g, -3.5, -34, 2.4, 0xfff3b0, OUT, 1); circ(g, 3.5, -34, 2.4, 0xfff3b0, OUT, 1);
  g.circle(-3.5, -34, 1).fill(OUT); g.circle(3.5, -34, 1).fill(OUT); g.moveTo(-4, -28).lineTo(4, -28).stroke({ width: 1.5, color: OUT });
  poly(g, [12, -22, 26, -26, 14, -17], 0xc9c9d1); circ(g, -11, -19, 7, 0x9c6a35); // dagger + shield
  return g;
}
function orc(): Graphics {
  const g = new Graphics(); g.ellipse(0, 1, 18, 6).fill({ color: 0x000000, alpha: 0.28 });
  rect(g, -10, -12, 8, 12, 0x4b5a3a, 2); rect(g, 2, -12, 8, 12, 0x4b5a3a, 2);
  g.ellipse(0, -26, 16, 16).fill(0x6f8a52).stroke({ width: 3, color: OUT });
  poly(g, [-14, -34, -4, -42, 14, -34, 10, -18, -10, -18], 0x7c7f8a); // plate
  circ(g, -16, -30, 7, 0x8d9099); circ(g, 16, -30, 7, 0x8d9099); // pauldrons
  circ(g, 0, -46, 11, 0x7fa05d); poly(g, [-5, -38, -3, -32, -1, -38], 0xf4f1e6, OUT, 1); poly(g, [5, -38, 3, -32, 1, -38], 0xf4f1e6, OUT, 1);
  g.circle(-4, -48, 1.6).fill(0xff5a3a); g.circle(4, -48, 1.6).fill(0xff5a3a); g.moveTo(-6, -53).lineTo(-2, -51).moveTo(6, -53).lineTo(2, -51).stroke({ width: 2, color: OUT });
  g.moveTo(18, -34).lineTo(30, -58).stroke({ width: 6, color: OUT }); g.moveTo(18, -34).lineTo(30, -58).stroke({ width: 3.5, color: 0x8a5a2b }); circ(g, 31, -60, 6, 0x6a4520);
  return g;
}
function wolf(): Graphics {
  const g = new Graphics(); g.ellipse(0, 1, 17, 5).fill({ color: 0x000000, alpha: 0.25 });
  for (const x of [-10, -4, 6, 12]) rect(g, x - 2, -10, 4, 10, 0x6b6e76, 1.5, OUT, 2);
  g.ellipse(0, -16, 17, 9).fill(0x8b8f99).stroke({ width: 2.5, color: OUT });
  poly(g, [-17, -18, -29, -26, -26, -14], 0x8b8f99); // tail
  g.ellipse(17, -21, 9, 7).fill(0x9a9ea8).stroke({ width: 2.5, color: OUT });
  poly(g, [14, -27, 17, -35, 20, -27], 0x8b8f99); poly(g, [20, -27, 24, -34, 26, -26], 0x8b8f99);
  poly(g, [23, -19, 31, -17, 24, -15], 0xf4f1e6, OUT, 1.2); circ(g, 18, -23, 1.8, 0xffd24a, OUT, 1);
  return g;
}
function soldier(): Graphics {
  const g = new Graphics(); g.ellipse(0, 1, 11, 4).fill({ color: 0x000000, alpha: 0.25 });
  rect(g, -6, -8, 4.5, 8, 0x55555f, 1.5); rect(g, 1.5, -8, 4.5, 8, 0x55555f, 1.5);
  g.ellipse(0, -17, 9, 10).fill(0x2f6fd0).stroke({ width: 2.5, color: OUT }); rect(g, -8, -14, 16, 5, 0x6b3b17, 1);
  circ(g, 0, -31, 8, 0xf0c9a0); g.arc(0, -33, 9, Math.PI, 0).fill(0xb8bdc9).stroke({ width: 2.5, color: OUT }); g.rect(-1.5, -41, 3, 7).fill(0xc0392b);
  circ(g, -10, -17, 7, 0xd6dae6); g.circle(-10, -17, 3).fill(0x2f6fd0); poly(g, [10, -17, 24, -23, 12, -13], 0xe3e6ee);
  return g;
}
function arrow(): Graphics { const g = new Graphics(); g.moveTo(-9, 0).lineTo(7, 0).stroke({ width: 2.4, color: 0x6b4a24 }); poly(g, [5, -3, 11, 0, 5, 3], 0xcfd3dd, OUT, 1); poly(g, [-10, -3, -6, 0, -10, 3], 0xe8e2cf, OUT, 1); return g; }
function orb(): Graphics { const g = new Graphics(); g.circle(0, 0, 11).fill({ color: 0x7fe6ff, alpha: 0.28 }); g.circle(0, 0, 6).fill(0xb7f4ff).stroke({ width: 1.5, color: 0x1c6f9a }); return g; }
function spark(): Graphics { const g = new Graphics(); g.circle(0, 0, 8).fill({ color: 0xffffff, alpha: 0.35 }); g.circle(0, 0, 4).fill({ color: 0xffffff, alpha: 0.9 }); return g; }
function slot(): Graphics {
  const g = new Graphics(); g.ellipse(0, 0, 32, 15).fill({ color: 0x6f6a5a, alpha: 0.95 }).stroke({ width: 3, color: OUT });
  g.ellipse(0, -2, 26, 11).fill(0x9a9484); g.moveTo(-9, -2).lineTo(9, -2).moveTo(0, -8).lineTo(0, 4).stroke({ width: 3, color: 0xf3e6a8, alpha: 0.9 }); return g;
}

export interface Textures {
  tower: Record<'archer' | 'barracks' | 'mage', Art[]>; enemy: Record<'goblin' | 'orc' | 'wolf', Art>; soldier: Art; arrow: Art; orb: Art; spark: Art; slot: Art; background: Texture; vignette: Texture;
}

export function buildTextures(r: Renderer, map: MapDef): Textures {
  const lv = [0, 1, 2];
  return {
    tower: { archer: lv.map((l) => bake(r, archerTower(l))), barracks: lv.map((l) => bake(r, barracks(l))), mage: lv.map((l) => bake(r, mageTower(l))) },
    enemy: { goblin: bake(r, goblin()), orc: bake(r, orc()), wolf: bake(r, wolf()) }, soldier: bake(r, soldier()),
    arrow: bake(r, arrow()), orb: bake(r, orb()), spark: bake(r, spark()), slot: bake(r, slot()), background: buildBackground(r, map), vignette: buildVignette(map),
  };
}

function nearPath(p: Vec, pts: Vec[], d: number): boolean {
  for (let i = 1; i < pts.length; i++) {
    const a = pts[i - 1], b = pts[i]; const abx = b.x - a.x, aby = b.y - a.y; const t = Math.max(0, Math.min(1, ((p.x - a.x) * abx + (p.y - a.y) * aby) / (abx * abx + aby * aby)));
    if (Math.hypot(a.x + abx * t - p.x, a.y + aby * t - p.y) < d) return true;
  }
  return false;
}

function buildBackground(r: Renderer, map: MapDef): Texture {
  const c = new Container(); const g = new Graphics(); const rng = new Rng(42); const W = map.width, H = map.height;
  g.rect(0, 0, W, H).fill(0x6cae45); c.addChild(g);
  for (let i = 0; i < 70; i++) { const x = rng.range(0, W), y = rng.range(0, H); g.ellipse(x, y, rng.range(60, 160), rng.range(30, 80)).fill({ color: rng.next() < 0.5 ? 0x78ba4d : 0x5f9e3c, alpha: 0.35 }); }
  // river
  const river = new Graphics(); river.moveTo(-20, 130).bezierCurveTo(300, 40, 560, 160, 840, 90).lineTo(840, 150).bezierCurveTo(560, 220, 300, 110, -20, 190).closePath().fill(0x4fa3d9).stroke({ width: 4, color: 0x2f6f9c }); c.addChild(river);
  const road = new Graphics(); const pts = map.path;
  const trace = (w: number, col: number) => { road.moveTo(pts[0].x, pts[0].y); for (const p of pts.slice(1)) road.lineTo(p.x, p.y); road.stroke({ width: w, color: col, join: 'round', cap: 'round' }); };
  trace(70, 0x4a2f16); trace(60, 0xb68a54); trace(44, 0xc9a06a); trace(18, 0xd6b17c); c.addChild(road);
  const deco = new Graphics();
  const keep = (p: Vec, pad: number) => !nearPath(p, pts, pad) && !map.slots.some((s) => Math.hypot(s.x - p.x, s.y - p.y) < 62);
  for (let i = 0; i < 420; i++) { const p = { x: rng.range(0, W), y: rng.range(0, H) }; if (!keep(p, 48)) continue; const k = rng.next();
    if (k < 0.5) { deco.moveTo(p.x, p.y).lineTo(p.x - 3, p.y - 8).moveTo(p.x, p.y).lineTo(p.x + 3, p.y - 9).stroke({ width: 1.6, color: 0x3f7f2a }); }
    else if (k < 0.7) { deco.circle(p.x, p.y, 2.6).fill([0xffe066, 0xff8fb1, 0xffffff][Math.floor(rng.range(0, 3))]); }
    else if (k < 0.8) { deco.ellipse(p.x, p.y, 9, 6).fill(0x9a9aa5).stroke({ width: 2, color: OUT }); } }
  c.addChild(deco);
  const trees: { x: number; y: number; s: number }[] = [];
  for (let i = 0; i < 260 && trees.length < 46; i++) { const p = { x: rng.range(10, W - 10), y: rng.range(10, H - 10) }; if (keep(p, 74) && !(p.y > 80 && p.y < 200 && p.x < 860)) trees.push({ ...p, s: rng.range(0.8, 1.35) }); }
  trees.sort((a, b) => a.y - b.y); const tg = new Graphics();
  for (const t of trees) { tg.ellipse(t.x, t.y + 4, 22 * t.s, 8 * t.s).fill({ color: 0, alpha: 0.2 }); rect(tg, t.x - 5 * t.s, t.y - 26 * t.s, 10 * t.s, 28 * t.s, 0x6b4a24, 2);
    for (const [dx, dy, rad, col] of [[-12, -34, 17, 0x2f8a3a], [12, -34, 17, 0x2f8a3a], [0, -48, 20, 0x38a046], [0, -30, 18, 0x34953f]] as [number, number, number, number][]) circ(tg, t.x + dx * t.s, t.y + dy * t.s, rad * t.s, col, OUT, 2.5); }
  c.addChild(tg);
  return r.generateTexture({ target: c, resolution: 2, antialias: true, frame: new Rectangle(0, 0, W, H) }); // exact map frame: overflow (road start, river) is cropped
}

function buildVignette(map: MapDef): Texture {
  const cv = document.createElement('canvas'); cv.width = 512; cv.height = 288; const x = cv.getContext('2d')!;
  const gr = x.createRadialGradient(256, 144, 90, 256, 144, 330); gr.addColorStop(0, 'rgba(255,240,200,0.0)'); gr.addColorStop(0.65, 'rgba(30,20,60,0.10)'); gr.addColorStop(1, 'rgba(10,5,30,0.55)');
  x.fillStyle = gr; x.fillRect(0, 0, 512, 288); void map; return Texture.from(cv);
}
