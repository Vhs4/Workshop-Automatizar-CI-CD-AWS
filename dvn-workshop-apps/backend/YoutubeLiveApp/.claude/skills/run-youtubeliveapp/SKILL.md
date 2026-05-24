---
name: run-youtubeliveapp
description: Build, run, smoke-test, screenshot, and tear down the YoutubeLiveApp .NET 8 backend (dvn-workshop-apps/backend/YoutubeLiveApp). Runs the app inside a `mcr.microsoft.com/dotnet/sdk:8.0` Docker container so the host does not need a .NET SDK installed. Use this skill whenever the user asks to run, start, launch, smoke-test, hit, curl, screenshot, or verify the backend / YoutubeLiveApp / .NET API — even if they don't say "run-youtubeliveapp". Drives the app via `.claude/skills/run-youtubeliveapp/driver.sh`.
---

The YoutubeLiveApp is an ASP.NET Core 8 Web API. `Program.cs` mounts everything under `/backend`, so the routes are `/backend/WeatherForecast` (sample controller) and `/backend/health` (from `AddHealthChecks`).

**All paths below are relative to this app's root: `dvn-workshop-apps/backend/YoutubeLiveApp/`.**

## Prerequisites

- Docker daemon running (`docker version` should succeed).
- Network access to `mcr.microsoft.com` for the first pull (~700 MB, cached after).
- Port `5118` free on the host (override with `HOST_PORT=...`).

No `dotnet` SDK on the host — the container has it.

## Run (agent path) — driver.sh

The driver wraps everything: AppleDouble cleanup → container start → health-poll → optional smoke → teardown. Always prefer this over raw `docker run`.

```bash
# From the app dir:
cd dvn-workshop-apps/backend/YoutubeLiveApp

# One-shot: start, hit /backend/WeatherForecast, validate JSON, tear down.
.claude/skills/run-youtubeliveapp/driver.sh smoke

# Long-lived: leave the container running for manual curls.
.claude/skills/run-youtubeliveapp/driver.sh up

# Tail logs (in another shell).
.claude/skills/run-youtubeliveapp/driver.sh logs

# Stop & remove.
.claude/skills/run-youtubeliveapp/driver.sh down
```

What `smoke` does on a clean machine (verified end-to-end):

```
[run-yt] stripped 5 AppleDouble (._*) files from .../YoutubeLiveApp
[run-yt] starting mcr.microsoft.com/dotnet/sdk:8.0 -> workshop-backend (host:5118 -> container:8080)
[run-yt] waiting up to 90s for http://localhost:5118/backend/health
[run-yt] ✓ health 200 — backend is up on http://localhost:5118
[run-yt] GET /backend/WeatherForecast
[{"date":"2026-05-25","temperatureC":45,...,"deployment":"v3"},...]
[run-yt] ✓ smoke OK
[run-yt] ✓ removed container workshop-backend
```

### After `up`, hit the API manually

```bash
curl -i http://localhost:5118/backend/health           # → 200 OK, body "Healthy"
curl    http://localhost:5118/backend/WeatherForecast  # → JSON array of 5 forecasts
```

### Env overrides

| Var               | Default                          | What it does                                |
|-------------------|----------------------------------|---------------------------------------------|
| `HOST_PORT`       | `5118`                           | Host port mapped to container `:8080`       |
| `CONTAINER_NAME`  | `workshop-backend`               | Docker container name                       |
| `IMAGE`           | `mcr.microsoft.com/dotnet/sdk:8.0` | SDK image used to compile & run           |
| `HEALTH_TIMEOUT`  | `90`                             | Seconds to wait for `/backend/health` = 200 |

## Run (human path)

If the human installs the .NET 8 SDK on the host (`brew install --cask dotnet-sdk@8`):

```bash
cd dvn-workshop-apps/backend/YoutubeLiveApp
dotnet run --project YoutubeLiveApp.csproj
# Listens on http://localhost:5118 (per Properties/launchSettings.json "http" profile).
# Ctrl-C to stop.
```

Useless headless / in CI — the driver is the agent path.

## Gotchas

- **AppleDouble `._*` files break the build inside the container.** The repo lives on a non-APFS volume (PortableSSD), so macOS creates `._<filename>` siblings for every source file. They are gitignored metadata, but a bind-mounted `/src` exposes them to the Linux container, where `csc` tries to compile them and aborts with `CS1504: Access to the path '/src/._WeatherForecast.cs' is denied.` The driver runs `find -name "._*" -delete` before each `up` to fix this. Don't remove that step.

- **The `dotnet/sdk:8.0` image is multi-project-aware and refuses to guess.** `dotnet run` without `--project YoutubeLiveApp.csproj` fails with `MSB1011: Specify which project or solution file to use`, especially when AppleDouble siblings exist. The driver always pins `--project YoutubeLiveApp.csproj`.

- **All endpoints are under `/backend`, not `/`.** A `curl http://localhost:5118/` returns 404 — that's by design (`app.Map("/backend", ...)` in `Program.cs`). Hit `/backend/health` and `/backend/WeatherForecast`.

- **The `ASPNETCORE_URLS` env in the driver overrides `HTTP_PORTS`.** Kestrel logs a warning (`Overriding HTTP_PORTS '8080'`) — that's expected, not an error.

- **First run downloads ~700 MB of base image.** Subsequent `smoke` runs reuse the cached layer; restore + run is ~20–30 s.

- **`Properties/launchSettings.json` is dev-only.** The driver passes `--no-launch-profile` so the container doesn't try to bind `https://localhost:7207` (no cert in the container). For the human path, the launch profile is fine.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `CS1504: Access to the path '/src/._*.cs' is denied.` | AppleDouble files crept back. Run `find . -name "._*" -delete` from the app dir, or just re-run the driver — it strips them on each `up`. |
| `MSB1011: Specify which project or solution file to use` | Same root cause. Driver pins `--project YoutubeLiveApp.csproj` to avoid it. |
| `curl: (7) Failed to connect to localhost port 5118` | Container exited. Check `docker logs workshop-backend`. Most commonly: AppleDouble files (see above) or port already in use (`HOST_PORT=5119 .../driver.sh up`). |
| `port is already allocated` | `docker rm -f workshop-backend` or pick another port via `HOST_PORT=`. |
| Container takes >90 s to go healthy | First-run NuGet restore over slow link. Bump `HEALTH_TIMEOUT=180`. |
| Builds fail with `EROFS` / read-only fs | The volume is mounted read-only somehow — re-run from the app dir, not via `sudo`. |
