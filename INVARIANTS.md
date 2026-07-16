# INVARIANTS — AI Call Quality Analytics System

> Ultra-compact context. Paste this into Codex/Gemini/DeepSeek instead of full CONTEXT.md.
> Every rule here is enforced in production code. Violations break the pipeline.

---

## Stack (frozen — no deviations)

Backend: FastAPI + Celery 5.x + Redis 7.4-alpine + MinIO + PostgreSQL 16 + SQLAlchemy 2.x + Pydantic 2.x + Playwright
Auth: PyJWT>=2.8.0 + slowapi — NEVER python-jose (CVE-2024-33664)
AI: WhisperX (cpu, int8, small model on Azure) + Pyannote.audio 3.1 + Presidio (extended) + Groq llama-3.3-70b-versatile
Frontend: React 19 + TypeScript + Vite + TailwindCSS v4 + Recharts + Zustand + motion/react ^12.40.0
Infra: Docker Compose (9 services) + nginx:alpine (SPA + reverse proxy)
Design: Waaqi GRC tokens — primary #00a99d, sidebar #0f1924, Inter + JetBrains Mono

## Column Names (exact — never deviate)

- `minio_audio_path` — never `audio_path`
- `transcript_redacted` — never `transcript`
- `pii_redacted` — boolean, set TRUE before any downstream task
- `talk_balance_score`, `politeness_score`, `clarity_score`, `resolution_score`, `sentiment_delta`

## Network / Hostname Rules

- Network: `cq_network`
- MinIO: `cq-minio:9000` — hyphens, not underscores (botocore rejects underscores)
- Container names: `cq_postgres`, `cq_redis`, `cq_minio`, `cq_api`, `cq_worker_io`, `cq_worker_cpu`, `cq_nginx`, `cq_flower`
- All service ports: bound to `127.0.0.1` in Docker — never `0.0.0.0`. No exception as of
  2026-07-16: `infra/docker-compose.app.yml:131` (nginx port 80) moved `0.0.0.0:80:80` →
  `127.0.0.1:80:80` (commit `28ee65d`, deploy/fahad-demo). External access is via Cloudflare
  Tunnel (`cloudflared` → `http://localhost:80`), which reaches a `127.0.0.1`-bound port fine
  since it runs on the same host.
- depends_on: use service names, NOT container_name values

## Database URLs

- API (async): `postgresql+asyncpg://user:pass@cq_postgres:5432/db`
- Workers (sync): `postgresql://user:pass@cq_postgres:5432/db`
- Never use asyncpg in Celery workers — causes MissingGreenlet error

## Queue Routing (hardware isolation — violating causes stall)

- `run_whisperx` → `gpu_queue` ONLY (concurrency=1, prefetch=1, max-tasks-per-child=1)
- All other tasks → `io_queue` (concurrency=4, prefetch=2)
- Speaker labels: `AGENT` or `CUSTOMER` — never `SPEAKER_00`/`SPEAKER_01`

## Security Invariants

- Audio binary → MinIO only, never PostgreSQL
- Raw transcripts → never DB, Presidio-redacted only
- `pii_redacted = TRUE` before `run_groq_inference` runs (gate enforced in task)
- JWT → Zustand sessionStorage, never localStorage
- REDIS_URL must include REDIS_PASSWORD
- MinIO webhook auth failure → always return HTTP 200 (prevents infinite retry loop)
- Platform admin endpoints → `get_db_platform` dependency only
- SET LOCAL app.platform_bypass = 'true' — never remove from RLS policies

## RLS Pattern (parameterised — never f-string SQL)

```python
# Correct: set_config() with bind param
await db.execute(
    text("SELECT set_config('app.current_tenant', :tid, true)"),
    {"tid": str(tenant_id)},
)
# NEVER: f"SET LOCAL app.current_tenant = '{tenant_id}'" — SQL injection surface
```

`SET LOCAL app.current_tenant` per transaction — never SET SESSION.

## Alembic

Head: `20260526_platform_rls_bypass` (8 migrations total)
Chain: create_tenants → add_tenant_id → enable_rls → force_rls → add_agent_sync_columns → agent_identity_extraction → indexes_and_constraints → platform_rls_bypass
Run: always inside `cq_api` container — never on host Python
Fallback: `alembic stamp 20260526_platform_rls_bypass` if inconsistent state error

## Pipeline Chain Order (invariant — do not reorder)

```
run_whisperx → extract_agent_identity → redact_pii → compute_talk_balance → run_groq_inference → write_scores → notify_websocket
```

extract_agent_identity MUST run before redact_pii — agent names are redacted as <PERSON> by Presidio.

## write_scores (idempotency)

`ON CONFLICT DO UPDATE` upsert scoped by `(call_id, tenant_id)` — changed 2026-06-21 (migration `20260621_idempotency`), replaces the earlier delete-before-insert pattern. Applies to both CallMetrics and SentimentTimeline.

## API Response Envelope

Correct rule (prior phrasing "every endpoint returns 200+envelope" was overreach): every endpoint returns the envelope SHAPE in the body (`{success, data, error, request_id}`) plus the CORRECT HTTP status for the outcome. Auth failures return 401 WITH the envelope body — confirmed via `/auth/login`'s `error_response()` helper (schemas/api.py), which builds `JSONResponse(status_code=401, content={"success": False, "data": None, "error": {...}, "request_id": ...})`. Envelope shape is not tied to a fixed status code.

## Scoring Formula (weights invariant)

```python
sentiment_delta_normalized = (sentiment_delta + 1.0) / 2.0
agent_score = (0.25 * politeness + 0.20 * sentiment_delta_normalized +
               0.20 * resolution + 0.15 * talk_balance + 0.20 * clarity)
display_score = round(agent_score * 10, 2)  # stored 0-10, shown ×10 as % in UI
```

## Talk Balance Formula

```python
agent_words = sum word count of AGENT segments
customer_words = sum word count of CUSTOMER segments
total_words = agent_words + customer_words
agent_ratio = agent_words / total_words if total_words > 0 else 0.5
talk_balance_score = round(1.0 - abs(agent_ratio - 0.5) * 2, 4)
# Perfect balance (50/50) = 1.0. Agent talking 100% = 0.0.
```

## LLM Config

- Groq primary: `llama-3.3-70b-versatile` (3.1 is deprecated — 400 error) — **this model is now itself DEPRECATED by Groq, decommission 2026-08-16.** Migration to `openai/gpt-oss-120b` via structured-output mode is PENDING (not started). Do not delete this line until migration lands — model still in production use. Note: gpt-oss is a reasoning model, so the current "respond ONLY with JSON" prompt-only approach will break; migration must use JSON-schema structured output, not prompt-only. Config lives on both master and deploy/fahad-demo — migrate both. Re-validate all 5 score components after migration.
- OpenRouter fallback: `meta-llama/llama-3.3-70b-instruct`
- Fallback triggers: HTTP 429 or 503 from Groq only
- Retry-based recovery requires nonzero temperature. `temperature: 0.0` makes
  `json_validate_failed` deterministic and renders `max_retries` useless
  (verified 2026-07-15: 4/4 identical failures, same transcript, same `0. nine`).

## Dockerfile Rules

- CPU worker (Azure): `backend/Dockerfile.cpu` — python:3.11-slim, no CUDA
  - torch==2.2.0+cpu via `--index-url https://download.pytorch.org/whl/cpu`
  - whisperx + pyannote.audio 3.1 + faster-whisper + ctranslate2
  - `numpy<2` last pip install step
  - compute_type hardcoded to "int8" in whisper_service.py
- GPU worker (local dev): `backend/Dockerfile.gpu` — nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04
- API worker: `backend/Dockerfile` — includes Playwright for PDF export

## Windows Service Deployment — cloudflared (re-breakable, verified 2026-07-16)

`cloudflared service install` on Windows (v2026.7.2) installs the service with **no arguments** —
bare `cloudflared.exe`, no `--config`, no `tunnel run`. It starts, has nothing to do, exits, and
crash-loops every 20s, with no cause logged anywhere (Application log: "service starting" only;
System log: "terminated unexpectedly" only). Reinstalling after the config file exists does NOT
fix it, `--config X service install` does NOT fix it, copying `config.yml` into LocalSystem's
profile does NOT fix it, `sc.exe config binPath=` fails under PowerShell quoting.

Fix — set the service args via the registry directly, then restart:

```powershell
$bin = '"C:\Program Files (x86)\cloudflared\cloudflared.exe" --config "C:\Users\fahad\.cloudflared\config.yml" tunnel run call-qa-tech'
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\cloudflared' -Name ImagePath -Value $bin
Restart-Service cloudflared
```

Verify: `(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\cloudflared').ImagePath`.

**Any reinstall or upgrade of the `cloudflared` service silently regresses to bare args** — re-run
the registry fix after every reinstall/upgrade. The token-based install path writes correct args
automatically but requires Cloudflare Zero Trust activation, which demands a payment card
(rejected for this project). See 70_Session_Handoff_2026-07-15.md STEP 3 for full context.

## Roles

PLATFORM_ADMIN, TENANT_ADMIN, SUPERVISOR, AGENT, VIEWER

## Upload Model

MinIO webhook: mc mirror --watch puts files in MinIO → MinIO fires POST /internal/minio-event → FastAPI creates Call row → Celery chain fires
No batch agent. No polling. No SQLite manifest.

## Banned Tools

Ollama (in pipeline), VADER, WeasyPrint, localStorage for JWT, python-jose, Node.js backend,
raw transcript in DB, audio blob in DB, asyncpg in Celery workers

## Code Style

Zero comments — ever. Self-documenting code only. Complete files, no partial snippets.

## Development Workflow

Claude Code = architect, auditor, prompt writer (for Codex/Antigravity), code executor and file editor
Antigravity (CLI) = React component generation, Frontend Dev
Codex CLI = Backend Dev, code generation

## Current State (v1.9)

All Docker. Target architecture: Azure B4ms (app tier, always-on) + NC4as_T4_v3 GPU worker (on-demand/Spot) — fully cloud, no local GPU.
`docker-compose.azure.yml` currently single-box CPU-only — needs splitting into two Compose files before VM deploy.
Multi-tenancy: triple-layer RLS live. Two tenants verified isolated.
Platform admin: 5 pages live (overview, tenants, health, usage, call monitor).
Alembic: 8 migrations applied. Head: 20260526_platform_rls_bypass.
`.env.prod`: REDIS_PASSWORD, MINIO_WEBHOOK_SECRET, CORS_ORIGINS added — update CORS_ORIGINS with real VM IP after provisioning.
Repo: github.com/Malik-Adeen/call-quality-analytics
Public demo URL (Fahad's machine, deploy/fahad-demo branch): https://call-qa.tech via Cloudflare
Tunnel (`cloudflared` Windows service → `http://localhost:80` → `cq_nginx`). Verified 2026-07-16:
login, WebSocket, and end-to-end call scoring all work through the tunnel. Tailscale Funnel is
off — do not treat `https://deltaroot-pt-lp.tailb8d983.ts.net` as current; that URL only appears
in historical records now (65_Session_Handoff_2026-06-28.md, LOG.md's 2026-06-28 entry).
