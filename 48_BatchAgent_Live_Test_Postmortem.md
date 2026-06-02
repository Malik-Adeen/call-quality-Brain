---
tags: [postmortem, batchagent, live-test]
date: 2026-05-08
status: complete — all steps passed (2026-05-09)
---

# 48 — BatchAgent Live Test Postmortem

> Session: May 8 2026. Claude Code used for execution.
> Context loaded: CONTEXT.md + INVARIANTS.md + 44_Session_Handoff_Next.md

---

## Environment

- Fresh Windows reinstall (May 8 2026)
- Docker Desktop moved to E:\docker\data during this session
- worker_gpu NOT running — deferred pending Docker disk migration
- All other services healthy at session start

---

## Results by Step

| Step | Result | Notes |
|---|---|---|
| 1 — Pre-flight | PASS | VRAM 6774 MiB free. All 5 core containers running. |
| 2 — JWT | PASS | Token obtained from admin@callquality.demo |
| 3 — .env keys | PASS | All 4 keys present. BATCH_AGENT_TOKEN written. |
| 4 — Watch folder | PASS | C:\Users\adeen\Desktop\batch_audio created |
| 5 — BatchAgent start | PASS | Built and started. "Watching /watch" confirmed in logs. |
| 6 — Drop test file | PASS | "Uploaded billing_dispute.mp3" confirmed in logs |
| 7 — Pipeline verification | PASS | score=88%, needs_agent_review=true, agent_id=null, Jolene detected high confidence |
| 8 — Dedup test | PASS | Silent skip confirmed across restart — SQLite manifest persisted correctly |

---

## Bugs Found and Fixed

### Bug 1 — POST /calls/upload returning HTTP 200 instead of 202

**File:** backend/app/routers/calls.py

**Root cause:** `@router.post("/upload", ...)` had no `status_code=202` on the decorator.
BatchAgent `upload_with_retry` only treats HTTP 202 as success. On 200 it retried
3 times then logged `Upload failed after retries: billing_dispute.mp3`.

**Fix:** Added `status_code=202` to the route decorator.

**Impact:** Without this fix, BatchAgent silently fails on every upload despite the
API accepting the file.

---

### Bug 2 — needs_agent_review never set at upload time

**File:** backend/app/routers/calls.py (Call constructor in upload endpoint)

**Root cause:** The Call ORM object was constructed without setting `needs_agent_review`.
The field defaulted to False. The pipeline's `extract_agent_identity` task sets it
post-processing, but calls uploaded without an agent_id should be immediately flagged.

**Fix:** Added `needs_agent_review=(agent_id is None)` to the Call constructor.

**Impact:** Supervisor dashboard would never show unassigned calls as needing review
until the full pipeline completed. Calls uploaded without agent_id now correctly
surface in the review queue immediately.

---

## Incident — DB Wiped by Docker Compose Network Recreation

**What happened:** Running `docker compose up --build cq_batch_agent` caused Docker
Compose to recreate `infra_cq_network`. All containers were treated as new,
including Postgres. The existing migrated DB was lost.

**Root cause:** Docker Compose recreates the network when the compose project name
or network config changes between runs — this occurred because the batch_agent
service was being added for the first time.

**Recovery:** Ran `alembic upgrade head` (6 migrations) followed by
`python scripts/reset_and_seed.py`. DB restored to 200 seeded calls.

**Prevention:** Always run `docker compose up -d --no-recreate` when adding a
single new service to avoid network recreation. Or use `docker compose up -d
--build cq_batch_agent` only after all other services are confirmed healthy
and the network already exists.

---

## Docker Disk Migration (same session)

Docker Desktop's WSL2 virtual disk was on C:\ consuming ~15GB during worker_gpu
image pull (CUDA base layers).

**Action taken:** Docker Desktop → Settings → Resources → Advanced → Disk image
location changed to `E:\docker\data`. Applied and restarted.

**docker-compose.yml updated:** worker_gpu cache mounts changed from
`C:\Users\adeen\.cache\` to `E:\projects\model-cache\`.

**Result:** All future image pulls and volume data go to E:\. C:\ protected.

---

## Completion Note

All steps completed 2026-05-09. BatchAgent single-tenant test fully verified.
Next: BatchAgent multi-tenant evolution per 46_BatchAgent_MultiTenant_Plan.md.
