---
tags: [handoff, session-starter]
date: 2026-04-17
status: reference
---

# 22 — New Chat Session Handoff

> Paste this entire document at the start of a new Claude session.

---

## WHO YOU ARE TALKING TO

**Adeen** — 6th semester BSCS student, Bahria University Islamabad, Pakistan.
Building an AI Call Quality & Agent Performance Analytics System for university final presentation demo.
**Demo date: Tuesday/Wednesday/Thursday next week (week of April 21, 2026)**

---

## HARDWARE

- CPU: AMD Ryzen 5 3600
- GPU: NVIDIA RTX 3060 Ti (8GB VRAM)
- OS: Windows + Docker Desktop + WSL2
- CUDA: 12.1.0
- Project: `N:\projects\call-quality-analytics`
- Vault: `N:\projects\docs`
- Audio test files: `N:\projects\Audio-Recording\`
- Repo: github.com/Malik-Adeen/call-quality-analytics

---

## SYSTEM OVERVIEW

**Cloud (Azure B2s — always-on):** FastAPI + PostgreSQL + Redis + MinIO + worker_io + Flower
**Local (RTX 3060 Ti — demo day):** worker_gpu via SSH tunnel to Azure

**7-stage AI pipeline:**
`POST /calls/upload` → `run_whisperx (gpu_queue)` → `redact_pii` → `compute_talk_balance` → `run_groq_inference` → `write_scores` → `notify_websocket`

**AI stack:** WhisperX large-v2 → Presidio PII redaction → Groq `llama-3.3-70b-versatile` / OpenRouter fallback

**Frontend:** React 18 + TypeScript + Vite + TailwindCSS v4 + Recharts + Zustand + motion/react

---

## CURRENT BUILD STATUS: v1.3 — DEMO READY

| Phase | Status |
|---|---|
| Phase 1 — Auth, Upload, Docker, Celery | ✅ |
| Phase 2.1 — WhisperX GPU | ✅ |
| Phase 2.2 — Presidio PII redaction | ✅ |
| Phase 2.3 — Groq inference | ✅ |
| Phase 2.4 — Scoring, chain, WebSocket | ✅ |
| Phase 3 — React dashboard (6 pages) | ✅ |
| Phase 4 — PDF export + reseed + CORS | ✅ |
| Hybrid architecture — SSH tunnel + Azure B2s | ✅ |
| Real audio testing (3 files verified) | ✅ |
| **Demo dry-run** | 🔲 NEXT |

---

## WHAT WORKS RIGHT NOW

- Azure B2s: `http://20.228.184.111:8000/health` ✅
- 200 seeded calls on Azure DB ✅
- Full hybrid E2E verified on real audio: billing_dispute (88.3%), irate_customer (71.0%), bpo_inbound_1 (75.1%) ✅
- PDF export working on real calls ✅
- WebSocket toast verified ✅
- SSH key auth — tunnel reconnects without password ✅

---

## HOW TO START FOR DEMO

**Step 1 — Start SSH tunnel (keep terminal open):**
```powershell
N:\projects\call-quality-analytics\scripts\tunnel.bat
```

**Step 2 — Start local GPU worker (new terminal):**
```powershell
docker compose -f N:\projects\call-quality-analytics\infra\docker-compose.hybrid.yml up -d worker_gpu
```

**Step 3 — Verify worker connected to Azure:**
```powershell
docker logs cq_worker_gpu --tail 5
# Must show: sync with worker_io@xxxxxxxxx
```

**Step 4 — Start frontend:**
```powershell
cd N:\projects\call-quality-analytics\frontend && npm run dev
```

**Step 5 — Open dashboard:**
```
http://localhost:5173
```
Login: `admin@callquality.demo` / `admin1234`

---

## DEMO DAY PROTOCOL

1. Close Chrome, Discord, all non-essential apps
2. `nvidia-smi` — confirm VRAM < 3GB before starting
3. Start `tunnel.bat` — verify silent connection
4. Start `worker_gpu` → verify `sync with worker_io` in logs
5. Start frontend
6. Upload ONE audio file only
7. Switch to Reports page — watch Live indicator + wait for toast
8. After toast → Call List → show score → open detail → PDF export
9. Show Agent View, Overview charts
10. Have `nvidia-smi` visible in background — shows GPU utilization live

**CRITICAL: Upload one file at a time. Wait for toast before next upload.**
**If VRAM hits 7.5GB+ in nvidia-smi — wait before uploading.**

---

## WHAT STILL NEEDS DOING BEFORE DEMO

| Item | Priority |
|---|---|
| Full demo dry-run (solo rehearsal) | HIGH |
| `git pull` on Azure VM + restart services | HIGH |
| `reset_and_seed.py` on Azure VM — clean 200 calls | HIGH |
| Prepare 2-3 trimmed audio files (2-3 min, clean) | MEDIUM |
| Trim `irate_customer.mp3` — remove YouTube tutorial | MEDIUM |

---

## AZURE INFRASTRUCTURE

| Resource | IP | Status |
|---|---|---|
| B2s East US (always-on) | `20.228.184.111` | ✅ Running |
| NC4as_T4_v3 | N/A | ❌ Quota disabled on Student account |

**SSH into Azure:**
```powershell
ssh -i C:\Users\adeen\.ssh\callquality_azure azureuser@20.228.184.111
```

**Reseed Azure DB:**
```bash
cd ~/call-quality-analytics && git pull && python3 scripts/reset_and_seed.py
```

---

## KNOWN ISSUES FOR DEMO

| Issue | Mitigation |
|---|---|
| PC crash if uploading multiple files rapidly | Upload one at a time, wait for toast |
| Local Redis blocks SSH tunnel port 6379 | Always stop local stack before starting tunnel.bat |
| Call List doesn't auto-update after processing | Navigate away and back — page remounts and fetches fresh |
| AGENT/CUSTOMER labels swapped on calls with pre-call announcement | Expected — Pyannote assigns AGENT to first speaker |

---

## CRITICAL INVARIANTS

1. Audio binary → MinIO only (`minio_audio_path`), never DB
2. Raw transcript → never DB — Presidio-redacted only
3. `pii_redacted = TRUE` before any downstream task
4. `run_whisperx` → `gpu_queue` only, concurrency=1
5. JWT in Zustand sessionStorage — never localStorage
6. Groq model: `llama-3.3-70b-versatile` (never 3.1)
7. MinIO endpoint: `cq-minio:9000` (hyphens)
8. Score display: backend 0–10 × 10 = % in UI
9. Zero code comments — ever

---

## TECH STACK (FROZEN)

**Backend:** FastAPI + Celery 5.x + Redis 7 + MinIO + PostgreSQL 16 + SQLAlchemy 2.x + Pydantic 2.x + Playwright
**AI:** WhisperX large-v2 + Pyannote.audio 3.1 + Presidio + Groq API
**Frontend:** React 18 + TypeScript + Vite + TailwindCSS v4 + Recharts + Zustand + motion/react
**Infra:** Docker Compose + Flower 2.0 + SSH tunnel

---

## SECOND BRAIN VAULT

Location: `N:\projects\docs`

Key files:
- `00_Master_Dashboard.md` — current state
- `22_Session_Handoff.md` — this file
- `24_Hybrid_Architecture_Postmortem.md` — SSH tunnel decisions
- `26_Audio_Testing_Postmortem.md` — real audio test results and crash recovery
