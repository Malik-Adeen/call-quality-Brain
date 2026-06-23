---
tags: [handoff, session-starter, llm-agnostic]
date: 2026-04-18
status: reference
---

# 22 — LLM Session Starter

> For use with any LLM: Claude, GPT, Gemini, Qwen, etc.
> FASTEST: Tell Claude to read N:\projects\docs\GRAPH_REPORT.md via filesystem.
> FALLBACK: Paste INVARIANTS.md (500 tokens) + task-specific file.

---

## Current State — v1.4 (as of 2026-04-18)

**What works:**
- Azure B2s at `20.228.184.111` — dashboard 24/7
- 200 seeded calls in Azure PostgreSQL
- Full 7-stage pipeline verified on real audio: tech_support 88.2%, billing_dispute 88.3%
- PDF export via Playwright
- WebSocket real-time notifications
- Extended Presidio: zip codes, SSN last-4, account numbers
- SSH tunnel auto-reconnects (tunnel.bat, key auth)
- Custom knowledge graph builder: `python scripts/build_graph.py` → GRAPH_REPORT.md

**What still needs doing:**
- Demo dry-run (full script rehearsal)
- `git pull` + `docker restart cq_worker_io` on Azure VM
- `reset_and_seed.py` on Azure VM
- Run `python scripts/build_graph.py` after any significant code change

---

## Context Loading Options

### Option A — Claude with filesystem access (fastest, zero tokens wasted)
```
Read N:\projects\docs\GRAPH_REPORT.md via filesystem tool.
That file contains the full project knowledge graph (~1100 tokens).
Then proceed with the task.
```

### Option B — Any LLM (paste this)
```
[paste contents of N:\projects\docs\INVARIANTS.md]
Task: [your task]
```

### Option C — Complex architecture decision
```
[paste N:\projects\docs\CONTEXT.md]
[paste relevant postmortem if applicable]
Task: [your task]
```

---

## How to Start (Hybrid Mode)

**Never run local cq_redis + tunnel.bat simultaneously — port 6379 conflict.**

```powershell
# 1. Check VRAM
nvidia-smi --query-gpu=memory.used,memory.free --format=csv

# 2. Start SSH tunnel (keep open)
N:\projects\call-quality-analytics\scripts\tunnel.bat

# 3. Start GPU worker only
docker compose -f N:\projects\call-quality-analytics\infra\docker-compose.hybrid.yml up -d worker_gpu

# 4. Verify sync
docker logs cq_worker_gpu --tail 5
# Must show: sync with worker_io@xxxxxxxxx

# 5. Start frontend
cd N:\projects\call-quality-analytics\frontend && npm run dev

# 6. Open http://localhost:5173 → admin@callquality.demo / admin1234
```

Full runbook: N:\projects\docs\STARTUP_HYBRID.md

---

## Crash Recovery

```powershell
ssh -i C:\Users\adeen\.ssh\callquality_azure azureuser@20.228.184.111 `
  "docker exec cq_postgres psql -U callquality -d callquality -c `
  \"UPDATE calls SET status='failed' WHERE status='processing';\""

ssh -i C:\Users\adeen\.ssh\callquality_azure azureuser@20.228.184.111 `
  "docker exec cq_redis redis-cli DEL gpu_queue"

docker compose -f N:\projects\call-quality-analytics\infra\docker-compose.yml `
  up -d api worker_io flower
```

---

## Azure Operations

```powershell
ssh -i C:\Users\adeen\.ssh\callquality_azure azureuser@20.228.184.111
# On VM:
cd ~/call-quality-analytics && git pull && docker restart cq_worker_io
python3 scripts/reset_and_seed.py
curl http://localhost:8000/health
```

---

## Key File Paths

| Purpose | Path |
|---|---|
| Knowledge graph (read first) | N:\projects\docs\GRAPH_REPORT.md |
| Graph builder script | N:\projects\call-quality-analytics\scripts\build_graph.py |
| Rules block (500 tokens) | N:\projects\docs\INVARIANTS.md |
| SSH tunnel | N:\projects\call-quality-analytics\scripts\tunnel.bat |
| Hybrid compose | N:\projects\call-quality-analytics\infra\docker-compose.hybrid.yml |
| SSH key | C:\Users\adeen\.ssh\callquality_azure |
| Test audio files | N:\projects\Audio-Recording\ |

---

## Demo Script Order

1. Overview page (StatCards + Score Distribution)
2. Call History (filters, search, pagination)
3. Click call → slide-in panel → RadarChart + sentiment timeline + transcript
4. Export PDF
5. Agent View → score history + strengths/weaknesses
6. Upload `tech_support.mp3` → Reports page → wait for toast
7. Call List → new call appears → open detail

**One file at a time. Wait for toast. Watch nvidia-smi.**
