# INVARIANTS — AI Call Quality Analytics System

> Ultra-compact context. Paste this into Qwen/Gemini instead of full CONTEXT.md.
> Every rule here is enforced in production code. Violations break the pipeline.
> Project has pivoted to B2B SaaS (April 30, 2026). See [[30_SaaS_Pivot_Plan]].
> Azure B2s decommissioned April 2026. All services run locally via docker-compose.yml.

---

## Stack (frozen — no deviations)

Backend: FastAPI + Celery 5.x + Redis 7 + MinIO + PostgreSQL 16 + SQLAlchemy 2.x + Pydantic 2.x + Playwright
AI: WhisperX large-v2 + Pyannote.audio 3.1 + Presidio (extended) + Groq llama-3.3-70b-versatile
Frontend: React 18 + TypeScript + Vite + TailwindCSS v4 + Recharts + Zustand
Infra: Docker Compose (single machine, all 8 services) + Flower 2.0
Cloud: Cloud-agnostic — Docker Compose deploys unchanged to any provider

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

## Scoring Formula (weights are default — per-tenant override allowed via tenants.settings JSONB)

```python
sentiment_delta_normalized = (sentiment_delta + 1.0) / 2.0
agent_score = (0.25 * politeness + 0.20 * sentiment_delta_normalized +
               0.20 * resolution + 0.15 * talk_balance + 0.20 * clarity)
display_score = round(agent_score * 10, 2)  # stored 0-10, shown ×10 as % in UI
```

## Multi-Tenancy Invariants (Phase 5+)

- All tenant-scoped tables carry `tenant_id UUID NOT NULL`
- PostgreSQL RLS: `FORCE ROW LEVEL SECURITY` on every tenant-scoped table
- Session variable: `SET LOCAL app.current_tenant = :id` — LOCAL not SESSION
- `contextvars.ContextVar` for async tenant identity propagation — never thread-local
- MinIO paths: `{tenant_id}/{call_id}.mp3` — prefix isolation, not bucket-per-tenant
- JWT carries `tenant_id` claim — injected at login, validated on every request

## LLM Config

- Groq primary: `llama-3.3-70b-versatile` (3.1 is deprecated — 400 error)
- OpenRouter fallback: `meta-llama/llama-3.3-70b-instruct`
- Fallback triggers: HTTP 429 or 503 from Groq only

## GPU / Dockerfile Rules

- Dockerfile.gpu base: `nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04`
- Python: must explicitly install 3.11 (base image ships 3.10)
- PyTorch: `torch==2.2.0+cu121` — index URL `https://download.pytorch.org/whl/cu121`
- `numpy<2` must be the LAST pip install step — pyannote pulls numpy>=2 as transitive dep
- Package: `nvidia-ml-py` — never `pynvml` (renamed)
- Cache mounts: `C:\Users\adeen\.cache\huggingface` + `C:\Users\adeen\.cache\torch`

## Banned Tools

Ollama (in pipeline), VADER, WeasyPrint, localStorage for JWT, raw transcript in DB,
audio blob in DB, Node.js backend, generic Celery pool (use named queues only),
SET SESSION for tenant context (use SET LOCAL only)

## Code Style

Zero comments — ever. Self-documenting code only. Complete files, no partial snippets.

## Current State (v1.4 — post-FYP demo, pre-SaaS build)

All services run locally on RTX 3060 Ti machine via docker-compose.yml.
Azure B2s (20.228.184.111) decommissioned — cloud credits exhausted.
SSH tunnel and hybrid architecture archived — no longer in use.
200 seeded calls in local DB. Pipeline verified: billing_dispute 88.3%, tech_support 88.2%.
Pivot: B2B SaaS — see [[30_SaaS_Pivot_Plan]] for full feature roadmap.
Repo: github.com/Malik-Adeen/call-quality-analytics
