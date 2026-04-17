---
tags: [phase-5, audio-testing, hybrid-pipeline, demo-prep]
date: 2026-04-17
status: complete
---

## What Was Built / Tested

Full hybrid Azure pipeline tested against 3 real call center audio files.
PC crash handled and recovered. Audio test results documented.
Demo day plan finalized. GPU quota confirmed unavailable on Azure for Students.

## Audio Test Results

| File | Score | Duration | Notes |
|---|---|---|---|
| billing_dispute.mp3 | 88.3% | 1m 27s | Clean short call, all metrics high, PII redacted correctly |
| irate_customer.mp3 | 71.0% | 12m 17s | Full YouTube tutorial included — talk balance skewed to 16.6% |
| bpo_inbound_1.mp3 | 75.1% | 2m 18s | Real AT&T telephony audio, AGENT/CUSTOMER labels swapped (podcast intro caused diarization misassignment) |

## Bugs Encountered & Resolutions

| Bug | Root Cause | Fix |
|---|---|---|
| Calls stuck in `pending` after upload | Local `cq_redis` occupying port 6379 — SSH tunnel could not bind — worker_gpu was talking to local Redis while Azure API wrote to Azure Redis | Stop local stack except worker_gpu before starting tunnel.bat |
| API not dispatching Celery chain | API restarted (WatchFiles reloader) mid-request, killing the chain dispatch | Confirmed in logs — re-upload after restart |
| PC crash mid-processing | WhisperX large-v2 + Pyannote pulling ~4-5GB VRAM + Windows memory pressure → OOM | Close all non-essential apps before demo; upload one file at a time; wait for toast before next upload |
| Toast not firing after crash recovery | tunnel.bat died in crash; worker_gpu reconnected to local Redis instead of Azure Redis | Restart tunnel.bat → restart worker_gpu → verify `sync with worker_io` in logs |
| API/worker_io/Flower did not auto-restart after crash | Docker restart policy `unless-stopped` requires manual start after host crash | Run `docker compose up -d api worker_io flower` after any crash recovery |

## Architecture Decisions

- NC4as_T4_v3 GPU quota request option is disabled on Azure for Students — confirmed not available
- Final demo architecture: Azure B2s (always-on dashboard) + Local RTX 3060 Ti (live pipeline)
- Upload one file at a time on demo day — wait for call_complete toast before next upload
- Demo flow: Upload page → switch to Reports page → watch Live indicator → toast fires → navigate to Call List

## PII Redaction Observations

- Agent/customer names → `<PERSON>` ✅
- Date references → `<DATE_TIME>` ✅
- Account number `326-143-411` → NOT redacted (not in Presidio default entity set — expected limitation)
- SSN last 4 digits (`5528`) in bpo_inbound_1 → redacted ✅
- Billing zip code → NOT redacted (not a default Presidio entity — expected)

## Diarization Observations

- Short clean calls (1-2 min): AGENT/CUSTOMER labels accurate
- Long calls with pre-call announcement: First speaker = podcast narrator → assigned AGENT incorrectly
- YouTube tutorials with post-call narration: Transcript includes tutorial content, inflates duration
- Talk balance skews heavily when one speaker dominates (irate customer: 16.6%)

## Demo Day Protocol (Finalized)

1. Close Chrome tabs, Discord, all non-essential apps
2. Check VRAM: `nvidia-smi` — confirm < 3GB used before starting
3. Start `tunnel.bat` — verify SSH connects silently
4. `docker compose -f infra/docker-compose.hybrid.yml up -d worker_gpu`
5. `docker logs cq_worker_gpu --tail 5` — verify `sync with worker_io`
6. Start frontend: `cd frontend && npm run dev`
7. Open `http://localhost:5173` — login
8. Upload ONE audio file — switch to Reports page — watch for toast
9. After toast fires → navigate to Call List → show score
10. Show PDF export on Call Detail
11. Show Agent View → Strengths/Weaknesses
12. Show Overview → Score Distribution chart
13. Have `nvidia-smi` visible in background terminal — shows GPU utilization live

## Invariants Confirmed

- PII redaction gate working on real audio ✅
- WhisperX large-v2 transcribing real telephony audio ✅
- Groq scoring and coaching summary accurate ✅
- PDF export working on real scored calls ✅
- Azure hybrid pipeline E2E verified ✅
- Local stack recovery after crash < 2 minutes ✅

## Next Session Entry Conditions

- Demo date: Tuesday/Wednesday/Thursday next week
- Run `git pull` on Azure VM before demo
- Run `reset_and_seed.py` on Azure VM for clean 200-call dataset
- Prepare 2-3 trimmed audio files (2-3 min, clean) for live demo segment
- Check Azure portal GPU quota — may have been approved
- Full demo dry-run before presentation day
