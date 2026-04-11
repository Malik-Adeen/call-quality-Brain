---
tags: [moc, dashboard]
status: active
created: 2026-04-11
updated: 2026-04-11
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
| **Deployment** | Local Docker → Azure GPU (demo day only) |

---

## Current Build State

| Phase | Description | Status | Tag |
|---|---|---|---|
| Phase 1 | Foundation — Auth, Upload, Docker, Celery | ✅ Complete | v0.1-phase1-complete |
| Phase 2.1 | GPU Worker — WhisperX + Pyannote ASR | ✅ Complete | v0.2-phase2.1-complete |
| Phase 2.2 | IO Worker — Presidio PII Redaction | ✅ Complete | v0.4-phase2.2-complete |
| Phase 2.3 | IO Worker — Groq LLM Inference | ✅ Complete | v0.5-phase2.3-complete |
| Phase 2.4 | IO Worker — Scoring, Chain Wiring, WebSocket | ✅ Complete | v0.6-phase2.4-complete |
| Audit Fixes | Security + pipeline fixes (GPT-5 audit) | ✅ Complete | v0.7-audit-fixes-complete |
| Phase 3A | Backend Read Endpoints | ✅ Complete | v0.8-phase3a-read-endpoints |
| Phase 3 | Frontend React Dashboard — 5 modules | ✅ Complete | v0.9-phase3-frontend-complete |
| Phase 4 | Demo Hardening + Azure Deployment | 🔲 Next | — |

---

## What Works Right Now

- Full 7-stage pipeline: upload → WhisperX → PII redact → talk balance → Groq → score → WebSocket ✅
- End-to-end verified: `test_call.wav` → `status=complete`, `score=8.72` ✅
- React dashboard: Login, KPI Overview, Call List, Call Detail, Agent View, Reports ✅
- All API endpoints live: `POST /auth/login`, `POST /calls/upload`, `GET /calls`, `GET /calls/{id}`, `GET /agents/{id}/scores` ✅
- WebSocket `call_complete` event fires on pipeline completion ✅
- 200 seeded calls in DB with 5 agents ✅

---

## What Still Needs Building (Phase 4)

| Item | Priority | Notes |
|---|---|---|
| PDF export (`reports.py`) | HIGH | Playwright stub — needs real implementation |
| DB cleanup + reseed | HIGH | Duplicate agents from multiple seed runs |
| Azure B2s deployment | HIGH | Always-on demo server |
| Azure NC4as_T4_v3 setup | HIGH | GPU for live demo |
| Diarized segments persisted to DB | MEDIUM | Audio sync in Call Detail — see [[19_Future_Transcript_Audio_Sync]] |
| `GET /admin/gpu-status` endpoint | LOW | Nice to have for demo |
| CORS restriction | LOW | Currently wildcard — fix before demo |

---

## Critical Invariants — Never Violate

1. Audio binary **never** in DB — MinIO only, store `minio_audio_path`
2. Raw transcript **never** in DB — Presidio-redacted text only
3. `pii_redacted = TRUE` must be set **before** any downstream task runs
4. `run_whisperx` → `gpu_queue` exclusively, concurrency=1
5. All other tasks → `io_queue`, concurrency=4
6. JWT in Zustand memory only — **never** localStorage
7. Scoring formula weights are **invariant** — never modify
8. Groq model: `llama-3.3-70b-versatile` (3.1 is deprecated)
9. OpenRouter fallback model: `meta-llama/llama-3.3-70b-instruct`
10. MinIO endpoint: `cq-minio:9000` (hyphens — underscores rejected by botocore)

---

## Known Issues / Deferred

| Issue | Severity | Decision |
|---|---|---|
| CORS `allow_origins=["*"]` with `allow_credentials=True` | WARNING | Deferred — fix on demo day |
| JWT passed in WS query param | WARNING | Deferred — API contract specifies `?token=` |
| Duplicate agents in DB from multiple seed runs | INFO | Fix with fresh TRUNCATE + reseed before demo |
| `diarized_segments` always empty in Call Detail | INFO | Pipeline stores transcript text only, not segments |
| `reports.py` PDF export is a stub | HIGH | Phase 4 |

---

## Architecture & Design Docs

- [[01_Master_Architecture]] — Stack manifest, banned tools, queue contract, scoring formula (LLM anchor doc)
- [[03_API_Contract]] — All FastAPI + WebSocket endpoint shapes, TypeScript interfaces (LLM anchor doc)
- [[15_Design_System]] — Tailwind tokens, Recharts palette, typography, colour system
- `02_Database_Schema.sql` — PostgreSQL 16 schema *(open directly — SQL file)*

---

## Planning Docs

- [[PROJECT_ROADMAP_1]] — Master roadmap with Mermaid architecture diagram
- [[04_Demo_Execution_Plan]] — Step-by-step daily execution guide for demo day

---

## Research

- [[06_Urdu_ASR_Research]] — Urdu ASR limitations, QLoRA fine-tuning, 8GB VRAM constraints

---

## Infrastructure Reference

- [[10_GPU_Infrastructure]] — RTX 3060 Ti · 8GB VRAM · CUDA 12.1 · WSL2 · Docker Desktop · package name gotchas

---

## Post-Mortems (chronological)

- [[07_Phase1_Postmortem]] — Phase 1: Auth, upload pipeline, 7-service Docker stack
- [[08_Phase2.1_Postmortem]] — Phase 2.1: WhisperX large-v2, Pyannote diarization, 33s inference
- [[09_Phase2.2_Postmortem]] — Phase 2.2: Presidio PII redaction gate, Celery chain bugs
- [[11_Phase2.3_Postmortem]] — Phase 2.3: Groq inference, model deprecation fix, 31/31 tests
- [[12_Phase2.4_Postmortem]] — Phase 2.4: Scoring formula, full chain wiring, WebSocket
- [[13_Phase2_E2E_Postmortem]] — Phase 2 E2E: Full pipeline verified x2, score=8.72
- [[14_Audit_Fixes]] — GPT-5 security audit: 3 critical + 3 warnings fixed
- [[16_Phase3A_Read_Endpoints]] — GET /calls, GET /calls/{id}, GET /agents/{id}/scores
- [[17_Phase3_Frontend]] — React dashboard: 5 modules, design system applied

---

## Phase 4 Planning

- [[18_Phase4_Plan]] — Demo hardening, PDF export, Azure deployment, demo day checklist

---

## LLM Session Starter

Copy and paste at the top of every new Claude or Antigravity session:

```
Vault: N:\projects\docs
Repo:  N:\projects\call-quality-analytics

Anchor docs:
- 01_Master_Architecture.md — stack manifest, banned tools, queue contract, scoring formula
- 02_Database_Schema.sql    — canonical column names and types
- 03_API_Contract.md        — exact JSON request/response shapes and TypeScript interfaces

Current state: Phase 4 — Demo Hardening

Rules:
- Do not suggest any tool not listed in 01_Master_Architecture.md
- All column names must match 02_Database_Schema.sql exactly
- All API response shapes must match 03_API_Contract.md exactly
- Zero comments in generated code
- Do not build beyond the current phase
```
