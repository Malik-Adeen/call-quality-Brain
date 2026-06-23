---
tags: [phase-5, audio-testing, hybrid-pipeline, demo-prep, infrastructure]
date: 2026-04-17
status: complete
---

# 26 — Audio Testing Postmortem

> Previous: [[24_Hybrid_Architecture_Postmortem]] · Next: [[27_Presidio_Extension_Postmortem]]
> See [[06_Urdu_ASR_Research]] for ASR research context

---

## What Was Built / Tested

Full hybrid Azure pipeline tested against 5 real call center audio files.
PC crash handled and recovered. Demo day protocol finalized.
GPU quota confirmed unavailable on Azure for Students — local RTX 3060 Ti is the permanent GPU solution.

## Audio Test Results

| File | Score | Duration | Notes |
|---|---|---|---|
| billing_dispute.mp3 | 88.3% | 1m 27s | Clean, all metrics high, PII redacted correctly |
| irate_customer.mp3 | 71.0% | 12m 17s | YouTube tutorial included — talk balance skewed 16.6% |
| bpo_inbound_1.mp3 | 75.1% | 2m 18s | Real AT&T telephony — AGENT/CUSTOMER labels swapped (podcast intro) |
| bpo_inbound_2.mp3 | 75.1% | 2m 18s | Duplicate of bpo_inbound_1 — same recording |
| tech_support.mp3 | 88.2% | 3m 24s | Best demo file — clean diarization, accurate PII redaction |

## Bugs Encountered & Resolutions

| Bug | Root Cause | Fix |
|---|---|---|
| Calls stuck in `pending` | Local `cq_redis` on port 6379 blocked SSH tunnel — worker_gpu talked to local Redis | Stop full local stack before starting tunnel.bat |
| API not dispatching chain | Uvicorn reloader restarted mid-request, killed chain dispatch | Re-upload after restart |
| PC crash mid-processing | WhisperX large-v2 + Pyannote ~4-5GB VRAM + Windows memory pressure → OOM | One file at a time, VRAM check before upload |
| Toast not firing after crash | tunnel.bat died; worker_gpu connected to local Redis | Restart tunnel.bat → restart worker_gpu |
| API/worker_io/Flower not restarting after crash | Docker `unless-stopped` requires manual start after host crash | `docker compose up -d api worker_io flower` |
| `processing` calls cause crash loop | Stuck tasks re-queued on worker restart → immediate OOM | `UPDATE calls SET status='failed' WHERE status='processing'` + `DEL gpu_queue` |

## Architecture Decisions

- NC4as_T4_v3 GPU quota disabled on Azure for Students — confirmed permanently unavailable
- Final demo: Azure B2s (always-on dashboard) + Local RTX 3060 Ti (live pipeline)
- One file at a time — wait for `call_complete` toast before next upload

## PII Redaction Observations

- Names → `<PERSON>` ✅
- Date references → `<DATE_TIME>` ✅  
- Account number `326-143-411` → NOT redacted (no context word — fixed in [[27_Presidio_Extension_Postmortem]])
- SSN last 4 `5528` → NOT redacted (fixed in [[27_Presidio_Extension_Postmortem]])
- Zip code `59714` → NOT redacted (fixed in [[27_Presidio_Extension_Postmortem]])

## Diarization Observations

- Short clean calls (1-2 min): AGENT/CUSTOMER labels accurate
- Calls with pre-call announcement: first speaker (narrator) → AGENT (incorrect)
- YouTube tutorials with post-call narration: transcript inflates duration
- Talk balance skews when one speaker dominates

## Demo Day Protocol (Finalized)

1. Close Chrome, Discord, all non-essential apps
2. `nvidia-smi` → confirm VRAM < 3GB
3. Start `tunnel.bat`
4. Start worker_gpu → verify `sync with worker_io`
5. Upload ONE file (`tech_support.mp3`) → Reports page → wait for toast
6. After toast → Call List → open detail → PDF export
