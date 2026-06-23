---
tags: [testing, pre-azure, e2e]
date: 2026-05-25
---

# 60 — Pre-Azure E2E Test Plan

> Run this in full on manager's laptop before touching Azure.
> Every gate must PASS before proceeding to the next.
> Document failures with screenshot + Flower task ID.

---

## Prerequisites

```bash
git checkout deploy/manager-laptop
docker compose up --build -d
# Wait for all 7 containers to be healthy
docker compose ps

# Apply migrations
cd backend
alembic upgrade head

# Seed demo data
cd ..
python scripts/reset_and_seed.py
```

Confirm at http://localhost:8000/docs — FastAPI should respond.
Confirm at http://localhost:5555 — Flower should show 0 tasks.

---

## Gate 1 — Stack Health

| Check | Command | Expected |
|---|---|---|
| All containers up | `docker compose ps` | 7/7 Up |
| GPU visible | `docker compose exec worker_gpu nvidia-smi` | RTX 5060, 8GB |
| Redis AOF | `docker compose exec cq_redis redis-cli config get appendonly` | `yes` |
| MinIO bucket exists | `docker compose exec cq_minio_init mc ls local/` | `audio-uploads` |
| Webhook registered | `docker compose exec cq_minio_init mc event list local/audio-uploads` | `arn:minio:sqs::PRIMARY:webhook` |

---

## Gate 2 — Manual Upload (Demo Tenant)

1. Login: http://localhost:5173 → admin@callquality.demo / admin1234
2. Navigate to Upload page
3. Drag-drop a WAV file
4. Watch Flower at http://localhost:5555 — verify task chain fires:
   - `run_whisperx` → RUNNING on gpu_queue
   - `extract_agent_identity` → SUCCESS
   - `redact_pii` → SUCCESS
   - `compute_talk_balance` → SUCCESS
   - `run_groq_inference` → SUCCESS
   - `write_scores` → SUCCESS
   - `notify_websocket` → SUCCESS
5. Verify WebSocket toast fires on dashboard
6. Verify call appears in CallList with score > 0
7. Open call detail → confirm transcript is redacted (no raw names/numbers)
8. Download PDF report → confirm it opens

**PASS criteria:** All 7 tasks green in Flower. Score displayed as %. PDF downloads.

---

## Gate 3 — Batch Upload via mc mirror (Demo Tenant)

```bash
# On manager's machine (outside Docker)
mc alias set callquality http://localhost:9000 minioadmin minioadmin_dev
mc mirror --watch C:\path\to\recordings\ callquality:audio-uploads/callquality-demo-XXXXXXXX/
```

> Replace `callquality-demo-XXXXXXXX` with the actual slug from the DB.
> Get slug: `docker compose exec postgres psql -U callquality -d callquality -c "SELECT slug FROM tenants;"`

1. Drop 2-3 WAV files into the watched folder
2. Confirm MinIO receives them (http://localhost:9001 → audio-uploads bucket)
3. Confirm webhook fires for each → Flower shows pipeline chains
4. Confirm all calls appear in dashboard

**PASS criteria:** Each dropped file triggers a separate pipeline run. No manual action needed after folder drop.

---

## Gate 4 — Multi-Tenancy Isolation

Two tenants are seeded: Demo Tenant + BPO Solutions (check slugs via DB query above).

**Test A — Data separation:**
1. Login as admin@callquality.demo → upload 1 call → note the call ID
2. Logout
3. Login as supervisor@bposolutions.demo (or whatever seed created) → verify that call ID does NOT appear in their CallList

**Test B — Concurrent upload from 2 tenants:**
```bash
# Terminal 1 — Demo Tenant mirror
mc mirror --watch C:\demo_audio\ callquality:audio-uploads/<demo-slug>/

# Terminal 2 — BPO Tenant mirror
mc mirror --watch C:\bpo_audio\ callquality:audio-uploads/<bpo-slug>/
```
Drop 1 file into each folder simultaneously.

Watch Flower — you should see 2 pipeline chains running. Because `gpu_queue` has `concurrency=1`, the two `run_whisperx` tasks will queue — one runs, the other waits. That is correct behaviour.

**PASS criteria:**
- Each tenant's dashboard shows only their own calls
- Both pipelines complete without errors
- No score from Tenant A appears in Tenant B's view
- gpu_queue shows max 1 active WhisperX at any time

---

## Gate 5 — Edge Cases

| Scenario | Action | Expected |
|---|---|---|
| Non-audio file | Drop a `.txt` into watched folder | Webhook fires, router ignores it, no Call row created |
| Unknown tenant slug | `mc cp file.wav callquality:audio-uploads/fake-slug/file.wav` | Webhook fires, router logs warning, no Call row created, 200 returned |
| Duplicate file drop | Drop same file twice | Two separate Call rows created (no dedup — correct by design) |
| Pipeline crash simulation | Stop worker_gpu mid-run: `docker stop cq_worker_gpu` | Call status → `failed` in DB |

---

## Gate 6 — WebSocket on Every Page

1. Open dashboard on Overview page
2. Trigger a new upload (via mc mirror drop)
3. Verify toast fires on Overview page (not just Reports page)
4. Navigate to Agents page mid-pipeline — verify toast still fires on arrival

**PASS criteria:** Toast fires regardless of which page is active.

---

## Sign-Off Checklist

- [ ] Gate 1 — Stack Health
- [ ] Gate 2 — Manual Upload
- [ ] Gate 3 — Batch Upload (mc mirror)
- [ ] Gate 4A — Data Separation
- [ ] Gate 4B — Concurrent Upload
- [ ] Gate 5 — Edge Cases
- [ ] Gate 6 — WebSocket on Every Page

All gates PASS → branch is Azure-ready.

---

## If WhisperX Fails on RTX 5060

Most likely cause: ctranslate2 wheel cuDNN mismatch (Perplexity finding).
Error will look like: `libcudnn_ops_infer.so.8: cannot open shared object file`

Fix: rebuild ctranslate2 from source inside the container:
```bash
docker compose exec worker_gpu bash
pip uninstall ctranslate2 -y
git clone https://github.com/OpenNMT/CTranslate2.git
cd CTranslate2
cmake -DWITH_CUDA=ON -DWITH_CUDNN=ON -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda .
make -j4
pip install .
```
Then restart worker_gpu and re-run the upload.
