# AI Call Quality & Agent Performance Analytics System
## Project Master Roadmap & Architectural Specification

**Status:** Phase 1 Complete ✅ | Phase 2 Commencing 🏗️


## 1. System Overview
This system is a decoupled, containerized AI analytics engine designed to transcribe, redact, and score customer service calls. It utilizes a distributed task queue to separate high-intensity GPU workloads (ASR) from high-concurrency IO workloads (LLM Inference/DB writes).

### Core Architecture
The system operates within a unified Docker network (`cq_network`) with 7 primary services.

```mermaid
graph TD
    Client(["Browser / React Frontend"])

    subgraph Docker Network [cq_network]
        API["<b>cq_api</b><br/>FastAPI :8000<br/>Auth · Upload · WS"]
        WIO["<b>cq_worker_io</b><br/>Celery io_queue<br/>concurrency=4"]
        WGPU["<b>cq_worker_gpu</b><br/>Celery gpu_queue<br/>concurrency=1"]
        FLOWER["<b>cq_flower</b><br/>Flower :5555<br/>Monitor"]
        PG["<b>cq_postgres</b><br/>PostgreSQL 16<br/>Port :5432"]
        REDIS["<b>cq_redis</b><br/>Redis 7<br/>Broker/Backend"]
        MINIO["<b>cq_minio</b><br/>MinIO :9000<br/>Object Store"]
    end

    GROQ(["Groq API<br/>llama-3.1-70b"])
    OR(["OpenRouter API<br/>Fallback Agent"])

    Client -->|"JWT Bearer"| API
    API -->|"Async Write"| PG
    API -->|"PUT Audio"| MINIO
    API -->|"Dispatch"| REDIS
    REDIS --> WIO
    REDIS --> WGPU
    WIO -->|"Inference"| GROQ
    GROQ -.->|"Fallback"| OR
    WIO -->|"Notify"| API

```


## 2. Phase 2: AI Pipeline (The "Brain")

Phase 2 implements a 7-stage sequential pipeline. Every stage is a Celery task. Stage 3 (PII Redaction) serves as a mandatory security gate.

### Pipeline Sequence Diagram

```mermaid
sequenceDiagram
    participant API as cq_api
    participant MINIO as cq_minio
    participant REDIS as cq_redis
    participant GPU as cq_worker_gpu
    participant IO as cq_worker_io
    participant LLM as Groq/OpenRouter

    API->>MINIO: 1. Store Raw Audio
    API->>REDIS: 2. Trigger run_whisperx
    REDIS->>GPU: 3. Process ASR (GPU Queue)
    GPU->>MINIO: 4. Fetch Audio
    GPU-->>REDIS: 5. Diarized JSON Result
    REDIS->>IO: 6. redact_pii (IO Queue)
    Note over IO: Presidio Gate: No raw PII hits DB
    REDIS->>IO: 7. run_groq_inference
    IO->>LLM: 8. JSON Request
    LLM-->>IO: 9. Scored Response
    IO->>API: 10. WebSocket 'complete'

```

### Pipeline Specification

| Stage | Task | Queue | Input | Output |
| --- | --- | --- | --- | --- |
| **01** | `ingest_upload` | API Sync | Multipart File | MinIO Path |
| **02** | `run_whisperx` | `gpu_queue` | MinIO Path | Diarized JSON |
| **03** | `redact_pii` | `io_queue` | Diarized JSON | Redacted JSON |
| **04** | `compute_talk_balance` | `io_queue` | Segment List | Float (0-1) |
| **05** | `run_groq_inference` | `io_queue` | Redacted Text | JSON Metrics |
| **06** | `write_scores` | `io_queue` | All Data | DB Commit |
| **07** | `notify_websocket` | `io_queue` | call_id | WS Event |



## 3. Database Schema (ERD)

The schema is optimized for analytical queries and historical score tracking.

```mermaid
erDiagram
    users ||--o{ calls : "manages"
    agents ||--o{ calls : "handles"
    calls ||--|| call_metrics : "scored_by"
    calls ||--o{ sentiment_timeline : "tracked_by"

    users {
        uuid id PK
        text email
        text role
    }
    agents {
        uuid id PK
        text name
        text team
    }
    calls {
        uuid id PK
        uuid agent_id FK
        text minio_audio_path
        text transcript_redacted
        numeric score
        text status
        boolean pii_redacted
        timestamptz created_at
    }
    call_metrics {
        uuid id PK
        uuid call_id FK
        numeric politeness_score
        numeric resolution_score
        numeric clarity_score
    }
    sentiment_timeline {
        uuid id PK
        uuid call_id FK
        integer timestamp_seconds
        numeric sentiment_value
    }

```


## 4. Engineering Invariants

To maintain SRC-grade integrity, these rules must never be violated:

1. **PII Security Gate:** Raw transcripts (containing PII) must **never** be written to the database. Only the output of `redact_pii` is persisted.
2. **Audio Isolation:** Audio binary data stays in MinIO. Only the object path is stored in PostgreSQL.
3. **Queue Isolation:** `run_whisperx` is pinned to `gpu_queue` (concurrency=1) to prevent VRAM overflow. All other tasks use `io_queue` (concurrency=4).
4. **Atomic Persistence:** Updates to `calls`, `call_metrics`, and `sentiment_timeline` must be executed within a single ACID transaction.



## 5. Milestone Roadmap

| Day | Phase | Milestone | Status |
| --- | --- | --- | --- |
| **1** | Phase 1 | Infra, Auth, MinIO Upload, Celery Config | ✅ |
| **2** | Phase 2.1 | WhisperX ASR + GPU Queue Routing | 🏗️ |
| **3** | Phase 2.2 | PII Redaction + Groq Inference Scoring | 🔲 |
| **4** | Phase 3 | Read Endpoints + Playwright PDF Export | 🔲 |
| **5** | Phase 4 | React Dashboard + Recharts Visualization | 🔲 |
| **6** | Phase 5 | Azure T4 Deployment + Demo Hardening | 🔲 |



## 6. Budget & Resources

* **Target OS:** Windows (Dev) / Azure Linux (Prod)
* **GPU:** NVIDIA T4 (Azure NC4as_T4_v3)
* **LLM Tier:** Groq (Llama-3.1-70b)
* **Azure Credit:** $85.00
* **Estimated Spend:** ~$11.50

```
