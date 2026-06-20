# PROJECT CONTEXT — AI Call Quality & Agent Performance Analytics System

> Universal session starter. Paste this into any LLM (Claude, GPT, Gemini, Codex, etc.)
> at the start of every working session. No prior conversation history required.
> This document is self-contained. The LLM reading this has everything needed to help.

---

## 1. Who is Building This

**Adeen** — Final Year student, BSCS, Bahria University Islamabad, Pakistan.
This began as his Final Year Project (FYP). The FYP demo was completed in April 2026.
The project is now being built out as a **B2B SaaS product** for call center analytics.

**Dev machine:**
- CPU: AMD Ryzen 5 3600
- GPU: NVIDIA RTX 3060 Ti (8GB VRAM), CUDA 12.1.0
- OS: Fedora Linux (daily driver) + Windows (secondary)
- Repository: https://github.com/Malik-Adeen/call-quality-analytics

**Workflow:**
- Claude Code = architect, auditor, prompt writer (for Codex and Antigravity), code executor and file editor
- Antigravity (CLI) = React component generation, Frontend Dev
- Codex CLI = Backend Dev, code generation

---

## 2. What the System Does

An end-to-end AI pipeline that takes a raw customer service audio call and produces:
- A full speaker-diarized, PII-redacted transcript (AGENT vs CUSTOMER)
- Five scored performance metrics (politeness, sentiment delta, resolution, talk balance, clarity)
- A composite agent performance score (0–100%)
- An AI-generated coaching summary with specific improvement recommendations
- A downloadable PDF report
- Real-time WebSocket notification when scoring completes

**Core value proposition:** Automates call center quality assurance. Replaces manual human
reviewers with an ASR + LLM scoring pipeline. Multi-tenant SaaS model.

---

## 3. System Architecture — v1.7 (Azure B4ms CPU-Only)

### 3.1 Deployment Topology

```
Browser (React Dashboard)
    |
    | HTTP/WebSocket (port 80)
    v
Azure B4ms VM — East US (4 vCPU, 16GB RAM, ~$0.19/hr)
    |- nginx:alpine            :80    (SPA serve + /api proxy + /ws proxy)
    |- FastAPI API (cq-api)    :8000  (internal only — never public)
    |- PostgreSQL 16           :5432  (127.0.0.1 only)
    |- Redis 7.4-alpine        :6379  (127.0.0.1 only, requirepass, AOF)
    |- MinIO                   :9000  (127.0.0.1 only)
    |- Celery worker_io               (io_queue, CPU tasks, concurrency=4)
    |- Celery worker_cpu              (gpu_queue, WhisperX CPU, concurrency=1)
    |- Flower 2.0              :5555  (127.0.0.1 only, basic auth)
    |- minio_init                     (one-shot bucket + webhook config)
```

All 9 services run in Docker Compose via `infra/docker-compose.azure.yml`.
Port 80 is the only public port. Port 8000 is intentionally NOT exposed.
The former hybrid SSH-tunnel architecture (Azure B2s + local GPU) is retired.

See [[11_Azure_Deployment]] for the full Azure runbook.

### 3.2 Upload Model (MinIO Webhook)

Files land in MinIO via `mc mirror --watch` (Dropbox-style).
MinIO fires `POST /internal/minio-event` → FastAPI creates Call row → Celery chain fires.
No batch agent. No polling. No SQLite manifest.

### 3.3 The 7-Stage Pipeline

Every upload triggers this exact sequence. No stage can be skipped. Stage 3 is a security gate.

| Stage | Task | Queue | Description |
|---|---|---|---|
| 1 | `run_whisperx` | `gpu_queue` | Transcribe + diarize → JSON segments with AGENT/CUSTOMER labels |
| 2 | `extract_agent_identity` | `io_queue` | Parse agent name/ID from transcript before PII redaction |
| **3** | **`redact_pii`** | `io_queue` | **Presidio PII gate — raw text NEVER hits the DB** |
| 4 | `compute_talk_balance` | `io_queue` | Word-count ratio between AGENT and CUSTOMER |
| 5 | `run_groq_inference` | `io_queue` | LLM scores 5 metrics + generates coaching summary |
| 6 | `write_scores` | `io_queue` | Atomic PostgreSQL transaction — all metrics written together |
| 7 | `notify_websocket` | `io_queue` | `call_complete` event → connected browser clients |

`extract_agent_identity` MUST run before `redact_pii` — agent names are PII and get redacted as `<PERSON>`.

### 3.4 Scoring Formula (weights invariant)

```python
sentiment_delta_normalized = (sentiment_delta + 1.0) / 2.0

agent_score = (
    0.25 * politeness_score           +
    0.20 * sentiment_delta_normalized +
    0.20 * resolution_score           +
    0.15 * talk_balance_score         +
    0.20 * clarity_score
)

display_score = round(agent_score * 10, 2)   # stored as 0-10, displayed as 0-100%
```

---

## 4. Full Technology Stack

### Backend
FastAPI (Python 3.11) · Celery 5.x · Redis 7.4-alpine · MinIO · PostgreSQL 16 · SQLAlchemy 2.x · Pydantic 2.x · Playwright

### Auth
PyJWT>=2.8.0 + slowapi (rate limiting) · Never python-jose (CVE-2024-33664)

### AI / ML
WhisperX (small model on CPU, ~60-90s/call on B4ms) · Pyannote.audio 3.1 (diarization, CPU) · Microsoft Presidio (extended) · Groq `llama-3.3-70b-versatile` · OpenRouter fallback

### Frontend
React 19 + TypeScript · Vite · TailwindCSS v4 · Recharts · Zustand (sessionStorage) · motion/react ^12.40.0 · Axios

### Design System (Waaqi GRC tokens)
- Primary: `#00a99d` (teal)
- Sidebar: `#0f1924` (dark navy)
- Fonts: Inter (body) + JetBrains Mono (scores/timestamps)

### Infrastructure
Docker Compose (9 services) · nginx:alpine (SPA + reverse proxy) · Flower 2.0

### Banned Tools
Ollama (in pipeline), VADER, WeasyPrint, localStorage for JWT, python-jose, Node.js backend, raw transcripts in DB, audio blobs in DB

---

## 5. Non-Negotiable Rules

1. **Audio binary** → MinIO only. Column: `minio_audio_path`. Never store audio in PostgreSQL.
2. **Raw transcripts** → never written to the database. Only Presidio-redacted text is persisted.
3. **`pii_redacted = TRUE`** must be set before `run_groq_inference` runs.
4. **`run_whisperx`** → `gpu_queue` exclusively. Concurrency locked to 1.
5. **JWT** lives in Zustand sessionStorage. Never localStorage, never a cookie.
6. **Groq model** is `llama-3.3-70b-versatile`. Never use 3.1 — deprecated, 400 error.
7. **MinIO hostname** is `cq-minio:9000` with hyphens. Underscores rejected by botocore.
8. **DATABASE_URL** uses `postgresql+asyncpg://` for the API, `postgresql://` for Celery workers.
9. **Score display**: backend stores 0–10, UI multiplies by 10 to show percentage.
10. **Zero code comments** — ever. Self-documenting code only.
11. **SET LOCAL app.current_tenant** per transaction. Never SET SESSION.
12. **REDIS_URL** must include `REDIS_PASSWORD`.
13. **MinIO webhook auth failure** → always return HTTP 200 (prevents infinite retry loop).
14. **Platform admin endpoints** → `get_db_platform` dependency only.
15. **SET LOCAL app.platform_bypass = 'true'** — never remove from RLS policies.
16. **All service ports** bound to `127.0.0.1` in Docker (not `0.0.0.0`).
17. **write_scores**: delete-before-insert, DELETE scoped by `call_id AND tenant_id`.
18. **depends_on**: use service names, not container_name values.

---

## 6. Database Schema

Full schema: [[02_Database_Schema]]

**Alembic head:** `20260526_platform_rls_bypass` (8 migrations applied)

Migration chain:
`create_tenants → add_tenant_id → enable_rls → force_rls → add_agent_sync_columns → agent_identity_extraction → indexes_and_constraints → platform_rls_bypass`

Never run Alembic on host Python — always inside `cq_api` container:
```bash
docker compose -f infra/docker-compose.azure.yml exec api alembic upgrade head
```

| Table | Key Columns |
|---|---|
| `tenants` | id, name, slug, plan_tier, settings JSONB |
| `users` | id, tenant_id, name, email, password_hash, role |
| `agents` | id, tenant_id, name, team, external_id, is_active |
| `calls` | id, tenant_id, agent_id, minio_audio_path, transcript_redacted, score, status, pii_redacted, needs_agent_review |
| `call_metrics` | id, call_id, politeness_score, sentiment_delta, resolution_score, talk_balance_score, clarity_score |
| `sentiment_timeline` | id, call_id, timestamp_seconds, sentiment_value |

**Roles:** `PLATFORM_ADMIN`, `TENANT_ADMIN`, `SUPERVISOR`, `AGENT`, `VIEWER`

**RLS:** Triple-layer row-level security on all tenant tables. Platform admin bypass via `app.platform_bypass = 'true'`.

---

## 7. API Summary

Full contract: [[03_API_Contract]]

Every endpoint returns: `{"success": true, "data": {}, "error": null, "request_id": "uuid"}`

Key endpoints:
- `POST /auth/login` → JWT token
- `POST /calls/upload` → triggers 7-stage pipeline
- `GET /calls` → paginated call list with filters
- `GET /calls/{id}` → full call detail with transcript + metrics
- `GET /agents/{id}/scores` → agent performance summary
- `POST /reports/export` → returns PDF binary (exempt from envelope)
- `WS /ws/{user_id}?token=` → real-time `call_complete` events
- `POST /internal/minio-event` → MinIO webhook handler (internal only)
- Platform admin: `/platform/overview`, `/platform/tenants`, `/platform/system-health`, `/platform/usage`, `/platform/call-monitor`

---

## 8. Current Build State — v1.7

| Component | Status |
|---|---|
| 7-stage AI pipeline | Complete and E2E verified |
| React dashboard (6 pages + platform admin) | Complete |
| PDF export (Playwright) | Complete |
| Multi-tenancy (RLS triple-layer) | Complete — Demo Tenant + Acme Corp verified isolated |
| Platform admin (5 pages) | Complete — overview, tenants, health, usage, call monitor |
| Azure B4ms CPU deployment | Files created, committed, pushed — pending VM provision |
| MinIO webhook upload model | Live |
| Extended Presidio PII | Complete |

---

## 9. Known Limitations

| Decision | Reason |
|---|---|
| Speaker labels can be swapped on pre-announcement audio | Pyannote assigns AGENT to first speaker chronologically |
| Audio playback broken | MinIO presigned URL double-prefix bug + CORS — disabled in frontend |
| Call List does not auto-refresh after processing | WebSocket updates don't trigger Call List re-fetch — navigate away and back |
| WhisperX slow on CPU | 90-120s per min of audio on B4ms (Phase 2: NC8as_T4_v3 GPU migration) |
| `diarized_segments` always empty in API | Word-level timestamps not persisted to DB |

---

## 10. Roadmap (B2B SaaS)

See [[ROADMAP]] for full phase planning.

**Done:** Phases 5 (multi-tenancy), 6 (agent roster), 7 (agent identity extraction from audio)
**Next:** Phase 8 — CRM integration (Zendesk first, adapter pattern, customer table)
**Phase 2 infra upgrade:** NC8as_T4_v3 GPU VM when call volume exceeds 80/day

Dropped: Urdu/English ASR fine-tuning — see [[06_Urdu_ASR_Research]] (historical only)

---

## 11. Repository Structure

```
call-quality-analytics/
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── celery_app.py            Celery config + queue routing
│   │   ├── database.py              Dual engine (async API + sync workers) + set_config() RLS
│   │   ├── models/orm.py            SQLAlchemy ORM models
│   │   ├── routers/                 auth, calls, agents, reports, ws, minio_event, platform
│   │   ├── pipeline/tasks.py        7-stage Celery chain + task_failure handler
│   │   └── services/
│   │       ├── whisper_service.py   WhisperX CPU (WHISPER_DEVICE=cpu, compute_type=int8)
│   │       ├── presidio_service.py  Extended PII (zip, SSN, account)
│   │       └── llm_client.py        Groq/OpenRouter chain
│   ├── alembic/versions/            8 migration files, head: 20260526_platform_rls_bypass
│   ├── Dockerfile                   API + Playwright (io_queue worker + api)
│   └── Dockerfile.cpu               CPU-only WhisperX + Pyannote (gpu_queue worker on Azure)
├── frontend/
│   ├── src/
│   │   ├── pages/                   Overview, CallList, Agents, Upload, Reports + Platform admin
│   │   ├── components/              Sidebar, CallDetailPanel
│   │   └── store/auth.ts            Zustand sessionStorage JWT
│   └── Dockerfile                   Multi-stage: Vite build → nginx:alpine
├── infra/
│   ├── docker-compose.yml           Local dev (GPU worker, no nginx)
│   ├── docker-compose.azure.yml     Azure CPU-only (9 services, nginx, no GPU reservation)
│   ├── nginx.conf                   SPA serve + /api proxy + /ws proxy + gzip
│   └── .env (gitignored)
├── scripts/
│   └── reset_and_seed.py            Creates Demo Tenant + Acme Corp with seeded calls
├── docs/
│   └── superpowers/plans/           Azure deployment plan + audit report
└── second-brain/                    This vault (symlinked or adjacent)
```
