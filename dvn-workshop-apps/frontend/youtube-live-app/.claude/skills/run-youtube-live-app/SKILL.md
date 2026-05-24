---
name: run-youtube-live-app
description: Install deps, boot `next dev`, smoke-test the home page, take a 1280x800 screenshot of the rendered UI, and tear down — for the youtube-live-app Next.js 14 frontend (dvn-workshop-apps/frontend/youtube-live-app). Use this skill whenever the user asks to run, start, launch, screenshot, preview, or verify the frontend / Next app / youtube-live-app — even if they don't say "run-youtube-live-app". Drives the app via `.claude/skills/run-youtube-live-app/driver.sh`.
---

The youtube-live-app is a Next.js 14 (app router) + TypeScript + Tailwind project. Single page: `src/app/page.tsx`, a customized create-next-app template with a "Workshop DevOps na Nuvem Especial v2" badge in the top-left. That badge string doubles as the smoke-test marker.

**All paths below are relative to this app's root: `dvn-workshop-apps/frontend/youtube-live-app/`.**

## Prerequisites

- Node ≥ 18.17 (Next 14 minimum). Verified on Node 24.14.1.
- macOS Google Chrome at `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` — used in headless mode for screenshots. Override with `CHROME=...` for other paths/browsers.
- Port `3000` free (override with `PORT=...`).
- `curl`, `lsof`.

## Run (agent path) — driver.sh

The driver handles `npm install`, dev-server lifecycle, health-polling, marker validation, screenshot, and teardown.

```bash
# From the app dir:
cd dvn-workshop-apps/frontend/youtube-live-app

# One-shot: install (if needed) → start dev → marker check → screenshot → stop.
.claude/skills/run-youtube-live-app/driver.sh smoke

# Long-lived: start dev and leave it running for manual interaction.
.claude/skills/run-youtube-live-app/driver.sh up

# Just the screenshot (auto-starts dev if not up; writes /tmp/yt-frontend-home.png).
.claude/skills/run-youtube-live-app/driver.sh shot

# Tail dev-server log (in another shell).
.claude/skills/run-youtube-live-app/driver.sh logs

# Stop the dev server (also kills stragglers on PORT via lsof).
.claude/skills/run-youtube-live-app/driver.sh down
```

What `smoke` does on a clean machine (verified end-to-end):

```
[run-fe] starting next dev on :3000
[run-fe] waiting up to 60s for http://localhost:3000/
[run-fe] ✓ home 200 — frontend is up on http://localhost:3000
[run-fe] GET / and check marker
[run-fe] ✓ marker present in HTML
[run-fe] rendering screenshot -> /tmp/yt-frontend-home.png
[run-fe] ✓ screenshot: PNG image data, 1280 x 800, 8-bit/color RGB, non-interlaced — /tmp/yt-frontend-home.png
[run-fe] killed stragglers on :3000 (...)
```

After that, view the screenshot:

```bash
open /tmp/yt-frontend-home.png       # macOS
# or just Read it from an agent — it's a 196 KB PNG.
```

### Env overrides

| Var             | Default                                                            | What it does                              |
|-----------------|--------------------------------------------------------------------|-------------------------------------------|
| `PORT`          | `3000`                                                             | Host port for `next dev`                  |
| `READY_TIMEOUT` | `60`                                                               | Seconds to wait for `/` = 200             |
| `CHROME`        | `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`     | Browser binary for headless screenshot    |
| `SHOT_OUT`      | `/tmp/yt-frontend-home.png`                                        | Where the screenshot is written           |

## Run (human path)

```bash
cd dvn-workshop-apps/frontend/youtube-live-app
npm install
npm run dev          # opens http://localhost:3000 — Ctrl-C to stop.
```

Useless for an agent (foreground, no readiness signal). Use the driver.

## Gotchas

- **First boot of `next dev` is slow.** On cold cache, Next 14 takes ~5 s to print "Ready" and another moment to compile the route on first request. The driver polls up to 60 s by default — bump `READY_TIMEOUT` if your machine is slower.
- **The "marker" check is intentionally narrow.** It greps for the literal string `Workshop DevOps na Nuvem Especial v2` from `src/app/page.tsx`. If you change that badge text, update the `MARKER` variable in `driver.sh`. A green smoke without the marker check would happily pass on any default create-next-app.
- **Headless Chrome prints harmless errors on shutdown.** Lines like `Can't perform OS integration while the browser is shutting down` and `Trying to load the allocator multiple times` are noise from Chrome's quit path — the PNG still gets written. The driver swallows Chrome's stderr.
- **`next dev` leaves stragglers if `kill` isn't precise.** The driver records the backgrounded PID, but Next spawns child workers. On `down`, after killing the tracked PID, it falls back to `lsof -ti tcp:$PORT` and SIGKILLs anything still bound to the port.
- **Chrome runs as the host user, not headless-Linux.** On Linux you'd want `chromium` + `--no-sandbox` (or Playwright). This driver targets the macOS Chrome path; for a different OS, set `CHROME=$(which chromium)` and you're done.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `curl: (7) Failed to connect to localhost port 3000` after `up` | `next dev` died during boot. `tail .next/driver.log` for the real error. Most often: port already used (`PORT=3001 ... up`) or `node_modules` corrupted (`rm -rf node_modules .next && .../driver.sh up`). |
| `Chrome binary not found at: /Applications/...` | Chrome isn't installed at the default path, or you're not on macOS. Set `CHROME=/path/to/chrome` (or Chromium) and re-run. |
| `screenshot file is empty` | Chrome started but couldn't render the page. The page may have a runtime error — open `http://localhost:${PORT}` in a real browser, or check `.next/driver.log` for compile errors. |
| `marker '...' not found in HTML` | `src/app/page.tsx` was edited and the badge text changed. Either restore the marker or update `MARKER=` in `driver.sh`. |
| Stale processes after `down` | `lsof -i :3000` to spot survivors; the driver already runs `lsof -ti tcp:$PORT \| xargs kill -9` as a safety net, so this is rare. |
| `EADDRINUSE :::3000` on boot | Previous run leaked a process. `.../driver.sh down` then retry, or just `PORT=3001 ... up`. |