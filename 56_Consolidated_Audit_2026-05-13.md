---
tags: [audit, security, performance]
date: 2026-05-13
status: active
sources: Claude (direct repo read), Gemini 2.5 Pro (repo_snapshot.xml), DeepSeek static analysis
---

# 56 — Consolidated Audit 2026-05-13

> Three LLMs analyzed the repo independently. This document is the authoritative
> synthesis, cross-referenced against LOG.md and audit_report_20260510.md.
> Already-fixed findings are excluded. Invalid findings are noted at the bottom.

---

## Already Fixed — Not Repeated Here

| Finding | Fixed |
|---|---|
| talk_balance formula | 2026-05-06 |
| Redis AOF persistence | 2026-05-06 |
| write_scores idempotency (delete-before-insert) | 2026-05-06 |
| PDF export missing role gate | 2026-05-10 |
| Email uniqueness missing tenant_id filter | 2026-05-10 |
| VIEWER upload gate (RoleGuard) | 2026-05-10 |
| VIEWER NEW ANALYSIS button | 2026-05-10 |

---

## 🔴 P0 — Security / Data Integrity (fix before Azure deploy)

### S1 — MinIO bucket is world-readable
**File:** `infra/docker-compose.yml:61`
**Evidence:**
```
mc anonymous set download local/audio-uploads
```
Anyone who knows or guesses a minio_audio_path can download raw call audio without authentication.
Presigned URLs are already generated in minio_client.py — this one line is the only reason
public access exists.

**Codex prompt:**
```
In infra/docker-compose.yml, find the minio_init entrypoint shell command.
Remove the line: mc anonymous set download local/audio-uploads
Add in its place: mc anonymous set none local/audio-uploads
No other changes. Zero comments.
```

---

### S2 — generate_presigned_url is not actually signed
**File:** `backend/app/services/minio_client.py:39-43`
**Evidence:**
```python
return f"http://localhost:9000/{self.bucket}/{key}"
```
Returns a hardcoded localhost URL with no signature and no expiry. In any non-local
environment this URL is wrong host, permanent access, and not a valid presigned URL.

**Codex prompt:**
```
In backend/app/services/minio_client.py, rewrite the generate_presigned_url method.
Use:
    return self.client.generate_presigned_url(
        "get_object",
        Params={"Bucket": self.bucket, "Key": key},
        ExpiresIn=expiry,
    )
The endpoint is already set correctly on self.client from __init__.
Do not hardcode localhost. Do not change any other method. Zero comments.
```

---

### S3 — JWT_SECRET defaults to "dummy_secret" in production compose
**File:** `infra/docker-compose.yml` (worker_gpu env section)
**Evidence:**
```yaml
JWT_SECRET=${JWT_SECRET:-dummy_secret}
```
If .env is missing or incomplete on a fresh deploy, the signing key is a publicly known
string. Every JWT issued by that instance is forgeable.

**Codex prompt:**
```
In infra/docker-compose.yml, find all occurrences of:
    JWT_SECRET=${JWT_SECRET:-dummy_secret}
Replace each with:
    JWT_SECRET=${JWT_SECRET}

In backend/app/auth/jwt.py, at module load time add:
    import os
    _secret = os.environ.get("JWT_SECRET", "")
    if not _secret:
        raise RuntimeError("JWT_SECRET is not set")
No other changes. Zero comments.
```

---

### S4 — extract_agent_identity overwrites an explicitly assigned agent_id
**File:** `backend/app/pipeline/tasks.py` (final DB write block of extract_agent_identity)
**Evidence:** The final SessionLocal block unconditionally sets `call.agent_id = final_agent_id`
where `final_agent_id` is None when extraction fails. If a supervisor uploaded the call with
an explicit agent_id, it gets erased.

**Codex prompt:**
```
In backend/app/pipeline/tasks.py, in the extract_agent_identity task, find the final
SessionLocal block that writes call.agent_name_extracted, call.agent_id, and
call.needs_agent_review.

Before writing call.agent_id, add a guard:
    if call.agent_id is not None:
        call.agent_name_extracted = raw_content
        call.needs_agent_review = False
        return segments

Only proceed to overwrite call.agent_id if call.agent_id is currently None.
Zero comments.
```

---

### S5 — get_db_with_tenant SET LOCAL issued outside active transaction
**File:** `backend/app/database.py:55-62`
**Status:** OPEN — confirmed FAIL in audit_report_20260510.md AGENT 2, not yet fixed.
**Evidence:**
```python
await db.execute(text("SET LOCAL app.current_tenant = :tid"), {"tid": tenant_id})
```
SET LOCAL requires an active PostgreSQL transaction. asyncpg uses autobegin — no transaction
exists until the first query. SET LOCAL issued before any query silently degrades to
session-level SET on some asyncpg versions, meaning tenant context leaks across
pooled connections.

**Codex prompt:**
```
In backend/app/database.py, in the get_db_with_tenant async generator:
Replace the bare await db.execute(text("SET LOCAL ...")) call with:
    async with db.begin():
        await db.execute(text("SET LOCAL app.current_tenant = :tid"), {"tid": tenant_id})
This ensures SET LOCAL is issued inside an active transaction.
Zero comments.
```

---

## 🔴 P0 — Pipeline Correctness

### P1 — GPU worker missing --prefetch-multiplier=1
**File:** `infra/docker-compose.yml:127`
**Evidence:**
```yaml
command: celery -A app.celery_app worker -Q gpu_queue --loglevel=info --concurrency=1 --max-tasks-per-child=1
```
Default Celery prefetch is 4. The gpu_queue worker reserves up to 4 tasks from the broker
while only able to process 1. The other 3 are held invisibly, blocking them from any
other worker. This is a silent queue stall on a single-GPU machine.

**Codex prompt:**
```
In infra/docker-compose.yml, find the worker_gpu service command.
Append --prefetch-multiplier=1 to the celery worker command string.
No other changes. Zero comments.
```

---

### P2 — Pipeline stages 1–5 do not set status=failed on final task failure
**File:** `backend/app/pipeline/tasks.py`
**Evidence:** Only write_scores has a try/except that sets call.status = "failed".
If run_whisperx, extract_agent_identity, redact_pii, compute_talk_balance, or
run_groq_inference exhausts all Celery retries and raises, the call stays in
status = "processing" forever. Manual psql intervention required (documented in handoff).

**Codex prompt:**
```
In backend/app/pipeline/tasks.py, after the SessionLocal import, add a Celery task
failure signal handler:

from celery.signals import task_failure

@task_failure.connect
def _on_task_failure(sender=None, task_id=None, exception=None, args=None,
                     kwargs=None, traceback=None, einfo=None, **kw):
    from app.models.orm import Call
    from sqlalchemy import text
    if not args or len(args) < 2:
        return
    call_id = args[0]
    tenant_id = args[1]
    if not call_id or not tenant_id:
        return
    with SessionLocal() as db:
        with db.begin():
            db.execute(text("SET LOCAL app.current_tenant = :tid"), {"tid": tenant_id})
            call = db.get(Call, call_id)
            if call and call.status not in ("complete", "failed"):
                call.status = "failed"

Zero comments.
```

---

### P3 — notify_websocket uses deprecated asyncio.get_event_loop()
**File:** `backend/app/pipeline/tasks.py` (notify_websocket task body)
**Evidence:**
```python
try:
    loop = asyncio.get_event_loop()
except RuntimeError:
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
loop.run_until_complete(manager.broadcast(tenant_id, payload))
```
asyncio.get_event_loop() is deprecated in Python 3.10+ in non-main threads.
Celery workers run in threads. On Python 3.12 this can raise RuntimeError.

**Codex prompt:**
```
In backend/app/pipeline/tasks.py, in the notify_websocket task body:
Find the entire try/except asyncio block and the loop.run_until_complete call.
Replace all of it with a single line:
    asyncio.run(manager.broadcast(tenant_id, payload))
Keep the import asyncio line at the top of the file. Zero comments.
```

---

## 🟡 P1 — Code Quality / Correctness

### Q1 — _inference_cache is an unbounded memory leak
**File:** `backend/app/services/llm_client.py:74`
Process-local, never evicted, grows indefinitely. Cross-worker cache hits are impossible
(separate processes). On a long-running worker_io process this leaks memory slowly.

**Codex prompt:**
```
In backend/app/services/llm_client.py:
Remove the _inference_cache dict declaration.
Remove the _cache_key function.
In run_inference, remove the cache hit check block and the cache assignment line.
No other changes. Zero comments.
```

---

### Q2 — call_metrics has no UNIQUE constraint on call_id
**File:** `backend/app/models/orm.py:66`
ORM declares `uselist=False` (one-to-one) but the table has no UNIQUE(call_id) constraint.
If write_scores fires twice concurrently due to a broker visibility timeout, two CallMetrics
rows are created and the ORM returns one arbitrarily.

**Codex prompt:**
```
Create a new Alembic migration file:
backend/alembic/versions/20260513_call_metrics_unique_call_id.py

The upgrade adds:
    op.create_unique_constraint("uq_call_metrics_call_id", "call_metrics", ["call_id"])
The downgrade drops it. Zero comments.
```

---

### Q3 — React version drift: package.json has React 19, INVARIANTS says React 18
**File:** `frontend/package.json:17`
```json
"react": "^19.2.4"
```
INVARIANTS.md frozen stack declares React 18. Package was silently upgraded.
All 9 pages are live and working, so React 19 is de facto in use.

**Decision:** Accept React 19. Update INVARIANTS.md frozen stack line to React 19.

---

### Q4 — /me endpoint returns empty tenant_name
**File:** `backend/app/routers/auth.py`
```python
tenant_name="",
```
/auth/login correctly fetches and returns tenant name. /auth/me hardcodes empty string.
Any UI component calling /me to refresh user context gets a blank tenant name.

**Codex prompt:**
```
In backend/app/routers/auth.py, in the /me endpoint handler:
Add db: AsyncSession = Depends(get_db) to the function parameters.
Before building the UserOut response, add:
    tenant_result = await db.execute(select(Tenant).where(Tenant.id == current_user.tenant_id))
    tenant = tenant_result.scalar_one_or_none()
    tenant_name = tenant.name if tenant else ""
Use tenant_name in the UserOut instead of "".
Zero comments.
```

---

## 🟡 P2 — Performance

### PERF1 — Missing composite indexes for tenant dashboard queries
No migration exists for these. All dashboard queries filter by tenant_id + created_at or
tenant_id + status. Single-column indexes exist but without tenant_id prefix they require
full scans filtered by RLS at scale.

**Codex prompt:**
```
Create a new Alembic migration file:
backend/alembic/versions/20260513_composite_indexes.py

The upgrade adds:
    op.create_index("idx_calls_tenant_created", "calls", ["tenant_id", text("created_at DESC")])
    op.create_index("idx_calls_tenant_status", "calls", ["tenant_id", "status", text("created_at DESC")])
    op.create_index("idx_calls_tenant_agent", "calls", ["tenant_id", "agent_id", text("created_at DESC")])
    op.create_index("idx_call_metrics_tenant", "call_metrics", ["tenant_id", "call_id"])
    op.create_index("idx_sentiment_tenant", "sentiment_timeline", ["tenant_id", "call_id"])
The downgrade drops them. Zero comments.
```

---

### PERF2 — Upload reads entire file into memory before streaming to MinIO
**File:** `backend/app/routers/calls.py:371`
100MB file buffered in memory before size check. Should stream to MinIO.
Priority: Low for current load. Address before Azure deploy with concurrent uploads.

---

### PERF3 — PDF export launches new Chromium process per request
**File:** `backend/app/routers/reports.py:23-32`
Playwright launches and closes a full browser per export. At scale, concurrent exports
each spawn a Chromium process. Move render_html_to_pdf to a Celery task on io_queue.
Priority: Low for current load.

---

## 🟢 Accepted / Won't Fix

| Finding | Reason |
|---|---|
| Raw transcript sent to Groq in extract_agent_identity | BY DESIGN — extract_agent_identity MUST precede redact_pii per INVARIANTS. Agent names are redacted as PERSON by Presidio so they cannot be extracted post-redaction. Accepted tradeoff. |
| JWT token as WebSocket query param | Low risk over HTTPS in production. Sec-WebSocket-Protocol workaround is non-standard. Accepted for v1. |
| Whisper models loaded fresh per call | CORRECT by design. --max-tasks-per-child=1 restarts the worker process after each GPU task to prevent VRAM leaks. Caching across tasks is impossible and undesirable. |
| FORCE RLS superuser bypass | INVALID finding (from Gemini + DeepSeek). Migration 20260501_force_rls.py applies FORCE ROW LEVEL SECURITY to all 5 tables. Superuser IS subject to RLS. Confirmed PASS in audit_report_20260510.md AGENT 2. |
| VRAM leakage in whisper_service.py | INVALID finding. whisper_service.py already does del model + _cuda_cleanup() after every model use. |

---

## Summary Table

| ID | Severity | File | Status |
|---|---|---|---|
| S1 | 🔴 CRITICAL | docker-compose.yml | Open |
| S2 | 🔴 CRITICAL | minio_client.py | Open |
| S3 | 🔴 CRITICAL | docker-compose.yml | Open |
| S4 | 🔴 CRITICAL | pipeline/tasks.py | Open |
| S5 | 🔴 CRITICAL | database.py | Open (from 2026-05-10) |
| P1 | 🔴 HIGH | docker-compose.yml | Open |
| P2 | 🔴 HIGH | pipeline/tasks.py | Open |
| P3 | 🔴 HIGH | pipeline/tasks.py | Open |
| Q1 | 🟡 MEDIUM | llm_client.py | Open |
| Q2 | 🟡 MEDIUM | orm.py + migration | Open |
| Q3 | 🟡 MEDIUM | package.json | Decision: accept React 19 |
| Q4 | 🟡 MEDIUM | auth.py | Open |
| PERF1 | 🟡 MEDIUM | migration needed | Open |
| PERF2 | 🟢 LOW | calls.py | Deferred to Azure |
| PERF3 | 🟢 LOW | reports.py | Deferred to Azure |

---

## Recommended Fix Order (one session)

1. S1 + S2 — MinIO security (2 line changes, highest impact)
2. S3 — JWT_SECRET hardening (1 line + 1 assertion)
3. P1 — GPU prefetch (1 flag added to compose command)
4. P3 — asyncio.run() fix (3 lines → 1 line)
5. S4 — agent_id preservation guard
6. P2 — task_failure signal handler
7. S5 — SET LOCAL transaction wrap
8. Q1 — remove _inference_cache
9. Q4 — /me tenant_name fix
10. Q2 + PERF1 — Alembic migrations (can be one migration file)
11. Q3 — Update INVARIANTS.md to accept React 19
