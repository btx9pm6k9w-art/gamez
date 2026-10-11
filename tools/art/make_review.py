#!/usr/bin/env python3
"""Build assets/ai/_candidates/review.html: contact sheet to pick the best candidate per asset.
Open it in a browser; click a thumbnail to mark it approved; 'Copy approvals' gives a JSON list."""
import json, os, glob, html
base = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ai", "_candidates"))
rows = []
for d in sorted(p for p in glob.glob(os.path.join(base, "*")) if os.path.isdir(p)):
    aid = os.path.basename(d); cells = []
    for img in sorted(glob.glob(os.path.join(d, "*.*"))):
        if img.endswith(".json"): continue
        rel = os.path.relpath(img, base); meta = img.rsplit(".", 1)[0] + ".json"
        m = json.load(open(meta)) if os.path.exists(meta) else {}
        cells.append(f'<figure data-id="{html.escape(aid)}" data-file="{html.escape(rel)}"><img src="{html.escape(rel)}" loading="lazy"><figcaption>{html.escape(str(m.get("model","")))} · seed {m.get("seed","")}</figcaption></figure>')
    rows.append(f'<section><h2>{html.escape(aid)}</h2><div class="row">{"".join(cells)}</div></section>')
page = """<!doctype html><meta charset=utf-8><title>Art review</title>
<style>body{font:14px system-ui;background:#1b1b1f;color:#eee;margin:16px}h2{margin:18px 0 6px}.row{display:flex;gap:10px;flex-wrap:wrap}
figure{margin:0;width:260px;cursor:pointer;border:3px solid transparent;border-radius:8px;padding:4px;background:#2a2a30}figure.on{border-color:#6f6}
img{width:100%;background:#888;border-radius:4px}figcaption{font-size:11px;opacity:.7}button{padding:8px 14px;margin:8px 0}</style>
<button onclick="copy()">Copy approvals</button><pre id=o></pre>""" + "".join(rows) + """
<script>const S=new Set(JSON.parse(localStorage.ap||'[]'));
document.querySelectorAll('figure').forEach(f=>{if(S.has(f.dataset.file))f.classList.add('on');f.onclick=()=>{f.classList.toggle('on');
f.classList.contains('on')?S.add(f.dataset.file):S.delete(f.dataset.file);localStorage.ap=JSON.stringify([...S])}});
function copy(){const t=JSON.stringify([...S],null,1);o.textContent=t;navigator.clipboard&&navigator.clipboard.writeText(t)}</script>"""
open(os.path.join(base, "review.html"), "w").write(page); print("wrote", os.path.join(base, "review.html"))
