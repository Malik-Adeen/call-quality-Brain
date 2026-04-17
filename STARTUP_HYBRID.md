# STARTUP — Hybrid Mode (Azure B2s + Local RTX 3060 Ti)

> Use this when: Azure B2s is running and you want the local GPU to process calls.
> Azure handles: API, PostgreSQL, Redis, MinIO, worker_io, Flower.
> Local handles: worker_gpu (WhisperX) via SSH tunnel.

---

## Prerequisites

- Azure B2s must be running at `20.228.184.111`
- SSH key at `C:\Users\adeen\.ssh\callquality_azure`
- No local `cq_redis` running — it blocks port 6379 which the tunnel needs

---

## Critical Warning

**Never run local `cq_redis` + `tunnel.bat` simultaneously.**
Port 6379 conflict causes silent routing failure — worker_gpu talks to local Redis
while Azure API writes to Azure Redis. Calls stay pending forever.

---

## Step 1 — Verify Azure is healthy

```powershell
curl http://20.228.184.111:8000/health
# Expected: {"status":"ok"}
```

If this fails, SSH in and check:
```powershell
ssh -i C:\Users\adeen\.ssh\callquality_azure azureuser@20.228.184.111
docker compose -f ~/call-quality-analytics/infra/docker-compose.yml ps
# All 7 services should show "Up"
```

---

## Step 2 — Check VRAM is clear

```powershell
nvidia-smi --query-gpu=memory.used,memory.free --format=csv
# memory.free must be > 5000 MiB before starting worker_gpu
```

If VRAM is occupied (WhisperX/Pyannote from previous session):
```powershell
docker stop cq_worker_gpu
# Wait 10 seconds — VRAM fully releases
nvidia-smi --query-gpu=memory.used,memory.free --format=csv
```

---

## Step 3 — Start SSH tunnel

Open a dedicated terminal. **Keep it open for the entire session.**

```powershell
N:\projects\call-quality-analytics\scripts\tunnel.bat
```

The script automatically:
- Stops any local containers that conflict (cq_api, cq_redis, etc.)
- Opens SSH tunnel forwarding :6379 (Redis) :5432 (Postgres) :9000 (MinIO)
- Auto-reconnects if connection drops (ServerAliveInterval=15)

Expected output after connecting:
```
STEP 1: Stopping local stack containers that conflict with tunnel...
STEP 2: Connecting SSH tunnel to Azure B2s...
 Forwarding :6379 (Redis) :5432 (Postgres) :9000 (MinIO)
 Keep this window open during the entire demo.
```
Then silence — SSH -N produces no output when connected successfully.

---

## Step 4 — Start local GPU worker

Open a new terminal (do NOT close the tunnel terminal).

```powershell
docker compose -f N:\projects\call-quality-analytics\infra\docker-compose.hybrid.yml up -d worker_gpu
```

---

## Step 5 — Verify worker connected to Azure Redis

```powershell
docker logs cq_worker_gpu --tail 10
```

Must see both of these lines:
```
Connected to redis://host.docker.internal:6379/0
sync with worker_io@086696510e9e
```

If you see `Connected` but no `sync` — wait 15 seconds and check again.
If `sync` never appears — the tunnel is not forwarding correctly. Restart tunnel.bat.

---

## Step 6 — Start frontend

```powershell
cd N:\projects\call-quality-analytics\frontend
npm run dev
```

Open `http://localhost:5173` → login: `admin@callquality.demo` / `admin1234`

Dashboard data loads from Azure. GPU inference happens locally via tunnel.

---

## Step 7 — Uploading audio (demo day rules)

1. `nvidia-smi` — confirm VRAM < 3GB before each upload
2. Upload ONE file at a time from the Upload page
3. Switch to Reports page — watch the **Live** indicator (green = WebSocket connected)
4. Wait for toast: `"Call scored: [Agent] — XX%"` before uploading next file
5. After toast → Call List (navigate away and back to refresh) → open Call Detail → PDF

---

## Crash Recovery

If your PC crashes mid-processing, stuck `processing` calls will cause
worker_gpu to OOM immediately on restart. Fix before restarting:

```powershell
# Fix stuck calls on Azure DB
ssh -i C:\Users\adeen\.ssh\callquality_azure azureuser@20.228.184.111 `
  "docker exec cq_postgres psql -U callquality -d callquality -c `
  \"UPDATE calls SET status='failed' WHERE status='processing';\""

# Flush stale Redis queue
ssh -i C:\Users\adeen\.ssh\callquality_azure azureuser@20.228.184.111 `
  "docker exec cq_redis redis-cli DEL gpu_queue"
```

Then restart from Step 2.

---

## Shutdown (end of session)

```powershell
# Stop GPU worker
docker stop cq_worker_gpu

# Close tunnel.bat terminal (Ctrl+C then Y)
# No other cleanup needed — Azure keeps running
```

---

## Azure Operations Reference

```powershell
# SSH into Azure VM
ssh -i C:\Users\adeen\.ssh\callquality_azure azureuser@20.228.184.111

# On Azure VM — update code and restart IO worker
cd ~/call-quality-analytics && git pull && docker restart cq_worker_io

# On Azure VM — reseed database (fresh 200 calls)
python3 scripts/reset_and_seed.py

# On Azure VM — check all services
docker compose -f infra/docker-compose.yml ps
```

---

## Port Reference

| Port | Service | Location |
|---|---|---|
| 8000 | FastAPI API | Azure (public) |
| 5432 | PostgreSQL | Azure → tunneled to localhost:5432 |
| 6379 | Redis | Azure → tunneled to localhost:6379 |
| 9000 | MinIO API | Azure → tunneled to localhost:9000 |
| 9001 | MinIO console | Azure (not tunneled — SSH forward manually if needed) |
| 5555 | Flower | Azure (not public — SSH forward manually if needed) |
| 5173 | React frontend | Local only |
