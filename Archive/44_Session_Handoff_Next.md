---
tags: [handoff, session-starter]
date: 2026-05-08
status: active — paste CONTEXT.md + INVARIANTS.md + this file at next session start
---

# 44 — Session Handoff (Next Chat)

> Workflow: Claude.ai chat = architect + auditor + Codex prompt writer.
> Claude Code terminal = code generator and executor.
> Claude.ai does NOT write production code directly.

---

## Current State — v1.8

- All local Docker. Azure VM deleted.
- Project path: E:\projects\call-quality-analytics
- Vault path: E:\projects\docs
- Alembic head: 20260701_agent_identity (migration 006)
- Pipeline: run_whisperx → extract_agent_identity → redact_pii →
  compute_talk_balance → run_groq_inference → write_scores → notify_websocket
- Multi-tenancy: triple-layer RLS live. Demo Tenant + Acme Corp verified isolated.
- Design: Waaqi GRC tokens. WAAQI_TOKENS.md at project root is authoritative.
  Sidebar #0f1924, primary teal #00a99d, Inter + JetBrains Mono.
- All 9 pages complete and verified loading on new machine.

---

## Environment (new machine — Windows reinstall May 8 2026)

Hardware: RTX 3060 Ti 8GB, CUDA 12.1, 16GB RAM
C:\ = Windows + user profile. E:\ = all project files.

Installed:
- NVIDIA Game Ready Driver (clean install)
- WSL2 + Docker Desktop (WSL2 backend)
- Node.js LTS, Python 3.11
- Claude Code CLI (npm install -g @anthropic-ai/claude-code)

System fixes applied:
- C:\Users\adeen\.wslconfig: memory=8GB, processors=6, swap=0
- TDR registry: TdrDelay=60, TdrDdiDelay=60

---

## Stack Status

All 7 containers confirmed healthy. DB migrated + 200 calls seeded.
Frontend verified at http://localhost:5173.
worker_gpu intentionally NOT started — NVIDIA driver stability unconfirmed.

Startup commands:
```powershell
cd E:\projects\call-quality-analytics\infra
docker compose up -d postgres redis minio minio_init api worker_io flower
cd E:\projects\call-quality-analytics\frontend && npm run dev
```

Alembic (run from backend/ with localhost override):
```powershell
$env:DATABASE_URL="postgresql://callquality:callquality_dev@localhost:5432/callquality"
alembic upgrade head
```

GPU worker (only after VRAM check):
```powershell
nvidia-smi --query-gpu=memory.used,memory.free --format=csv
# free must be > 5000 MiB
docker compose up -d worker_gpu
docker logs cq_worker_gpu --tail 5
# Must show: celery@worker_gpu ready.
```

Login: admin@callquality.demo / admin1234 (Demo Tenant — 200 calls)

---

## Immediate Next Task — BatchAgent Live Test

BatchAgent is built and audited. Not yet run.
Files: batch_agent/main.py, Dockerfile, requirements.txt
Service: cq_batch_agent in docker-compose.yml

Step 1 — Add to infra/.env:
```
API_URL=http://cq_api:8000
BATCH_AGENT_TOKEN=<JWT from login>
BATCH_WATCH_DIR=C:\Users\adeen\Desktop\batch_audio
SEMAPHORE_LIMIT=4
```

Get JWT:
```powershell
$r = Invoke-RestMethod -Uri "http://localhost:8000/auth/login" `
  -Method POST -ContentType "application/json" `
  -Body '{"email":"admin@callquality.demo","password":"admin1234"}'
$r.data.access_token
```

Step 2 — Run the 8-step test:
  1. mkdir C:\Users\adeen\Desktop\batch_audio
  2. docker compose up -d --build cq_batch_agent
  3. Confirm logs: "Watching /watch"
  4. Drop billing_dispute.mp3 into watch folder
  5. Confirm call: pending → processing → complete
  6. Confirm needs_agent_review=true, no agent assigned
  7. Assign via PATCH /calls/{id}/assign-agent
  8. Drop same file again → confirm silent skip (dedup)

Note: worker_gpu must be running for pipeline to process.
Check VRAM before starting worker_gpu (see above).

---

## Planned Features (in order, do not skip ahead)

### 1. BatchAgent Live Test
Above. Confirm end-to-end before anything else.

### 2. BatchAgent Multi-Tenant Evolution
Full plan: E:\projects\docs\46_BatchAgent_MultiTenant_Plan.md
Order: API keys table → multi-tenant config file → config reload without restart.
Do NOT start until single-tenant test passes.

### 3. Pre-Deployment Role-Based Audit
Full plan: E:\projects\docs\45_Pre_Deployment_Audit_Plan.md
Claude Code sub-agents, 5 domains, zero failures = deploy to Azure.
Research round first (Perplexity, DeepSeek, GLM, Gemini, Codex).
Do NOT start until BatchAgent multi-tenant is complete.

### 4. Azure Deployment
After audit passes. Fresh Azure B2s.

---

## Known Tech Debt (dormant)

Call.agent_id FK uses ondelete=CASCADE but column is nullable=True.
Should be ondelete=SET NULL. Fix when hard-delete support is added.
File: backend/app/models/orm.py

---

## Audit Checklist (every Codex-generated file)

- [ ] Zero code comments
- [ ] minio_audio_path never audio_path
- [ ] cq-minio:9000 hyphens not underscores
- [ ] extract_agent_identity BEFORE redact_pii in chain
- [ ] Talk balance: 1 - 2 * abs(agent_ratio - 0.5)
- [ ] Score: stored 0-10, displayed x10 as %
- [ ] JWT in sessionStorage never localStorage
- [ ] Groq: llama-3.3-70b-versatile
- [ ] depends_on uses service names not container_name values
- [ ] Waaqi tokens: #00a99d teal, #0f1924 sidebar, Inter font
- [ ] SET LOCAL not SET SESSION for RLS tenant context

---

## Vault Reference

| Doc | Purpose |
|---|---|
| CONTEXT.md | Full architecture — paste at session start |
| INVARIANTS.md | Compact rules — paste to Gemini/DeepSeek/GLM |
| 44_Session_Handoff_Next.md | This file |
| 45_Pre_Deployment_Audit_Plan.md | Audit plan + sub-agent prompts |
| 46_BatchAgent_MultiTenant_Plan.md | Single → multi-tenant evolution |
| WAAQI_TOKENS.md | Design tokens (project root) |
| STARTUP_LOCAL.md | Full startup runbook |
