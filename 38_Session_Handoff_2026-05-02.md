---
tags: [handoff, session, phase7]
date: 2026-05-02
status: handoff
---

# 38 — Session Handoff 2026-05-02 (Phase 7 Backend Complete)

## Current State — v1.7

**Alembic head:** `20260701_agent_identity`

**What works:**
- All local Docker — Azure deleted, cloud-agnostic compose stack
- Migration 006 applied: `agent_id` nullable, `needs_agent_review`, `agent_name_extracted`, `external_agent_id` on calls table
- Phase 7 backend complete: `extract_agent_identity` task live in pipeline
- Pipeline chain: run_whisperx → redact_pii → extract_agent_identity → compute_talk_balance → run_groq_inference → write_scores → notify_websocket
- Upload endpoint: agent optional, external_agent_id optional
- Notion supervisor dashboard created: https://www.notion.so/354506f0067381cbb715d3f5356cac20

**What still needs doing — Phase 7 frontend only:**
- `PATCH /calls/{id}/assign-agent` endpoint (backend, small)
- Upload form: agent dropdown optional, `external_agent_id` field, label change
- Call list: yellow "Needs Review" badge when `needs_agent_review = TRUE`
- Call detail panel: supervisor manual assign control
- E2E smoke test: upload with no agent, verify pipeline, verify DB result

---

## How to Start the System (All Local)

```powershell
cd N:\projects\call-quality-analytics\infra
docker compose up -d
```

Wait 30 seconds for postgres, then verify:
```powershell
docker logs cq_worker_gpu --tail 5
docker logs cq_worker_io --tail 5
```

Frontend:
```powershell
cd N:\projects\call-quality-analytics\frontend
npm run dev
```

Dashboard: http://localhost:5173
Login: admin@callquality.demo / admin1234

---

## Alembic Migration History

| Revision ID | Description | Status |
|---|---|---|
| `20260501_create_tenants` | Create tenants table | ✅ |
| `20260501_add_tenant_id` | tenant_id on all 5 tables + backfill | ✅ |
| `20260501_enable_rls` | RLS policies on all 5 tables | ✅ |
| `20260501_force_rls` | FORCE RLS on all tables | ✅ |
| `20260601_add_agent_sync_columns` | external_id, is_active, email on agents | ✅ |
| `20260701_agent_identity` | agent_id nullable, needs_agent_review, agent_name_extracted, external_agent_id on calls | ✅ |

**CRITICAL: All future revision IDs must be ≤32 characters** (alembic_version.version_num is VARCHAR(32))

---

## Key Invariants Added This Session

| Rule | Correct | Wrong |
|---|---|---|
| Alembic runs via docker exec | `docker exec cq_api alembic upgrade head` | Running from host (missing fastapi dependency) |
| env.py get_sync_url() | Strip asyncpg prefix only | Do NOT replace @cq_postgres with @localhost |
| Revision ID length | ≤32 characters | Full descriptive names that exceed 32 chars |

All prior invariants from [[36_Session_Handoff_2026-05-02]] still apply.

---

## Files Changed This Session

```
backend/alembic/versions/20260701_agent_identity_extraction.py   (NEW — migration 006)
backend/alembic/env.py                                            (MODIFIED — removed localhost replace)
backend/app/models/orm.py                                         (MODIFIED — Call: 4 new columns)
backend/app/pipeline/tasks.py                                     (MODIFIED — extract_agent_identity task)
backend/app/celery_app.py                                         (MODIFIED — new task route)
backend/app/routers/calls.py                                      (MODIFIED — optional agent, outerjoin, null guards)
backend/requirements.txt                                          (MODIFIED — rapidfuzz added)
docs/37_Phase7_Postmortem.md                                      (NEW)
docs/38_Session_Handoff_2026-05-02.md                             (THIS FILE)
```

---

## For the Next LLM Session

Load these files:
1. `GRAPH_REPORT.md` — via filesystem (Claude reads directly)
2. `38_Session_Handoff_2026-05-02.md` — this file
3. `39_Frontend_Session_Prompt.md` — complete frontend session prompt with skill instructions, Playwright MCP workflow, and Codex prompts for all 4 tasks

The frontend session prompt is self-contained — paste it as the first message and it has everything needed.
