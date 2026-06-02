# INVARIANTS — AI Call Quality Analytics System

> Ultra-compact context. Paste this into Qwen/Gemini/DeepSeek instead of full CONTEXT.md.
> Every rule here is enforced in production code. Violations break the pipeline.

---

## Stack (frozen — no deviations)

Backend: FastAPI + Celery 5.x + Redis 7.4-alpine + MinIO + PostgreSQL 16 + SQLAlchemy 2.x + Pydantic 2.x + Playwright
Auth: PyJWT>=2.8.0 + slowapi (rate limiting) — never python-jose (CVE-2024-33664)
AI: WhisperX large-v2 + Pyannote.audio 3.1 + Presidio (extended) + Groq llama-3.3-70b-versatile
Frontend: React 19 + TypeScript + Vite + TailwindCSS v4 + Recharts + Zustand + motion/react ^12.40.0
Infra: Docker Compose (dev: + Flower 2.0) (prod: + nginx)

## Column Names (exact — never deviate)

- `minio_audio_path` — never `audio_path`
- `transcript_redacted` — never `transcript`
- `pii_redacted` — boolean, set TRUE before any downstream task
- `talk_balance_score`, `politeness_score`, `clarity_score`, `resolution_score`, `sentiment_delta`

## Network / Hostname Rules

- Network: `cq_network`
- MinIO: `cq-minio:9000` — hyphens, not underscores (botocore rejects underscores)
- Container names: `cq_postgres`, `cq_redis`, `cq_minio`, `cq_api`, `cq_worker_io`, `cq_worker_gpu`, `cq_flower`

## Database URLs

- API (async): `postgresql+asyncpg://user:pass@cq_postgres:5432/db`
- Workers (sync): `postgresql://user:pass@cq_postgres:5432/db`
- Never use asyncpg in Celery workers — causes MissingGreenlet error

## Queue Routing (hardware isolation — violating causes VRAM OOM)

- `run_whisperx` → `gpu_queue` ONLY (concurrency=1, prefetch=1)
- All other tasks → `io_queue` (concurrency=4, prefetch=2)
- Speaker labels: `AGENT` or `CUSTOMER` — never `SPEAKER_00`/`SPEAKER_01`

## Security Invariants

- Audio binary → MinIO only, never PostgreSQL
- Raw transcripts → never DB, Presidio-redacted only
- `pii_redacted = TRUE` before `run_groq_inference` runs (gate enforced in task)
- JWT → Zustand sessionStorage, never localStorage
- MinIO bucket: never anonymous. Presigned URLs only (1hr expiry).
- JWT_SECRET: no default fallback. Fails loudly on startup if unset.
- REDIS_URL must include REDIS_PASSWORD (format: redis://:password@cq_redis:6379/0)
- MinIO webhook auth failure → always return HTTP 200 (prevents infinite retry)
- Platform admin endpoints → get_db_platform dependency only
- SET LOCAL app.platform_bypass = 'true' — never remove from RLS policies

## Pipeline Chain Order (invariant — do not reorder)

```
run_whisperx → extract_agent_identity → redact_pii → compute_talk_balance → run_groq_inference → write_scores → notify_websocket
```

extract_agent_identity MUST run before redact_pii — agent names are redacted as <PERSON> by Presidio.

## WebSocket Architecture

notify_websocket publishes to Redis channel ws:broadcast:{tenant_id}.
FastAPI redis_subscriber (started via lifespan) receives and calls manager.broadcast().
Never call manager.broadcast() directly from a Celery task — wrong process, empty connections.

## Scoring Formula (weights invariant)

```python
sentiment_delta_normalized = (sentiment_delta + 1.0) / 2.0
agent_score = (0.25 * politeness + 0.20 * sentiment_delta_normalized +
               0.20 * resolution + 0.15 * talk_balance + 0.20 * clarity)
display_score = round(agent_score * 10, 2)  # stored 0-10, shown ×10 as % in UI
```

## Talk Balance Formula (corrected — architecture review finding May 2026)

```python
agent_words = sum word count of AGENT segments
customer_words = sum word count of CUSTOMER segments
total_words = agent_words + customer_words
agent_ratio = agent_words / total_words if total_words > 0 else 0.5
talk_balance_score = round(1.0 - abs(agent_ratio - 0.5) * 2, 4)
# Perfect balance (50/50) = 1.0. Any imbalance reduces score. Agent talking 100% = 0.0.
```

## LLM Config

- Groq primary: `llama-3.3-70b-versatile` (3.1 is deprecated — 400 error)
- OpenRouter fallback: `meta-llama/llama-3.3-70b-instruct`
- Fallback triggers: HTTP 429 or 503 from Groq only
- No in-process inference cache — LLM results are never cached

## GPU / Dockerfile Rules

- Dockerfile.gpu base: `nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04`
- Python: must explicitly install 3.11 (base image ships 3.10)
- PyTorch: `torch==2.2.0+cu121` — index URL `https://download.pytorch.org/whl/cu121`
- `numpy<2` must be the LAST pip install step — pyannote pulls numpy>=2 as transitive dep
- Package: `nvidia-ml-py` — never `pynvml` (renamed)
- Cache mounts: `E:\projects\model-cache\huggingface` + `E:\projects\model-cache\torch`
- spaCy wheel: en_core_web_lg-3.8.0-py3-none-any.whl must be COPYed locally (DNS timeout in Docker build)

## Multi-Tenancy / RLS

- All tables (except tenants) have FORCE ROW LEVEL SECURITY
- Regular endpoints: get_db_with_tenant → SET LOCAL app.current_tenant = '{tenant_id}'
- Platform admin endpoints: get_db_platform → SET LOCAL app.platform_bypass = 'true'
- Migration 008 adds bypass condition to all 5 RLS policies
- write_scores DELETE scoped by call_id AND tenant_id (not just call_id)

## Alembic Head

20260526_platform_rls_bypass (migration 008)
Run migrations: docker compose exec api alembic upgrade head
Never run alembic on host Python — always inside cq_api container.

## Windows Docker Sync Delay

New files written to host may not appear in containers immediately.
Fix: docker compose cp ..\backend\<path>\<file> api:/app/<path>/<file>

## Banned Tools

Ollama (in pipeline), VADER, WeasyPrint, localStorage for JWT, raw transcript in DB,
audio blob in DB, Node.js backend, generic Celery pool, python-jose

## Code Style

Zero comments — ever. Self-documenting code only. Complete files, no partial snippets.

## Development Workflow

Claude.ai = architect, auditor, prompt writer.
Claude Code = code executor and file editor.
Antigravity (Gemini) = React component generation.
Paste errors to Claude.ai for diagnosis before any fix attempt.

## Upload Model (MinIO Webhook — no BatchAgent)

Files land in MinIO via mc mirror --watch (Dropbox model).
MinIO fires POST /internal/minio-event → FastAPI creates Call row → Celery chain fires.
No batch agent, no polling, no SQLite manifest.

## Current State (v1.9)

All local Docker. Pipeline verified. Multi-tenancy RLS live (migrations 001-008).
PLATFORM_ADMIN dashboard: 5 pages live (Overview, Tenants, SystemHealth, UsageAnalytics, CallMonitor).
Prod deployment files written: frontend/Dockerfile, infra/nginx.conf, infra/docker-compose.prod.yml.
spaCy wheel (400MB) downloaded locally for Docker build.
Next: prod build → smoke test → secrets rotation → Azure Canada Central VM → deploy.
Repo: github.com/Malik-Adeen/call-quality-analytics
Vault: E:\projects\docs
