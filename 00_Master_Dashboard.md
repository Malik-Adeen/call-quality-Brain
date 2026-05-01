---
tags: [moc, dashboard]
status: active
created: 2026-04-11
updated: 2026-05-01
---

# 00 — Master Dashboard

> Single entry point for the entire knowledge vault.
> Read this first at the start of any working session.
> For LLM sessions: Claude reads [[GRAPH_REPORT]] via filesystem (fastest) or paste [[INVARIANTS]] (500 tokens).

---

## Project Identity

| Property | Value |
|---|---|
| System | AI Call Quality & Agent Performance Analytics System |
| Type | B2B SaaS product (pivoted from FYP — April 30, 2026) |
| Builder | Malik Adeen — BSCS, Bahria University Islamabad |
| Repo | https://github.com/Malik-Adeen/call-quality-analytics |
| Local path | N:\projects\call-quality-analytics |
| Vault | N:\projects\docs |
| Cloud | None — Azure resources deleted (credits exhausted). Building cloud-agnostic locally. |
| FYP demo | Completed — week of April 21, 2026 |
| Instructor confirmed | Phase 5 → 6 → 7. CRM + Priority deferred. (2026-04-30) |

---

## Build State — v1.5 (Phase 5 DB Layer Complete)

| Phase | Description | Status | Notes |
|---|---|---|---|
| 1 | Foundation — Auth, Upload, Docker, Celery | ✅ | [[07_Phase1_Postmortem]] |
| 2.1 | WhisperX GPU + Pyannote diarization | ✅ | [[08_Phase2.1_Postmortem]] |
| 2.2 | Presidio PII redaction gate | ✅ | [[09_Phase2.2_Postmortem]] |
| 2.3 | Groq LLM inference | ✅ | [[11_Phase2.3_Postmortem]] |
| 2.4 | Scoring + chain + WebSocket | ✅ | [[12_Phase2.4_Postmortem]] |
| 2 E2E | Full pipeline end-to-end verified | ✅ | [[13_Phase2_E2E_Postmortem]] |
| Audit | Security fixes | ✅ | [[14_Audit_Fixes]] |
| 3A | Backend read endpoints | ✅ | [[16_Phase3A_Read_Endpoints]] |
| 3 | React dashboard — 6 pages | ✅ | [[17_Phase3_Frontend]] |
| UI | Light parchment redesign | ✅ | [[21_UI_Redesign_Postmortem]] |
| 4 | PDF + Azure B2s + Hybrid SSH tunnel | ✅ (Azure deleted) | [[23_Phase4_Postmortem]] |
| Hybrid | SSH tunnel + WAN Celery tuning | ✅ (Azure deleted) | [[24_Hybrid_Architecture_Postmortem]] |
| Audio | 5 real call recordings verified | ✅ | [[26_Audio_Testing_Postmortem]] |
| PII+ | Extended Presidio recognizers | ✅ | [[27_Presidio_Extension_Postmortem]] |
| **Phase 5 — DB** | **Migrations 001–003: tenants table, tenant_id, RLS** | ✅ | [[35_Session_Handoff_2026-05-01]] |
| **Phase 5 — Auth** | **JWT tenant_id claim + ContextVar middleware** | 🔄 Next | [[34_Final_Implementation_Plan]] |
| **Phase 5 — Workers** | **Celery tenant injection + MinIO path change** | 🔲 | [[34_Final_Implementation_Plan]] |
| **Phase 6** | **Agent Integration (roster sync)** | 🔲 | [[33_SaaS_Implementation_Plan]] |
| **Phase 7** | **Agent Identity Extraction from Audio** | 🔲 | [[33_SaaS_Implementation_Plan]] |
| Phase 8 | CRM Integration — DEFERRED | ⏸ | [[30_SaaS_Pivot_Plan]] |
| Phase 9 | High / Low Priority Customers — DEFERRED | ⏸ | [[30_SaaS_Pivot_Plan]] |

---

## Phase 5 Detailed Checklist

```
[x] Migration 001 — tenants table
[x] Migration 002 — tenant_id on all 5 tables (backfill + NOT NULL + FK + index)
[x] Migration 003 — RLS policies + role update (ADMIN → TENANT_ADMIN)
[ ] jwt.py — add tenant_id param to create_access_token
[ ] dependencies.py — validate tenant_id in get_current_user, set request.state.tenant_id
[ ] auth.py router — pass tenant_id to create_access_token on login
[ ] database.py — get_db_with_tenant() dependency (SET LOCAL per transaction)
[ ] main.py — tenant middleware registration
[ ] tasks.py — SET LOCAL at start of every Celery task
[ ] celery_app.py — add extract_agent_identity to routes (Phase 7 prep)
[ ] MinIO path — change to {tenant_id}/{call_id}.mp3
[ ] orm.py — add Tenant model + tenant_id FK to all 5 ORM models
[ ] POST /platform/tenants — new endpoint (PLATFORM_ADMIN only)
[ ] FORCE ROW LEVEL SECURITY — add after middleware is verified working
[ ] reset_and_seed.py — make tenant-aware
```

---

## Alembic State

| Migration | Revision ID | Status |
|---|---|---|
| 001 Create tenants | `20260501_create_tenants` | ✅ Applied |
| 002 Add tenant_id | `20260501_add_tenant_id` | ✅ Applied |
| 003 RLS + roles | `20260501_enable_rls` | ✅ Applied |

Current head: `20260501_enable_rls`

Run migrations: `cd backend && alembic upgrade head`

---

## LLM Context Loading (fastest to slowest)

| Method | Tokens | How |
|---|---|---|
| `GRAPH_REPORT.md` via filesystem | ~1,100 | Claude reads directly — no paste needed |
| `INVARIANTS.md` paste | ~500 | For Qwen/Gemini sessions |
| `CONTEXT.md` paste | ~2,500 | Full architecture for complex decisions |
| Full vault paste | ~30,000 | Gemini 1.5 Pro only (free, 1M context) |

Update graph after code changes: `python scripts/build_graph.py`

---

## Startup Runbook

All services run locally. Hybrid/Azure runbooks are historical — Azure VM deleted.

```
docker compose -f infra/docker-compose.yml up -d
```

GPU worker runs in the same compose stack locally (no SSH tunnel needed).

---

## How Claude Works In This Project

- **Codex / Copilot** writes all code
- **Claude** reviews every generated file before it runs — checks against checklists in [[34_Final_Implementation_Plan]]
- **Workflow:** generate → paste to Claude → review → approve/fix → run
- Claude does NOT generate implementation code directly

---

## Architecture (current — all local)

```
Browser → Vite dev server → FastAPI (local Docker)
                                ↕ Celery queues (local Redis)
                           Local RTX 3060 Ti (worker_gpu · WhisperX large-v2)
                           Local PostgreSQL + MinIO (Docker)
```

Full spec: [[01_Master_Architecture]] · GPU: [[10_GPU_Infrastructure]]

---

## Critical Invariants (full list: [[INVARIANTS]])

1. Audio → `minio_audio_path`, never PostgreSQL
2. Raw transcript → never DB, Presidio-redacted only
3. `pii_redacted=TRUE` before `run_groq_inference`
4. `run_whisperx` → `gpu_queue`, concurrency=1
5. JWT → sessionStorage, never localStorage
6. Groq: `llama-3.3-70b-versatile`
7. MinIO: `cq-minio:9000` (hyphens, never underscores)
8. Score: stored 0–10, displayed ×10 as %
9. Zero code comments
10. `SET LOCAL app.current_tenant` per transaction — never `SET SESSION`
11. `current_setting('app.current_tenant', true)` — `true` arg mandatory
12. `ContextVar` for async tenant propagation — never `threading.local()`
13. FastAPI → `postgresql+asyncpg://` | Celery workers → `postgresql://` (psycopg2)
14. `expire_on_commit=False` on async session factory

---

## Vault Index

| File | Purpose |
|---|---|
| [[GRAPH_REPORT]] | Auto-generated knowledge graph |
| [[CONTEXT]] | Universal LLM context — paste into any chat |
| [[INVARIANTS]] | 500-token rules block |
| [[ROADMAP]] | B2B SaaS phase planning |
| [[30_SaaS_Pivot_Plan]] | Pivot declaration, feature specs, research |
| [[33_SaaS_Implementation_Plan]] | Confirmed scope (Phase 5→6→7) with checklists |
| [[34_Final_Implementation_Plan]] | Research-complete implementation plan + review checklists |
| [[35_Session_Handoff_2026-05-01]] | Last session handoff — start here |
| [[32_Windows_Reinstall_Backup_Guide]] | Pre-reinstall backup checklist |
| [[STARTUP_LOCAL]] | All-local Docker startup runbook |
| [[01_Master_Architecture]] | Stack manifest, pipeline, scoring formula |
| [[02_Database_Schema]] | PostgreSQL schema (pre-Phase 5 baseline) |
| [[03_API_Contract]] | All endpoint shapes + TypeScript interfaces |
| [[10_GPU_Infrastructure]] | CUDA, Docker, cache paths |
| [[20_New_Design_System]] | Light parchment design tokens |
| [[06_Urdu_ASR_Research]] | Historical — dropped scope |
