// Headless render check: builds are served by `vite preview`; drives a scripted game and saves screenshots.
// Software GL only (no GPU in CI) — good for visual/logic verification, NOT for performance numbers.
import { chromium } from 'playwright-core';
import { spawn } from 'node:child_process';
import { mkdirSync, readdirSync, existsSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const out = process.argv[2] || 'screenshots'; mkdirSync(out, { recursive: true });
const base = process.env.PW_BROWSERS_PATH || '/opt/pw-browsers';
const dir = readdirSync(base).filter((d) => /^chromium-\d+$/.test(d)).sort().pop();
const exe = [join(base, dir, 'chrome-linux', 'chrome'), join(base, dir, 'chrome-linux64', 'chrome')].find(existsSync);
const srv = spawn('npx', ['vite', 'preview', '--port', '4173', '--strictPort'], { stdio: 'ignore' });
await new Promise((r) => setTimeout(r, 2500));
const browser = await chromium.launch({ executablePath: exe, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-unsafe-webgpu', '--no-sandbox', '--disable-gpu-compositing', '--disable-features=VizDisplayCompositor'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
async function shot(name) { // page.screenshot fails on WebGPU canvases in headless; fall back to Pixi's own extractor
  try { await page.screenshot({ path: join(out, name), timeout: 15000 }); }
  catch { const b64 = await page.evaluate(async () => { const g = window.__game; return (await g.renderer.app.renderer.extract.base64(g.renderer.app.stage)); }); writeFileSync(join(out, name), Buffer.from(b64.split(',')[1], 'base64')); console.log('(extract fallback)', name); }
}
const errors = []; page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') errors.push(`[${m.type()}] ${m.text()}`); }); page.on('pageerror', (e) => errors.push(`[pageerror] ${e.message}`));
const rend = process.env.RENDERER || 'webgl';
await page.goto(`http://localhost:4173/?renderer=${rend}`, { waitUntil: 'load' });
await page.waitForSelector('html[data-ready="1"]', { timeout: 60000 });
const backend = await page.evaluate(() => window.__game.renderer.backend); console.log('backend:', backend);
await page.evaluate(() => { const g = window.__game; g.paused = true; g.exec({ type: 'build', slot: 1, kind: 'barracks' }); g.exec({ type: 'build', slot: 2, kind: 'archer' }); g.exec({ type: 'build', slot: 3, kind: 'mage' }); g.advance(0.1); });
await shot('01_built.png');
await page.evaluate(() => { const g = window.__game; g.advance(32); });
await shot('02_wave1.png');
await page.evaluate(() => { const g = window.__game; g.exec({ type: 'upgrade', tower: g.world.towers[1].id }); g.exec({ type: 'build', slot: 0, kind: 'archer' }); g.exec({ type: 'build', slot: 4, kind: 'barracks' }); g.advance(40); g.select({ kind: 'tower', id: g.world.towers[0].id }); g.advance(0.05); });
await shot('03_wave2_selected.png');
const st = await page.evaluate(() => { const w = window.__game.world; return { t: +w.time.toFixed(1), gold: Math.floor(w.gold), lives: w.lives, wave: w.waveIndex, enemies: w.enemies.length, soldiers: w.soldiers.length, towers: w.towers.length }; });
console.log('state:', JSON.stringify(st)); console.log('errors:', errors.length ? '\n' + errors.slice(0, 12).join('\n') : 'none');
await browser.close(); srv.kill();
