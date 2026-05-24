#!/usr/bin/env bash
# Driver for the YoutubeLiveApp .NET 8 backend.
# Runs the app inside a dotnet/sdk:8.0 container, polls health, optionally
# hits the /backend/WeatherForecast endpoint, and tears down.
#
# Usage (from this app dir, dvn-workshop-apps/backend/YoutubeLiveApp/):
#   .claude/skills/run-youtubeliveapp/driver.sh up        # start + wait for health
#   .claude/skills/run-youtubeliveapp/driver.sh smoke     # up + hit WeatherForecast + down
#   .claude/skills/run-youtubeliveapp/driver.sh logs      # tail logs of running container
#   .claude/skills/run-youtubeliveapp/driver.sh down      # stop & remove container
#
# Env overrides:
#   HOST_PORT (default 5118), CONTAINER_NAME (default workshop-backend),
#   IMAGE (default mcr.microsoft.com/dotnet/sdk:8.0), HEALTH_TIMEOUT (default 90s).

set -euo pipefail

HOST_PORT="${HOST_PORT:-5118}"
CONTAINER_NAME="${CONTAINER_NAME:-workshop-backend}"
IMAGE="${IMAGE:-mcr.microsoft.com/dotnet/sdk:8.0}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-90}"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

log()  { printf '\033[36m[run-yt]\033[0m %s\n' "$*"; }
fail() { printf '\033[31m[run-yt]\033[0m %s\n' "$*" >&2; exit 1; }

cleanup_appledouble() {
  # macOS on non-APFS volumes (eg this PortableSSD) creates ._* AppleDouble
  # files for every source file. When the host dir is bind-mounted into the
  # Linux container, csc tries to compile them and aborts. They are gitignored
  # metadata — safe to delete.
  local n
  n=$(find "$APP_DIR" -name "._*" -print -delete 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" -gt 0 ] && log "stripped $n AppleDouble (._*) files from $APP_DIR"
  return 0
}

up() {
  cleanup_appledouble
  if docker ps --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q .; then
    log "container '${CONTAINER_NAME}' already running"
  else
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    log "starting ${IMAGE} -> ${CONTAINER_NAME} (host:${HOST_PORT} -> container:8080)"
    docker run -d \
      --name "$CONTAINER_NAME" \
      -v "$APP_DIR":/src \
      -w /src \
      -p "${HOST_PORT}:8080" \
      -e ASPNETCORE_URLS=http://+:8080 \
      -e ASPNETCORE_ENVIRONMENT=Development \
      "$IMAGE" \
      dotnet run --project YoutubeLiveApp.csproj --no-launch-profile >/dev/null
  fi

  log "waiting up to ${HEALTH_TIMEOUT}s for http://localhost:${HOST_PORT}/backend/health"
  local deadline=$(( $(date +%s) + HEALTH_TIMEOUT ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    if [ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${HOST_PORT}/backend/health" 2>/dev/null)" = "200" ]; then
      log "✓ health 200 — backend is up on http://localhost:${HOST_PORT}"
      return 0
    fi
    if ! docker ps --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q .; then
      log "container exited prematurely — last logs:"
      docker logs --tail 30 "$CONTAINER_NAME" 2>&1 || true
      fail "backend container died before going healthy"
    fi
    sleep 2
  done
  log "timeout — last logs:"
  docker logs --tail 30 "$CONTAINER_NAME" 2>&1 || true
  fail "health check did not reach 200 within ${HEALTH_TIMEOUT}s"
}

smoke() {
  up
  log "GET /backend/WeatherForecast"
  local body
  body=$(curl -fsS "http://localhost:${HOST_PORT}/backend/WeatherForecast")
  printf '%s\n' "$body" | head -c 400; echo
  printf '%s' "$body" | grep -q '"temperatureC"' || fail "response missing temperatureC field"
  log "✓ smoke OK"
  down
}

logs() { docker logs --tail 50 -f "$CONTAINER_NAME"; }

down() {
  if docker ps -a --filter "name=^${CONTAINER_NAME}$" --format '{{.Names}}' | grep -q .; then
    docker rm -f "$CONTAINER_NAME" >/dev/null
    log "✓ removed container ${CONTAINER_NAME}"
  else
    log "no container '${CONTAINER_NAME}' to remove"
  fi
}

case "${1:-smoke}" in
  up)    up ;;
  smoke) smoke ;;
  logs)  logs ;;
  down)  down ;;
  *)     fail "unknown command: ${1}  (use up | smoke | logs | down)" ;;
esac
