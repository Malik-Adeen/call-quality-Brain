# GRAPH REPORT — AI Call Quality Analytics System
Updated: 2026-06-19 | graphify semantic extraction complete (OpenRouter DeepSeek v3)

---

## Graphify Index (authoritative — updated 2026-06-19)

```
1,061 nodes | 2,320 edges | 63 communities
76% EXTRACTED · 24% INFERRED · 565 inferred edges (avg confidence: 0.52)
Built from commit: 6b6b9bbd
```

Run: `graphify . --update --backend openrouter-ds`
Key: `export OPENROUTER=$(grep "^OPENROUTER" infra/.env | sed "s/.*=[ ]*['\"]*//" | tr -d "'\"\r\n ")`

---

## GitNexus Index (authoritative — updated 2026-06-19)

```
1,598 symbols | 2,224 relationships | 86 clusters | 32 execution flows
```

Run `npx gitnexus analyze` after any significant code change. CLAUDE.md auto-updates.

---

## GOD NODES (highest connectivity)

1. `fileHashes` — 115 edges
2. `User` — 82 edges
3. `Call` — 73 edges
4. `Agent` — 60 edges
5. `CallMetrics` — 54 edges
6. `ApiResponse` — 50 edges
7. `UUID` — 33 edges
8. `Tenant` — 32 edges
9. `app.database` — imported by 8+ files (get_db, get_db_with_tenant, get_db_platform)
10. `app.pipeline.tasks` — central hub: entire 7-stage chain

---

## PIPELINE (sequential — no stage skippable)

```
run_whisperx(gpu_queue) → extract_agent_identity(io_queue) → redact_pii(io_queue)
→ compute_talk_balance(io_queue) → run_groq_inference(io_queue)
→ write_scores(io_queue) → notify_websocket(io_queue)
```

---

## SERVICES (9 containers — docker-compose.azure.yml)

| Container | Image | Purpose |
|---|---|---|
| cq_postgres | postgres:16-alpine | Primary datastore |
| cq_redis | redis:7.4.2-alpine | Celery broker + WebSocket |
| cq_minio | minio/minio | Audio object storage |
| cq_minio_init | minio/mc | Bucket + webhook setup (one-shot) |
| cq_api | Dockerfile | FastAPI + Playwright |
| cq_worker_io | Dockerfile | Celery io_queue (4 concurrent) |
| cq_worker_cpu | Dockerfile.cpu | Celery gpu_queue (1 concurrent, CPU WhisperX) |
| cq_nginx | frontend/Dockerfile | nginx:alpine SPA + /api + /ws proxy |
| cq_flower | mher/flower:2.0 | Queue monitor (127.0.0.1:5555, basic auth) |

---

## COMMUNITIES (55 named, 8 thin omitted)

Backend Documentation · Database Models · Auth Dependencies · Celery Configuration
App Middleware · Execution Pipeline · Call Analytics UI · Design Tokens
Stack Manifest · Analytics Dashboard · API Models · Call UI Components
CLI Tools · Text Processing · Database Migrations · Auth UI
Metadata Index · Agent Management · Data Seeding · Scoring Tests
Call Models · System Architecture · MinIO Tests · Auth API
Agent Analytics · LLM Tasks · Project Documentation · Pipeline Rules
Platform Overview · Model Preflight · Usage Analytics · Migrations Config
System Health · RLS Migration · Tenant DB · Urdu ASR Research
LLM Session · Design Brief · UI Guidelines

---

## KEY RELATIONSHIPS

- `tasks.py::write_scores()` — highest betweenness, bridges pipeline ↔ ORM models
- `tasks.py::notify_websocket()` → Redis pub/sub → WebSocket → browser
- `database.py::get_db_with_tenant()` → set_config() → RLS enforcement → all tenant queries
- `minio_event.py` → MinIO webhook → Call row creation → Celery chain start
- `platform_rls_bypass` migration → modifies tenant_isolation policies on 5 tables
