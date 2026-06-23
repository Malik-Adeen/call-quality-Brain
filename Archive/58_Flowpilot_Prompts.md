# OpenFlowKit — Flowpilot Prompts
# AI Call Quality Analytics System
# Use with: Groq llama-3.3-70b-versatile or Claude claude-sonnet-4-20250514
# Paste each prompt separately into Flowpilot. Generate one diagram at a time.

---

## DIAGRAM 1 — 7-Stage AI Pipeline

Paste this into Flowpilot:

---

Create a vertical top-to-bottom flowchart showing the 7-stage AI audio processing pipeline for a call quality analytics system. Use a clean, modern dark style.

Nodes in order (top to bottom):

1. UPLOAD (rectangle, blue)
   Label: "Audio Upload"
   Subtitle: "POST /calls/upload · WAV/MP3/M4A · max 100MB"

2. INGEST (rectangle, blue)
   Label: "Stage 1: Ingest"
   Subtitle: "Store audio → MinIO · Create pending DB row"

3. WHISPERX (rectangle, purple)
   Label: "Stage 2: WhisperX Transcription"
   Subtitle: "gpu_queue · RTX 3060 Ti · ~33s · AGENT/CUSTOMER labels"

4. IDENTITY (rectangle, orange)
   Label: "Stage 3: Agent Identity Extraction"
   Subtitle: "io_queue · Groq LLM · fuzzy match against agents table"

5. PII (rectangle, red)
   Label: "Stage 4: PII Redaction Gate"
   Subtitle: "io_queue · Presidio · Raw text NEVER hits DB"

6. TALK (rectangle, teal)
   Label: "Stage 5: Talk Balance"
   Subtitle: "io_queue · score = 1 - 2 * abs(agent_ratio - 0.5)"

7. GROQ (rectangle, teal)
   Label: "Stage 6: Groq LLM Scoring"
   Subtitle: "io_queue · llama-3.3-70b-versatile · 5 metrics + coaching"

8. WRITE (rectangle, green)
   Label: "Stage 7: Write Scores"
   Subtitle: "io_queue · Atomic transaction · delete-then-insert (idempotent)"

9. NOTIFY (rectangle, green)
   Label: "Stage 8: Notify WebSocket"
   Subtitle: "io_queue · Redis pub/sub → browser toast · call_complete event"

Add a side node connected to WRITE:
   Label: "Score Formula"
   Style: dashed border, yellow
   Content:
   "0.25 × politeness
    0.20 × sentiment_delta
    0.20 × resolution
    0.15 × talk_balance
    0.20 × clarity
    ──────────────────
    × 10 = 0–100%"

Add a side node connected to PII:
   Label: "Security Gate"
   Style: dashed red border
   Content: "If pii_redacted ≠ TRUE
   → inference refused"

Connect all nodes top to bottom with arrows. Label the arrow between WHISPERX and IDENTITY: "segments[]". Label the arrow between PII and TALK: "redacted_segments[]".

---

## DIAGRAM 2 — System Architecture

Paste this into Flowpilot:

---

Create a system architecture diagram showing the full deployment topology of an AI Call Quality Analytics System running in local Docker. Use a clean layered style with swimlanes or grouped sections.

Show four layers from top to bottom:

LAYER 1 — User Layer (light blue background):
- Node: "QA Manager / Supervisor" (person icon)
- Node: "React Dashboard" (rectangle)
  Subtitle: "React 19 · TypeScript · Vite · TailwindCSS v4 · Recharts"
  Port: localhost:5173
- Arrow: browser → dashboard labeled "HTTP + WebSocket"

LAYER 2 — API Layer (dark background):
- Node: "FastAPI API" (rectangle, blue)
  Subtitle: "REST + WebSocket · :8000 · SQLAlchemy async · Pydantic v2"
- Node: "Flower Monitor" (rectangle, orange)
  Subtitle: "Queue monitor · :5555"
- Arrow: dashboard → FastAPI labeled "Vite proxy"

LAYER 3 — Worker Layer (purple background):
Two workers side by side:
- Left: "Celery worker_io" (rectangle, teal)
  Subtitle: "io_queue · concurrency=4 · prefetch=2
  Tasks: extract_agent_identity, redact_pii,
  compute_talk_balance, run_groq_inference,
  write_scores, notify_websocket"

- Right: "Celery worker_gpu" (rectangle, purple)
  Subtitle: "gpu_queue · concurrency=1 · prefetch=1
  Task: run_whisperx
  RTX 3060 Ti · 8GB VRAM · CUDA 12.1"

Below worker_gpu:
- Node: "WhisperX large-v2 + Pyannote 3.1" (rectangle, purple dashed)
  Subtitle: "~33s inference · speaker diarization"

LAYER 4 — Data Layer (dark grey background):
Four nodes side by side:
- "PostgreSQL 16" (cylinder, blue)
  Subtitle: ":5432 · RLS · 6 tables · 007 migrations"
- "Redis 7" (cylinder, red)
  Subtitle: ":6379 · AOF persistence · Celery broker + pub/sub"
- "MinIO" (cylinder, green)
  Subtitle: ":9000 · audio-uploads bucket · presigned URLs"
- "BatchAgent" (rectangle, grey)
  Subtitle: ":8080 · watchdog · SHA-256 dedup · multi-tenant"

External service (right side, outside the main diagram):
- "Groq API" (cloud, teal)
  Subtitle: "llama-3.3-70b-versatile · 5-metric scoring + coaching"
- "Presidio" (rectangle, red)
  Subtitle: "PII redaction · extended for South Asian entities"

Arrows:
- FastAPI ↔ PostgreSQL (labeled "SQLAlchemy asyncpg")
- FastAPI ↔ Redis (labeled "pub/sub + result backend")
- FastAPI → MinIO (labeled "presigned URL")
- worker_io → PostgreSQL
- worker_io → Redis (labeled "Celery")
- worker_io → Groq API (labeled "HTTPS · BYOK")
- worker_io → Presidio
- worker_gpu → MinIO (labeled "download audio")
- worker_gpu → PostgreSQL
- BatchAgent → FastAPI (labeled "POST /calls/upload")

---

## DIAGRAM 3 — Multi-Tenancy Architecture

Paste this into Flowpilot:

---

Create a diagram showing the multi-tenancy and data isolation architecture of a B2B SaaS call quality analytics system. Use a clean enterprise style.

Show the overall structure as nested containers:

OUTER CONTAINER: "Shared Infrastructure" (light grey border)
Contains: FastAPI, PostgreSQL, Redis, MinIO, Celery workers

Inside PostgreSQL, show three layers of isolation:
1. "FORCE ROW LEVEL SECURITY" (red label at top)
   Subtitle: "Even superuser obeys RLS policies · 6 tables"

2. Two tenant boxes side by side:
   LEFT BOX: "Demo Tenant" (blue border)
   Contents:
   - Users: admin@callquality.demo, supervisor@, viewer@
   - Roles: TENANT_ADMIN, SUPERVISOR, VIEWER
   - Agents: 5 agents (Sarah Chen, Marcus Williams, etc.)
   - Calls: tenant-scoped via tenant_id FK

   RIGHT BOX: "BPO Solutions Tenant" (green border)
   Contents:
   - Users: bpo_admin@bposolutions.com
   - Roles: TENANT_ADMIN
   - Agents: isolated agents
   - Calls: completely isolated

3. Below both boxes, show the RLS policy:
   Label: "RLS Policy on every query"
   Content: "WHERE tenant_id = current_setting('app.current_tenant')::uuid"
   Style: dashed yellow box

Show the request flow on the right side as a vertical sequence:
1. "JWT Token arrives" → contains tenant_id claim
2. "get_current_user()" → extracts tenant_id → sets request.state.tenant_id
3. "get_db_with_tenant()" → BEGIN transaction → SET LOCAL app.current_tenant = :tid
4. "Query executes" → RLS filters to tenant automatically
5. "Response" → only tenant's data returned

Add a red warning box:
Label: "NEVER crosses tenant boundary"
Content: "No shared calls · No shared agents · No shared metrics
Verified: Demo Tenant and BPO Solutions fully isolated"

---

## TIPS FOR USING THESE PROMPTS IN FLOWPILOT

1. Open openflowkit.com → New Flow
2. Settings (gear icon) → add your Groq API key
3. Select model: llama-3.3-70b-versatile
4. Open Flowpilot panel
5. Paste ONE prompt at a time
6. After generation, refine with follow-up messages like:
   - "Make the color scheme match dark mode"
   - "Add the Waaqi GRC teal color #00a99d as the primary accent"
   - "Make the pipeline nodes wider and add more spacing"
   - "Export as SVG for Figma"
7. Export: PNG for presentations · SVG for Figma · JSON for version control
