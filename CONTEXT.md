# PROJECT CONTEXT — AI Call Quality & Agent Performance Analytics System

> Universal session starter. Paste this into any LLM at the start of every working session.
> This document is self-contained. No prior conversation history required.

---

## 1. Who is Building This

**Adeen** — Final Year student, BSCS, Bahria University Islamabad, Pakistan.
FYP demo completed April 2026. Now building as a B2B SaaS product.

**Hardware:**
- GPU: NVIDIA RTX 3060 Ti (8GB VRAM), CUDA 12.1.0
- OS: Windows + Docker Desktop + WSL2
- Project path: E:\projects\call-quality-analytics
- Knowledge vault: E:\projects\docs
- Repository: https://github.com/Malik-Adeen/call-quality-analytics

**IDE:** Antigravity (Gemini) for code gen, Claude Code (terminal), Claude for architecture + audit

---

## 2. What the System Does

End-to-end AI pipeline: raw customer service audio → scored agent performance report.

**Outputs per call:**
- Speaker-diarized, PII-redacted transcript (AGENT vs CUSTOMER)
- Five scored metrics: politeness, sentiment delta, resolution, talk balance, clarity
- Composite agent performance score (0–100%)
- AI-generated coaching summary
- Downloadable PDF report
- Real-time WebSocket notification on completion

**Core value:** Automates call center QA. Replaces manual reviewers with GPU-accelerated pipeline.

---

## 3. System Architecture

### 3.1 Deployment — Local Docker (Azure Canada Central is the target)

```
Browser (React Dashboard)
    |
    | HTTP/WebSocket → nginx:80
    v
nginx (frontend/Dockerfile — multi-stage Node→nginx)
    |--- serves React static files (dist/)
    |--- /api/  → proxied to api:8000
    |--- /ws/   → proxied to api:8000/ws/ (WebSocket upgrade)
    v
FastAPI API :8000
    |
    |--- PostgreSQL 16 (postgres_data named volume)
    |--- Redis 7.4-alpine (requirepass, AOF persistence)
    |--- MinIO (webhook model — mc mirror --watch)
    |--- Celery worker_io (io_queue, concurrency=4)
    |--- Celery worker_gpu (gpu_queue, concurrency=1)
```

**Dev compose:** `infra/docker-compose.yml` (volume mounts, 127.0.0.1 ports, Flower)
**Prod compose:** `infra/docker-compose.prod.yml` (no mounts, nginx service, .env.prod)

**Upload model:** Files land in MinIO via mc mirror --watch (Dropbox model).
MinIO fires POST /internal/minio-event → FastAPI creates Call row → Celery chain fires.

**IMPORTANT — Windows Docker file sync delay:** New files written to E:\projects\... may not
appear inside containers immediately. Use `docker compose cp` to copy files directly.

### 3.2 The 7-Stage Pipeline

| Stage | Task | Queue |
|---|---|---|
| 0 | `extract_agent_identity` | `io_queue` |
| 1 | Ingest + MinIO store | API sync |
| 2 | `run_whisperx` | `gpu_queue` |
| 3 | `redact_pii` | `io_queue` |
| 4 | `compute_talk_balance` | `io_queue` |
| 5 | `run_groq_inference` | `io_queue` |
| 6 | `write_scores` | `io_queue` |
| 7 | `notify_websocket` | `io_queue` |

### 3.3 Scoring Formula (weights invariant)

```python
sentiment_delta_normalized = (sentiment_delta + 1.0) / 2.0
agent_score = (
    0.25 * politeness_score +
    0.20 * sentiment_delta_normalized +
    0.20 * resolution_score +
    0.15 * talk_balance_score +
    0.20 * clarity_score
)
display_score = round(agent_score * 10, 2)
```

Score stored 0–10. UI multiplies by 10 to display as percentage.

---

## 4. Technology Stack (frozen)

| Layer | Tech |
|---|---|
| Backend | FastAPI + Celery 5.x + SQLAlchemy 2.x + Pydantic 2.x + Playwright |
| Auth | PyJWT>=2.8.0 (NOT python-jose), slowapi rate limiting |
| AI | WhisperX large-v2 + Pyannote.audio 3.1 + Presidio + Groq llama-3.3-70b-versatile |
| DB | PostgreSQL 16 + asyncpg + Alembic (8 migrations applied) |
| Cache | Redis 7.4-alpine + redis-py (requirepass enabled) |
| Storage | MinIO (pin to real tag before Azure — currently latest) |
| Frontend | React 19 + TypeScript + Vite + TailwindCSS v4 + Recharts + Zustand + motion/react |
| Infra | Docker Compose + nginx (prod) |

**Banned:** Ollama in pipeline, VADER, WeasyPrint, localStorage for JWT, Node.js backend, python-jose

---

## 5. Non-Negotiable Rules

1. Audio binary → MinIO only. Column: `minio_audio_path`. Never PostgreSQL.
2. Raw transcripts → never DB. Only Presidio-redacted text persisted.
3. `pii_redacted = TRUE` before `run_groq_inference` runs.
4. `run_whisperx` → `gpu_queue` only. Concurrency locked to 1.
5. JWT → Zustand sessionStorage. Never localStorage, never a cookie.
6. Groq model: `llama-3.3-70b-versatile`. Never 3.1.
7. MinIO hostname: `cq-minio:9000` (hyphens). Underscores rejected.
8. `DATABASE_URL`: `postgresql+asyncpg://` for API, `postgresql://` for Celery workers.
9. Score: stored 0–10, displayed ×10 as % in UI.
10. Zero code comments. Ever.
11. `SET LOCAL app.current_tenant` per transaction. Never SET SESSION.
12. `write_scores`: delete-before-insert, DELETE scoped by `call_id AND tenant_id`.
13. MinIO webhook auth failure → always return HTTP 200 (prevents infinite retry).
14. Redis requires password. `REDIS_URL` must include `REDIS_PASSWORD`.
15. All service ports bound to `127.0.0.1` in local Docker (nginx handles exposure in prod).
16. Platform admin endpoints use `get_db_platform` (sets `SET LOCAL app.platform_bypass = 'true'`).
17. `SET LOCAL app.platform_bypass = 'true'` is the RLS bypass — never remove from policies.

---

## 6. Database Schema (migrations 001–008 applied)

| Table | Key Columns |
|---|---|
| `tenants` | id, name, slug, plan_tier, settings JSONB |
| `users` | id, tenant_id, name, email, password_hash, role |
| `agents` | id, tenant_id, name, team, email, external_id, is_active |
| `calls` | id, tenant_id, agent_id, minio_audio_path, transcript_redacted, score, status, pii_redacted, needs_agent_review |
| `call_metrics` | id, call_id, tenant_id, politeness_score, sentiment_delta, resolution_score, talk_balance_score, clarity_score |
| `sentiment_timeline` | id, call_id, tenant_id, timestamp_seconds, sentiment_value |

**Alembic head:** `20260526_platform_rls_bypass` (migration 008)
**Roles:** PLATFORM_ADMIN, TENANT_ADMIN, SUPERVISOR, AGENT, VIEWER

**Seeded accounts:**
- `platform@callquality.internal` / `platform1234` — ⚠️ ROTATE BEFORE PRODUCTION
- `admin@callquality.demo` / `admin1234` — TENANT_ADMIN (Demo Tenant)

---

## 7. API Summary

Every endpoint returns: `{"success": true, "data": {}, "error": null, "request_id": "uuid"}`

**Auth** (rate limited): `POST /auth/login` (10/min), `POST /auth/register` (3/hr), `GET /auth/me`

**Calls:** `/calls`, `/calls/{id}`, `/calls/upload`, `PATCH /calls/{id}/assign-agent`

**Platform (PLATFORM_ADMIN only — all use get_db_platform):**
- `GET /platform/tenants` — list all tenants
- `POST /platform/tenants` — create tenant
- `GET /platform/overview` — KPIs + infra status
- `GET /platform/system-health` — workers.gpu/io + queues + failed/stuck
- `GET /platform/usage` — per-tenant daily + summary + kpis
- `GET /platform/calls` — cross-tenant paginated (pagination.total_count)
- `GET /platform/calls/{id}` — cross-tenant call detail

**Internal:** `POST /internal/minio-event` (always 200)
**Reports:** `POST /reports/export` (PDF binary via Playwright)
**WebSocket:** `WS /ws/{user_id}?token=`

---

## 8. Current Build State — v1.9

| Component | Status |
|---|---|
| 7-stage AI pipeline | ✅ Complete |
| React tenant dashboard (9 pages) | ✅ Complete |
| PLATFORM_ADMIN dashboard (5 pages) | ✅ Complete |
| Auth: Register + Login | ✅ Complete |
| Management: Agents, Users, Tenants | ✅ Complete |
| Multi-tenancy RLS (migrations 001–008) | ✅ Complete |
| P0 security: Redis auth, PyJWT, slowapi | ✅ Complete |
| UI P0+P1 accessibility fixes | ✅ Complete |
| pytest skeleton (5 files) | ✅ Complete |
| frontend/Dockerfile (multi-stage) | ✅ Written |
| infra/nginx.conf | ✅ Written |
| infra/docker-compose.prod.yml | ✅ Written |
| .env.prod | ✅ Created (needs secrets rotation) |
| backend/Dockerfile (spaCy wheel fix) | ✅ Fixed |

**Blocked on:** en_core_web_lg-3.8.0-py3-none-any.whl (400MB) download finishing

**Checklist before Azure go-live:**
- [ ] Docker prod build passes cleanly
- [ ] Local smoke test: `http://localhost` loads, login works, /api/ proxy, WebSocket connects
- [ ] .env.prod secrets rotation (all passwords, MINIO_IMAGE_TAG, CORS_ORIGINS → Azure domain)
- [ ] `platform@callquality.internal` password rotated from `platform1234`
- [ ] MinIO image pinned to real tag (not `latest`)
- [ ] Azure VM provisioned — Canada Central, ports 80/443 open
- [ ] `docker compose -f docker-compose.prod.yml up -d` on VM
- [ ] End-to-end test on Azure: upload audio → pipeline → score

---

## 9. Frontend Pages Map

| Route | Component | Role |
|---|---|---|
| `/login` | Login.tsx | Public |
| `/register` | Register.tsx | Public |
| `/` | Overview.tsx | All tenant roles |
| `/calls` | CallList.tsx | All |
| `/calls/:id` | CallDetail.tsx | All |
| `/agents` | Agents.tsx | All |
| `/agents/manage` | AgentManagement.tsx | TENANT_ADMIN, SUPERVISOR |
| `/users` | UserManagement.tsx | TENANT_ADMIN |
| `/upload` | UploadCall.tsx | TENANT_ADMIN, SUPERVISOR |
| `/reports` | Reports.tsx | All |
| `/tenants` | TenantManagement.tsx | PLATFORM_ADMIN |
| `/platform/overview` | PlatformOverview.tsx | PLATFORM_ADMIN |
| `/platform/health` | SystemHealth.tsx | PLATFORM_ADMIN |
| `/platform/usage` | UsageAnalytics.tsx | PLATFORM_ADMIN |
| `/platform/calls` | CallMonitor.tsx | PLATFORM_ADMIN |

**PLATFORM_ADMIN redirect:** `/` → `/platform/overview` (RootRedirect in App.tsx)

---

## 10. Design System — Waaqi GRC Tokens

| Token | Value |
|---|---|
| Primary | #00a99d |
| Sidebar | #0f1924 |
| Page bg | #f5f6f8 |
| Text tertiary | #6b778c (WCAG AA 4.57:1) |
| Success bg/text | #d1fadf / #027a48 |
| Error bg/text | #fee4e2 / #b42318 |
| Font | Inter + JetBrains Mono |

TailwindCSS v4 `@theme` spacing: `--spacing-46/50/54` added for chart heights.

---

## 11. Repository Structure

```
call-quality-analytics/
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── database.py          (get_db, get_db_with_tenant, get_db_platform)
│   │   ├── limiter.py           (slowapi shared instance)
│   │   ├── auth/jwt.py          (PyJWT — not python-jose)
│   │   ├── routers/             auth, calls, agents, reports, ws, users, platform, minio_event
│   │   └── pipeline/tasks.py
│   ├── alembic/versions/        001–008 migrations
│   ├── tests/                   conftest, test_scoring, test_pipeline, test_auth, test_minio_event
│   ├── Dockerfile               (CPU — fixed for spaCy wheel local install)
│   └── Dockerfile.gpu           (CUDA 12.1 — RTX 3060 Ti)
├── frontend/
│   ├── Dockerfile               (multi-stage Node 20 build → nginx:alpine)
│   └── src/ (14 pages + components)
├── infra/
│   ├── docker-compose.yml       (dev)
│   ├── docker-compose.prod.yml  (prod — nginx service, no mounts, .env.prod)
│   ├── nginx.conf               (SPA routing, /api/ + /ws/ proxy)
│   ├── .env                     (dev — gitignored)
│   └── .env.prod                (prod — gitignored, needs secrets rotation)
└── scripts/reset_and_seed.py
```

---

## 12. Roadmap (Locked Order)

1. **Azure deploy** — smoke test → secrets rotation → VM provision → docker compose prod
2. **ROI reporting** — South Asian enterprise buyers need business-case before features
3. **Agentic AI assistant** — NL query layer over PostgreSQL (channel TBD)
