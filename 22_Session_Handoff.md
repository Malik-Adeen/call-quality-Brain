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
- Reference UI: `N:\projects\Google-Inspo` (Google AI Studio exported app — design source of truth)
- Repo: github.com/Malik-Adeen/call-quality-analytics

---

## SYSTEM OVERVIEW

8-service Docker stack. FastAPI API + Celery workers (gpu_queue + io_queue) + PostgreSQL 16 + Redis 7 + MinIO + MinIO Init + Flower.

**7-stage AI pipeline:**
`POST /calls/upload` → `run_whisperx (gpu_queue)` → `redact_pii` → `compute_talk_balance` → `run_groq_inference` → `write_scores` → `notify_websocket (all io_queue)`

**AI stack:** WhisperX large-v2 (RTX 3060 Ti) → Presidio PII redaction → Groq `llama-3.3-70b-versatile` primary / OpenRouter `meta-llama/llama-3.3-70b-instruct` fallback

**Frontend:** React 18 + TypeScript + Vite + TailwindCSS v4 + Recharts + Zustand (sessionStorage persist) + motion/react

---

## CURRENT BUILD STATUS: v1.2 — DEMO READY (LOCAL)

| Phase | Status |
|---|---|
| Phase 1 — Auth, Upload, Docker, Celery | ✅ |
| Phase 2.1 — WhisperX GPU | ✅ |
| Phase 2.2 — Presidio PII redaction | ✅ |
| Phase 2.3 — Groq inference | ✅ |
| Phase 2.4 — Scoring, chain, WebSocket | ✅ |
| Audit fixes (3 critical + 3 warnings) | ✅ |
| Phase 3A — Read endpoints | ✅ |
| Phase 3 — React dashboard (6 pages) | ✅ |
| UI redesign (light parchment theme) | ✅ |
| UI bug fixes (4 bugs post-redesign) | ✅ |
| Phase 4 — PDF export + reseed + MinIO volume + CORS | ✅ |
| **Azure B2s + NC4as_T4_v3 deploy** | 🔲 NEXT |

---

## WHAT WORKS RIGHT NOW

- Upload real `.wav`/`.mp3` → full pipeline → score displayed in dashboard via WebSocket
- E2E verified twice: `test_call.wav` → `score=8.72` · `test_call.mp3` → `score=92%`
- Dashboard: Login, Overview (StatCards + charts), Call History (table + search + filters), Call Detail (slide-in panel with RadarChart), Agents (cards + score history), Upload, Reports (WebSocket live)
- `POST /reports/export` → validated Playwright PDF with metadata, metrics bar chart, coaching summary
- `scripts/reset_and_seed.py` — one-command demo reset (TRUNCATE + bcrypt passwords + 200 calls)
- MinIO audio persists across container restarts (`minio_data` named volume)
- CORS locked to `http://localhost:5173`
- 200 seeded calls, 5 agents in DB

---

## WHAT NEEDS TO BE DONE NEXT

1. **Azure B2s deployment** — always-on demo server. Runbook: `11_Azure_Deployment.md`
2. **Azure NC4as_T4_v3 GPU** — start 20min before demo, stop immediately after. Runbook: `11_Azure_Deployment.md`
3. **CORS update for Azure** — change `allow_origins` in `main.py` to Azure B2s public IP before demo
4. **Final demo dry-run** — script order: KPI Overview → Call List → Call Detail → Agent View → Live Upload → PDF export

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
10. Score display: backend 0–10 × 10 = percentage shown in UI (e.g. 7.85 → 78.5%)
11. Zero code comments — ever

---

## CODING RULES (NON-NEGOTIABLE)

- Zero comments in any generated code. Ever. No exceptions.
- Highly readable, self-documenting code instead.
- Zero prose inside code blocks — executable code only.
- No banned tools: Ollama, VADER, WeasyPrint, localStorage for JWT, raw transcript in DB, audio blob in DB, Node.js backend

---

## TECH STACK (FROZEN — NO DEVIATIONS)

**Backend:** FastAPI + Celery 5.x + Redis 7 + MinIO + PostgreSQL 16 + SQLAlchemy 2.x async + Pydantic 2.x + python-jose + bcrypt + Playwright
**AI:** WhisperX (faster-whisper-turbo large-v2) + Pyannote.audio 3.1 + Presidio + Groq API
**Frontend:** React 18 + TypeScript + Vite + TailwindCSS v4 + Recharts + Zustand + Axios + motion/react
**Infra:** Docker Compose (8 services) + Flower 2.0

---

## FRONTEND DESIGN SYSTEM

Light parchment theme. Source of truth: `N:\projects\Google-Inspo\src\App.tsx`

| Token | Value |
|---|---|
| Background | `#E4E3E0` warm parchment |
| Cards | `bg-white border border-[#141414]` sharp edges, no radius |
| Active nav | `bg-[#141414] text-[#E4E3E0]` full-width button |
| Body font | Inter |
| Data/numbers | JetBrains Mono (`font-mono`) |
| Headers/names | Playfair Display italic (`font-serif`) |
| Score high >80% | `#10b981` emerald |
| Score mid 60-80% | `#141414` black |
| Score low <60% | `#ef4444` red |

**Key components:**
- `CallDetailPanel.tsx` — shared slide-in panel (motion/react spring), used by Overview and CallList
- `Sidebar.tsx` — w-64, NEW ANALYSIS button pinned to bottom
- `App.tsx` — sticky header with page title (serif italic) + user avatar

---

## KNOWN ISSUES (DEFERRED)

- CORS origin must be updated to Azure B2s public IP before demo day
- Audio playback removed — CORS + ephemeral MinIO; see `19_Future_Transcript_Audio_Sync.md`

---

## TOOLING WORKFLOW

- **Claude** — architecture decisions, code generation, vault updates (writes vault only after test validation)
- **Antigravity IDE** — file writing, container execution, verification
- **Gemini** — supplementary debugging

---

## SECOND BRAIN (OBSIDIAN VAULT)

Location: `N:\projects\docs`

Key files to read at session start:
- `00_Master_Dashboard.md` — current state, invariants, component map
- `01_Master_Architecture.md` — stack manifest (LLM anchor doc)
- `03_API_Contract.md` — all API shapes and TypeScript interfaces (LLM anchor doc)
- `21_UI_Redesign_Postmortem.md` — full design system history and bug log
- `23_Phase4_Postmortem.md` — Phase 4 bugs and decisions

---

## HOW TO START DOCKER AFTER RESTART

```powershell
docker compose -f N:\projects\call-quality-analytics\infra\docker-compose.yml up -d
cd N:\projects\call-quality-analytics\frontend && npm run dev
$r = Invoke-RestMethod -Uri "http://localhost:8000/auth/login" -Method POST -ContentType "application/json" -Body '{"email":"admin@callquality.demo","password":"admin1234"}'
$token = $r.data.access_token
```

## RESET DB (demo prep or after corrupted state)

```powershell
cd N:\projects\call-quality-analytics
python scripts/reset_and_seed.py
```
