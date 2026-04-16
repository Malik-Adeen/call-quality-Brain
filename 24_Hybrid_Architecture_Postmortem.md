---
tags: [phase-4, azure, hybrid-architecture, ssh-tunnel, celery-wan, websocket]
date: 2026-04-16
status: complete
---

## What Was Built

Full hybrid cloud architecture connecting local RTX 3060 Ti GPU worker to Azure B2s via SSH tunnel.
SSH tunnel auto-reconnect batch script with ServerAliveInterval keep-alives.
WAN-tuned Celery configuration for intercontinental Redis connections.
Dedicated `docker-compose.hybrid.yml` for local GPU worker pointing at Azure.
WebSocket URL fix — hardcoded `localhost:8000` replaced with `window.location.host` for portability.
Vite proxy updated to point at Azure B2s for both REST and WebSocket traffic.
SSH key-based auth set up — no password prompts on tunnel reconnect.

## Bugs Encountered & Resolutions

| Bug | Root Cause | Fix |
|---|---|---|
| `TypeError: 'str' object cannot be interpreted as an integer` on worker start | `broker_transport_options` socket keepalive keys passed as strings — Linux containers require integer socket constants | Replaced string keys with `socket.TCP_KEEPIDLE`, `socket.TCP_KEEPINTVL`, `socket.TCP_KEEPCNT` from Python `socket` module |
| WebSocket toast not firing | WebSocket hardcoded to `ws://localhost:8000` — didn't follow Vite proxy to Azure | Changed to `${wsProtocol}//${window.location.host}/ws/...` — proxied through Vite automatically |
| `docker-compose up --build` took 2786s on B2s | B2s has 2 vCPU — full Dockerfile.gpu build including PyTorch 731MB download | Excluded `worker_gpu` from B2s deploy entirely — GPU worker runs locally only |
| `worker_gpu` image orphan warning | `docker-compose.hybrid.yml` only defines `worker_gpu` but other containers exist on same network | Expected warning — use `--remove-orphans` only if explicitly cleaning up |

## Architecture Decisions

- **SSH tunnel over Tailscale/WireGuard** — Pakistan's national firewall (DPI) throttles UDP; SSH port 22 TCP bypasses it entirely. Validated by 4 independent LLM research opinions including Gemini Deep Research with citations.
- **`host.docker.internal`** — GPU worker Docker container reaches SSH tunnel ports on the Windows host via this alias
- **`--without-gossip --without-mingle`** on GPU worker — eliminates AMQP chatter that causes desync panics on high-latency WAN links
- **`task_acks_late = True`** — tasks acknowledged only after completion, prevents duplicate WhisperX processing if tunnel drops mid-inference
- **`visibility_timeout = 3600`** — 1 hour lock on queued tasks, prevents Redis from reassigning a long-running inference task
- **Vite proxy** handles both REST (`/api`) and WebSocket (`/ws`) routing to Azure — frontend code never hardcodes IP addresses

## Network Architecture

```
Browser (localhost:5173)
    ↓ Vite proxy
Azure B2s (20.228.184.111:8000)
    FastAPI · PostgreSQL · Redis · MinIO · worker_io · Flower
    ↕ Celery tasks via Redis
SSH Tunnel (localhost:6379/5432/9000 → Azure)
    ↕
Local RTX 3060 Ti
    worker_gpu (WhisperX large-v2 · ~33s inference)
```

## Validated Outputs

- Full E2E hybrid pipeline: local upload → Azure API → SSH tunnel → local GPU → Azure DB → Azure dashboard
- `James O'Brien · Sales · 92% · Positive · Resolved` appeared in Azure Call List ✅
- GPU worker logs confirmed: `transport: redis://host.docker.internal:6379/0` ✅
- All 6 pipeline tasks registered on `gpu_queue` ✅

## Files Created

| File | Purpose |
|---|---|
| `scripts/tunnel.bat` | Auto-reconnect SSH tunnel with keep-alives — run before demo |
| `infra/docker-compose.hybrid.yml` | GPU worker only — connects to Azure via tunnel |
| `infra/.env.azure-worker` | Local worker env pointing at localhost tunnel ports (gitignored) |
| `backend/app/celery_app.py` | WAN-tuned Celery config with socket keepalives and late acks |

## Invariants Confirmed

- `run_whisperx` → `gpu_queue` exclusively, concurrency=1 ✅
- Audio fetched from Azure MinIO via SSH tunnel ✅
- Results written to Azure PostgreSQL via SSH tunnel ✅
- JWT never in localStorage ✅
- `.env.azure-worker` gitignored — API keys never committed ✅

## Next Phase Entry Conditions (Demo Day)

- `tunnel.bat` running → `curl http://localhost:6379` responds (or redis-cli ping)
- `docker compose -f infra/docker-compose.hybrid.yml up -d worker_gpu` starts cleanly
- Upload `.wav` → score appears in Azure dashboard within 60s
- WebSocket toast fires on Reports page (Live indicator green)
- `git pull` on Azure VM to pick up latest commits
