---
tags: [handoff, session-starter]
date: 2026-04-17
status: reference
---

# 22 — New Chat Session Handoff

> Paste this entire document at the start of a new Claude session.
> It contains everything needed to continue without re-explaining anything.

---

## WHO YOU ARE TALKING TO

**Adeen** — 6th semester BSCS student, Bahria University Islamabad, Pakistan.
Building an AI Call Quality & Agent Performance Analytics System for university final presentation demo.
**Demo date: Tuesday/Wednesday/Thursday — week of April 21, 2026**

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
**Local (RTX 3060 Ti — demo day only):** worker_gpu via SSH tunnel to Azure

**7-stage AI pipeline:**
`POST /calls/upload` → `run_whisperx (gpu_queue)` → `redact_pii` → `compute_talk_balance` → `run_groq_inference` → `write_scores` → `notify_websocket`

**AI stack:** WhisperX large-v2 → Presidio PII redaction (extended) → Groq `llama-3.3-70b-versatile` / OpenRouter fallback

**Frontend:** React 18 + TypeScript + Vite + TailwindCSS v4 + Recharts + Zustand + motion/react

---

## CURRENT BUILD STATUS: v1.4 — DEMO READY

| Phase | Status |
|---|---|
| Phase 1 — Auth, Upload, Docker, Celery | ✅ |
| Phase 2 — Full AI Pipeline | ✅ |
| Phase 3 — React Dashboard (6 pages) | ✅ |
| Phase 4 — PDF export + Azure + Hybrid architecture | ✅ |
| Real audio testing (5 files verified) | ✅ |
| Presidio extended (zip, SSN last-4, account numbers) | ✅ |
| **Demo dry-run** | 🔲 NEXT |

---

## WHAT WORKS RIGHT NOW

- Azure B2s live: `http://20.228.184.111:8000/health` ✅
- 200 seeded calls on Azure DB ✅
- Full hybrid E2E verified on real audio ✅
- Best demo file: `tech_support.mp3` → 88.2%, 3m 24s, clean diarization ✅
- PDF export working ✅
- WebSocket toast working ✅
- Extended Presidio: zip codes, SSN last-4, account numbers now redacted ✅
- SSH key auth — tunnel reconnects without password ✅

---

## REAL AUDIO TEST RESULTS

| File | Score | Duration | Use for demo? |
|---|---|---|---|
| tech_support.mp3 | 88.2% | 3m 24s | ✅ YES — best file |
| billing_dispute.mp3 | 88.3% | 1m 27s | ✅ Good backup |
| irate_customer.mp3 | 71.0% | 12m 17s | ⚠️ Needs trim |
| bpo_inbound_1.mp3 | 75.1% | 2m 18s | ℹ️ Labels swapped |
| bpo_inbound_2.mp3 | 75.1% | 2m 18s | ❌ Duplicate of bpo_inbound_1 |

---

## HOW TO START FOR DEMO

```
CRITICAL: Never run full local stack + tunnel simultaneously.
Port 6379 conflict kills the hybrid architecture silently.
```

**Step 1 — Check VRAM is clear:**
```powershell
nvidia-smi --query-gpu=memory.used,memory.free --format=csv
# Must show memory.free > 5000 MiB
```

**Step 2 — Start SSH tunnel (keep this terminal open):**
```powershell
N:\projects\call-quality-analytics\scripts\tunnel.bat
```

**Step 3 — Start local GPU worker only:**
```powershell
docker compose -f N:\projects\call-quality-analytics\infra\docker-compose.hybrid.yml up -d worker_gpu
```

**Step 4 — Verify synced with Azure:**
```powershell
docker logs cq_worker_gpu --tail 5
# Must show: sync with worker_io@xxxxxxxxx
```

**Step 5 — Start frontend:**
```powershell
cd N:\projects\call-quality-analytics\frontend && npm run dev
```

**Step 6 — Open dashboard:**
```
http://localhost:5173
Login: admin@callquality.demo / admin1234
```

---

## DEMO DAY PROTOCOL

1. Close Chrome, Discord, all non-essential apps
2. `nvidia-smi` — confirm VRAM < 3GB
3. Start `tunnel.bat`
4. Start `worker_gpu` → confirm `sync with worker_io` in logs
5. Start frontend
6. Demo script: Overview → Call History → Call Detail → Agent View → Upload
7. Upload `tech_support.mp3` — switch to Reports page — wait for toast
8. After toast → Call List → open detail → PDF export
9. Keep `nvidia-smi` visible in background

**CRITICAL: One file at a time. Wait for toast before next upload.**
**If VRAM > 7GB — restart worker_gpu before uploading.**

---

## IF SYSTEM CRASHES

```bash
# Fix stuck processing calls on Azure
ssh -i C:\Users\adeen\.ssh\callquality_azure azureuser@20.228.184.111
docker exec cq_postgres psql -U callquality -d callquality -c "UPDATE calls SET status='failed' WHERE status='processing';"
docker exec cq_redis redis-cli DEL gpu_queue

# Restart local services after crash
docker compose -f N:\projects\call-quality-analytics\infra\docker-compose.yml up -d api worker_io flower
```

---

## WHAT STILL NEEDS DOING

| Item | Priority |
|---|---|
| Full demo dry-run (solo rehearsal) | HIGH |
| `git pull` on Azure VM + `docker restart cq_worker_io` | HIGH |
| `reset_and_seed.py` on Azure VM — clean 200 calls | HIGH |
| Verify Presidio fix: re-upload bpo_inbound_1 — confirm `<ZIP_CODE>` and `<SSN>` appear | MEDIUM |
| Trim `irate_customer.mp3` if using it live | LOW |

---

## AZURE INFRASTRUCTURE

| Resource | IP | Cost | Status |
|---|---|---|---|
| B2s East US (always-on) | `20.228.184.111` | ~$0.042/hr | ✅ Running |
| NC4as_T4_v3 GPU | N/A | — | ❌ Quota disabled on Student account |

**SSH into Azure:**
```powershell
ssh -i C:\Users\adeen\.ssh\callquality_azure azureuser@20.228.184.111
```

**Update Azure and restart IO worker:**
```bash
cd ~/call-quality-analytics && git pull && docker restart cq_worker_io
```

**Reseed Azure DB:**
```bash
python3 scripts/reset_and_seed.py
```

---

## CRITICAL INVARIANTS — NEVER VIOLATE

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
**AI:** WhisperX large-v2 + Pyannote.audio 3.1 + Presidio (extended) + Groq API
**Frontend:** React 18 + TypeScript + Vite + TailwindCSS v4 + Recharts + Zustand + motion/react
**Infra:** Docker Compose + Flower 2.0 + SSH tunnel (hybrid mode)

---

## KNOWN ISSUES

| Issue | Mitigation |
|---|---|
| PC crashes if multiple files uploaded rapidly | One at a time, wait for toast, check VRAM first |
| Local Redis blocks SSH tunnel port 6379 | Stop full local stack before starting tunnel.bat |
| Call List doesn't auto-update after processing | Navigate away and back to remount |
| AGENT/CUSTOMER labels swapped on pre-call announcement audio | Expected — Pyannote assigns AGENT to first speaker |
| `processing` calls cause crash loop on worker_gpu restart | Run psql UPDATE + redis DEL before restarting |

---

## SECOND BRAIN VAULT

Location: `N:\projects\docs`

| File | Content |
|---|---|
| `00_Master_Dashboard.md` | Current state, checklist, start sequence |
| `01_Master_Architecture.md` | Stack manifest, invariants, scoring formula |
| `03_API_Contract.md` | All API shapes, TypeScript interfaces |
| `11_Azure_Deployment.md` | B2s runbook, budget tracker |
| `24_Hybrid_Architecture_Postmortem.md` | SSH tunnel decisions, WAN Celery tuning |
| `26_Audio_Testing_Postmortem.md` | Real audio test results, crash recovery |
| `27_Presidio_Extension_Postmortem.md` | Custom PII recognizers added |

---

## POST-MORTEMS (chronological)

07 → 08 → 09 → 11 → 12 → 13 → 14 → 16 → 17 → 21 → 23 → 24 → 26 → 27
