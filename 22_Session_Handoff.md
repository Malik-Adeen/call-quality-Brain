---
tags: [handoff, session-starter]
date: 2026-04-16
status: reference
---

# 22 — New Chat Session Handoff

> Paste this entire document at the start of a new Claude session.
> It contains everything needed to continue without re-explaining anything.

---

## WHO YOU ARE TALKING TO

**Adeen** — 6th semester BSCS student, Bahria University Islamabad, Pakistan.
Building an AI Call Quality & Agent Performance Analytics System for university final presentation demo.

---

## HARDWARE

- CPU: AMD Ryzen 5 3600
- GPU: NVIDIA RTX 3060 Ti (8GB VRAM)
- OS: Windows + Docker Desktop + WSL2
- CUDA: 12.1.0
- Project: `N:\projects\call-quality-analytics`
- Vault: `N:\projects\docs`
- Repo: github.com/Malik-Adeen/call-quality-analytics

---

## SYSTEM OVERVIEW

**Cloud (Azure B2s — always-on):** FastAPI API + PostgreSQL + Redis + MinIO + worker_io + Flower
**Local (RTX 3060 Ti — demo day):** worker_gpu via SSH tunnel to Azure

**7-stage AI pipeline:**
`POST /calls/upload` → `run_whisperx (gpu_queue)` → `redact_pii` → `compute_talk_balance` → `run_groq_inference` → `write_scores` → `notify_websocket (all io_queue)`

**AI stack:** WhisperX large-v2 (RTX 3060 Ti) → Presidio PII redaction → Groq `llama-3.3-70b-versatile` primary / OpenRouter fallback

**Frontend:** React 18 + TypeScript + Vite + TailwindCSS v4 + Recharts + Zustand (sessionStorage) + motion/react

---

## CURRENT BUILD STATUS: v1.3 — HYBRID CLOUD DEPLOYED

| Phase | Status |
|---|---|
| Phase 1 — Auth, Upload, Docker, Celery | ✅ |
| Phase 2.1 — WhisperX GPU | ✅ |
| Phase 2.2 — Presidio PII redaction | ✅ |
| Phase 2.3 — Groq inference | ✅ |
| Phase 2.4 — Scoring, chain, WebSocket | ✅ |
| Audit fixes | ✅ |
| Phase 3A — Read endpoints | ✅ |
| Phase 3 — React dashboard (6 pages) | ✅ |
| UI redesign (light parchment theme) | ✅ |
| UI bug fixes | ✅ |
| Phase 4 — PDF export + reseed + MinIO volume + CORS | ✅ |
| Hybrid architecture — SSH tunnel + Azure B2s | ✅ |
| **Demo dry-run** | 🔲 NEXT |

---

## WHAT WORKS RIGHT NOW

- Azure B2s live at `http://20.228.184.111:8000/health` ✅
- 200 seeded calls on Azure ✅
- Full hybrid E2E verified: local upload → Azure API → SSH tunnel → RTX 3060 Ti → Azure DB → dashboard ✅
- `James O'Brien · Sales · 92%` confirmed in Azure Call List ✅
- PDF export working (Playwright on Azure) ✅
- WebSocket proxied through Vite — no hardcoded IPs ✅
- SSH key auth set up — tunnel reconnects without password ✅

---

## HOW TO START FOR DEMO

**Step 1 — Start SSH tunnel (keep this terminal open):**
```powershell
N:\projects\call-quality-analytics\scripts\tunnel.bat
```

**Step 2 — Start local GPU worker (new terminal):**
```powershell
docker compose -f N:\projects\call-quality-analytics\infra\docker-compose.hybrid.yml up -d worker_gpu
```

**Step 3 — Start frontend:**
```powershell
cd N:\projects\call-quality-analytics\frontend && npm run dev
```

**Step 4 — Open dashboard:**
```
http://localhost:5173
```
Login: `admin@callquality.demo` / `admin1234`

---

## AZURE INFRASTRUCTURE

| Resource | IP | Status |
|---|---|---|
| B2s East US (always-on) | `20.228.184.111` | ✅ Running |
| NC4as_T4_v3 (GPU) | TBD | ⏳ Quota pending |

**SSH into Azure:**
```powershell
ssh -i C:\Users\adeen\.ssh\callquality_azure azureuser@20.228.184.111
```

**Reset DB on Azure:**
```bash
cd ~/call-quality-analytics && python3 scripts/reset_and_seed.py
```

---

## WHAT NEEDS TO BE DONE NEXT

1. **Demo dry-run** — full script: KPI Overview → Call List → Call Detail → Agents → Live Upload → PDF export
2. **WebSocket toast verification** — upload a call, confirm toast fires on Reports page
3. **Git pull on Azure** — `ssh azureuser@20.228.184.111 "cd ~/call-quality-analytics && git pull && docker restart cq_api cq_worker_io"`
4. **GPU quota check** — portal.azure.com → Quotas → check if NC4as_T4_v3 East US approved

---

## CRITICAL INVARIANTS — NEVER VIOLATE

1. Audio binary → MinIO only (`minio_audio_path`), never DB
2. Raw transcript → never DB (Presidio-redacted only)
3. `pii_redacted = TRUE` before any downstream task
4. `run_whisperx` → `gpu_queue` only, concurrency=1
5. JWT in Zustand sessionStorage — never localStorage
6. Scoring: `display_score = round((0.25×pol + 0.20×sent_norm + 0.20×res + 0.15×bal + 0.20×cla) × 10, 2)`
7. Groq model: `llama-3.3-70b-versatile` (never 3.1)
8. MinIO endpoint: `cq-minio:9000` (hyphens, not underscores)
9. `DATABASE_URL`: `postgresql+asyncpg://` for API, `postgresql://` for workers
10. Score display: backend 0–10 × 10 = percentage shown in UI
11. Zero code comments — ever

---

## CODING RULES (NON-NEGOTIABLE)

- Zero comments in any generated code. Ever. No exceptions.
- Highly readable, self-documenting code instead.
- Zero prose inside code blocks — executable code only.
- No banned tools: Ollama, VADER, WeasyPrint, localStorage for JWT, raw transcript in DB, audio blob in DB, Node.js backend

---

## TECH STACK (FROZEN)

**Backend:** FastAPI + Celery 5.x + Redis 7 + MinIO + PostgreSQL 16 + SQLAlchemy 2.x async + Pydantic 2.x + python-jose + bcrypt + Playwright
**AI:** WhisperX large-v2 + Pyannote.audio 3.1 + Presidio + Groq API
**Frontend:** React 18 + TypeScript + Vite + TailwindCSS v4 + Recharts + Zustand + Axios + motion/react
**Infra:** Docker Compose + Flower 2.0 + SSH tunnel (hybrid mode)

---

## FRONTEND DESIGN SYSTEM

| Token | Value |
|---|---|
| Background | `#E4E3E0` warm parchment |
| Cards | `bg-white border border-[#141414]` sharp edges, no radius |
| Active nav | `bg-[#141414] text-[#E4E3E0]` |
| Body font | Inter |
| Data/numbers | JetBrains Mono (`font-mono`) |
| Headers/names | Playfair Display italic (`font-serif`) |
| Score high >80% | `#10b981` emerald |
| Score mid 60-80% | `#141414` black |
| Score low <60% | `#ef4444` red |

---

## TOOLING WORKFLOW

- **Claude** — architecture decisions, code generation, vault updates (writes vault only after validation)
- **Antigravity IDE** — file writing, container execution, verification
- **Gemini** — supplementary debugging

---

## SECOND BRAIN (OBSIDIAN VAULT)

Location: `N:\projects\docs`

Key files:
- `00_Master_Dashboard.md` — current state, invariants, component map
- `01_Master_Architecture.md` — stack manifest (LLM anchor doc)
- `03_API_Contract.md` — all API shapes and TypeScript interfaces
- `11_Azure_Deployment.md` — B2s + T4 runbooks
- `23_Phase4_Postmortem.md` — Phase 4 decisions
- `24_Hybrid_Architecture_Postmortem.md` — SSH tunnel + WAN Celery tuning
