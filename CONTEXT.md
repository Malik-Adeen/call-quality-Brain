# PROJECT CONTEXT — AI Call Quality & Agent Performance Analytics System

> Universal session starter. Paste this into any LLM (Claude, GPT, Gemini, Qwen, etc.)
> at the start of every working session. No prior conversation history required.
> This document is self-contained. The LLM reading this has everything needed to help.

---

## 1. Who is Building This

**Adeen** — Final Year student, BSCS, Bahria University Islamabad, Pakistan.
This began as his Final Year Project (FYP). The FYP demo was completed in April 2026.
The project is now being built out as a **B2B SaaS product** for call center analytics.

**Hardware:**
- CPU: AMD Ryzen 5 3600
- GPU: NVIDIA RTX 3060 Ti (8GB VRAM), CUDA 12.1.0
- OS: Windows + Docker Desktop + WSL2
- Project path: `N:\projects\call-quality-analytics`
- Knowledge vault: `N:\projects\docs`
- Repository: https://github.com/Malik-Adeen/call-quality-analytics

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
reviewers with a GPU-accelerated ASR + LLM scoring pipeline.

---

## 3. System Architecture

See [[01_Master_Architecture]] for the full technical specification.

### 3.1 Deployment Topology

```
Browser (React Dashboard)
    |
    | HTTP/WebSocket via Vite proxy
    v
Azure B2s VM — East US (20.228.184.111)
    |- FastAPI API         :8000   (REST + WebSocket)
    |- PostgreSQL 16       :5432   (relational store)
    |- Redis 7             :6379   (Celery broker + result backend)
    |- MinIO               :9000   (audio object storage)
    |- Celery worker_io           (CPU tasks, concurrency=4)
    |- Flower 2.0          :5555   (queue monitor)
    |
    | Celery gpu_queue tasks via encrypted SSH tunnel
    | (ports :6379, :5432, :9000 forwarded through SSH)
    v
Local Windows Machine — RTX 3060 Ti
    |- Celery worker_gpu          (GPU tasks, concurrency=1)
    |- WhisperX large-v2          (~33s inference on 3060 Ti)
    |- Pyannote.audio 3.1         (speaker diarization)
```

See [[10_GPU_Infrastructure]] for GPU setup details.
See [[11_Azure_Deployment]] for Azure runbooks and SSH tunnel configuration.

### 3.2 The 7-Stage Pipeline

Every upload triggers this exact sequence. No stage can be skipped. Stage 3 is a security gate.

| Stage | Task | Queue | Description |
|---|---|---|---|
| 1 | `ingest_upload` | API sync | Receive audio → store in MinIO → create pending DB row |
| 2 | `run_whisperx` | `gpu_queue` | Transcribe + diarize → JSON segments with AGENT/CUSTOMER labels |
| **3** | **`redact_pii`** | `io_queue` | **Presidio PII gate — raw text NEVER hits the DB** |
| 4 | `compute_talk_balance` | `io_queue` | Word-count ratio between AGENT and CUSTOMER |
| 5 | `run_groq_inference` | `io_queue` | LLM scores 5 metrics + generates coaching summary |
| 6 | `write_scores` | `io_queue` | Atomic PostgreSQL transaction — all metrics written together |
| 7 | `notify_websocket` | `io_queue` | `call_complete` event → connected browser clients |

### 3.3 Scoring Formula (default weights — per-tenant override allowed in Phase 5+)

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

See [[01_Master_Architecture]] for full version details and banned tools list.

### Backend
FastAPI (Python 3.11) · Celery 5.x · Redis 7 · MinIO · PostgreSQL 16 · SQLAlchemy 2.x · Pydantic 2.x · Playwright

### AI / ML
WhisperX large-v2 · Pyannote.audio 3.1 · Microsoft Presidio (extended) · Groq `llama-3.3-70b-versatile` · OpenRouter fallback

### Frontend
React 18 + TypeScript · Vite · TailwindCSS v4 · Recharts · Zustand (sessionStorage) · motion/react · Axios

### Infrastructure
Docker Compose (8 services) · Flower 2.0 · SSH tunnel (scripts/tunnel.bat)

---

## 5. Non-Negotiable Rules

These rules exist for security, correctness, and reproducibility. Never violate them.

1. **Audio binary** → MinIO only. Column: `minio_audio_path`. Never store audio in PostgreSQL.
2. **Raw transcripts** → never written to the database. Only Presidio-redacted text is persisted.
3. **`pii_redacted = TRUE`** must be set before any downstream task runs.
4. **`run_whisperx`** → `gpu_queue` exclusively. Concurrency locked to 1.
5. **`io_queue`** concurrency is 4. All non-GPU tasks go here.
6. **JWT** lives in Zustand sessionStorage. Never localStorage, never a cookie.
7. **Groq model** is `llama-3.3-70b-versatile`. Never use 3.1 — it is deprecated.
8. **MinIO hostname** is `cq-minio:9000` with hyphens. Underscores rejected by botocore.
9. **DATABASE_URL** uses `postgresql+asyncpg://` for the API, `postgresql://` for Celery workers.
10. **Score display**: backend stores 0–10, UI multiplies by 10 to show percentage.
11. **Zero code comments** — ever. Self-documenting code only.
12. **Banned tools**: Ollama, VADER, WeasyPrint, localStorage for JWT, Node.js backend.
13. **Multi-tenancy (Phase 5+)**: `SET LOCAL app.current_tenant` per transaction. Never `SET SESSION`.

---

## 6. Database Schema

Full schema: [[02_Database_Schema]]

| Table | Key Columns |
|---|---|
| `tenants` | id, name, slug, plan_tier, settings JSONB — **Phase 5** |
| `users` | id, tenant_id, name, email, password_hash, role (PLATFORM_ADMIN/TENANT_ADMIN/SUPERVISOR/VIEWER) |
| `agents` | id, tenant_id, name, team, external_id, is_active — **Phase 6** |
| `calls` | id, tenant_id, agent_id, minio_audio_path, transcript_redacted, score, status, pii_redacted, needs_agent_review — **Phase 7** |
| `call_metrics` | id, call_id, politeness_score, sentiment_delta, resolution_score, talk_balance_score, clarity_score |
| `sentiment_timeline` | id, call_id, timestamp_seconds, sentiment_value |
| `tenant_integrations` | id, tenant_id, integration_type, access_token, refresh_token — **Phase 8** |
| `customers` | id, tenant_id, external_crm_id, name, crm_tier — **Phase 8** |

> Tables marked Phase 5/6/7/8 do not exist yet. Current schema is single-tenant — see [[02_Database_Schema]].

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

---

## 8. Current Build State — v1.4 (FYP Demo Complete)

| Component | Status |
|---|---|
| 7-stage AI pipeline | Complete and E2E verified — see [[13_Phase2_E2E_Postmortem]] |
| React dashboard (6 pages) | Complete — see [[17_Phase3_Frontend]] |
| PDF export (Playwright) | Complete — see [[23_Phase4_Postmortem]] |
| Azure B2s deployment | Running at 20.228.184.111 — see [[11_Azure_Deployment]] |
| Hybrid GPU via SSH tunnel | Complete — see [[24_Hybrid_Architecture_Postmortem]] |
| Extended Presidio PII | Complete — see [[27_Presidio_Extension_Postmortem]] |
| Real audio testing | 5 files verified — see [[26_Audio_Testing_Postmortem]] |

---

## 9. Known Limitations

| Decision | Reason |
|---|---|
| Speaker labels can be swapped on pre-announcement audio | Pyannote assigns AGENT to first speaker chronologically |
| Account numbers without context word not redacted | Context-based matching design — see [[27_Presidio_Extension_Postmortem]] |
| Call List does not auto-refresh after processing | WebSocket update not on CallList page — navigate away and back |
| Audio playback removed | CORS issues with MinIO presigned URLs — see [[19_Future_Transcript_Audio_Sync]] |
| `diarized_segments` always empty in API | Word-level timestamps not persisted to DB |

---

## 10. Roadmap (B2B SaaS)

See [[ROADMAP]] for full phase planning. See [[30_SaaS_Pivot_Plan]] for research-backed feature specs.

Phase 5: Multi-tenancy (PostgreSQL RLS, tenant table, JWT tenant claim, MinIO prefix isolation)
Phase 6: Agent integration (roster sync API, external_id, soft-delete)
Phase 7: Agent identity extraction from audio (Groq transcript parse, fuzzy name match)
Phase 8: CRM integration (Zendesk first, adapter pattern, customer table)
Phase 9: High / low priority customers (priority scoring, DB trigger, dashboard surfacing)

Dropped: Urdu/English ASR fine-tuning — see [[06_Urdu_ASR_Research]] (historical only)

---

## 11. Repository Structure

```
call-quality-analytics/
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── celery_app.py        WAN-tuned Celery config
│   │   ├── database.py          Dual engine (async API + sync workers)
│   │   ├── models/orm.py        SQLAlchemy ORM models
│   │   ├── routers/             auth, calls, agents, reports, ws
│   │   ├── pipeline/tasks.py    7-stage Celery chain
│   │   └── services/
│   │       ├── whisper_service.py
│   │       ├── presidio_service.py    Extended PII (zip, SSN, account)
│   │       └── llm_client.py          Groq/OpenRouter chain
│   ├── Dockerfile               API + Playwright
│   └── Dockerfile.gpu           CUDA 12.1 + WhisperX + Pyannote
├── frontend/src/
│   ├── pages/                   Overview, CallList, Agents, Upload, Reports
│   ├── components/              Sidebar, CallDetailPanel
│   └── store/auth.ts            Zustand sessionStorage JWT
├── infra/
│   ├── docker-compose.yml
│   ├── docker-compose.hybrid.yml
│   └── .env (gitignored)
├── scripts/
│   ├── reset_and_seed.py
│   └── tunnel.bat
└── docs/                        This vault — [[00_Master_Dashboard]]
```
