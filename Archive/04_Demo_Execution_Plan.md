# 04 — Demo Execution Plan
> **Daily execution guide.** Work through each checkbox sequentially.
> When starting any Antigravity or Claude session, state: **"We are on Phase N, Step M."**
> Never ask an LLM to build two phases simultaneously.

---

## How to Use This Document

1. Paste `01_Master_Architecture.md` + `02_Database_Schema.sql` + `03_API_Contract.md` at the top of every LLM session
2. State the current phase and step number explicitly
3. Complete the Definition of Done gate before advancing to the next phase
4. Check items off as you complete them — this is your live project state tracker

---

## Phase 0 — Local Infrastructure Setup
**Timeline:** Days 1–3 · Azure spend: $0 · Local Arch Linux only

### 0.1 — System Prerequisites
- [ ] Install Docker and Docker Compose: `sudo pacman -S docker docker-compose`
- [ ] Enable Docker daemon: `sudo systemctl enable --now docker`
- [ ] Add user to docker group: `sudo usermod -aG docker $USER` then re-login
- [ ] Verify GPU availability: `nvidia-smi` — note down VRAM total
- [ ] Accept Pyannote.audio model terms at `hf.co/pyannote/speaker-diarization-3.1`
- [ ] Accept Pyannote.audio model terms at `hf.co/pyannote/segmentation-3.0`

### 0.2 — Repository and Environment
- [ ] Initialise Git repo with `main` as default branch
- [ ] Create directory structure: `/backend` `/frontend` `/infra` `/scripts`
- [ ] Create `/infra/.env` file with all variables from the template below
- [ ] Populate `.env` with real values: `GROQ_API_KEY` · `OPENROUTER_API_KEY` · `HF_TOKEN` · `JWT_SECRET`

```
POSTGRES_USER=callquality
POSTGRES_PASSWORD=callquality_dev
POSTGRES_DB=callquality
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin_dev
GROQ_API_KEY=
OPENROUTER_API_KEY=
HF_TOKEN=
JWT_SECRET=
FLOWER_USER=admin
FLOWER_PASSWORD=flower_dev
WHISPER_DEVICE=cpu
WHISPER_MODEL=base
```

### 0.3 — Docker Compose: Ephemeral Infrastructure

The compose file below is the canonical `docker-compose.yml`. It is ephemeral by design.
No named volumes. No backup cron jobs. No production SSL. Data lives only as long as containers do.

```yaml
version: "3.9"

networks:
  callquality_net:
    driver: bridge

services:

  postgres:
    image: postgres:16-alpine
    container_name: cq_postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    ports:
      - "5432:5432"
    networks:
      - callquality_net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 10s

  redis:
    image: redis:7-alpine
    container_name: cq_redis
    restart: unless-stopped
    command: redis-server --save "" --appendonly no
    ports:
      - "6379:6379"
    networks:
      - callquality_net
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 10

  minio:
    image: minio/minio:latest
    container_name: cq_minio
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    ports:
      - "9000:9000"
      - "9001:9001"
    networks:
      - callquality_net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 15s

  api:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: cq_api
    restart: unless-stopped
    env_file: .env
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      REDIS_URL: redis://redis:6379/0
      MINIO_ENDPOINT: minio:9000
      MINIO_ACCESS_KEY: ${MINIO_ROOT_USER}
      MINIO_SECRET_KEY: ${MINIO_ROOT_PASSWORD}
      MINIO_BUCKET: audio-uploads
    ports:
      - "8000:8000"
    networks:
      - callquality_net
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
      minio:
        condition: service_healthy

  worker_io:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: cq_worker_io
    restart: unless-stopped
    command: >
      celery -A app.celery_app worker
      --queues=io_queue
      --concurrency=4
      --prefetch-multiplier=2
      --loglevel=info
      --hostname=worker_io@%h
    env_file: .env
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      REDIS_URL: redis://redis:6379/0
    networks:
      - callquality_net
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  worker_gpu:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: cq_worker_gpu
    restart: unless-stopped
    command: >
      celery -A app.celery_app worker
      --queues=gpu_queue
      --concurrency=1
      --prefetch-multiplier=1
      --loglevel=info
      --hostname=worker_gpu@%h
    env_file: .env
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      REDIS_URL: redis://redis:6379/0
      WHISPER_DEVICE: ${WHISPER_DEVICE}
      WHISPER_MODEL: ${WHISPER_MODEL}
      HF_TOKEN: ${HF_TOKEN}
    networks:
      - callquality_net
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    # deploy:
    #   resources:
    #     reservations:
    #       devices:
    #         - driver: nvidia
    #           count: 1
    #           capabilities: [gpu]

  flower:
    image: mher/flower:2.0
    container_name: cq_flower
    restart: unless-stopped
    command: >
      celery --broker=redis://redis:6379/0
      flower --port=5555
      --basic_auth=${FLOWER_USER}:${FLOWER_PASSWORD}
    ports:
      - "5555:5555"
    networks:
      - callquality_net
    depends_on:
      - redis
```

### 0.4 — Infrastructure Verification
- [ ] Run: `docker compose up -d postgres redis minio`
- [ ] Verify: `docker compose ps` — all three show `healthy`
- [ ] Verify MinIO console at `http://localhost:9001` — login works
- [ ] Verify Redis: `docker exec cq_redis redis-cli ping` — returns `PONG`
- [ ] Run `scripts/seed_data.py` (Phase 4.1 below) — verify 200 rows inserted and verification table prints
- [ ] Commit initial state to Git

### ✅ Phase 0 — Definition of Done
- `docker compose ps` shows `postgres`, `redis`, `minio` all `healthy`
- `seed_data.py` completes and prints the agent breakdown table
- All 5 schema tables exist with correct column names from `02_Database_Schema.sql`
- `.env` populated with all real API keys

---

## Phase 1 — Foundation Layer
**Timeline:** Weeks 1–2 · Azure spend: $0 · Local only

### 1.1 — Backend Scaffolding
- [ ] Create `backend/requirements.txt` with core deps: `fastapi uvicorn[standard] sqlalchemy[asyncio] alembic asyncpg psycopg2-binary celery[redis] boto3 python-jose[cryptography] bcrypt pydantic[email]`
- [ ] Create `backend/Dockerfile` — Python 3.11 slim base, non-root user, `uvicorn` entrypoint
- [ ] Create `backend/app/main.py` — FastAPI app factory, CORS middleware, router registration
- [ ] Create `backend/app/routers/` — `auth.py` `calls.py` `agents.py` `reports.py` `ws.py`
- [ ] Create `backend/app/models/` — SQLAlchemy ORM models matching `02_Database_Schema.sql` **exactly**
- [ ] Create `backend/app/schemas/` — Pydantic models matching `03_API_Contract.md` envelope **exactly**
- [ ] **GATE:** Run `psql` diff between ORM column names and live schema — zero mismatches permitted

### 1.2 — Authentication
- [ ] Implement `POST /auth/login` — returns JWT matching `03_API_Contract.md` response shape exactly
- [ ] Implement JWT decode middleware injecting `current_user` into request state
- [ ] Implement `require_role()` dependency — `VIEWER` role must not be able to `POST /calls/upload`
- [ ] Test: valid credentials → assert `access_token` returned
- [ ] Test: invalid credentials → assert `401 INVALID_CREDENTIALS`
- [ ] Test: `VIEWER` role upload attempt → assert `403 FORBIDDEN`

### 1.3 — File Upload and MinIO
- [ ] Implement MinIO client: `upload_audio(file, agent_id) -> minio_audio_path`
- [ ] Implement `POST /calls/upload` — validate type/size → upload → insert `pending` row → enqueue
- [ ] Verify: `minio_audio_path` stored in `calls` table — audio binary **never** in DB
- [ ] Verify: `calls.pii_redacted` is `FALSE` on the newly inserted row
- [ ] Test: upload `.wav` → assert MinIO object exists at returned path
- [ ] Test: upload `.exe` → assert `400 INVALID_FILE_TYPE`

### 1.4 — Celery Workers
- [ ] Create `backend/app/celery_app.py` — broker, result backend, `task_routes` from `01_Master_Architecture.md`
- [ ] Create placeholder tasks in `backend/app/pipeline/tasks.py` — each logs stage name and returns `True`
- [ ] Run: `docker compose up -d` — all 7 services
- [ ] Verify: `docker compose logs worker_io | grep "ready"` — worker registered
- [ ] Verify: `docker compose logs worker_gpu | grep "ready"` — worker registered
- [ ] Verify: enqueue a test task via Flower UI → confirm it routes to the correct queue
- [ ] Access Flower at `http://localhost:5555` — both `worker_io` and `worker_gpu` visible

### ✅ Phase 1 — Definition of Done
- `POST /auth/login` returns correct `03_API_Contract.md` envelope
- `POST /calls/upload` creates MinIO object **and** `pending` row in `calls` table
- Both Celery workers visible in Flower with correct queue assignments
- All pytest tests pass

---

## Phase 2 — Core AI Pipeline
**Timeline:** Weeks 3–5 · Azure spend: $0 · CPU fallback path

### 2.1 — WhisperX Transcription
- [ ] Add to `requirements.txt`: `whisperx pyannote.audio`
- [ ] Implement `run_whisperx` task on `gpu_queue`
- [ ] Load `WHISPER_DEVICE` and `WHISPER_MODEL` from environment — never hardcode
- [ ] Implement pynvml VRAM sentinel — defer if VRAM < 2 GB; skip gracefully if no GPU
- [ ] Speaker labels output: `AGENT` or `CUSTOMER` — remap `SPEAKER_00`/`SPEAKER_01` immediately after diarization
- [ ] Output format: matches `diarized_segments` schema in `03_API_Contract.md` exactly
- [ ] Test: run on one real 3–5 min audio file — verify output shape and speaker labels

### 2.2 — PII Redaction Gate
- [ ] Add to `requirements.txt`: `presidio-analyzer presidio-anonymizer`
- [ ] Implement `redact_pii` task on `io_queue` — executes immediately after `run_whisperx`
- [ ] Detect entity types: `CREDIT_CARD` `PHONE_NUMBER` `EMAIL_ADDRESS` `PERSON` `US_SSN` `IBAN_CODE` `DATE_TIME` `LOCATION`
- [ ] Replace with typed tokens: `<CREDIT_CARD>` `<PHONE>` `<EMAIL>` `<PERSON>` etc.
- [ ] Set `calls.pii_redacted = TRUE` in DB before any downstream task runs
- [ ] **GATE:** regex scan the redacted output — assert zero raw PII patterns survive
- [ ] Never log transcript content — log only `call_id` and entity count

### 2.3 — Groq Inference
- [ ] Implement `backend/app/services/llm_client.py` with `PROVIDER_CHAIN` from `01_Master_Architecture.md`
- [ ] Fallback triggers: HTTP `429` or HTTP `503` from Groq only
- [ ] System prompt: `"You are a professional call quality analyst. Respond ONLY with valid JSON. No markdown, no preamble."`
- [ ] Validate Groq response with Pydantic: `{resolution_score, politeness_score, clarity_score, sentiment_delta, coaching_summary}`
- [ ] All float scores must be `0.0 – 1.0` — reject and retry if out of range
- [ ] Cache result by MD5 of redacted transcript — skip re-inference on duplicate uploads

### 2.4 — Scoring and Database Write
- [ ] Implement `compute_talk_balance` — word count ratio from diarized speaker segments; no model
- [ ] Implement `write_scores` — apply scoring formula from `01_Master_Architecture.md` exactly
- [ ] DB write is one atomic transaction: `UPDATE calls` + `INSERT call_metrics` + `INSERT N sentiment_timeline rows`
- [ ] On transaction failure: full rollback → set `calls.status = 'failed'`
- [ ] `calls.status = 'complete'` set only inside the same transaction as the score write
- [ ] Verify with query: confirm all 3 tables populated for a test `call_id`

### 2.5 — WebSocket Notification
- [ ] Implement `/ws/{user_id}` endpoint — JWT auth via `?token=` query param
- [ ] Implement `ConnectionManager` — dict of `user_id → WebSocket`
- [ ] Implement `notify_websocket` task — emit `call_complete` event matching `03_API_Contract.md`
- [ ] Test: upload → process → verify `call_complete` WS event received with correct `score` and `call_id`

### ✅ Phase 2 — Definition of Done
- 5-minute real audio file → complete scored result in < 15 min on CPU
- `calls.pii_redacted = TRUE` for every completed call — no exceptions
- Groq returns valid JSON for 10 consecutive test calls — zero parse errors
- All 7 pipeline stages visible in Flower task history
- Zero raw PII patterns detectable in `transcript_redacted` column via regex

---

## Phase 3 — Frontend Dashboard
**Timeline:** Weeks 5–6 · Provision Azure `B2s` at start of Week 5

### 3.1 — Project Setup
- [ ] Scaffold: `npm create vite@latest frontend -- --template react-ts`
- [ ] Install: `tailwindcss recharts axios react-router-dom zustand`
- [ ] Create `frontend/src/types/api.ts` — paste TypeScript interfaces from `03_API_Contract.md` exactly
- [ ] Create `frontend/src/api/client.ts` — Axios instance, JWT from Zustand injected via interceptor
- [ ] JWT stored in Zustand (memory) — **never** `localStorage`
- [ ] Axios interceptor: redirect to `/login` on `401` response

### 3.2 — Module 1: KPI Overview
- [ ] Build `KPICard` component: props `label` · `value` · `delta` · `trend: 'up'|'down'|'flat'`
- [ ] KPI Overview page: 4 cards — Total Calls · Avg Score · Resolution % · Avg Sentiment Delta
- [ ] 30-day Recharts `LineChart` sparkline below each card
- [ ] Wire to `GET /calls?status=complete&date_from=<30 days ago>`
- [ ] Verify numbers match `seed_data.py` verification output

### 3.3 — Module 2: Call List
- [ ] Data table columns: agent name · score · duration · resolved badge · `created_at`
- [ ] Filter panel: agent dropdown · resolved toggle · score range · date range
- [ ] Pagination controls
- [ ] Score colour coding: green ≥ 7.5 · amber 5.5–7.4 · red < 5.5
- [ ] Row click navigates to `/calls/{id}`

### 3.4 — Module 3: Call Detail + Audio Sync
- [ ] Two-panel layout: left transcript · right scores + coaching summary
- [ ] `AGENT` segments: left-aligned, blue background
- [ ] `CUSTOMER` segments: right-aligned, grey background
- [ ] HTML5 `<audio>` player fixed at page bottom — `src` from MinIO presigned URL
- [ ] Clicking any segment: `audioRef.current.currentTime = segment.start`
- [ ] Active word highlight: compare `currentTime` to `word.start`/`word.end` every 100ms
- [ ] Recharts `AreaChart` sentiment timeline below transcript
- [ ] Recharts horizontal `BarChart` showing all 5 `CallMetrics` component scores

### 3.5 — Module 4: Agent View
- [ ] Summary stat cards from `GET /agents/{id}/scores`
- [ ] Recharts `LineChart` score history, 30-day rolling window
- [ ] Team average reference line on the chart
- [ ] Strengths/weaknesses cards — top 2 and bottom 2 component scores highlighted

### 3.6 — Module 5: Reports + WebSocket
- [ ] Export PDF button on `CallDetail` — `POST /reports/export` → browser download via `Blob` URL
- [ ] Loading spinner while Playwright renders
- [ ] `useWebSocket` hook — connect to `/ws/{user_id}?token={jwt}`
- [ ] On `call_complete`: update call in list state + show toast: `"Call scored: {agent_name} — {score}/10"`
- [ ] Reconnect with exponential backoff: 1s → 2s → 4s → 8s → cap at 30s

### ✅ Phase 3 — Definition of Done
- All 5 modules render correctly against seeded data
- Clicking a transcript segment seeks audio to correct timestamp (within 0.5s)
- WebSocket toast appears within 3 seconds of uploading a test call
- PDF export produces a file > 50 KB with visible Recharts SVGs
- Score colour coding correct across the entire call list

---

## Phase 4 — Demo Preparation, Seed Data & Azure GPU Migration
**Timeline:** Weeks 7–8 · Provision `NC4as_T4_v3` in Week 8 only

### 4.1 — Seed Data Script

Save as `scripts/seed_data.py`. Run after Phase 0 infra is healthy.

```python
import os
import sys
import uuid
import math
import random
from datetime import datetime, timedelta, timezone

try:
    import psycopg2
    from psycopg2.extras import RealDictCursor, execute_values
except ImportError:
    print("Run: pip install psycopg2-binary")
    sys.exit(1)

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://callquality:callquality_dev@localhost:5432/callquality"
)

AGENTS = [
    {"name": "Sarah Chen",      "team": "Support", "skill_bias": +0.8},
    {"name": "Marcus Williams", "team": "Support", "skill_bias": +0.3},
    {"name": "Priya Patel",     "team": "Sales",   "skill_bias": +0.1},
    {"name": "James O'Brien",   "team": "Sales",   "skill_bias": -0.4},
    {"name": "Fatima Al-Zahra", "team": "Support", "skill_bias": -0.9},
]

ISSUE_CATEGORIES = [
    "billing_dispute", "technical_support", "account_access",
    "service_cancellation", "upgrade_request", "refund_request",
    "delivery_issue", "password_reset", "plan_change", "complaint",
]

COACHING_HIGH = [
    "Agent demonstrated excellent active listening throughout. Sentiment improved significantly across the call. Resolution confirmed verbally before closing. Recommend sharing as a positive training example.",
    "Outstanding de-escalation within the first 90 seconds. Talk balance near-ideal. Step-by-step resolution walkthrough prevented a likely callback.",
    "Strong product knowledge communicated without condescension. Teach-back technique used unprompted at call close.",
]
COACHING_MID = [
    "Competent handling with one gap: agent interrupted the customer twice during the explanation phase. Resolution achieved but customer confidence appeared low. Recommend active listening training.",
    "Adequate resolution but call ran long due to over-explaining steps the customer had not asked about. Core skills are solid — focus on conciseness.",
    "Good opening and closing. Weakness in the middle: two holds in four minutes while checking refund policy. Recommend having policy reference materials open during calls.",
]
COACHING_LOW = [
    "Call ended without confirmed resolution. Customer stated the issue persists but agent closed after a standard script response. Mandatory resolution confirmation checklist review required.",
    "Multiple clarity failures. Agent used internal jargon the customer explicitly said they did not understand. Sentiment declined steadily. Communication skills training recommended.",
    "Agent rushed the call, cutting off the customer's problem description at 1:15 and jumping to a solution that was incorrect for the actual issue described.",
]

def clamp(v, lo, hi):
    return max(lo, min(hi, v))

def normal_score(mean, std):
    return clamp(random.gauss(mean, std), 2.0, 9.5)

def coaching_for(score):
    if score >= 7.5:
        return random.choice(COACHING_HIGH)
    if score >= 5.5:
        return random.choice(COACHING_MID)
    return random.choice(COACHING_LOW)

def build_call(agent_id, skill_bias, created_at):
    call_id = str(uuid.uuid4())
    score = round(normal_score(6.8 + skill_bias, 1.4), 2)
    resolved = random.random() < clamp(1 / (1 + math.exp(-0.7 * (score - 5.5))), 0.05, 0.97)
    duration = random.randint(180, 720) if resolved else random.randint(300, 1080)

    if resolved:
        s_start = round(random.uniform(-0.7, 0.1), 4)
        s_end   = round(random.uniform(0.2, 0.85), 4)
    else:
        s_start = round(random.uniform(-0.5, 0.2), 4)
        s_end   = round(random.uniform(-0.8, 0.1), 4)

    s_norm  = round((s_end - s_start + 1.0) / 2.0, 4)
    pol     = round(clamp(((score - 2.0) / 7.5) + random.gauss(0, 0.08), 0.0, 1.0), 4)
    res     = round(clamp(float(resolved) * 0.7 + random.gauss(0.15, 0.1), 0.0, 1.0), 4)
    cla     = round(clamp(((score - 2.0) / 7.5) * 0.9 + random.gauss(0, 0.08), 0.0, 1.0), 4)
    bal     = round(clamp(random.gauss(0.48 if score >= 7.0 else 0.38, 0.06), 0.1, 0.9), 4)
    s_delta = round(s_end - s_start, 4)

    num_points = min(max(4, duration // 60), 12)
    timeline = []
    for i in range(num_points):
        progress = i / (num_points - 1) if num_points > 1 else 0
        val = round(clamp(s_start + (s_end - s_start) * progress + random.gauss(0, 0.12), -1.0, 1.0), 4)
        timeline.append((call_id, int((duration / num_points) * i), val))

    import hashlib
    fake_hash = hashlib.md5(call_id.encode()).hexdigest()[:12]
    audio_path = f"audio-uploads/{agent_id}/{created_at.strftime('%Y/%m/%d')}/{fake_hash}.wav"

    call_row = (
        call_id, agent_id, audio_path,
        f"[REDACTED — {random.choice(ISSUE_CATEGORIES).replace('_', ' ').title()}]",
        duration, round(clamp((0.25*pol + 0.20*s_norm + 0.20*res + 0.15*bal + 0.20*cla) * 10, 0, 10), 2),
        resolved, s_start, s_end, True, "complete",
        random.choice(ISSUE_CATEGORIES), coaching_for(score), created_at,
    )
    metrics_row = (str(uuid.uuid4()), call_id, pol, s_delta, res, bal, cla)
    return call_row, metrics_row, timeline

def main():
    print("=" * 60)
    print("AI Call Quality — Seed Data Generator")
    print("200 calls · 5 agents · 90-day window")
    print("=" * 60)

    conn = psycopg2.connect(DATABASE_URL)
    conn.autocommit = False
    cur = conn.cursor(cursor_factory=RealDictCursor)

    cur.execute("""
        INSERT INTO agents (name, team) VALUES (%s, %s) RETURNING id
    """, (AGENTS[0]["name"], AGENTS[0]["team"]))

    agent_ids = {}
    for a in AGENTS:
        cur.execute("INSERT INTO agents (name, team) VALUES (%s, %s) RETURNING id", (a["name"], a["team"]))
        agent_ids[a["name"]] = {"id": str(cur.fetchone()["id"]), "skill_bias": a["skill_bias"]}
    conn.commit()

    agent_list  = list(agent_ids.values())
    now         = datetime.now(timezone.utc)
    calls, metrics, timeline = [], [], []

    for _ in range(200):
        agent      = random.choices(agent_list, k=1)[0]
        days_ago   = min(random.expovariate(1 / 15), 90)
        created_at = now - timedelta(days=days_ago, seconds=random.randint(0, 86400))
        c, m, t    = build_call(agent["id"], agent["skill_bias"], created_at)
        calls.append(c)
        metrics.append(m)
        timeline.extend(t)

    execute_values(cur, """
        INSERT INTO calls (
            id, agent_id, minio_audio_path, transcript_redacted, duration,
            score, resolved, sentiment_start, sentiment_end, pii_redacted,
            status, issue_category, coaching_summary, created_at
        ) VALUES %s
    """, calls)

    execute_values(cur, """
        INSERT INTO call_metrics (id, call_id, politeness_score, sentiment_delta,
            resolution_score, talk_balance_score, clarity_score)
        VALUES %s
    """, metrics)

    execute_values(cur, """
        INSERT INTO sentiment_timeline (call_id, timestamp_seconds, sentiment_value)
        VALUES %s
    """, timeline)

    conn.commit()

    cur.execute("""
        SELECT a.name, COUNT(c.id) AS calls,
               ROUND(AVG(c.score)::numeric, 2) AS avg_score,
               SUM(CASE WHEN c.resolved THEN 1 ELSE 0 END) AS resolved
        FROM agents a
        JOIN calls c ON c.agent_id = a.id
        GROUP BY a.id, a.name ORDER BY avg_score DESC
    """)
    print(f"\n{'Agent':<22} {'Calls':<7} {'Avg Score':<11} Resolved")
    print("-" * 55)
    for r in cur.fetchall():
        print(f"{r['name']:<22} {r['calls']:<7} {r['avg_score']:<11} {r['resolved']}")

    cur.close()
    conn.close()
    print("\n✓ Seed complete.")

if __name__ == "__main__":
    random.seed(42)
    main()
```

### 4.2 — Observability
- [ ] Implement `GET /admin/gpu-status` — ADMIN role only
- [ ] Return: `vram_total_mb` · `vram_used_mb` · `vram_free_mb` · `gpu_utilization_pct` · `temperature_c` · `gpu_queue_depth` · `io_queue_depth` · `active_workers`
- [ ] Return `null` GPU fields gracefully when no GPU is present — do not error
- [ ] Verify Flower shows correct queue depths matching `LLEN gpu_queue` in Redis

### 4.3 — Azure B2s Deployment (Always-On Demo Server)
- [ ] Provision Azure `B2s` VM — Ubuntu 22.04 LTS — estimated cost $0.05/hr
- [ ] Install Docker + Docker Compose on VM (`apt` — no NVIDIA runtime needed)
- [ ] Copy repo and `.env` to VM
- [ ] Run `docker compose up -d` — verify all 7 services healthy
- [ ] Run `seed_data.py` on the VM
- [ ] Access dashboard via VM public IP — verify all 5 modules load with seeded data
- [ ] Note VM public IP — this is your always-on demo URL

### 4.4 — Azure NC4as_T4_v3 GPU Migration (Live Pipeline Demo Only)
- [ ] Provision `NC4as_T4_v3` — Ubuntu 22.04 LTS — cost $0.53/hr
- [ ] Install NVIDIA Container Toolkit: `sudo apt install nvidia-container-toolkit`
- [ ] Uncomment the `deploy.resources` block in `docker-compose.yml` for `worker_gpu`
- [ ] Set in `.env`: `WHISPER_DEVICE=cuda` and `WHISPER_MODEL=large-v2`
- [ ] Run `docker compose up -d worker_gpu` — verify GPU worker starts
- [ ] Verify: `docker exec cq_worker_gpu nvidia-smi` — T4 visible
- [ ] Test full pipeline: upload real audio → verify < 90s end-to-end

### 4.5 — Demo Day Protocol
- [ ] `B2s` VM is running and healthy — dashboard pre-loaded with seeded data
- [ ] Start `NC4as_T4_v3` VM exactly 20 minutes before the live pipeline demo segment
- [ ] Prepare 2–3 real audio files (3–5 minutes each) on your local machine, ready to upload
- [ ] Verify Flower dashboard accessible — show both workers during professor demo
- [ ] Demo script order: KPI Overview → Call List → Call Detail (audio sync) → Agent View → Live Upload
- [ ] **Immediately after demo:** stop `NC4as_T4_v3` — do not leave it running

### 4.6 — Final Hardening
- [ ] Change `FLOWER_PASSWORD` from default in production `.env`
- [ ] Verify all API endpoints return the exact `03_API_Contract.md` envelope format
- [ ] Run full pytest suite — all tests pass
- [ ] Verify GitHub Actions CI runs clean on `main` branch
- [ ] You can verbally explain every architectural decision when asked by the professor

### ✅ Phase 4 — Definition of Done (Demo Ready)
- `docker compose up -d` on Azure VM brings all 7 services up in < 3 minutes
- Dashboard loads immediately with 200 realistic calls — no empty states
- Live upload of a real audio file completes in < 90 seconds and appears in the dashboard via WebSocket
- All 5 dashboard modules functional with zero browser console errors
- Total Azure spend < $15 of $85 budget
- `NC4as_T4_v3` VM stopped and deallocated after demo

---

## Quick Reference: LLM Session Starter

Copy this block. Fill in the current phase and step. Paste at the top of every session.

```
Context anchor documents attached:
- 01_Master_Architecture.md — stack manifest, banned tools, queue contract, scoring formula
- 02_Database_Schema.sql    — canonical column names and types
- 03_API_Contract.md        — exact JSON request/response shapes and TypeScript interfaces

Current state: Phase [N], Step [M] — [description of task]

Rules:
- Do not suggest any tool not listed in 01_Master_Architecture.md
- All column names must match 02_Database_Schema.sql exactly
- All API response shapes must match 03_API_Contract.md exactly
- Do not write comments in code
- Do not build beyond the current step
```