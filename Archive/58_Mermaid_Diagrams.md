## Diagram 1 — 7-Stage AI Pipeline

```mermaid
flowchart TD
    A([🎙️ Audio Upload\nWAV · MP3 · M4A · max 100MB]):::upload

    subgraph API["⚡ API Layer — Synchronous"]
        B[Stage 1: Ingest\nStore audio → MinIO\nCreate pending DB row]:::api
    end

    subgraph GPU["🖥️ GPU Worker — gpu_queue · concurrency=1 · prefetch=1"]
        C[Stage 2: WhisperX large-v2\nTranscribe + Diarize\nRTX 3060 Ti · ~33s · AGENT/CUSTOMER labels]:::gpu
    end

    subgraph IO["⚙️ IO Worker — io_queue · concurrency=4"]
        D[Stage 3: Extract Agent Identity\nGroq LLM · fuzzy name match\nagainst agents table]:::io
        E{Stage 4: PII Redaction Gate\nPresidio · South Asian entities\nRaw text NEVER hits DB}:::gate
        F[Stage 5: Compute Talk Balance\n1 - 2 × abs agent_ratio - 0.5\nPerfect 50/50 = 1.0]:::io
        G[Stage 6: Groq LLM Scoring\nllama-3.3-70b-versatile\n5 metrics + coaching summary]:::io
        H[Stage 7: Write Scores\nAtomic transaction\ndelete-then-insert · idempotent]:::io
        I[Stage 8: Notify WebSocket\nRedis pub/sub\ncall_complete → browser toast]:::io
    end

    SCORE["Score Formula\n━━━━━━━━━━━━\n0.25 × politeness\n0.20 × sentiment_delta\n0.20 × resolution\n0.15 × talk_balance\n0.20 × clarity\n━━━━━━━━━━━━\n× 10 = 0–100%"]:::formula
    GATE_WARN["🔴 Security Gate\nIf pii_redacted ≠ TRUE\n→ inference refused"]:::warn

    A --> B
    B --> C
    C -->|segments[]| D
    D -->|redacted_segments[]| E
    E -->|pii_redacted = TRUE| F
    E -.->|BLOCKED| GATE_WARN
    F --> G
    G --> H
    H --> I
    H -.-> SCORE

    classDef upload fill:#3b82f6,stroke:#1d4ed8,color:#fff,rx:12
    classDef api fill:#0ea5e9,stroke:#0369a1,color:#fff
    classDef gpu fill:#7c3aed,stroke:#4c1d95,color:#fff
    classDef io fill:#0f766e,stroke:#134e4a,color:#fff
    classDef gate fill:#dc2626,stroke:#7f1d1d,color:#fff
    classDef formula fill:#1e293b,stroke:#f59e0b,color:#f59e0b,stroke-dasharray:5 5
    classDef warn fill:#1e293b,stroke:#dc2626,color:#dc2626,stroke-dasharray:5 5
```

---

## Diagram 2 — System Architecture

```mermaid
flowchart TB
    subgraph USER["👤 User Layer"]
        BROWSER["QA Manager / Supervisor\n🌐 Browser"]
        DASH["React Dashboard\nReact 19 · TypeScript · Vite\nTailwindCSS v4 · Recharts\nlocalhost:5173"]
    end

    subgraph DOCKER["🐳 Local Docker Compose — 8 Services"]
        subgraph APILAYER["API Layer"]
            API["FastAPI API\nREST + WebSocket\nSQLAlchemy async · Pydantic v2\n:8000"]
            FLOWER["Flower 2.0\nQueue Monitor\n:5555"]
        end

        subgraph WORKERS["Worker Layer"]
            WIO["Celery worker_io\nio_queue · concurrency=4\nextract_agent_identity\nredact_pii · compute_talk_balance\nrun_groq_inference\nwrite_scores · notify_websocket"]
            WGPU["Celery worker_gpu\ngpu_queue · concurrency=1\nrun_whisperx\nRTX 3060 Ti · 8GB VRAM"]
            WHISPER["WhisperX large-v2\n+ Pyannote.audio 3.1\n~33s inference · diarization"]
        end

        subgraph DATA["Data Layer"]
            PG[("PostgreSQL 16\n:5432 · RLS\n6 tables · 7 migrations")]
            REDIS[("Redis 7\n:6379 · AOF\nbroker + pub/sub")]
            MINIO[("MinIO\n:9000\naudio-uploads\npresigned URLs")]
            BATCH["BatchAgent\n:8080 · watchdog\nSHA-256 dedup\nmulti-tenant"]
        end
    end

    subgraph EXTERNAL["☁️ External Services"]
        GROQ["Groq API\nllama-3.3-70b-versatile\n5-metric scoring + coaching"]
        PRESIDIO["Presidio\nPII Redaction\nSouth Asian entities"]
    end

    BROWSER -->|HTTP + WebSocket| DASH
    DASH -->|Vite proxy| API
    API <-->|asyncpg| PG
    API <-->|pub/sub| REDIS
    API -->|presigned URL| MINIO
    WIO <-->|Celery| REDIS
    WIO --> PG
    WIO -->|HTTPS · BYOK| GROQ
    WIO --> PRESIDIO
    WGPU --> WHISPER
    WGPU -->|download audio| MINIO
    WGPU --> PG
    BATCH -->|POST /calls/upload| API

    classDef data fill:#1e3a5f,stroke:#3b82f6,color:#93c5fd
    classDef worker fill:#3b0764,stroke:#7c3aed,color:#d8b4fe
    classDef api fill:#052e16,stroke:#16a34a,color:#86efac
    classDef external fill:#431407,stroke:#ea580c,color:#fdba74
    classDef user fill:#082f49,stroke:#0ea5e9,color:#7dd3fc

    class PG,REDIS,MINIO,BATCH data
    class WIO,WGPU,WHISPER worker
    class API,FLOWER api
    class GROQ,PRESIDIO external
    class BROWSER,DASH user
```

---

## Diagram 3 — Multi-Tenancy & RLS

```mermaid
flowchart TD
    subgraph REQUEST["🔐 Request Auth Flow"]
        J1["JWT arrives\ncontains tenant_id claim"]
        J2["get_current_user\nextracts tenant_id\nsets request.state.tenant_id"]
        J3["get_db_with_tenant\nBEGIN transaction\nSET LOCAL app.current_tenant = :tid"]
        J4["Query executes\nRLS filters automatically"]
        J5["Response\nonly tenant data returned"]

        J1 --> J2 --> J3 --> J4 --> J5
    end

    subgraph INFRA["🐳 Shared Infrastructure"]
        subgraph PG["PostgreSQL 16"]
            RLS["🔴 FORCE ROW LEVEL SECURITY\nEven superuser obeys RLS\nApplied to all 6 tables"]

            subgraph DEMO["🔵 Demo Tenant"]
                DU["Users\nadmin@callquality.demo\nsupervisor@callquality.demo\nviewer@callquality.demo"]
                DA["Agents\nSarah Chen · Marcus Williams\nAisha Rahman · David Park\nPriya Patel"]
                DC["Calls\n200 seeded · scores 82–92%"]
            end

            subgraph BPO["🟢 BPO Solutions Tenant"]
                BU["Users\nbpo_admin@bposolutions.com"]
                BA["Agents\nisolated agent pool"]
                BC["Calls\ncompletely isolated"]
            end

            POLICY["RLS Policy applied on every query\nWHERE tenant_id =\ncurrent_setting('app.current_tenant')::uuid"]
        end
    end

    WARN["⛔ NEVER crosses tenant boundary\nNo shared calls · No shared agents\nNo shared metrics · No shared scores\n✅ Verified: Demo ↔ BPO fully isolated"]:::warn

    RLS --> DEMO
    RLS --> BPO
    DEMO -.-> POLICY
    BPO -.-> POLICY
    INFRA -.-> WARN

    classDef warn fill:#1e293b,stroke:#dc2626,color:#fca5a5,stroke-dasharray:5 5
```
