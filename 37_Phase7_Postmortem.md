---
tags: [postmortem, phase7, session]
date: 2026-05-02
status: complete
---

# 37 — Phase 7 Postmortem: Agent Identity Extraction

## What Was Built

### Migration 006 — calls table changes
- `agent_id` made nullable (was NOT NULL)
- `needs_agent_review BOOLEAN NOT NULL DEFAULT FALSE` added
- `agent_name_extracted TEXT` added
- `external_agent_id TEXT` added
- Revision ID: `20260701_agent_identity` (32 chars — revision IDs must be ≤32 chars, alembic_version is VARCHAR(32))
- Applied locally via `alembic upgrade head` run from outside Docker

### ORM — Call model updated
- `agent_id`: `nullable=True`
- `needs_agent_review`: `nullable=False`, `server_default="false"`
- `agent_name_extracted`: `nullable=True`
- `external_agent_id`: `nullable=True`

### extract_agent_identity — new Celery task (io_queue)
- Inserts between `redact_pii` and `compute_talk_balance` in the chain
- Path 1: `external_agent_id` provided at upload → direct DB lookup by `(tenant_id, external_id)` → assign or flag, zero Groq cost
- Path 2: Groq name extraction from first 500 words → rapidfuzz `token_set_ratio` matching → threshold assignment
- rapidfuzz thresholds: ≥90 + clear = auto-assign, 75–89 + clear = auto-assign, <75 or ambiguous = `needs_agent_review=TRUE`
- Ambiguity: `abs(top - second) ≤ 5` → flag regardless of absolute score
- Nickname map: mike→michael, jon→john, liz→elizabeth, bill→william, bob→robert, kate→katherine, nick→nicholas, chris→christopher, dave→david, dan→daniel
- Groq fallback: OpenRouter on 429/503 only

### celery_app.py
- `extract_agent_identity` added to task_routes under `io_queue`

### calls.py — upload endpoint
- `agent_id` changed from required to optional (`Form(None)`)
- `external_agent_id` optional field added
- Chain updated to include `extract_agent_identity` between `redact_pii` and `compute_talk_balance`
- `agent_id=None` calls handled — minio path uses "unassigned" prefix

### calls.py — list and detail
- `list_calls` and `get_call` changed from INNER JOIN to `outerjoin` — null-agent calls now visible
- `_call_to_summary` null-guarded: `agent_id`, `agent_name`, `agent_team`
- `get_call` CallDetail null-guarded: same three fields

### notify_websocket — null guard
- `call_agent_id = str(call.agent_id) if call.agent_id else None`

### requirements.txt
- `rapidfuzz` added

---

## Bugs Caught in Review (pre-run)

| Bug | Severity | Root Cause |
|---|---|---|
| `external_agent_id` column missing from migration + ORM | Critical | Codex wrote tasks.py + calls.py referencing it, never added to schema |
| INNER JOIN hides null-agent calls | Critical | agent_id nullable but join still INNER |
| `get_call` AttributeError on null agent | Critical | CallDetail constructor accessed agent.name/team without null guard |
| `str(None)` in WebSocket payload | Moderate | notify_websocket didn't guard null agent_id |
| `rapidfuzz` missing from requirements.txt | Critical | Codex wrote import, never updated requirements |

---

## Bugs Encountered During Deployment

| Bug | Root Cause | Fix |
|---|---|---|
| `docker exec cq_api alembic upgrade head` hung | `get_sync_url()` replaced `@cq_postgres:` with `@localhost:` — inside Docker, localhost ≠ postgres container | Removed the localhost replace from `env.py` |
| `alembic upgrade head` failed with `ModuleNotFoundError: No module named 'fastapi'` | Running alembic outside Docker on Python 3.14 which lacks project dependencies | Fixed by removing localhost replace so `docker exec` works correctly |
| `StringDataRightTruncation` on `alembic_version` | Revision ID `20260701_agent_identity_extraction` = 34 chars, `alembic_version.version_num` is VARCHAR(32) | Shortened revision ID to `20260701_agent_identity` (22 chars) |
| C drive at 0GB — Docker completely frozen | Docker Desktop WSL2 + Claude app + pip cache filling C drive | Disabled hibernation (freed 6.4GB), cleared pip/npm caches. Docker on N drive already. Required full reboot to unfreeze WSL2. |

---

## Architecture Decisions

### alembic runs inside Docker via `docker exec`
`env.py` must NOT replace `@cq_postgres:` with `@localhost:`. That replacement was for running alembic from the host machine outside Docker, which requires the full project dependencies (fastapi etc.) to be installed locally. Running inside Docker is the correct approach — `cq_postgres` resolves via `cq_network`.

### Revision IDs must be ≤32 characters
`alembic_version.version_num` is `VARCHAR(32)`. All future revision IDs must stay within this limit. Pattern: `YYYYMMDD_shortname` (e.g. `20260701_agent_identity`).

---

## Phase 7 Remaining

| Task | Status |
|---|---|
| Migration 006 | ✅ Applied |
| ORM update | ✅ |
| extract_agent_identity task | ✅ |
| celery_app.py route | ✅ |
| Upload endpoint changes | ✅ |
| calls.py null guards + outerjoin | ✅ |
| requirements.txt rapidfuzz | ✅ |
| PATCH /calls/{id}/assign-agent endpoint | 🔲 |
| Upload form frontend changes | 🔲 |
| "Needs Review" badge on call list | 🔲 |
| Manual assign control in call detail panel | 🔲 |
| E2E smoke test — upload with no agent_id | 🔲 |
