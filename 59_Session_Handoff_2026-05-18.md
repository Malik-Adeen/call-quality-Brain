---
tags: [handoff, session-starter]
date: 2026-05-18
status: active
---

# 59 — Session Handoff (2026-05-18)

> Paste CONTEXT.md + this file at the start of any new session.

---

## What Was Done This Session

### Batch Agent Replaced — Dropbox Model Implemented

Removed the existing `batch_agent/` watchdog Docker container (SHA-256 dedup,
PollingObserver, asyncio semaphore) entirely. Replaced with a MinIO webhook +
`mc mirror --watch` architecture ("Dropbox model").

**Why:** The old batch agent ran on your server and watched a volume mount.
In a cloud multi-tenant SaaS, tenants can't mount a folder into your server.
The correct model is: tenant runs `mc mirror --watch` on their own machine
(like Dropbox desktop sync), your server reacts to files landing in MinIO.

### New Architecture

```
Tenant machine
    mc mirror --watch /recordings/ callquality:audio-uploads/<slug>/
                    ↓
Your MinIO (cloud)
    audio-uploads/<slug>/call.wav lands
                    ↓
MinIO fires POST /internal/minio-event (webhook)
                    ↓
FastAPI: auth check → parse slug → lookup tenant → create call row → Celery chain
                    ↓
7-stage pipeline runs end to end
```

### Files Changed

| File | Change |
|---|---|
| `infra/docker-compose.yml` | Removed cq_batch_agent service + batch_checksums volume. Added MinIO webhook env vars. Added `cq-api` network alias to api service. minio_init uses `until mc alias set` readiness loop. |
| `backend/app/routers/minio_event.py` | New file — POST /internal/minio-event endpoint |
| `backend/app/main.py` | Registered minio_event router with prefix="/internal" |
| `backend/app/database.py` | Fixed SET LOCAL parameterization (asyncpg can't use $1 in SET) |
| `batch_agent/` | Deleted entirely |

### New Router — minio_event.py

- Auth: checks `Authorization: Bearer {MINIO_WEBHOOK_SECRET}` — returns 200 on failure (not 403, prevents MinIO infinite retry)
- Parses `Key` field: `audio-uploads/<tenant_slug>/<filename>`
- Strips bucket prefix before storing as `minio_audio_path`
- Inserts `calls` row with `status=pending`, `pii_redacted=False`
- Fires Celery chain: `run_whisperx → extract_agent_identity → redact_pii → compute_talk_balance → run_groq_inference → write_scores → notify_websocket`

### Key Bugs Found and Fixed

| Bug | Fix |
|---|---|
| ARN case-sensitive: `primary` ≠ `PRIMARY` | `mc event add` must use `arn:minio:sqs::PRIMARY:webhook` (uppercase matches env var suffix) |
| MinIO rejects `cq_api` hostname (underscore) | Added `cq-api` network alias to api service |
| MinIO prepends "Bearer " to auth token | Comparison changed to `f"Bearer {expected_secret}"` |
| `SET LOCAL app.current_tenant = $1` fails in asyncpg | Changed to f-string: `f"SET LOCAL app.current_tenant = '{tenant_id}'"` |
| MinIO Key includes bucket prefix: `audio-uploads/demo/file.wav` | Strip with `key.removeprefix(f"{bucket}/")` before storing |
| Double `/internal` prefix on route | Route decorator changed from `/internal/minio-event` to `/minio-event` |
| `extract_agent_identity` missing from Celery chain | Added between `run_whisperx` and `redact_pii` |
| `mc admin service restart` fails without TTY | Replaced entire approach — env vars + `mc event add` only, no restart needed |

### MinIO Init Strategy (Final)

Env vars on minio service register the webhook target at MinIO boot:
```
MINIO_NOTIFY_WEBHOOK_ENABLE_PRIMARY: "on"
MINIO_NOTIFY_WEBHOOK_ENDPOINT_PRIMARY: "http://cq-api:8000/internal/minio-event"
MINIO_NOTIFY_WEBHOOK_QUEUE_DIR_PRIMARY: "/data/.webhook-queue"
MINIO_NOTIFY_WEBHOOK_QUEUE_LIMIT_PRIMARY: "10000"
```

minio_init just binds the bucket to the ARN (no config set, no restart):
```sh
until mc alias set local http://cq-minio:9000 ... >/dev/null 2>&1; do sleep 1; done
mc mb --ignore-existing local/audio-uploads
mc anonymous set none local/audio-uploads
mc cp /tmp/test_pipeline.wav local/audio-uploads/test_pipeline.wav
mc event add --ignore-existing --event put local/audio-uploads arn:minio:sqs::PRIMARY:webhook
mc event list local/audio-uploads
```

### E2E Test Result

```
File: test_call.wav (3.37 MiB)
Dropped into: local/audio-uploads/demo/test_call9.wav
WhisperX: succeeded in 198s — AGENT/CUSTOMER diarized correctly
Groq inference: score 9.18, billing_dispute, resolved=True
write_scores: committed to DB
notify_websocket: fired
```

Full pipeline verified working via MinIO webhook trigger.

---

## Current State

| Component | Status |
|---|---|
| MinIO webhook → pipeline | ✅ E2E verified |
| Batch agent | ✅ Removed |
| `POST /internal/minio-event` | ✅ Live |
| Auth (Bearer token) | ✅ Working |
| minio_init ARN registration | ✅ Reliable (env vars + retry loop) |
| SET LOCAL asyncpg fix | ✅ Applied to minio_event.py + database.py |

---

## What To Do Next

### 1. pytest skeleton (was next from doc 57, still pending)
CI finds zero tests — warning not failure but needs fixing.
- `backend/tests/test_scoring.py` — scoring formula, talk_balance
- `backend/tests/test_pipeline.py` — PII gate, idempotency
- `backend/tests/test_auth.py` — JWT, roles, tenant isolation
- `backend/tests/test_minio_event.py` — webhook auth, key parsing, tenant lookup

### 2. Tenant onboarding flow
The `mc mirror --watch` command is the client-side sync agent.
Package it as a simple installer script (PowerShell for Windows, bash for Linux)
that tenants run once. Store tenant slug + MinIO credentials in the script.

### 3. Bot Feature (NL query layer)
Per CONTEXT.md roadmap:
- New `/bot` FastAPI router
- NL → SQL via Groq, tenant-scoped
- Web widget in dashboard

### 4. Azure Canada Central Deploy

---

## Tenant Sync Client (How to Use)

Tenant runs this on their recording server:
```bash
mc alias set callquality https://your-minio.callquality.io <access_key> <secret_key>
mc mirror --watch /var/recordings/ callquality:audio-uploads/<tenant_slug>/
```

Register as Windows Service or Linux systemd unit for 24/7 operation.
No Docker required on tenant side.

---

## Key Reminders

- Always run `alembic upgrade head` after fresh DB init
- Always run `python scripts/reset_and_seed.py` to seed demo data (from host)
- MinIO ARN is uppercase: `arn:minio:sqs::PRIMARY:webhook`
- Webhook endpoint: `http://cq-api:8000/internal/minio-event` (hyphen, not underscore)
- `SET LOCAL` in asyncpg must use f-string, never parameterized
- `docker compose down` (no -v) preserves volumes; `-v` wipes everything

---

## Credentials

| Account | Email | Password |
|---|---|---|
| Demo Tenant Admin | admin@callquality.demo | admin1234 |
| Demo Supervisor | supervisor@callquality.demo | supervisor1234 |
| Demo Viewer | viewer@callquality.demo | viewer1234 |
| Platform Admin | platform@callquality.internal | platform1234 |

---

## Key File Locations

| Purpose | Path |
|---|---|
| Project root | E:\projects\call-quality-analytics |
| Vault | E:\projects\docs |
| MinIO event router | backend/app/routers/minio_event.py |
| Docker compose | infra/docker-compose.yml |
| CI pipeline | .github/workflows/ci.yml |
| Demo audio | C:\Users\adeen\Desktop\batch_audio\demo_tenant\ |
