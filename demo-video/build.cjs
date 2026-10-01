// Builds vendor-panel-demo/index.html from narration.json, the voice-over
// WAV lengths and the captured screenshots.   node build.cjs
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const proj = path.join(__dirname, 'vendor-panel-demo');
const ffprobe = require(path.join(proj, 'node_modules', 'ffprobe-static')).path;
const scenes = JSON.parse(fs.readFileSync(path.join(__dirname, 'narration.json'), 'utf8'));
const shotsDir = path.join(__dirname, 'shots');
const assets = path.join(proj, 'assets', 'shots');
fs.mkdirSync(assets, { recursive: true });

// which screenshots each scene shows, in order (stable names; numbers stripped)
const IMAGES = {
  intro: ['owner-dashboard'],
  master: ['master-partners', 'master-branches-logins'],
  signin: ['owner-dashboard'],
  menu: ['menu-grid', 'media'],
  stock: ['inventory', 'recipes', 'suppliers'],
  tables: ['dine-in', 'reservations'],
  kot: ['kot'],
  billing: ['pos-billing', 'pos-offline-bill'],
  live: ['live-operations', 'delivery', 'online-orders'],
  offline: ['pos-offline-settled', 'pos-synced'],
  chain: ['command-center', 'branch-performance', 'chain-inventory'],
  staff: ['staff-directory', 'roles'],
  roles: ['manager-dashboard', 'cashier-pos', 'kitchen-kds'],
  business: ['crm', 'finance', 'tasks', 'integrations'],
  outro: ['command-center'],
};

// copy shots under stable names
const available = new Set();
for (const f of fs.readdirSync(shotsDir)) {
  const m = f.match(/^\d+-(.+)\.png$/);
  if (!m) continue;
  fs.copyFileSync(path.join(shotsDir, f), path.join(assets, `${m[1]}.png`));
  available.add(m[1]);
}
const dur = (file) => Number(execFileSync(ffprobe, ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', file]).toString().trim());

const GAP = 0.9; // breath after each narration
// shots are 2880×1800 (16:10); shown at frame width 1776 they are 1110 tall, 350 more than the 760 frame
const FRAME_W = 1776, FRAME_H = 760;
const PAN = Math.round(FRAME_W * 1800 / 2880 - FRAME_H);
let t = 0.6;
const timeline = scenes.map((s) => {
  const voice = path.join(proj, 'assets', 'voice', `${s.id}.wav`);
  const v = dur(voice);
  const d = Math.max(v + GAP, s.id === 'intro' || s.id === 'outro' ? v + 1.6 : 0);
  const images = (IMAGES[s.id] ?? []).filter((n) => available.has(n));
  const out = { ...s, start: t, duration: d, voice: v, images };
  t += d;
  return out;
});
const total = Math.ceil(t + 0.5);

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const sceneHtml = timeline
  .map((s, i) => {
    const isCard = s.id === 'intro' || s.id === 'outro';
    const n = s.images.length || 1;
    const per = s.duration / n;
    const imgs = s.images
      .map((img, k) => `      <div class="clip shotwrap" id="s${i}i${k}" data-start="${(s.start + k * per).toFixed(2)}" data-duration="${per.toFixed(2)}"><img class="shot" src="assets/shots/${img}.png" alt=""></div>`)
      .join('\n');
    return `
    <section class="clip scene ${isCard ? 'card' : ''}" id="s${i}" data-start="${s.start.toFixed(2)}" data-duration="${s.duration.toFixed(2)}" data-track-index="0">
      <div class="brand"><span class="dot"></span>Proviyaa · Restaurant Vendor Panel</div>
      ${isCard ? `<div class="hero"><h1>${esc(s.title)}</h1><p>${esc(s.subtitle ?? '')}</p></div>` : `
      <div class="caption"><div class="step">${esc(s.step ?? '')}</div><h2>${esc(s.title)}</h2></div>
      <div class="frame">${imgs}</div>`}
      <div class="progress"><div class="bar" id="p${i}"></div></div>
      <div class="counter">${i === 0 || i === timeline.length - 1 ? '' : `${esc(s.step)} of 13`}</div>
    </section>
    <audio id="v${i}" data-start="${s.start.toFixed(2)}" data-duration="${s.voice.toFixed(2)}" data-track-index="1" data-volume="1" src="assets/voice/${s.id}.wav"></audio>`;
  })
  .join('\n');

const anim = timeline
  .map((s, i) => {
    const lines = [
      `tl.fromTo("#s${i} .brand", {opacity:0, y:-10}, {opacity:1, y:0, duration:0.5}, ${s.start.toFixed(2)});`,
      `tl.fromTo("#p${i}", {scaleX:0}, {scaleX:1, duration:${s.duration.toFixed(2)}, ease:"none"}, ${s.start.toFixed(2)});`,
    ];
    if (s.id === 'intro' || s.id === 'outro') {
      lines.push(`tl.fromTo("#s${i} h1", {opacity:0, y:30}, {opacity:1, y:0, duration:0.9, ease:"power3.out"}, ${(s.start + 0.2).toFixed(2)});`);
      lines.push(`tl.fromTo("#s${i} .hero p", {opacity:0, y:20}, {opacity:1, y:0, duration:0.8, ease:"power3.out"}, ${(s.start + 0.7).toFixed(2)});`);
    } else {
      lines.push(`tl.fromTo("#s${i} .step", {opacity:0, x:-20}, {opacity:1, x:0, duration:0.5}, ${(s.start + 0.1).toFixed(2)});`);
      lines.push(`tl.fromTo("#s${i} h2", {opacity:0, x:-20}, {opacity:1, x:0, duration:0.6}, ${(s.start + 0.25).toFixed(2)});`);
      const n = s.images.length || 1;
      const per = s.duration / n;
      s.images.forEach((_, k) => {
        const st = s.start + k * per;
        lines.push(`tl.fromTo("#s${i}i${k}", {opacity:0, y:24, scale:0.985}, {opacity:1, y:0, scale:1, duration:0.6, ease:"power2.out"}, ${st.toFixed(2)});`);
        // the 16:10 screenshot is wider than the frame is tall: hold on the top, then pan down to reveal the rest
        const panFor = Math.max(per - 1.4, 1.5);
        lines.push(`tl.fromTo("#s${i}i${k} .shot", {y:0}, {y:-${PAN}, duration:${panFor.toFixed(2)}, ease:"sine.inOut"}, ${(st + 0.8).toFixed(2)});`);
      });
    }
    lines.push(`tl.to("#s${i}", {opacity:0, duration:0.35}, ${(s.start + s.duration - 0.35).toFixed(2)});`);
    return lines.join('\n      ');
  })
  .join('\n      ');

const html = `<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=1920, height=1080" />
    <script src="https://cdn.jsdelivr.net/npm/gsap@3.14.2/dist/gsap.min.js"></script>
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      html, body { width: 1920px; height: 1080px; overflow: hidden; background: #0b1410; font-family: Inter, "Segoe UI", ui-sans-serif, system-ui, sans-serif; color: #f4f7f5; }
      #root { position: relative; width: 1920px; height: 1080px; background: radial-gradient(1200px 700px at 20% 10%, #16352a 0%, #0b1410 60%); }
      .scene { position: absolute; inset: 0; }
      .brand { position: absolute; top: 44px; left: 72px; font-size: 24px; font-weight: 600; letter-spacing: 0.01em; color: #cfe9d9; display: flex; align-items: center; gap: 12px; }
      .brand .dot { width: 14px; height: 14px; border-radius: 50%; background: #65d000; box-shadow: 0 0 18px #65d000aa; display: inline-block; }
      .caption { position: absolute; top: 108px; left: 72px; width: 1776px; }
      .step { font-size: 22px; font-weight: 700; letter-spacing: 0.18em; text-transform: uppercase; color: #8fe05a; margin-bottom: 8px; }
      h2 { font-size: 52px; font-weight: 700; letter-spacing: -0.02em; line-height: 1.1; }
      .frame { position: absolute; top: 230px; left: 72px; width: 1776px; height: 760px; }
      .shotwrap { position: absolute; inset: 0; border-radius: 18px; overflow: hidden; box-shadow: 0 30px 80px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,255,255,0.08); background: #fff; }
      .shot { width: 100%; height: auto; display: block; }
      .card .hero { position: absolute; left: 72px; top: 380px; width: 1776px; }
      .card h1 { font-size: 92px; font-weight: 800; letter-spacing: -0.03em; line-height: 1.05; max-width: 1500px; }
      .card .hero p { margin-top: 26px; font-size: 36px; color: #b9d6c6; font-weight: 400; }
      .progress { position: absolute; left: 72px; right: 72px; bottom: 36px; height: 6px; background: rgba(255,255,255,0.12); border-radius: 3px; overflow: hidden; }
      .bar { width: 100%; height: 100%; background: #65d000; transform-origin: left center; }
      .counter { position: absolute; right: 72px; top: 48px; font-size: 20px; color: #9fbfae; font-weight: 500; }
    </style>
  </head>
  <body>
    <div id="root" data-composition-id="main" data-start="0" data-duration="${total}" data-width="1920" data-height="1080">
${sceneHtml}
    </div>
    <script>
      const tl = gsap.timeline({ paused: true });
      ${anim}
      window.__timelines = window.__timelines || {};
      window.__timelines["main"] = tl;
      tl.seek(0);
    </script>
  </body>
</html>
`;
fs.writeFileSync(path.join(proj, 'index.html'), html);
console.log(`index.html: ${timeline.length} scenes, ${total}s, images missing:`, timeline.flatMap((s) => (IMAGES[s.id] ?? []).filter((n) => !available.has(n))).join(', ') || 'none');
console.log(timeline.map((s) => `${s.id}@${s.start.toFixed(1)}s/${s.duration.toFixed(1)}s`).join(' '));
