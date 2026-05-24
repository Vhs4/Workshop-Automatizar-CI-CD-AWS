#!/usr/bin/env bash
# Driver for the youtube-live-app Next.js 14 frontend.
# Boots `next dev` in the background, polls until the home page returns 200,
# takes a 1280x800 screenshot via headless Google Chrome, validates a known
# marker string in the HTML, and tears down.
#
# Usage (from this app dir, dvn-workshop-apps/frontend/youtube-live-app/):
#   .claude/skills/run-youtube-live-app/driver.sh up         # start + wait for 200
#   .claude/skills/run-youtube-live-app/driver.sh smoke      # up + html marker + screenshot + down
#   .claude/skills/run-youtube-live-app/driver.sh shot [OUT] # up + screenshot to OUT + leave running
#   .claude/skills/run-youtube-live-app/driver.sh logs       # tail dev-server log
#   .claude/skills/run-youtube-live-app/driver.sh down       # stop dev server
#
# Env overrides:
#   PORT (default 3000), CHROME (default macOS Chrome path),
#   READY_TIMEOUT (default 60s), SHOT_OUT (default /tmp/yt-frontend-home.png).

set -euo pipefail

PORT="${PORT:-3000}"
READY_TIMEOUT="${READY_TIMEOUT:-60}"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
SHOT_OUT="${SHOT_OUT:-/tmp/yt-frontend-home.png}"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PID_FILE="${APP_DIR}/.next/driver.pid"
LOG_FILE="${APP_DIR}/.next/driver.log"
MARKER="Workshop DevOps na Nuvem Especial v2"

log()  { printf '\033[36m[run-fe]\033[0m %s\n' "$*"; }
fail() { printf '\033[31m[run-fe]\033[0m %s\n' "$*" >&2; exit 1; }

ensure_deps() {
  if [ ! -d "$APP_DIR/node_modules" ]; then
    log "node_modules missing — running npm install (may take ~1 min)"
    (cd "$APP_DIR" && npm install --no-audit --no-fund)
  fi
}

up() {
  ensure_deps
  mkdir -p "$APP_DIR/.next"
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    log "dev server already running (PID $(cat "$PID_FILE"))"
  else
    log "starting next dev on :${PORT}"
    ( cd "$APP_DIR" && PORT="$PORT" nohup npx next dev -p "$PORT" >"$LOG_FILE" 2>&1 & echo $! >"$PID_FILE" )
  fi

  log "waiting up to ${READY_TIMEOUT}s for http://localhost:${PORT}/"
  local deadline=$(( $(date +%s) + READY_TIMEOUT ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    if [ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/" 2>/dev/null)" = "200" ]; then
      log "✓ home 200 — frontend is up on http://localhost:${PORT}"
      return 0
    fi
    if [ -f "$PID_FILE" ] && ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      log "dev server died — last log:"
      tail -20 "$LOG_FILE" || true
      fail "next dev exited before serving"
    fi
    sleep 1
  done
  log "timeout — last log:"
  tail -20 "$LOG_FILE" || true
  fail "home page did not reach 200 within ${READY_TIMEOUT}s"
}

shot() {
  local out="${1:-$SHOT_OUT}"
  up
  [ -x "$CHROME" ] || fail "Chrome binary not found at: $CHROME (set CHROME=... to override)"
  log "rendering screenshot -> ${out}"
  "$CHROME" \
    --headless=new --disable-gpu --no-sandbox --hide-scrollbars \
    --window-size=1280,800 \
    --screenshot="$out" \
    "http://localhost:${PORT}/" >/dev/null 2>&1 || true
  [ -s "$out" ] || fail "screenshot file is empty: $out"
  log "✓ screenshot: $(file "$out" | sed 's/.*: //') — $out"
}

smoke() {
  up
  log "GET / and check marker"
  local html
  html=$(curl -fsS "http://localhost:${PORT}/")
  printf '%s' "$html" | grep -qF "$MARKER" || fail "expected marker '$MARKER' not found in HTML"
  log "✓ marker present in HTML"
  shot "$SHOT_OUT"
  down
}

logs() { tail -f "$LOG_FILE"; }

down() {
  if [ -f "$PID_FILE" ]; then
    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
      log "✓ stopped dev server (PID $pid)"
    fi
    rm -f "$PID_FILE"
  else
    log "no dev server pidfile to stop"
  fi
  # belt-and-suspenders: any leftover next-server on PORT
  if command -v lsof >/dev/null 2>&1; then
    local lp
    lp=$(lsof -ti tcp:"$PORT" 2>/dev/null || true)
    [ -n "$lp" ] && { kill -9 $lp 2>/dev/null || true; log "killed stragglers on :$PORT ($lp)"; }
  fi
}

case "${1:-smoke}" in
  up)    up ;;
  smoke) smoke ;;
  shot)  shift; shot "${1:-}" ;;
  logs)  logs ;;
  down)  down ;;
  *)     fail "unknown command: ${1}  (use up | smoke | shot [OUT] | logs | down)" ;;
esac
