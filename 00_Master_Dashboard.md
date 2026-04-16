---
tags: [moc, dashboard]
status: active
created: 2026-04-11
updated: 2026-04-16
---

# 00 — Master Dashboard

> **Second Brain MOC.** Single entry point for the entire vault.
> Always read this first when starting a new session.

---

## Project Identity

| Property | Value |
|---|---|
| **System** | AI Call Quality & Agent Performance Analytics System |
| **Purpose** | University final-year demo — GPU-accelerated transcription + LLM scoring pipeline |
| **Stack** | FastAPI · Celery · Redis · MinIO · PostgreSQL · WhisperX · Groq · React |
| **Repo** | github.com/Malik-Adeen/call-quality-analytics |
| **Local path** | N:\projects\call-quality-analytics |
| **Vault path** | N:\projects\docs |
| **Azure B2s** | `20.228.184.111` — East US — always-on dashboard |

---

## Current Build State — v1.3

| Phase | Description | Status |
|---|---|---|
| Phase 1 | Foundation — Auth, Upload, Docker, Celery | ✅ |
| Phase 2.1 | GPU Worker — WhisperX + Pyannote ASR | ✅ |
| Phase 2.2 | IO Worker — Presidio PII Redaction | ✅ |
| Phase 2.3 | IO Worker — Groq LLM Inference | ✅ |
| Phase 2.4 | IO Worker — Scoring, Chain, WebSocket | ✅ |
| Audit Fixes | Security + pipeline fixes | ✅ |
| Phase 3A | Backend Read Endpoints | ✅ |
| Phase 3 | React Dashboard — 6 pages | ✅ |
| UI Redesign | Light parchment theme | ✅ |
| UI Bug Fixes | Score formatting, metric formatting | ✅ |
| Phase 4 | PDF export · reseed · MinIO volume · CORS | ✅ |
| Hybrid Deploy | Azure B2s + SSH tunnel + WAN Celery tuning | ✅ |
| **Demo dry-run** | Full script rehearsal | 🔲 Next |

---

## What Works Right Now (v1.3)

- Azure B2s live: `http://20.228.184.111:8000/health` ✅
- 200 seeded calls on Azure DB ✅
- Full hybrid E2E: local upload → Azure API → SSH tunnel → RTX 3060 Ti → Azure DB ✅
- Verified: `James O'Brien · Sales · 92%` in Azure Call List ✅
- PDF export (Playwright on Azure) ✅
- WebSocket proxied through Vite — no hardcoded IPs ✅
- SSH key auth — tunnel reconnects silently ✅
- Score display: `%` format everywhere ✅

---

## What Still Needs Doing

| Item | Priority |
|---|---|
| `git pull` on Azure VM + restart services | HIGH |
| WebSocket toast verification (upload + confirm toast fires) | HIGH |
| Demo dry-run — full script rehearsal | HIGH |
| GPU quota check (East US NC4as_T4_v3) | MEDIUM |

---

## Hybrid Architecture

```
Browser (localhost:5173)
    ↓ Vite proxy (/api → Azure, /ws → Azure)
Azure B2s (20.228.184.111:8000)
    FastAPI · PostgreSQL · Redis · MinIO · worker_io · Flower
    ↕ Celery gpu_queue tasks
SSH Tunnel (localhost:6379/5432/9000 → Azure via port 22)
    ↕
Local RTX 3060 Ti
    worker_gpu · WhisperX large-v2 · ~33s inference
```

**Start sequence for demo:**
1. `scripts/tunnel.bat` — keep open
2. `docker compose -f infra/docker-compose.hybrid.yml up -d worker_gpu`
3. `cd frontend && npm run dev`
4. Open `http://localhost:5173`

---

## Azure Infrastructure

| Resource | Region | IP | Cost | Status |
|---|---|---|---|---|
| B2s (always-on) | East US | `20.228.184.111` | ~$0.042/hr | ✅ Running |
| NC4as_T4_v3 | East US | TBD | ~$0.526/hr | ⏳ Quota pending |

---

## Critical Invariants — Never Violate

1. Audio binary → MinIO only (`minio_audio_path`), never DB
2. Raw transcript → never DB — Presidio-redacted only
3. `pii_redacted = TRUE` before any downstream task
4. `run_whisperx` → `gpu_queue` exclusively, concurrency=1
5. JWT in Zustand sessionStorage — never localStorage
6. Scoring formula weights invariant — never modify
7. Groq model: `llama-3.3-70b-versatile` (never 3.1)
8. MinIO endpoint: `cq-minio:9000` (hyphens)
9. `DATABASE_URL`: `postgresql+asyncpg://` for API, `postgresql://` for workers
10. Score display: backend 0–10 × 10 = % in UI
11. Zero code comments — ever

---

## Frontend Component Map

| File | Purpose |
|---|---|
| `src/App.tsx` | Router, ProtectedLayout, sticky Header |
| `src/components/Sidebar.tsx` | w-64, NEW ANALYSIS button at bottom |
| `src/components/CallDetailPanel.tsx` | Slide-in panel, RadarChart, sentiment timeline |
| `src/pages/Overview.tsx` | StatCards + Score Distribution + Recent Activity |
| `src/pages/CallList.tsx` | Table, status filters, search, slide-in panel |
| `src/pages/Agents.tsx` | Agent cards, Score History, Strengths/Weaknesses (% formatted) |
| `src/pages/UploadCall.tsx` | Audio upload form |
| `src/pages/Reports.tsx` | PDF export, WebSocket live toast (% formatted, proxied WS) |
| `src/pages/Login.tsx` | Login form |
| `src/store/auth.ts` | Zustand + sessionStorage |
| `src/utils/format.ts` | `scoreColor`, `formatDuration`, `formatDate` |
| `vite.config.ts` | Proxy: `/api` + `/ws` → `20.228.184.111:8000` |

---

## Known Issues / Deferred

| Issue | Severity |
|---|---|
| `diarized_segments` always empty | INFO — see [[19_Future_Transcript_Audio_Sync]] |
| JWT passed in WS query param | WARNING — deferred, per API contract |
| Audio playback removed | INFO — deferred |
| NC4as_T4_v3 quota pending | MEDIUM — fallback is local RTX |

---

## Post-Mortems (chronological)

- [[07_Phase1_Postmortem]]
- [[08_Phase2.1_Postmortem]]
- [[09_Phase2.2_Postmortem]]
- [[11_Phase2.3_Postmortem]]
- [[12_Phase2.4_Postmortem]]
- [[13_Phase2_E2E_Postmortem]]
- [[14_Audit_Fixes]]
- [[16_Phase3A_Read_Endpoints]]
- [[17_Phase3_Frontend]]
- [[21_UI_Redesign_Postmortem]]
- [[23_Phase4_Postmortem]]
- [[24_Hybrid_Architecture_Postmortem]]

---

## Reference Docs

- [[01_Master_Architecture]] — Stack manifest, banned tools, queue contract, scoring formula
- [[03_API_Contract]] — FastAPI + WebSocket endpoint shapes, TypeScript interfaces
- [[11_Azure_Deployment]] — B2s + NC4as_T4_v3 runbooks, budget tracker
- [[20_New_Design_System]] — Light design system tokens
- [[22_Session_Handoff]] — Copy-paste session starter for new Claude chats
