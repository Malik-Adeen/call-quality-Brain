# 01 — Master Architecture & Stack Manifest

> Canonical technical reference. Read this before making any architectural decision.
> Every decision in this file is final. No deviations, no alternatives.
> Cross-reference: CONTEXT.md (project overview) · 02_Database_Schema.sql · 03_API_Contract.md

---

## 1. System Identity

| Property | Value |
|---|---|
| Project | AI Call Quality & Agent Performance Analytics System |
| Purpose | FYP — automated call center quality assurance via GPU-accelerated ASR + LLM scoring |
| Target | Bahria University final year project + production-grade system |
| Deployment | Hybrid: Azure B2s (always-on) + Local RTX 3060 Ti (GPU inference via SSH tunnel) |

---

## 2. Mandated Tech Stack

### 2.1 Backend

| Layer | Tool | Version | Notes |
|---|---|---|---|
| API Framework | FastAPI | latest stable | Stateless, async, Python 3.11+ |
| Task Queue | Celery | 5.x | Two named queues only — see §5 |
| Message Broker | Redis | 7 Alpine | No AOF persistence |
| Object Storage | MinIO | latest | S3-compatible, self-hosted, audio files only |
| Database | PostgreSQL | 16 Alpine | Schema in `02_Database_Schema.sql` |
| ORM | SQLAlchemy | 2.x | asyncpg for API, psycopg2 for workers |
| Validation | Pydantic | 2.x | All request/response models |
| Auth | python-jose + bcrypt | latest | JWT, 8-hour expiry |
| PDF Export | Playwright Headless Chromium | latest | Renders Recharts SVGs correctly |

### 2.2 AI / ML

| Layer | Tool | Notes |
|---|---|---|
| ASR | WhisperX (faster-whisper large-v2) | GPU required for <60s inference |
| Diarization | Pyannote.audio 3.1 | Requires HF_TOKEN |
| PII Redaction | Microsoft Presidio (extended) | Custom recognizers for zip, SSN last-4, account numbers |
| LLM Primary | Groq API — `llama-3.3-70b-versatile` | Free tier, zero local VRAM |
| LLM Fallback | OpenRouter — `meta-llama/llama-3.3-70b-instruct` | HTTP 429/503 overflow only |

### 2.3 Frontend

| Layer | Tool | Notes |
|---|---|---|
| Framework | React 18 + TypeScript | Vite scaffold |
| Charts | Recharts | All dashboard visualizations |
| Styling | TailwindCSS v4 | @tailwindcss/vite plugin — no config file |
| HTTP Client | Axios | JWT injected via interceptor |
| State | Zustand | JWT in sessionStorage — never localStorage |
| Animation | motion/react | Slide-in panels |
| Icons | lucide-react | |

### 2.4 Infrastructure

| Layer | Tool | Notes |
|---|---|---|
| Containerization | Docker Compose | 8 services total |
| Queue Monitor | Flower 2.0 | Port 5555, basic auth |
| Network | SSH tunnel | Forwards :6379/:5432/:9000 from local to Azure |

---

## 3. Banned Tools

Never use these. The reasons are architectural, not preferential.

| Tool | Reason | Replacement |
|---|---|---|
| Ollama | Retired permanently | Groq API + OpenRouter |
| VADER | No diarization, no structured output | Groq llama-3.3-70b-versatile |
| WeasyPrint | No JS engine — Recharts SVGs render blank | Playwright |
| Generic Celery pool | No GPU/CPU isolation — causes VRAM OOM | gpu_queue (×1) + io_queue (×4) |
| Audio BLOB in DB | Violates MinIO contract, causes DB bloat | MinIO only |
| localStorage for JWT | Security violation | Zustand sessionStorage |
| Raw transcript in DB | PII compliance violation | Presidio-redacted text only |
| Node.js backend | Not part of this stack | FastAPI only |
| pynvml package | Renamed | nvidia-ml-py |

---

## 4. LLM Inference — Provider Chain

```python
PROVIDER_CHAIN = [
    {
        "name":     "groq",
        "base_url": "https://api.groq.com/openai/v1",
        "model":    "llama-3.3-70b-versatile",
    },
    {
        "name":     "openrouter",
        "base_url": "https://openrouter.ai/api/v1",
        "model":    "meta-llama/llama-3.3-70b-instruct",
    },
]
```

Fallback triggers: HTTP 429 or 503 from Groq only.
Both fail → raise `AllProvidersUnavailableError`. Never silently return bad data.

---

## 5. Celery Queue Contract

Hardware isolation. Violating this causes GPU VRAM OOM panics.

| Queue | Worker | Concurrency | prefetch-multiplier | Tasks |
|---|---|---|---|---|
| `gpu_queue` | `worker_gpu` | 1 (enforced) | 1 (never prefetch) | `run_whisperx` only |
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

VRAM sentinel: check `nvidia-ml-py` before loading WhisperX. If free VRAM < 2GB → retry in 30s.

---

## 6. The 7-Stage Pipeline

Sequential. No stage may be skipped. Stage 3 is a hard security gate.

| # | Task | Queue | Input → Output |
|---|---|---|---|
| 01 | `ingest_upload` | API sync | Multipart audio → MinIO path + Redis job |
| 02 | `run_whisperx` | `gpu_queue` | MinIO path → diarized JSON |
| **03** | **`redact_pii`** | `io_queue` | **Diarized JSON → redacted JSON. Raw text deleted.** |
| 04 | `compute_talk_balance` | `io_queue` | Redacted segments → float |
| 05 | `run_groq_inference` | `io_queue` | Redacted transcript → 5 scores + summary |
| 06 | `write_scores` | `io_queue` | All metrics → atomic PostgreSQL transaction |
| 07 | `notify_websocket` | `io_queue` | `call_complete` event → connected clients |

Speaker labels: `AGENT` or `CUSTOMER` — never `SPEAKER_00` or `SPEAKER_01`.

---

## 7. Scoring Formula (invariant — never modify weights)

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

Stored in DB as 0–10. Displayed in UI as 0–100% (multiply by 10).

---

## 8. Docker Compose Services

| Service | Container | Port | Responsibility |
|---|---|---|---|
| `postgres` | `cq_postgres` | 5432 | Relational store |
| `redis` | `cq_redis` | 6379 | Celery broker + result backend |
| `minio` | `cq_minio` | 9000/9001 | Audio object storage |
| `minio_init` | `cq_minio_init` | — | Bucket creation + test file upload |
| `api` | `cq_api` | 8000 | FastAPI — auth, upload, results, WebSocket |
| `worker_io` | `cq_worker_io` | — | CPU Celery worker — io_queue |
| `worker_gpu` | `cq_worker_gpu` | — | GPU Celery worker — gpu_queue |
| `flower` | `cq_flower` | 5555 | Celery queue dashboard |

---

## 9. Hybrid Deployment Architecture

```
Azure B2s East US (20.228.184.111)
    postgres + redis + minio + api + worker_io + flower

SSH tunnel (scripts/tunnel.bat)
    localhost:6379 → Azure Redis
    localhost:5432 → Azure PostgreSQL
    localhost:9000 → Azure MinIO

Local RTX 3060 Ti
    worker_gpu → connects via host.docker.internal to tunnel ports
    docker-compose.hybrid.yml — starts worker_gpu only
```

**SSH tunnel command:**
```
ssh -N -L 6379:localhost:6379 -L 5432:localhost:5432 -L 9000:localhost:9000
    -o ServerAliveInterval=15 -o ServerAliveCountMax=3
    -i C:\Users\adeen\.ssh\callquality_azure
    azureuser@20.228.184.111
```

**Critical:** Never run local Redis (cq_redis) at the same time as the SSH tunnel.
Port 6379 conflict causes worker_gpu to talk to local Redis while Azure API writes to Azure Redis.

---

## 10. GPU Infrastructure

Reference: `10_GPU_Infrastructure.md`

| Property            | Value                                                   |
| ------------------- | ------------------------------------------------------- |
| GPU                 | NVIDIA RTX 3060 Ti                                      |
| VRAM                | 8GB                                                     |
| CUDA                | 12.1.0                                                  |
| Dockerfile.gpu base | nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04           |
| PyTorch             | 2.2.0+cu121                                             |
| Python in GPU image | 3.11 (manually installed — base image ships 3.10)       |
| WhisperX VRAM       | ~3GB                                                    |
| Pyannote VRAM       | ~1GB                                                    |
| Combined peak       | ~4-5GB                                                  |
| numpy               | Must be < 2.0 (last pip install step in Dockerfile.gpu) |

Cache volume mounts (Windows host):
- `C:\Users\adeen\.cache\huggingface` → `/root/.cache/huggingface`
- `C:\Users\adeen\.cache\torch` → `/root/.cache/torch`
