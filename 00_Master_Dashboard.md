---
tags: [moc, dashboard]
status: active
created: 2026-04-11
updated: 2026-04-14
---

# 00 — Master Dashboard

> **Second Brain MOC.** Single entry point for the entire vault.
> Always read this first when starting a new session. Check phase status before writing any code.

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
| **Reference UI** | N:\projects\Google-Inspo (exported Google AI Studio app — source of truth for design) |
| **Deployment** | Local Docker → Azure GPU (demo day only) |

---

## Current Build State

| Phase | Description | Status | Tag |
|---|---|---|---|
| Phase 1 | Foundation — Auth, Upload, Docker, Celery | ✅ Complete | v0.1 |
| Phase 2.1 | GPU Worker — WhisperX + Pyannote ASR | ✅ Complete | v0.2 |
| Phase 2.2 | IO Worker — Presidio PII Redaction | ✅ Complete | v0.4 |
| Phase 2.3 | IO Worker — Groq LLM Inference | ✅ Complete | v0.5 |
| Phase 2.4 | IO Worker — Scoring, Chain Wiring, WebSocket | ✅ Complete | v0.6 |
| Audit Fixes | Security + pipeline fixes (GPT-5 audit) | ✅ Complete | v0.7 |
| Phase 3A | Backend Read Endpoints | ✅ Complete | v0.8 |
| Phase 3 | React Dashboard — 6 pages | ✅ Complete | v0.9 |
| UI Redesign | Light design system — Google AI Studio inspired | ✅ Complete | v1.0 |
| UI Bug Fixes | 4 functional bugs fixed post-redesign | ✅ Complete | v1.1 |
| Phase 4 | Demo Hardening + Azure Deployment | 🔲 Next | — |

---

## What Works Right Now (v1.1)

- Full 7-stage pipeline: upload → WhisperX → PII redact → talk balance → Groq → score → WebSocket ✅
- End-to-end verified twice: `test_call.wav` → `status=complete`, `score=8.72` ✅
- React dashboard: Login, Overview, Call History, Call Detail (slide-in panel), Agents, Upload, Reports ✅
- All API endpoints live ✅
- WebSocket `call_complete` event fires and displays toast in Reports page ✅
- 200 seeded calls in DB with 5 agents ✅
- SessionStorage JWT persistence — survives page reload, clears on tab close ✅
- Slide-in `CallDetailPanel` with RadarChart, AreaChart, and transcript viewer ✅
- Recent Activity rows clickable → open CallDetailPanel ✅
- Call History search filters by agent name / team / category client-side ✅
- Agent tab loads all agents via multi-page fetch ✅

---

## What Still Needs Building (Phase 4)

| Item | Priority | Notes |
|---|---|---|
| PDF export (`reports.py`) | HIGH | Playwright stub — needs real implementation |
| DB cleanup + reseed | HIGH | Duplicate agents from multiple seed runs — TRUNCATE + reseed |
| Azure B2s deployment | HIGH | Always-on demo server |
| Azure NC4as_T4_v3 setup | HIGH | GPU for live demo ($0.53/hr, start 20min before) |
| Diarized segments in DB | MEDIUM | See [[19_Future_Transcript_Audio_Sync]] — needs real audio data |
| MinIO named volume | MEDIUM | Audio lost on container restart — add before Azure |
| CORS restriction | LOW | Currently wildcard — fix before demo day |
| `GET /admin/gpu-status` | LOW | Nice to have |

---

## Critical Invariants — Never Violate

1. Audio binary **never** in DB — MinIO only, store `minio_audio_path`
2. Raw transcript **never** in DB — Presidio-redacted text only
3. `pii_redacted = TRUE` must be set **before** any downstream task runs
4. `run_whisperx` → `gpu_queue` exclusively, concurrency=1
5. All other tasks → `io_queue`, concurrency=4
6. JWT in Zustand **sessionStorage** — never localStorage, never in-memory-only (survives reload)
7. Scoring formula weights are **invariant** — never modify
8. Groq model: `llama-3.3-70b-versatile` (3.1 is deprecated)
9. OpenRouter fallback: `meta-llama/llama-3.3-70b-instruct` — triggers on HTTP 429/503 only
10. MinIO endpoint: `cq-minio:9000` (hyphens — underscores rejected by botocore)
11. Score display: backend stores **0–10**, UI shows as **percentage (×10)** e.g. 7.85 → 78.5%

---

## Frontend Design System (v1.0 — Light Theme)

Documented in [[20_New_Design_System]]. Key tokens:

| Token | Value |
|---|---|
| Background | `#E4E3E0` warm parchment |
| Sidebar | `#E4E3E0` same as bg, `border-r border-[#141414]` |
| Cards | `bg-white border border-[#141414]` sharp edges |
| Text primary | `#141414` near-black |
| Text secondary | `rgba(20,20,20,0.7)` |
| Text muted | `opacity-50` on any element |
| Active nav | `bg-[#141414] text-[#E4E3E0]` full-width button |
| Score high | `#10b981` emerald (>80%) |
| Score mid | `#141414` black (60–80%) |
| Score low | `#ef4444` red (<60%) |
| Font body | Inter |
| Font data | JetBrains Mono (`font-mono`) |
| Font headers | Playfair Display italic (`font-serif`) |

Reference source: `N:\projects\Google-Inspo\src\App.tsx`

---

## Frontend Component Map

| File | Purpose |
|---|---|
| `src/App.tsx` | Router, ProtectedLayout, sticky Header with page title + user avatar |
| `src/components/Sidebar.tsx` | w-64 sidebar, full-width black active nav, NEW ANALYSIS button at bottom |
| `src/components/CallDetailPanel.tsx` | Slide-in panel (motion/react spring), RadarChart, sentiment timeline, transcript |
| `src/pages/Overview.tsx` | 3 StatCards + Score Distribution BarChart + Recent Activity (clickable) |
| `src/pages/CallList.tsx` | grid-cols-6 table, status filter pills, inline search, slide-in panel |
| `src/pages/CallDetail.tsx` | Thin wrapper — renders CallDetailPanel via URL param |
| `src/pages/Agents.tsx` | Agent cards with progress bar, Score History LineChart, Strengths/Weaknesses |
| `src/pages/UploadCall.tsx` | Audio file upload form, pipeline start confirmation |
| `src/pages/Reports.tsx` | PDF export table, WebSocket live status, toast notifications |
| `src/pages/Login.tsx` | Login form |
| `src/store/auth.ts` | Zustand + sessionStorage persist |
| `src/utils/format.ts` | `scoreColor`, `scoreBadgeStyle`, `formatDuration`, `formatDate` |
| `src/types/api.ts` | All TypeScript interfaces matching 03_API_Contract.md |

---

## Known Issues / Deferred

| Issue | Severity | Decision |
|---|---|---|
| CORS `allow_origins=["*"]` with `allow_credentials=True` | WARNING | Deferred — fix on demo day |
| JWT passed in WS query param | WARNING | Deferred — API contract specifies `?token=` |
| Duplicate agents in DB from multiple seed runs | INFO | Fix with TRUNCATE + reseed before demo |
| `diarized_segments` always empty | INFO | Pipeline stores text only — see [[19_Future_Transcript_Audio_Sync]] |
| `reports.py` PDF export is a stub | HIGH | Phase 4 |
| MinIO data lost on container restart | MEDIUM | Add named volume before Azure deploy |
| Audio playback removed | INFO | CORS issues — deferred until real data available |

---

## Architecture & Design Docs

- [[01_Master_Architecture]] — Stack manifest, banned tools, queue contract, scoring formula
- [[03_API_Contract]] — All FastAPI + WebSocket endpoint shapes, TypeScript interfaces
- [[20_New_Design_System]] — Complete light design system tokens and component patterns
- `02_Database_Schema.sql` — PostgreSQL 16 schema

---

## Post-Mortems (chronological)

- [[07_Phase1_Postmortem]] — Phase 1: Auth, upload, 7-service Docker stack
- [[08_Phase2.1_Postmortem]] — Phase 2.1: WhisperX large-v2, Pyannote, 33s inference
- [[09_Phase2.2_Postmortem]] — Phase 2.2: Presidio PII gate, Celery chain bugs
- [[11_Phase2.3_Postmortem]] — Phase 2.3: Groq inference, model deprecation fix
- [[12_Phase2.4_Postmortem]] — Phase 2.4: Scoring formula, chain wiring, WebSocket
- [[13_Phase2_E2E_Postmortem]] — Phase 2 E2E: Full pipeline verified x2, score=8.72
- [[14_Audit_Fixes]] — GPT-5 security audit: 3 critical + 3 warnings fixed
- [[16_Phase3A_Read_Endpoints]] — GET /calls, GET /calls/{id}, GET /agents/{id}/scores
- [[17_Phase3_Frontend]] — React dashboard: 6 pages, initial dark design
- [[21_UI_Redesign_Postmortem]] — Full UI overhaul: light theme, Google AI Studio inspired

---

## Future / Deferred Features

- [[19_Future_Transcript_Audio_Sync]] — Diarized segment timestamps → clickable transcript audio sync

---

## Phase 4 Planning

- [[18_Phase4_Plan]] — Demo hardening, PDF export, Azure deployment, demo day checklist

---

## LLM Session Starter (copy this into every new session)

```
Vault:        N:\projects\docs
Repo:         N:\projects\call-quality-analytics
Reference UI: N:\projects\Google-Inspo\src\App.tsx

Anchor docs (always read before coding):
- 01_Master_Architecture.md — stack, banned tools, queue contract, scoring formula
- 02_Database_Schema.sql    — canonical column names and types
- 03_API_Contract.md        — exact JSON shapes and TypeScript interfaces
- 00_Master_Dashboard.md    — current build state and invariants

Current state: Phase 4 — Demo Hardening
Last completed: v1.1 — UI redesign + 4 bug fixes (Recent Activity click, Agent tab, filtering, search)

Hardware: RTX 3060 Ti · 8GB VRAM · Windows + Docker Desktop + WSL2

Rules:
- Zero code comments — ever
- No banned tools (see 01_Master_Architecture.md §3)
- Score display: backend 0-10 × 10 = percentage for UI
- JWT in Zustand sessionStorage — never localStorage
- MinIO endpoint: cq-minio:9000 (hyphens)
- DATABASE_URL: postgresql+asyncpg:// for API, postgresql:// for workers
```
