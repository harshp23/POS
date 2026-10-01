# Client demo video — Proviyaa Restaurant Vendor Panel

A narrated, step-by-step walkthrough (about 2 min 50 s, 1920×1080, 30 fps) built with
[HyperFrames](https://github.com/heygen-com/hyperframes) from real screenshots of the
running local platform (Proviyaa master on :5173, the vendor panel on :8642).

Output: `vendor-panel-demo/renders/vendor-panel-demo.mp4`.

## What is in it

15 scenes, driven by `narration.json` (one entry per scene: id, step, title, spoken text):

1. Intro card
2. Step 1 — onboard the restaurant in Proviyaa master (partners, partner detail, branches + POS logins)
3. Step 2 — the owner signs in (dashboard)
4. Step 3 — build the menu (menu grid, media hub)
5. Step 4 — stock, recipes and suppliers
6. Step 5 — floor plan and tables (dine-in, reservations)
7. Step 6 — kitchen tickets (KOT)
8. Step 7 — billing and payments (POS, takeaway bill)
9. Step 8 — live orders, delivery and online orders
10. Step 9 — works offline (bill settled with the API blocked, then synced)
11. Step 10 — chain view (command center, branch performance, chain inventory)
12. Step 11 — staff and roles
13. Step 12 — each role gets its own panel (branch manager, cashier POS, kitchen display)
14. Step 13 — customers, finance, tasks, integrations
15. Outro card

The screenshots are of the "Latur Spice House" test restaurant (two branches) that
`backend/scripts/latur-full.ts` fills in; see `docs/qa/LATUR-SPICE-HOUSE-FULL-RUN-20260930.md`.

## Pipeline

| Step | Command (from `demo-video/`) | Produces |
| --- | --- | --- |
| 1. Screenshots | `PPT="$(npm root -g)/puppeteer" node capture.cjs` | `shots/01-….png` … `34-….png` (1440×900 at 2×) |
| 2. Voice-over | `powershell -ExecutionPolicy Bypass -File tts.ps1` | `vendor-panel-demo/assets/voice/<scene>.wav` |
| 3. Composition | `node build.cjs` | `vendor-panel-demo/index.html` (+ copies shots to `assets/shots/`) |
| 4. Check | `cd vendor-panel-demo && npx --yes hyperframes@0.8.101 lint` | 0 errors expected (Studio layout warnings are fine) |
| 5. Preview stills | `npx --yes hyperframes@0.8.101 snapshot --at 16,47,105 --no-end --describe false` | `vendor-panel-demo/snapshots/contact-sheet.jpg` |
| 6. Render | `npx --yes hyperframes@0.8.101 render -q looks -w 2 -o renders/vendor-panel-demo.mp4` | the MP4 |

Prerequisites:

- The five local servers from `.claude/launch.json` running: `pos-backend-local` (:8787),
  `web-build-windows` (:8642), `qa-media` (:8643), `master-admin-web` (:5173), `master-admin-api` (:8000).
- Puppeteer installed globally (`npm i -g puppeteer`); `PPT` points at its directory.
- FFmpeg: the project depends on `ffmpeg-static` / `ffprobe-static`. Before `render`, put them on PATH:
  `export PATH="$PWD/node_modules/ffmpeg-static:$PWD/node_modules/ffprobe-static/bin/win32/x64:$PATH"`
  (PowerShell: `$env:PATH = "$pwd\node_modules\ffmpeg-static;$pwd\node_modules\ffprobe-static\bin\win32\x64;" + $env:PATH`).
- Voice: Windows "Microsoft Zira Desktop" via System.Speech (no network). Swap `tts.ps1` for any
  TTS that writes `assets/voice/<id>.wav`; `build.cjs` times the scenes from the WAV lengths.
- Logins are read from `backend/.data/laturspice-accounts.txt` and `backend/.data/LOGINS.txt`
  (git-ignored, local test accounts only). Nothing in the video is from the live database.
- Rendering launches one Chrome per worker (~256 MB each); on this 8 GB machine use `-w 2`.

Re-capturing only the master-admin shots: `ONLY=master PPT=... node capture.cjs` (keeps the other 31).

## Changing the video

- Script / wording: edit `narration.json`, re-run steps 2–6.
- Which screenshots a scene shows: the `IMAGES` map at the top of `build.cjs` (names are the
  shot file names without their number prefix).
- Look and motion: the CSS and GSAP lines in `build.cjs` (brand colours, caption, the slow
  top-to-bottom pan over each 16:10 screenshot, crossfades, progress bar).
- New screens: add a `snap(page, 'name')` in `capture.cjs`, then reference `'name'` in `IMAGES`.
