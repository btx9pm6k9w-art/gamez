import { GameRenderer, type Selection } from './render/renderer';
import { addEnemy, applyCommands, createWorld, DT, maxLevel, step, towerCost, type Command, type SimEvent, type World } from './sim/world';
import { MAP_FARMLANDS, SELL_REFUND, type TowerKind } from './sim/data';

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
type Mode = 'normal' | 'rally' | 'reinforce';

class Game {
  world: World; renderer!: GameRenderer; sel: Selection = null; mode: Mode = 'normal'; speed = 1; paused = false; acc = 0; last = performance.now();
  bench: { n: number; until: number; frames: number[]; sim: number[]; started: number } | null = null; pending: Command[] = []; journal: { tick: number; cmd: Command }[] = []; seed = 1; frames: number[] = []; simMs = 0; perfTick = 0; showPerf = true;
  constructor() { this.world = createWorld(this.seed); }

  async init(): Promise<void> {
    this.renderer = await GameRenderer.create($('app'), MAP_FARMLANDS);
    addEventListener('resize', () => this.renderer.resize($('app').clientWidth, $('app').clientHeight));
    const cv = this.renderer.app.canvas; cv.addEventListener('pointerdown', (e) => this.click(e)); cv.addEventListener('pointermove', (e) => { this.renderer.hover = this.renderer.toWorld(e.clientX, e.clientY); });
    addEventListener('keydown', (e) => this.key(e));
    $('btnCall').onclick = () => this.exec({ type: 'callWave' }); $('btnPause').onclick = () => this.togglePause(); $('btnSpeed').onclick = () => this.cycleSpeed();
    $('btnReinf').onclick = () => this.setMode(this.mode === 'reinforce' ? 'normal' : 'reinforce');
    requestAnimationFrame((t) => this.frame(t));
  }

  exec(cmd: Command): void { this.pending.push(cmd); this.journal.push({ tick: this.world.tick, cmd }); }
  restart(): void { this.seed++; this.world = createWorld(this.seed); this.sel = null; this.mode = 'normal'; this.journal = []; this.pending = []; this.renderer.selection = null; $('banner').style.display = 'none'; this.refreshMenu(); }
  togglePause(): void { this.paused = !this.paused; $('btnPause').classList.toggle('on', this.paused); }
  cycleSpeed(): void { this.speed = this.speed === 1 ? 2 : this.speed === 2 ? 3 : 1; $('btnSpeed').textContent = `${this.speed}×`; }
  setMode(m: Mode): void { this.mode = m; this.renderer.rallyPreview = m === 'rally'; $('btnReinf').classList.toggle('on', m === 'reinforce');
    const h = $('hint'); h.style.display = m === 'normal' ? 'none' : 'block'; h.textContent = m === 'reinforce' ? 'Click on the road to call reinforcements (Esc to cancel)' : 'Click inside the blue circle to set the rally point (Esc to cancel)'; }

  key(e: KeyboardEvent): void {
    if (e.repeat) return; const k = e.key.toLowerCase();
    if (k === ' ') { e.preventDefault(); this.exec({ type: 'callWave' }); } else if (k === 'p') this.togglePause(); else if (k === 'f') this.cycleSpeed();
    else if (k === '1') this.setMode(this.mode === 'reinforce' ? 'normal' : 'reinforce'); else if (k === 'b') this.startBench(400); else if (k === 'escape') { this.setMode('normal'); this.select(null); } else if (k === 'f3') { this.showPerf = !this.showPerf; $('perf').style.display = this.showPerf ? 'block' : 'none'; }
  }

  select(s: Selection): void { this.sel = s; this.renderer.selection = s; this.refreshMenu(); }
  click(e: PointerEvent): void {
    const p = this.renderer.toWorld(e.clientX, e.clientY); const w = this.world;
    if (this.mode === 'reinforce') { this.exec({ type: 'reinforce', x: p.x, y: p.y }); this.setMode('normal'); return; }
    if (this.mode === 'rally' && this.sel?.kind === 'tower') { this.exec({ type: 'rally', tower: this.sel.id, x: p.x, y: p.y }); this.setMode('normal'); return; }
    const near = (q: { x: number; y: number }) => Math.hypot(q.x - p.x, (q.y - p.y) * 1.6) < 42;
    const t = w.towers.find((q) => near(w.map.slots[q.slot])); if (t) { this.select({ kind: 'tower', id: t.id }); return; }
    const si = w.map.slots.findIndex((q, i) => near(q) && !w.towers.some((x) => x.slot === i)); this.select(si >= 0 ? { kind: 'slot', slot: si } : null);
  }

  refreshMenu(): void {
    const m = $('menu'); const w = this.world; m.innerHTML = ''; if (!this.sel) { m.style.display = 'none'; return; }
    const btn = (label: string, cost: string, enabled: boolean, fn: () => void) => { const b = document.createElement('button'); b.innerHTML = `<span>${label}</span><span class="gold">${cost}</span>`; b.disabled = !enabled; b.onclick = (ev) => { ev.stopPropagation(); fn(); }; m.appendChild(b); };
    const title = (t: string) => { const d = document.createElement('div'); d.className = 'title'; d.textContent = t; m.appendChild(d); };
    if (this.sel.kind === 'slot') {
      const slot = this.sel.slot; title('Build'); (['archer', 'barracks', 'mage'] as TowerKind[]).forEach((k) => { const c = towerCost(k, 0); btn(k[0].toUpperCase() + k.slice(1), `${c}`, w.gold >= c, () => { this.exec({ type: 'build', slot, kind: k }); this.select(null); }); });
      const p = w.map.slots[slot]; this.placeMenu(p.x, p.y - 30);
    } else {
      const id = this.sel.id; const t = w.towers.find((q) => q.id === id); if (!t) { m.style.display = 'none'; return; }
      title(`${t.kind[0].toUpperCase() + t.kind.slice(1)}  L${t.level + 1}`);
      if (t.level < maxLevel(t.kind)) { const c = towerCost(t.kind, t.level + 1); btn('Upgrade', `${c}`, w.gold >= c, () => this.exec({ type: 'upgrade', tower: id })); } else title('Max level');
      if (t.kind === 'barracks') btn('Set rally', '', true, () => this.setMode('rally'));
      btn('Sell', `+${Math.floor(t.spent * SELL_REFUND)}`, true, () => { this.exec({ type: 'sell', tower: id }); this.select(null); });
      const p = w.map.slots[t.slot]; this.placeMenu(p.x, p.y - 70);
    }
  }
  placeMenu(wx: number, wy: number): void { const m = $('menu'); const s = this.renderer.toScreen(wx, wy); m.style.display = 'flex'; m.style.left = `${s.x}px`; m.style.top = `${s.y}px`; }

  hud(): void {
    const w = this.world; $('gold').textContent = String(Math.floor(w.gold)); $('lives').textContent = String(w.lives);
    $('wave').textContent = `${Math.min(w.waveIndex, w.map.waves.length)}/${w.map.waves.length}`;
    const canCall = w.status === 'playing' && w.waveIndex < w.map.waves.length && w.waveTimer > 0 && w.waveTimer !== Infinity;
    $('timer').textContent = canCall ? `Next in ${Math.ceil(w.waveTimer)}s` : ''; ($('btnCall') as HTMLButtonElement).disabled = !canCall; $('btnCall').textContent = canCall ? `Call wave +${Math.ceil(w.waveTimer)}g [Space]` : 'Call wave [Space]';
    const rc = $('btnReinf') as HTMLButtonElement; rc.textContent = w.reinforceCd > 0 ? `Reinforce ${Math.ceil(w.reinforceCd)}s` : 'Reinforce [1]'; rc.disabled = w.reinforceCd > 0;
    const b = $('banner'); if (w.status !== 'playing') { b.style.display = 'flex'; b.innerHTML = `${w.status === 'won' ? 'Victory!' : 'Defeat'}<div style="font-size:16px">Lives left ${w.lives} · Kills ${w.kills}</div><button id="again">Play again</button>`; ($('again') as HTMLButtonElement).onclick = () => this.restart(); }
    if (this.sel) this.refreshMenu();
  }

  /** 15 s stress test at 1x real time: many unkillable enemies + max towers + soldiers. Press B. Results in banner + console + window.__benchResult. */
  startBench(n: number): void {
    this.seed = 99; this.world = createWorld(99); const w = this.world; w.gold = 1e7; w.lives = 1e9; w.waveTimer = Infinity; this.sel = null; this.renderer.selection = null; this.refreshMenu();
    const kinds: TowerKind[] = ['barracks', 'archer', 'mage', 'archer', 'barracks', 'mage', 'archer', 'mage', 'archer'];
    w.map.slots.forEach((_, i) => { this.pending.push({ type: 'build', slot: i, kind: kinds[i % kinds.length] }); }); step(w, this.pending.splice(0));
    for (let r = 0; r < 2; r++) for (const t of w.towers) step(w, [{ type: 'upgrade', tower: t.id }]);
    this.paused = false; this.speed = 1; this.acc = 0; this.bench = { n, until: performance.now() + 15000, frames: [], sim: [], started: performance.now() };
    $('banner').style.display = 'none';
  }
  benchTick(ft: number, simMs: number): void {
    const b = this.bench; if (!b) return; const w = this.world;
    while (w.enemies.length < b.n) addEnemy(w, ['goblin', 'orc', 'wolf'][(w.rng.next() * 3) | 0] as 'goblin', 1e9, w.rng.next() * 40);
    w.lives = 1e9; b.frames.push(ft * 1000); b.sim.push(simMs);
    if (performance.now() > b.until) {
      const f = [...b.frames].sort((a, c) => a - c).slice(Math.floor(b.frames.length * 0.05)); const q = (p: number) => f[Math.min(f.length - 1, Math.floor(f.length * p))]; const avg = f.reduce((a, c) => a + c, 0) / f.length;
      const res = { backend: this.renderer.backend, dpr: devicePixelRatio, canvas: `${this.renderer.app.canvas.width}x${this.renderer.app.canvas.height}`, enemies: w.enemies.length, soldiers: w.soldiers.length, projectiles: w.projectiles.length, sprites: this.renderer.spriteCount,
        fpsAvg: +(1000 / avg).toFixed(1), msAvg: +avg.toFixed(2), msP50: +q(0.5).toFixed(2), msP95: +q(0.95).toFixed(2), msP99: +q(0.99).toFixed(2), msMax: +f[f.length - 1].toFixed(2), simMsPerStep: +(b.sim.filter((x) => x > 0).reduce((a, c) => a + c, 0) / Math.max(1, b.sim.filter((x) => x > 0).length)).toFixed(3), frames: b.frames.length, target120: q(0.99) <= 8.4 ? 'PASS (p99<=8.4ms)' : 'FAIL (p99>8.4ms)' };
      (window as unknown as { __benchResult: unknown }).__benchResult = res; console.log('BENCH', JSON.stringify(res)); this.bench = null; this.restart();
      const bn = $('banner'); bn.style.display = 'flex'; bn.innerHTML = `<div>Benchmark</div><pre style="font-size:15px;text-align:left;margin:0">${JSON.stringify(res, null, 1)}</pre><div style="font-size:14px">Send me this result. Click to close.</div>`; bn.onclick = () => { bn.style.display = 'none'; bn.onclick = null; };
    }
  }

  perfText(): string {
    const f = this.frames.slice(-240); if (!f.length) return ''; const avg = f.reduce((a, b) => a + b, 0) / f.length; const sorted = [...f].sort((a, b) => a - b); const p99 = sorted[Math.floor(sorted.length * 0.99)] ?? avg;
    return `${this.renderer.backend}  ${(1000 / avg).toFixed(0)} fps\nframe ${avg.toFixed(2)} ms  p99 ${p99.toFixed(2)} ms\nsim ${this.simMs.toFixed(2)} ms/step  sprites ${this.renderer.spriteCount}\nenemies ${this.world.enemies.length}  soldiers ${this.world.soldiers.length}`;
  }

  advance(seconds: number, render = true): void { // deterministic stepping for tests/tools
    const evs: SimEvent[] = []; for (let i = 0; i < seconds / DT; i++) { step(this.world, this.pending.splice(0)); evs.push(...this.world.events); }
    if (render) { const recent = evs.slice(-12); this.renderer.update(this.world, 0, recent, this.world.time, 0.016); this.hud(); } // only the latest events spawn FX (avoid replaying minutes of effects)
  }

  frame(now: number): void {
    const ft = (now - this.last) / 1000; this.last = now; this.frames.push(ft * 1000); if (this.frames.length > 600) this.frames.shift();
    const evs: SimEvent[] = []; const t0 = performance.now(); let steps = 0;
    if (this.paused) { if (this.pending.length) applyCommands(this.world, this.pending.splice(0)); }
    else { this.acc += Math.min(ft, 0.1) * this.speed; let n = 0; while (this.acc >= DT && n < 12) { step(this.world, this.pending.splice(0)); evs.push(...this.world.events); this.acc -= DT; n++; } steps = n; }
    const sm = steps ? (performance.now() - t0) / steps : 0; if (steps) this.simMs = this.simMs * 0.9 + sm * 0.1; this.benchTick(ft, sm); // ms per sim STEP (not per frame)
    this.renderer.update(this.world, this.paused ? 0 : this.acc / DT, evs, this.world.time, Math.min(ft, 0.05) * (this.paused ? 0 : 1));
    this.hud(); if (this.showPerf && ++this.perfTick % 15 === 0) $('perf').textContent = this.perfText();
    requestAnimationFrame((t) => this.frame(t));
  }
}

const game = new Game();
game.init().then(() => { (window as unknown as { __game: Game }).__game = game; document.documentElement.dataset.ready = '1'; });
