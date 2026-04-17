---
tags: [handoff, session-starter, llm-agnostic]
date: 2026-04-17
status: reference
---

# 22 — LLM Session Starter

> For use with any LLM: Claude, GPT, Gemini, Qwen, Copilot, etc.
> Paste CONTEXT.md + this file at the start of any working session.
> CONTEXT.md gives the full project picture. This file gives current operational state.

---

## Current State — v1.4 (as of 2026-04-17)

All core phases complete. System is deployed and working end-to-end.

**What works:**
- Azure B2s at `20.228.184.111` serving the dashboard 24/7
- 200 seeded calls in Azure PostgreSQL
- Full 7-stage pipeline verified on real audio: billing dispute, tech support, irate customer, BPO inbound
- Best verified score: 88.3% on billing_dispute.mp3, 88.2% on tech_support.mp3
- PDF export via Playwright — renders all charts correctly
- WebSocket real-time notifications firing correctly
- Extended Presidio: zip codes, SSN last-4, account numbers now redacted
- SSH tunnel auto-reconnects via tunnel.bat with key auth (no password)

**What still needs doing:**
- Demo dry-run (full script rehearsal before presentation)
- `git pull` + `docker restart cq_worker_io` on Azure VM
- `reset_and_seed.py` on Azure VM — clean 200 calls before demo
- Verify extended Presidio on bpo_inbound_1 reupload

---

## How to Start the System (Hybrid Mode)

The system runs in hybrid mode: Azure handles the API/database/IO, local RTX handles GPU inference.

**Critical warning:** Never run local `cq_redis` and `tunnel.bat` simultaneously.
Port 6379 conflict causes silent routing failure — worker_gpu talks to local Redis
while Azure API writes to Azure Redis. Tasks never get processed.

```powershell
# Step 1: Check VRAM (must be > 5000 MiB free before uploading audio)
nvidia-smi --query-gpu=memory.used,memory.free --format=csv

# Step 2: Start SSH tunnel (keep this terminal open for entire session)
N:\projects\call-quality-analytics\scripts\tunnel.bat

# Step 3: Start GPU worker only
docker compose -f N:\projects\call-quality-analytics\infra\docker-compose.hybrid.yml up -d worker_gpu

# Step 4: Verify worker synced with Azure
docker logs cq_worker_gpu --tail 5
# Must show: sync with worker_io@xxxxxxxxx

# Step 5: Start frontend
cd N:\projects\call-quality-analytics\frontend && npm run dev

# Step 6: Open dashboard
# URL: http://localhost:5173
# Login: admin@callquality.demo / admin1234
```

---

## If System Crashes

```powershell
# 1. Fix stuck processing calls in Azure DB (run from local terminal)
ssh -i C:\Users\adeen\.ssh\callquality_azure azureuser@20.228.184.111 `
  "docker exec cq_postgres psql -U callquality -d callquality -c `
  \"UPDATE calls SET status='failed' WHERE status='processing';\""

# 2. Flush stale Redis queue
ssh -i C:\Users\adeen\.ssh\callquality_azure azureuser@20.228.184.111 `
  "docker exec cq_redis redis-cli DEL gpu_queue"

# 3. Restart local services that died in crash
docker compose -f N:\projects\call-quality-analytics\infra\docker-compose.yml `
  up -d api worker_io flower
```

---

## Azure Operations

```powershell
# SSH into Azure VM
ssh -i C:\Users\adeen\.ssh\callquality_azure azureuser@20.228.184.111

# On Azure VM:
cd ~/call-quality-analytics && git pull && docker restart cq_worker_io

# Reseed database (run after git pull on Azure VM)
python3 scripts/reset_and_seed.py

# Health check
curl http://20.228.184.111:8000/health
```

---

## Demo Script (in order)

1. Open dashboard → Overview page (StatCards + Score Distribution chart)
2. Call History → filters, search, pagination
3. Click any call → slide-in detail panel → RadarChart, sentiment timeline, transcript
4. Click Export PDF → download and show
5. Agent View → score history chart, strengths/weaknesses
6. Upload page → upload `tech_support.mp3`
7. Switch to Reports page → watch Live indicator → wait for `call_complete` toast
8. Navigate to Call History → new call appears with score

**One file at a time. Wait for toast before next upload. Watch nvidia-smi.**

---

## Known Issues (with workarounds)

| Issue | Workaround |
|---|---|
| Call List doesn't auto-refresh after processing | Navigate away and back — page remounts and fetches |
| AGENT/CUSTOMER labels swapped on pre-announcement audio | Expected limitation of unsupervised diarization |
| PC crashes on rapid sequential uploads | One file at a time, restart worker_gpu between uploads |
| tunnel.bat drops on network interruption | Auto-reconnects — loop in bat file handles this |
| `processing` calls re-queued on worker restart causing crash loop | Fix with psql UPDATE + redis DEL before restarting |

---

## Key File Paths

| Purpose | Path |
|---|---|
| Project root | N:\projects\call-quality-analytics |
| Knowledge vault | N:\projects\docs |
| Test audio files | N:\projects\Audio-Recording |
| SSH tunnel script | N:\projects\call-quality-analytics\scripts\tunnel.bat |
| Hybrid compose | N:\projects\call-quality-analytics\infra\docker-compose.hybrid.yml |
| Presidio service | N:\projects\call-quality-analytics\backend\app\services\presidio_service.py |
| SSH private key | C:\Users\adeen\.ssh\callquality_azure |

---

## For the Next LLM Session

Before asking for help, confirm you have loaded:
1. `CONTEXT.md` — full project architecture and rules
2. This file (`22_Session_Handoff.md`) — current operational state

Together they give any LLM enough context to make correct decisions without needing
to read all 27 postmortem files.

If working on a specific subsystem, also load the relevant postmortem:
- Pipeline issues → `24_Hybrid_Architecture_Postmortem.md`
- PII redaction → `27_Presidio_Extension_Postmortem.md`
- Audio testing → `26_Audio_Testing_Postmortem.md`
- UI/Frontend → `21_UI_Redesign_Postmortem.md`
- API endpoints → `16_Phase3A_Read_Endpoints.md`
