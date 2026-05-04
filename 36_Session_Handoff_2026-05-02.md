---
tags: [handoff, session, phase6]
date: 2026-05-02
status: handoff
---

# 36 — Session Handoff 2026-05-02

## What Was Done This Session

### Phase 6 — Agent Integration (COMPLETE ✅)

#### Migration 005 — Agent sync columns
- Added `external_id TEXT` (nullable) to agents table
- Added `is_active BOOLEAN NOT NULL DEFAULT TRUE` to agents table
- Added `email TEXT` (nullable) to agents table
- Created partial unique index: `agents_external_id_tenant_idx ON agents(tenant_id, external_id) WHERE external_id IS NOT NULL`
- Revision: `20260601_add_agent_sync_columns` → down_revision: `20260501_force_rls`
- Applied and verified in psql ✅

#### ORM update (`backend/app/models/orm.py`)
- Added `external_id`, `is_active`, `email` columns to `Agent` model

#### New endpoints (`backend/app/routers/agents.py`)
- `POST /agents/sync` — bulk upsert by `(tenant_id, external_id)`, xmax trick for created/updated counts, skips items with no external_id, role guard: `TENANT_ADMIN` or `SUPERVISOR`
- `GET /agents` — list agents with `?include_inactive=true` support, uses `get_db_with_tenant`
- Fixed pre-existing bug: `GET /{agent_id}/scores` was using `get_db` — updated to `get_db_with_tenant` (would have returned zero rows with FORCE RLS active)

#### Smoke tests passed
| Test | Result |
|---|---|
| `GET /agents` | 5 active agents returned, RLS scoped ✅ |
| Sync new agent EXT001 | `created:1, updated:0, skipped:0` ✅ |
| Sync same agent again | `created:0, updated:1, skipped:0` — xmax trick working ✅ |
| Sync no external_id | `created:0, updated:0, skipped:1` ✅ |

---

### Pipeline — Known Risk Resolved + Full E2E Verified

#### Celery header propagation fix
- **Root cause:** `self.request.headers` is `None` on chain tasks 2–6. Celery 5.x does not propagate custom headers beyond task 1.
- **Fix:** Removed all `self.request.headers.get("tenant_id")` calls. Added `tenant_id: str` as explicit last argument to all 6 task signatures. Updated chain dispatch in `calls.py` to pass `tenant_id_str` explicitly via `.si()` / `.s()`.
- Files changed: `backend/app/pipeline/tasks.py`, `backend/app/routers/calls.py`

#### GPU OOM fix
- **Root cause:** `worker_gpu` had a hard `memory: 6G` Docker limit. WhisperX large-v2 (int8) + alignment model + pyannote peaks past 6GB system RAM during transcription, causing silent SIGKILL with no Python traceback.
- **Fix:** Removed `limits.memory: 6G` from `docker-compose.yml` worker_gpu deploy block. GPU reservation preserved.
- Additional: `batch_size` reduced from 2 → 1 in `whisper_service.py` to halve peak VRAM during attention pass.

#### `notify_websocket` DetachedInstanceError fix
- **Root cause:** `call.agent_id` accessed outside the `with SessionLocal()` block — ORM object detached after session closed, triggering expired attribute lazy load with no session.
- **Fix:** Added `call_agent_id = str(call.agent_id)` inside the session block, used `call_agent_id` in the payload dict outside it.

#### Full E2E pipeline result
```
run_whisperx         ✅  214s — language: en, AGENT/CUSTOMER diarization correct
redact_pii           ✅
compute_talk_balance ✅  talk_balance_score: 0.8017
run_groq_inference   ✅  0.93s — Groq llama-3.3-70b-versatile, HTTP 200
write_scores         ✅  score: 9.18 written to DB
notify_websocket     ✅  WebSocket broadcast sent
```
Call status: `complete`. Score: `9.18`. Issue category: `billing_dispute`. Resolved: `true`.

---

## Exact State Right Now

**Alembic current head:** `20260601_add_agent_sync_columns`

**Files created/modified this session:**
```
backend/alembic/versions/20260601_add_agent_sync_columns.py   (NEW)
backend/app/models/orm.py                                      (MODIFIED — Agent columns)
backend/app/routers/agents.py                                  (MODIFIED — 2 new endpoints + get_db fix)
backend/app/pipeline/tasks.py                                  (MODIFIED — explicit tenant_id arg + notify_websocket fix)
backend/app/routers/calls.py                                   (MODIFIED — chain dispatch)
backend/app/services/whisper_service.py                        (MODIFIED — batch_size=1)
infra/docker-compose.yml                                       (MODIFIED — removed memory: 6G cap)
docs/36_Session_Handoff_2026-05-02.md                          (THIS FILE)
```

**Infrastructure notes:**
- `cq_worker_gpu` memory cap removed — no longer constrained to 6G
- Groq API key rotated — new key active in `.env` and confirmed live in container
- `ALLOW_LEGACY_TOKENS` is `"false"` — all tokens must carry `tenant_id` claim

---

## Where To Start Next Session

**Phase 7 — Agent Identity Extraction.** Start a new chat, read `00_Master_Dashboard.md` + `34_Final_Implementation_Plan.md` + this file.

Phase 7 checklist (from `34_Final_Implementation_Plan.md`):

```
[ ] Migration 006 — calls table: agent_id nullable, needs_agent_review BOOL, agent_name_extracted TEXT
[ ] extract_agent_identity Celery task (io_queue) — insert into chain after redact_pii
[ ] celery_app.py — add extract_agent_identity to task routes
[ ] Upload form — add optional external_agent_id field
[ ] rapidfuzz matching (token_set_ratio, thresholds: ≥90 auto, 75-89 conditional, <75 flag)
[ ] Groq name extraction prompt — first 500 words only
[ ] Frontend — "Needs Review" badge on call list for needs_agent_review=TRUE
[ ] Supervisor manual assign from call detail panel
```

**Dependency check before starting Phase 7:** Run a real production call through the upload
to confirm the pipeline holds under real-world audio (not just the test WAV).
The test file is clean/short — production calls may be longer and noisier.

---

## Key Invariants (never violate)

| Rule | Correct | Wrong |
|---|---|---|
| Celery tenant_id | Explicit function arg | `self.request.headers.get()` |
| Tenant GUC | `SET LOCAL app.current_tenant` | `SET SESSION` |
| RLS setting | `current_setting('app.current_tenant', true)` | Missing `true` arg |
| Async safety | `ContextVar` | `threading.local()` |
| DB drivers | asyncpg → FastAPI, psycopg2 → Celery | Never cross |
| MinIO hostname | `cq-minio:9000` | `cq_minio:9000` |
| Groq model | `llama-3.3-70b-versatile` | `llama-3.1-*` |
| ORM outside session | Capture all values inside `with SessionLocal()` | Access ORM attrs after block closes |
| Groq fallback trigger | 429 or 503 only | 401 must fail loud — fix the key |
| JWT storage | sessionStorage | localStorage |
