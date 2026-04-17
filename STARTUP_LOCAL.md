# STARTUP — Local Mode (All Services on Local Machine)

> Use this when: working offline, no Azure, everything runs locally.
> All 8 services run on your machine. GPU inference is local.
> Frontend points to localhost:8000.

---

## Prerequisites

- Docker Desktop running
- WSL2 enabled
- NVIDIA Container Toolkit installed (for GPU worker)
- `N:\projects\call-quality-analytics\infra\.env` populated

---

## Critical Warning

**Never run local mode + tunnel.bat simultaneously.**
Both bind port 6379. The conflict causes silent failures.
If tunnel.bat ran in a previous session, make sure it's closed before starting local mode.

---

## Step 1 — Verify frontend Vite proxy points to localhost

Check `N:\projects\call-quality-analytics\frontend\vite.config.ts`:

```typescript
proxy: {
  '/api': {
    target: 'http://localhost:8000',   // ← must be localhost, not Azure IP
```

If it shows `20.228.184.111` (Azure), switch it back:
```powershell
# Edit vite.config.ts — change target to http://localhost:8000
# and ws target to ws://localhost:8000
```

---

## Step 2 — Start all services

```powershell
docker compose -f N:\projects\call-quality-analytics\infra\docker-compose.yml up -d
```

This starts all 8 containers:
- `cq_postgres` — PostgreSQL 16
- `cq_redis` — Redis 7
- `cq_minio` — MinIO object storage
- `cq_minio_init` — creates bucket + uploads test file (exits after)
- `cq_api` — FastAPI :8000
- `cq_worker_io` — Celery io_queue (CPU tasks)
- `cq_worker_gpu` — Celery gpu_queue (WhisperX)
- `cq_flower` — Queue monitor :5555

First run builds images — takes 20–30 min. Subsequent starts take ~30 seconds.

---

## Step 3 — Verify all services are up

```powershell
docker ps --format "table {{.Names}}\t{{.Status}}"
```

Expected:
```
NAMES           STATUS
cq_worker_gpu   Up X minutes
cq_flower       Up X minutes
cq_worker_io    Up X minutes
cq_api          Up X minutes
cq_minio_init   Exited (0)        ← this one exits after init, that's correct
cq_minio        Up X minutes
cq_redis        Up X minutes
cq_postgres     Up X minutes
```

---

## Step 4 — Verify API is healthy

```powershell
curl http://localhost:8000/health
# Expected: {"status":"ok"}
```

---

## Step 5 — Verify GPU worker connected

```powershell
docker logs cq_worker_gpu --tail 5
```

Must see:
```
Connected to redis://cq_redis:6379/0
celery@worker_gpu ready.
```

---

## Step 6 — Seed the database (first run or after reset)

```powershell
cd N:\projects\call-quality-analytics
python scripts/reset_and_seed.py
```

Prints agent breakdown table when complete. 200 calls inserted.

---

## Step 7 — Start frontend

```powershell
cd N:\projects\call-quality-analytics\frontend
npm run dev
```

Open `http://localhost:5173` → login: `admin@callquality.demo` / `admin1234`

---

## Step 8 — Verify MinIO bucket exists

```powershell
docker exec cq_minio mc alias set local http://localhost:9000 minioadmin minioadmin_dev
docker exec cq_minio mc ls local/audio-uploads
# Should show test_pipeline.wav
```

If bucket is missing (happens after `docker compose down`):
```powershell
docker exec cq_minio mc mb --ignore-existing local/audio-uploads
docker exec cq_minio mc anonymous set download local/audio-uploads
```

---

## Uploading Audio (GPU constraints)

```powershell
# Check VRAM before each upload
nvidia-smi --query-gpu=memory.used,memory.free --format=csv
# memory.free must be > 5000 MiB
```

- Upload ONE file at a time
- Wait for `call_complete` WebSocket toast before next upload
- If VRAM > 7GB during processing — wait, don't upload another file

---

## Crash Recovery

```powershell
# Fix stuck processing calls
docker exec cq_postgres psql -U callquality -d callquality `
  -c "UPDATE calls SET status='failed' WHERE status='processing';"

# Flush stale gpu_queue
docker exec cq_redis redis-cli DEL gpu_queue

# Restart services that died in crash
docker compose -f N:\projects\call-quality-analytics\infra\docker-compose.yml `
  up -d api worker_io flower
```

---

## Rebuild (after code changes)

```powershell
# Rebuild only the API container (most common)
docker compose -f N:\projects\call-quality-analytics\infra\docker-compose.yml `
  up -d --build api

# Rebuild GPU worker (after requirements-gpu.txt changes — takes ~30 min)
docker compose -f N:\projects\call-quality-analytics\infra\docker-compose.yml `
  up -d --build worker_gpu

# Rebuild everything (nuclear option)
docker compose -f N:\projects\call-quality-analytics\infra\docker-compose.yml `
  up -d --build
```

Note: API and worker_io have live volume mounts (`../backend:/app`).
Python file changes are picked up automatically without rebuild.
Only rebuild when `requirements.txt` or `Dockerfile` changes.

---

## Shutdown

```powershell
# Stop all services (data persists in minio_data volume)
docker compose -f N:\projects\call-quality-analytics\infra\docker-compose.yml down

# Nuclear reset — wipes all data including MinIO volume
docker compose -f N:\projects\call-quality-analytics\infra\docker-compose.yml down -v
# Run reset_and_seed.py again after this
```

---

## Useful Commands

```powershell
# Watch worker_gpu live (WhisperX processing)
docker logs cq_worker_gpu -f

# Watch worker_io live (Presidio, Groq, scoring)
docker logs cq_worker_io -f

# Check Redis queue depths
docker exec cq_redis redis-cli LLEN gpu_queue
docker exec cq_redis redis-cli LLEN io_queue

# Check VRAM
nvidia-smi

# Flower dashboard (Celery queue monitor)
# http://localhost:5555 — login: admin / flower_dev

# MinIO console
# http://localhost:9001 — login: minioadmin / minioadmin_dev

# Get auth token for API testing
$r = Invoke-RestMethod -Uri "http://localhost:8000/auth/login" `
  -Method POST -ContentType "application/json" `
  -Body '{"email":"admin@callquality.demo","password":"admin1234"}'
$token = $r.data.access_token
```

---

## Port Reference

| Port | Service | URL |
|---|---|---|
| 8000 | FastAPI API | http://localhost:8000 |
| 5432 | PostgreSQL | localhost:5432 |
| 6379 | Redis | localhost:6379 |
| 9000 | MinIO API | http://localhost:9000 |
| 9001 | MinIO console | http://localhost:9001 |
| 5555 | Flower | http://localhost:5555 |
| 5173 | React frontend | http://localhost:5173 |

---

## Switching from Local → Hybrid Mode

1. Close frontend (Ctrl+C in npm terminal)
2. `docker stop cq_api cq_postgres cq_redis cq_minio cq_worker_io cq_flower`
3. Update `vite.config.ts` proxy target → `http://20.228.184.111:8000`
4. Start `tunnel.bat`
5. Start `docker-compose.hybrid.yml up -d worker_gpu`
6. `npm run dev`

## Switching from Hybrid → Local Mode

1. Close tunnel.bat (Ctrl+C, Y)
2. Close frontend
3. Update `vite.config.ts` proxy target → `http://localhost:8000`
4. `docker compose -f infra/docker-compose.yml up -d`
5. `npm run dev`
