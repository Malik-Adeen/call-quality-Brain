# 01 — Master Architecture & Stack Manifest
> **LLM Anchor Document.** Paste this at the start of every Antigravity or Claude session.
> Every decision in this file is final. No deviations, no alternatives, no suggestions to replace any item.

---

## 1. System Identity

| Property         | Value                                                            |
| ---------------- | ---------------------------------------------------------------- |
| Project          | AI Call Quality & Agent Performance Analytics System             |
| Purpose          | University final presentation demo — 1-week operational lifespan |
| Target Audience  | Professor evaluating a technically rigorous AI pipeline          |
| Deployment Model | Local-first development → Azure GPU for demo day only            |

---

## 2. Mandated Tech Stack

### 2.1 Backend

| Layer | Tool | Version | Notes |
|---|---|---|---|
| API Framework | FastAPI | latest stable | Stateless, async, Python 3.11+ |
| Task Queue | Celery | 5.x | Two named queues only — see §5 |
| Message Broker | Redis | 7 Alpine | Ephemeral — no AOF persistence |
| Object Storage | MinIO | latest | S3-compatible, self-hosted, audio files only |
| Database | PostgreSQL | 16 Alpine | Schema defined in `02_Database_Schema.sql` |
| ORM | SQLAlchemy | 2.x | Async engine, alembic for migrations |
| Validation | Pydantic | 2.x | All request/response models |
| Auth | python-jose + bcrypt | latest | JWT, 8-hour expiry |

### 2.2 AI / ML

| Layer | Tool | Notes |
|---|---|---|
| ASR | WhisperX (faster-whisper-turbo) | `large-v2` on GPU · `base` on CPU fallback |
| Diarization | Pyannote.audio 3.1 | Requires `HF_TOKEN` — accept model terms at hf.co first |
| PII Redaction | Microsoft Presidio | Mandatory gate — runs before every DB write and every LLM call |
| LLM Primary | Groq API — `llama-3.3-70b-versatile` | Free tier, zero local VRAM |
| LLM Fallback | OpenRouter — `meta-llama/llama-3.3-70b-instruct` | $10 budget, HTTP 429 overflow only |

### 2.3 Frontend

| Layer | Tool | Notes |
|---|---|---|
| Framework | React 18 + TypeScript | Vite scaffold |
| Routing | React Router v6 | |
| Charts | Recharts | All dashboard visualisations |
| Styling | TailwindCSS | Core utility classes only |
| HTTP Client | Axios | JWT injected via interceptor |
| State | Zustand | JWT stored in memory — never localStorage |

### 2.4 Infrastructure & Observability

| Layer | Tool | Notes |
|---|---|---|
| Containerisation | Docker Compose | 7 services, ephemeral volumes |
| Queue Monitor | Flower 2.0 | Port 5555, basic auth enabled |
| PDF Export | Playwright Headless Chromium | Replaces WeasyPrint — renders JS/SVG correctly |

---

## 3. Banned Tools

These tools must never appear in generated code, suggestions, or architectural decisions.

| Tool | Reason | Replacement |
|---|---|---|
| **Ollama** | Retired from production path permanently | Groq API (primary) + OpenRouter (fallback) |
| **VADER** | No diarization, no structured output | Groq `llama-3.1-70b-versatile` |
| **WeasyPrint** | No JS engine — Recharts SVG renders blank | Playwright Headless Chromium |
| **Generic Celery pool** | No GPU/CPU isolation — causes OOM panics | `gpu_queue` (×1) + `io_queue` (×4) |
| **Audio BLOB in DB** | DB bloat, violates MinIO contract | MinIO only — store `minio_audio_path` in DB |
| **localStorage for JWT** | Security violation | Zustand in-memory store |
| **Raw transcript in DB** | PII compliance violation | Presidio-redacted text only |
| **Node.js backend** | Not part of this stack | FastAPI only |

---

## 4. LLM Inference — Groq Primary / OpenRouter Fallback

```python
PROVIDER_CHAIN = [
    {
        "name":     "groq",
        "base_url": "https://api.groq.com/openai/v1",
        "api_key":  GROQ_API_KEY,
        "model":    "llama-3.3-70b-versatile",
    },
    {
        "name":     "openrouter",
        "base_url": "https://openrouter.ai/api/v1",
        "api_key":  OPENROUTER_API_KEY,
        "model":    "meta-llama/llama-3.3-70b-instruct",
    },
]
```

**Fallback trigger conditions:**
- HTTP `429` (rate limit) from Groq → try OpenRouter
- HTTP `503` (unavailable) from Groq → try OpenRouter
- Both fail → raise `AllProvidersUnavailableError` — never silently return bad data
- Never fall back to a local model under any circumstance

**OpenRouter budget:** $10. Realistic project spend is < $1. The remaining balance is insurance.

---

## 5. Celery Queue Contract

This is the hardware isolation contract. Violating it causes GPU VRAM OOM panics.

| Queue | Worker | Concurrency | prefetch-multiplier | Tasks |
|---|---|---|---|---|
| `gpu_queue` | `worker_gpu` | **1** (enforced) | **1** (never prefetch) | `run_whisperx` only |
| `io_queue` | `worker_io` | 4 | 2 | all other tasks |

```python
task_routes = {
    "pipeline.tasks.run_whisperx":         {"queue": "gpu_queue"},
    "pipeline.tasks.redact_pii":           {"queue": "io_queue"},
    "pipeline.tasks.compute_talk_balance": {"queue": "io_queue"},
    "pipeline.tasks.run_groq_inference":   {"queue": "io_queue"},
    "pipeline.tasks.write_scores":         {"queue": "io_queue"},
    "pipeline.tasks.notify_websocket":     {"queue": "io_queue"},
}
```

**VRAM sentinel:** before loading the Whisper model, check `pynvml.nvmlDeviceGetMemoryInfo()`.
If free VRAM < 2 GB → raise `Retry(countdown=30)`. Skip this check gracefully if no GPU is present.

---

## 6. The 7-Stage Pipeline

Stages execute sequentially. No stage may be skipped. Stage 03 is a hard gate.

| # | Task | Queue | Input → Output |
|---|---|---|---|
| 01 | `ingest_upload` | API (sync) | Multipart audio → MinIO path + Redis job |
| 02 | `run_whisperx` | `gpu_queue` | MinIO path → diarized JSON |
| **03** | **`redact_pii`** | `io_queue` | **Diarized JSON → redacted JSON. Raw text deleted.** |
| 04 | `compute_talk_balance` | `io_queue` | Redacted segments → `float` |
| 05 | `run_groq_inference` | `io_queue` | Redacted transcript → 5 scores + summary |
| 06 | `write_scores` | `io_queue` | All metrics → atomic PostgreSQL transaction |
| 07 | `notify_websocket` | `io_queue` | `call_complete` event → connected clients |

**WhisperX diarized segment schema:**
```json
[
  {
    "speaker": "AGENT",
    "start": 0.0,
    "end": 4.82,
    "text": "Hello, thank you for calling.",
    "words": [
      {"word": "Hello", "start": 0.0, "end": 0.44},
      {"word": "thank", "start": 0.52, "end": 0.78}
    ]
  }
]
```
Speaker labels must be `AGENT` or `CUSTOMER` — never `SPEAKER_00` or `SPEAKER_01`.

---

## 7. Scoring Formula

This formula is invariant. Do not modify weights.

```python
sentiment_delta_normalized = (sentiment_delta + 1.0) / 2.0

agent_score = (
    0.25 * politeness_score           +
    0.20 * sentiment_delta_normalized +
    0.20 * resolution_score           +
    0.15 * talk_balance_score         +
    0.20 * clarity_score
)

display_score = round(agent_score * 10, 2)
```

| Component | Weight | Source | Range |
|---|---|---|---|
| `politeness_score` | 25% | Groq output | 0.0 – 1.0 |
| `sentiment_delta` | 20% | Groq output (normalised) | −1.0 – +1.0 → 0.0 – 1.0 |
| `resolution_score` | 20% | Groq output | 0.0 – 1.0 |
| `talk_balance_score` | 15% | Python word-count, no model | 0.0 – 1.0 |
| `clarity_score` | 20% | Groq output | 0.0 – 1.0 |
| `display_score` | — | Computed | 0.00 – 10.00 |

---

## 8. Docker Compose Services

| Service | Container | Port | Responsibility |
|---|---|---|---|
| `postgres` | `cq_postgres` | 5432 | Relational store |
| `redis` | `cq_redis` | 6379 | Celery broker + result backend |
| `minio` | `cq_minio` | 9000 / 9001 | Audio object storage |
| `api` | `cq_api` | 8000 | FastAPI — auth, upload, results, WebSocket |
| `worker_io` | `cq_worker_io` | — | CPU Celery worker — `io_queue` |
| `worker_gpu` | `cq_worker_gpu` | — | GPU/CPU-fallback Celery worker — `gpu_queue` |
| `flower` | `cq_flower` | 5555 | Celery queue dashboard |

---

## 9. Deployment Strategy

| Phase | Environment | Hardware | Azure Spend |
|---|---|---|---|
| 0 – 2 | Local Arch Linux | CPU fallback, Docker Compose | $0 |
| 3 – 4 | Azure `B2s` (always-on) | 2 vCPU · 4 GB RAM · $0.05/hr | ~$8 |
| Demo day | Azure `NC4as_T4_v3` (on-demand) | NVIDIA T4 · $0.53/hr · ~4 hrs | ~$2 |
| **Total** | | | **< $15 of $85** |

**Azure GPU activation:** uncomment the `deploy.resources.reservations.devices` block in
`docker-compose.yml` and set `WHISPER_DEVICE=cuda`, `WHISPER_MODEL=large-v2` in `.env`.
Stop the `NC4as_T4_v3` VM immediately after demo. Never leave it running idle.