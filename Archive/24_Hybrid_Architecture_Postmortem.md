---
tags: [phase-4, azure, hybrid-architecture, ssh-tunnel, celery-wan, websocket, infrastructure]
date: 2026-04-16
status: complete
---

# 24 — Hybrid Architecture Postmortem

> Previous: [[23_Phase4_Postmortem]] · Next: [[26_Audio_Testing_Postmortem]]
> See [[11_Azure_Deployment]] for runbooks · [[10_GPU_Infrastructure]] for GPU spec

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
| `TypeError: 'str' object cannot be interpreted as an integer` | Socket keepalive keys passed as strings | Replaced with `socket.TCP_KEEPIDLE`, `socket.TCP_KEEPINTVL`, `socket.TCP_KEEPCNT` |
| WebSocket toast not firing | WebSocket hardcoded to `ws://localhost:8000` | Changed to `${wsProtocol}//${window.location.host}/ws/...` |
| `docker-compose up --build` took 2786s on B2s | 2 vCPU B2s — full Dockerfile.gpu build | Excluded `worker_gpu` from B2s deploy — runs locally only |
| Orphan warning on hybrid compose | Only `worker_gpu` defined but other containers exist | Expected — use `--remove-orphans` only if cleaning up |

## Architecture Decisions

- **SSH tunnel over Tailscale/WireGuard** — Pakistan's national DPI firewall throttles UDP. SSH port 22 TCP bypasses it. Validated by 4 independent LLM research opinions including Gemini Deep Research.
- **`host.docker.internal`** — GPU worker Docker container reaches SSH tunnel ports on the Windows host
- **`--without-gossip --without-mingle`** — eliminates AMQP chatter on high-latency WAN links
- **`task_acks_late = True`** — acknowledges tasks only after completion, prevents duplicate WhisperX processing
- **`visibility_timeout = 3600`** — prevents Redis from reassigning long-running inference tasks

## Network Architecture

```
Browser (localhost:5173)
    ↓ Vite proxy
Azure B2s (20.228.184.111:8000)
    FastAPI · PostgreSQL · Redis · MinIO · worker_io · Flower
    ↕ Celery tasks via Redis
SSH Tunnel (localhost:6379/5432/9000 → Azure via port 22)
    ↕
Local RTX 3060 Ti
    worker_gpu (WhisperX large-v2 · ~33s inference)
```

## Validated Outputs

- Full E2E: local upload → Azure API → SSH tunnel → local GPU → Azure DB → Azure dashboard
- `James O'Brien · Sales · 92%` confirmed in Azure Call List ✅
- `transport: redis://host.docker.internal:6379/0` in worker logs ✅

## Files Created

| File | Purpose |
|---|---|
| `scripts/tunnel.bat` | Auto-reconnect SSH tunnel — run before demo |
| `infra/docker-compose.hybrid.yml` | GPU worker only — connects to Azure via tunnel |
| `infra/.env.azure-worker` | Local worker env (gitignored) |
| `backend/app/celery_app.py` | WAN-tuned Celery with socket keepalives |

## Invariants Confirmed

- `run_whisperx` → `gpu_queue`, concurrency=1 ✅
- `.env.azure-worker` gitignored ✅
- Port 6379 conflict: never run local `cq_redis` + `tunnel.bat` simultaneously

## Next Phase Entry Conditions

- `tunnel.bat` running silently (SSH key auth, no password)
- `docker compose -f infra/docker-compose.hybrid.yml up -d worker_gpu` starts cleanly
- `docker logs cq_worker_gpu --tail 5` shows `sync with worker_io`
- Upload `.wav` → score in Azure dashboard within 60s
- WebSocket toast fires on Reports page
