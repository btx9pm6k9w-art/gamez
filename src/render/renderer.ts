import { Application, Container, Graphics, Sprite } from 'pixi.js';
import { buildTextures, type Art, type Textures } from './art';
import type { MapDef } from '../sim/data';
import { ENEMIES, BARRACKS, SHOOTERS } from '../sim/data';
import type { SimEvent, World } from '../sim/world';

export type Selection = { kind: 'slot'; slot: number } | { kind: 'tower'; id: number } | null;
interface Particle { s: Sprite; vx: number; vy: number; life: number; max: number; g: number; grow: number }

export class GameRenderer {
  app!: Application; tex!: Textures; backend = 'unknown';
  stage = new Container(); world = new Container(); entities = new Container(); fxLayer = new Container(); ui = new Graphics(); bars = new Graphics();
  slotSprites: Sprite[] = []; pools = { tower: new Map<number, Sprite>(), enemy: new Map<number, Sprite>(), soldier: new Map<number, Sprite>(), proj: new Map<number, Sprite>() };
  particles: Particle[] = []; free: Sprite[] = []; scale = 1; ox = 0; oy = 0; map!: MapDef; selection: Selection = null; rallyPreview = false; hover: { x: number; y: number } | null = null;

  static async create(host: HTMLElement, map: MapDef): Promise<GameRenderer> {
    const r = new GameRenderer(); r.map = map; const app = new Application();
    const opts = { resizeTo: undefined, antialias: true, resolution: Math.min(window.devicePixelRatio || 1, 2), autoDensity: true, background: 0x14182a, width: host.clientWidth || 1280, height: host.clientHeight || 720, powerPreference: 'high-performance' as const };
    // Default WebGL2 (verified; Metal-backed via ANGLE on macOS). WebGPU is opt-in (?renderer=webgpu) until benchmarked on real hardware.
    let forced = new URLSearchParams(location.search).get('renderer') ?? 'webgl'; try { if (sessionStorage.getItem('renderer-fallback')) forced = 'webgl'; } catch { /* storage blocked */ }
    if (forced === 'webgpu') { try { await app.init({ ...opts, preference: 'webgpu' }); } catch { await app.init({ ...opts, preference: 'webgl' }); } }
    else await app.init({ ...opts, preference: 'webgl' });
    r.app = app; r.backend = (app.renderer as unknown as { name?: string }).name ?? 'unknown'; host.appendChild(app.canvas);
    // WebGPU device loss => remember and reload on WebGL so the game never stays blank.
    const dev = (app.renderer as unknown as { gpu?: { device?: { lost?: Promise<unknown> } } }).gpu?.device; dev?.lost?.then(() => { try { sessionStorage.setItem('renderer-fallback', '1'); } catch { /* ignore */ } location.reload(); });
    r.tex = buildTextures(app.renderer, map); r.build(); r.resize(host.clientWidth, host.clientHeight); return r;
  }

  private build(): void {
    const { app, tex, map } = this; app.stage.addChild(this.stage); this.stage.addChild(this.world);
    const bg = new Sprite(tex.background); this.world.addChild(bg);
    for (const p of map.slots) { const s = this.sprite(tex.slot, p.x, p.y); this.world.addChild(s); this.slotSprites.push(s); }
    this.entities.sortableChildren = true; this.world.addChild(this.entities); this.world.addChild(this.ui); this.world.addChild(this.bars); this.world.addChild(this.fxLayer);
    const vg = new Sprite(tex.vignette); vg.width = map.width; vg.height = map.height; vg.eventMode = 'none'; this.world.addChild(vg);
  }
  private sprite(a: Art, x = 0, y = 0): Sprite { const s = new Sprite(a.texture); s.anchor.set(a.ax, a.ay); s.position.set(x, y); return s; }

  resize(w: number, h: number): void {
    this.app.renderer.resize(w, h); this.scale = Math.min(w / this.map.width, h / this.map.height);
    this.ox = (w - this.map.width * this.scale) / 2; this.oy = (h - this.map.height * this.scale) / 2;
    this.stage.scale.set(this.scale); this.stage.position.set(this.ox, this.oy);
  }
  toWorld(clientX: number, clientY: number): { x: number; y: number } {
    const r = this.app.canvas.getBoundingClientRect(); return { x: (clientX - r.left - this.ox) / this.scale, y: (clientY - r.top - this.oy) / this.scale };
  }
  toScreen(x: number, y: number): { x: number; y: number } { const r = this.app.canvas.getBoundingClientRect(); return { x: r.left + this.ox + x * this.scale, y: r.top + this.oy + y * this.scale }; }

  private spawn(a: Art, x: number, y: number, tint: number, vx: number, vy: number, life: number, scale: number, grow = 0, g = 0): void {
    const s = this.free.pop() ?? new Sprite(); s.texture = a.texture; s.anchor.set(0.5); s.tint = tint; s.alpha = 1; s.position.set(x, y); s.scale.set(scale); s.blendMode = 'normal'; s.visible = true;
    if (!s.parent) this.fxLayer.addChild(s); if (this.particles.length < 500) this.particles.push({ s, vx, vy, life, max: life, g, grow }); else this.free.push(s);
  }
  private burst(x: number, y: number, n: number, tint: number, speed: number, life: number, scale: number): void {
    for (let i = 0; i < n; i++) { const a = Math.random() * Math.PI * 2, v = speed * (0.4 + Math.random() * 0.8); this.spawn(this.tex.spark, x, y, tint, Math.cos(a) * v, Math.sin(a) * v - speed * 0.3, life * (0.7 + Math.random() * 0.6), scale, -0.6, 160); }
  }
  private fx(events: SimEvent[]): void {
    for (const e of events) {
      if (e.x == null || e.y == null) continue;
      if (e.type === 'hit') this.burst(e.x, e.y - 12, 3, 0xffa63a, 90, 0.28, 0.35);
      else if (e.type === 'death') this.burst(e.x, e.y - 14, 9, 0xffc83a, 120, 0.5, 0.55);
      else if (e.type === 'leak') this.burst(e.x, e.y - 14, 12, 0xff4d4d, 150, 0.6, 0.8);
      else if (e.type === 'build' || e.type === 'upgrade') this.burst(e.x, e.y - 8, 14, 0xffe08a, 110, 0.55, 0.5);
      else if (e.type === 'spell') this.burst(e.x, e.y - 8, 18, 0x8fd0ff, 130, 0.7, 0.8);
      else if (e.type === 'soldierDown') this.burst(e.x, e.y - 12, 6, 0x9ab8ff, 80, 0.45, 0.6);
    }
  }

  private sync<T extends { id: number }>(pool: Map<number, Sprite>, items: T[], make: (it: T) => Sprite, place: (s: Sprite, it: T) => void): void {
    const seen = new Set<number>();
    for (const it of items) { seen.add(it.id); let s = pool.get(it.id); if (!s) { s = make(it); pool.set(it.id, s); this.entities.addChild(s); } place(s, it); }
    for (const [id, s] of pool) if (!seen.has(id)) { this.entities.removeChild(s); s.destroy(); pool.delete(id); }
  }

  update(w: World, alpha: number, events: SimEvent[], t: number, dt: number): void {
    const { tex } = this; const lerp = (a: number, b: number) => a + (b - a) * alpha;
    const occupied = new Set(w.towers.map((q) => q.slot)); this.slotSprites.forEach((s, i) => { s.visible = !occupied.has(i); });
    this.sync(this.pools.tower, w.towers, (q) => this.sprite(tex.tower[q.kind][0]), (s, q) => { const a = tex.tower[q.kind][q.level]; s.texture = a.texture; s.anchor.set(a.ax, a.ay); const p = w.map.slots[q.slot]; s.position.set(p.x, p.y + 4); s.zIndex = p.y; });
    this.sync(this.pools.enemy, w.enemies, (e) => this.sprite(tex.enemy[e.def]), (s, e) => {
      const x = lerp(e.px, e.x), y = lerp(e.py, e.y); const moving = e.blockedBy == null; const ph = t * (moving ? 9 : 4) + e.id; const dx = e.x - e.px;
      s.position.set(x, y - Math.abs(Math.sin(ph)) * (moving ? 3 : 0.8)); s.rotation = Math.sin(ph) * (moving ? 0.07 : 0.03); s.scale.y = 1 + Math.sin(ph * 2) * 0.03;
      if (Math.abs(dx) > 0.01) s.scale.x = dx < 0 ? -1 : 1; s.zIndex = y; });
    this.sync(this.pools.soldier, w.soldiers, () => this.sprite(tex.soldier), (s, q) => {
      const x = lerp(q.px, q.x), y = lerp(q.py, q.y); const ph = t * 8 + q.id; s.position.set(x, y - Math.abs(Math.sin(ph)) * 1.4); const tg = q.target != null ? w.enemies.find((e) => e.id === q.target) : undefined;
      if (tg) s.scale.x = tg.x < q.x ? -1 : 1; s.zIndex = y; s.alpha = q.life != null ? Math.min(1, q.life / 1.5) : 1; });
    this.sync(this.pools.proj, w.projectiles, () => this.sprite(tex.arrow), (s, p) => {
      const x = lerp(p.px, p.x), y = lerp(p.py, p.y); const a = p.magic ? tex.orb : tex.arrow; s.texture = a.texture; s.anchor.set(a.ax, a.ay); s.position.set(x, y); s.rotation = p.magic ? 0 : Math.atan2(p.y - p.py, p.x - p.px); s.zIndex = 10000; });
    // hp bars
    const b = this.bars; b.clear();
    const bar = (x: number, y: number, wid: number, f: number, col: number) => { b.rect(x - wid / 2, y, wid, 4).fill({ color: 0x1a0f08, alpha: 0.85 }); b.rect(x - wid / 2 + 1, y + 1, (wid - 2) * Math.max(0, f), 2).fill(col); };
    for (const e of w.enemies) if (e.hp < e.maxHp) bar(lerp(e.px, e.x), lerp(e.py, e.y) - ENEMIES[e.def].radius * 3.4 - 6, 26, e.hp / e.maxHp, 0xe0463a);
    for (const q of w.soldiers) if (q.hp < q.maxHp) bar(lerp(q.px, q.x), lerp(q.py, q.y) - 44, 22, q.hp / q.maxHp, 0x4aa3ff);
    // selection / range
    const u = this.ui; u.clear();
    if (this.selection?.kind === 'slot') { const p = w.map.slots[this.selection.slot]; u.ellipse(p.x, p.y, 40, 20).stroke({ width: 3, color: 0xfff1b8, alpha: 0.9 }); }
    const sel = this.selection;
    if (sel?.kind === 'tower') {
      const q = w.towers.find((x) => x.id === sel.id);
      if (q) { const p = w.map.slots[q.slot]; u.ellipse(p.x, p.y, 40, 20).stroke({ width: 3, color: 0xfff1b8, alpha: 0.9 });
        if (q.kind === 'barracks') { u.circle(p.x, p.y, BARRACKS.rallyRange).fill({ color: 0x4aa3ff, alpha: this.rallyPreview ? 0.14 : 0.06 }).stroke({ width: 2, color: 0x4aa3ff, alpha: 0.5 }); u.circle(q.rally.x, q.rally.y, 9).fill({ color: 0x2f6fd0, alpha: 0.9 }).stroke({ width: 2, color: 0xffffff }); }
        else { const r = SHOOTERS[q.kind].levels[q.level].range; u.circle(p.x, p.y, r).fill({ color: 0xffffff, alpha: 0.07 }).stroke({ width: 2, color: 0xffffff, alpha: 0.45 }); } }
    }
    // particles
    this.fx(events);
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i]; p.life -= dt; if (p.life <= 0) { p.s.visible = false; this.free.push(p.s); this.particles.splice(i, 1); continue; }
      p.vy += p.g * dt; p.s.x += p.vx * dt; p.s.y += p.vy * dt; const k = p.life / p.max; p.s.alpha = k; p.s.scale.set(Math.max(0.05, p.s.scale.x + p.grow * dt));
    }
  }
  get spriteCount(): number { return this.entities.children.length + this.particles.length; }
}
