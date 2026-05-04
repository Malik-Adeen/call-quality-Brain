# GRAPH REPORT — AI Call Quality Analytics System
Generated: 2026-05-03 11:11 | Run `python scripts/build_graph.py` to update

---

## GOD NODES (highest connectivity)

- app.database (imported by 8 files)
- app.models.orm (imported by 7 files)
- app.auth.dependencies (imported by 5 files)
- app.config (imported by 4 files)
- app.schemas.api (imported by 4 files)
- Celery tasks: run_whisperx, extract_agent_identity, redact_pii, compute_talk_balance, run_groq_inference, write_scores, notify_websocket
- tasks.py → central hub: run_whisperx→redact_pii→compute_talk_balance→run_groq_inference→write_scores→notify_websocket
- presidio_service.py → PII gate: 10 entity types, 3 custom recognizers (ZIP/SSN-last4/ACCOUNT)
- llm_client.py → inference: Groq primary → OpenRouter fallback (429/503 only)

---

## PIPELINE (sequential — no stage skippable)

1.ingest_upload(api_sync) → 2.run_whisperx(gpu_queue) → 3.redact_pii(⚠ GATE) → 4.compute_talk_balance(io_queue) → 5.run_groq_inference(io_queue) → 6.write_scores(io_queue) → 7.notify_websocket(io_queue)

Queue routing:
- gpu_queue: worker_gpu, concurrency=1, prefetch=1 → run_whisperx ONLY
- io_queue: worker_io, concurrency=4, prefetch=2 → all other tasks

---

## SERVICES (7 containers)

  cq_api:8000 — FastAPI REST+WebSocket
  cq_worker_io — Celery io_queue CPU
  cq_worker_gpu — Celery gpu_queue WhisperX
  cq_postgres:5432 — relational store
  cq_redis:6379 — Celery broker+backend
  cq_minio:9000 — audio object storage
  cq_flower:5555 — queue monitor

Hybrid: worker_gpu runs locally, connects to Azure B2s via SSH tunnel (:6379/:5432/:9000)
Azure: 20.228.184.111:8000

---

## DATABASE SCHEMA

  users: id:uuid | name:text | email:text | password_hash:text
  agents: id:uuid | name:text | team:text
  calls: id:uuid | agent_id:fk→agents | minio_audio_path:text | transcript_redacted:text
  call_metrics: id:uuid | call_id:fk→calls | politeness_score:numeric | sentiment_delta:numeric
  sentiment_timeline: id:uuid | call_id:fk→calls | timestamp_seconds:int | sentiment_value:numeric

Key column invariants:
  ⚠ minio_audio_path — never audio_path
  ⚠ transcript_redacted — raw text NEVER written to DB
  ⚠ pii_redacted=TRUE before run_groq_inference

---

## AI STACK

ASR: WhisperX faster-whisper large-v2 + Pyannote.audio 3.1
  VRAM: ~4-5GB peak (WhisperX ~3GB + Pyannote ~1GB) | Speed: ~33s warm cache on RTX 3060 Ti
  Labels: AGENT or CUSTOMER — never SPEAKER_00/01

PII: Microsoft Presidio (extended)
  Entities: CREDIT_CARD, PHONE_NUMBER, EMAIL_ADDRESS, PERSON, US_SSN, IBAN_CODE, DATE_TIME, LOCATION, ZIP_CODE, ACCOUNT_NUMBER
  Custom: SSN last-4 (context: last four/social) | ZIP_CODE (context: billing/zip/address) | ACCOUNT_NUMBER (context: account/member/id)

LLM: Groq llama-3.3-70b-versatile → fallback: OpenRouter meta-llama/llama-3.3-70b-instruct
  Trigger: HTTP 429 or 503 from Groq only
  Output: politeness_score, clarity_score, resolution_score, sentiment_delta, coaching_summary, issue_category, resolved, sentiment_start, sentiment_end

Scoring: 0.25*pol + 0.20*((sdelta+1)/2) + 0.20*res + 0.15*bal + 0.20*cla → ×10 = display_%

---

## FRONTEND

Pages: Overview, CallList, Agents, Upload, Reports, Login
Shared: CallDetailPanel, Sidebar
State: Zustand sessionStorage persist — JWT survives reload, clears on tab close
Proxy: Vite /api + /ws → 20.228.184.111:8000 (hybrid mode) or localhost:8000 (local mode)
Design: bg=#E4E3E0 warm parchment | score_high=#10b981 (>80%) | score_mid=#141414 (60-80%) | score_low=#ef4444 (<60%)
Fonts: Inter body, JetBrains Mono data, Playfair Display italic headers

---

## BACKEND FILES (26 python files)

  config.py: cls:[Settings,Config]
  database.py: fns:[build_async_url,build_sync_url] cls:[Base]
  dependencies.py: fns:[require_role]
  jwt.py: fns:[create_access_token,decode_access_token]
  orm.py: cls:[Tenant,User]
  tasks.py: tasks:[run_whisperx,extract_agent_identity,redact_pii,compute_talk_balance,run_groq_inference,write_scores,notify_websocket]
  agents.py: cls:[AgentSyncItem,AgentSyncRequest]
  calls.py: fns:[_score_float,_call_to_summary]
  platform.py: cls:[TenantCreateRequest,TenantOut]
  reports.py: fns:[build_metrics_rows,build_transcript_html,build_report_html] cls:[ExportRequest]
  ws.py: fns:[__init__,disconnect] cls:[ConnectionManager]
  api.py: cls:[ApiError,ApiResponse]
  llm_client.py: fns:[_cache_key,_call_provider,run_inference,validate_zero_to_one] cls:[InferenceResult]
  minio_client.py: fns:[__init__,ensure_bucket_exists,upload_audio,download_file] cls:[MinioClient]
  presidio_service.py: fns:[redact_text]
  whisper_service.py: fns:[_remap_speakers,_cuda_cleanup,transcribe_and_diarize]

---

## FRONTEND FILES (16 ts/tsx files)

  auth.ts: exports:[useAuthStore]
  api.ts: exports:[ApiError,ApiResponse,CallMetrics]
  dashboardTransforms.ts: exports:[GroupedDayPoint,CoachingRiskAgent,IssueSpikePoint]
  format.ts: exports:[scoreColor,scoreBadgeStyle,scoreBadge]
  App.tsx: exports:[App]
  CallDetailPanel.tsx: exports:[CallDetailPanel]
  Sidebar.tsx: exports:[Sidebar]
  Agents.tsx: exports:[Agents]
  CallDetail.tsx: exports:[CallDetail]
  CallList.tsx: exports:[CallList]
  Login.tsx: exports:[Login]
  Overview.tsx: exports:[Overview]
  Reports.tsx: exports:[Reports]
  UploadCall.tsx: exports:[UploadCall]

---

## VAULT (54 docs)

  00_Master_Dashboard.md: 00 — Master Dashboard | Project Identity | Build State — v1.6 (Phase 6 Complete, Pipeline E2E Verifi
  01_Master_Architecture.md: 01 — Master Architecture & Stack Manifest | 1. System Identity | 2. Mandated Tech Stack
  03_API_Contract.md: 03 — API & WebSocket Contract | Global Response Envelope | POST /auth/login
  04_Demo_Execution_Plan.md: 04 — Demo Execution Plan | How to Use This Document | Phase 0 — Local Infrastructure Setup
  06_Urdu_ASR_Research.md: Phase 3 & 4 Research: Urdu ASR and QLoRA Fine-Tuning | **Context:** This document dictates the const
  07_Phase1_Postmortem.md: What Was Built | Bugs Encountered & Resolutions | Architecture Decisions
  08_Phase2.1_Postmortem.md: What Was Built | Bugs Encountered & Resolutions | Architecture Decisions
  09_Phase2.2_Postmortem.md: What Was Built | Bugs Encountered & Resolutions | Architecture Decisions
  10_GPU_Infrastructure.md: Host Environment | Dockerfile.gpu Base Image | Python Version Disambiguation
  11_Azure_Deployment.md: Region Decision | Azure B2s — Always-On Demo Server | Azure NC4as_T4_v3 — GPU (T4 16GB) — Pending Qu
  11_Phase2.3_Postmortem.md: What Was Built | Bugs Encountered & Resolutions | Architecture Decisions
  12_Phase2.4_Postmortem.md: What Was Built | Bugs Encountered & Resolutions | Chain Signature Map
  13_Phase2_E2E_Postmortem.md: What Was Built | End-to-End Result | Bugs Encountered & Resolutions
  14_Audit_Fixes.md: Source | Fix Tracker | Key Fix Details
  15_Design_System.md: Design System — AI Call Quality Dashboard | Accent Colour | Typography
  16_Phase3A_Read_Endpoints.md: What Was Built | Bugs Encountered & Resolutions | Verified Results
  17_Phase3_Frontend.md: What Was Built | Tech Stack | Architecture Decisions
  18_Phase4_Plan.md: 18 — Phase 4 Plan: Demo Hardening & Azure Deployment | Overview | Task List
  19_Future_Transcript_Audio_Sync.md: Future Implementation: Transcript Audio Sync | What It Is | Current Behaviour
  20_New_Design_System.md: 20 — New Design System (Google AI Studio Inspired) | Design Philosophy | Colour Palette
  21_UI_Redesign_Postmortem.md: What Was Built | Bugs Encountered & Resolutions | Architecture Decisions
  22_Session_Handoff.md: 22 — LLM Session Starter | Current State — v1.4 (as of 2026-04-18) | Context Loading Options
  23_Phase4_Postmortem.md: What Was Built | Bugs Encountered & Resolutions | Architecture Decisions
  24_Hybrid_Architecture_Postmortem.md: 24 — Hybrid Architecture Postmortem | What Was Built | Bugs Encountered & Resolutions
  25_Architecture_Diagram.md: Architecture Diagram — Hybrid Cloud System | What the diagram shows | Arrow key
  26_Audio_Testing_Postmortem.md: 26 — Audio Testing Postmortem | What Was Built / Tested | Audio Test Results
  27_Presidio_Extension_Postmortem.md: 27 — Presidio Extension Postmortem | What Was Built | New Recognizers Added
  28_WhisperX_Debug_System.md: WhisperX Self-Improving Debug System — Architecture Spec | 1. Project Summary | 2. Core Architecture
  29_Session_Handoff_2026-04-29.md: Session Handoff — 2026-04-29 | System State: v1.4 — DEMO READY | What Was Done This Session
  30_SaaS_Pivot_Plan.md: 30 — B2B SaaS Pivot Plan | Pivot Declaration | Features Roadmap (in implementation order)
  31_Session_Handoff_2026-04-30.md: 31 — Session Handoff — 2026-04-30 | What Happened This Session | Current System State
  32_Windows_Reinstall_Backup_Guide.md: 32 — Windows Reinstall Backup Guide | What Is Safe (N drive — do nothing) | What Will Be Lost (C dri
  33_SaaS_Implementation_Plan.md: 33 — SaaS Implementation Plan (Confirmed Scope) | Confirmed Scope (3 Phases) | Phase 5 — Multi-Tenan
  34_Final_Implementation_Plan.md: 34 — Final Implementation Plan (Research-Complete) | How We Work | Phase 5 — Multi-Tenancy
  35_Session_Handoff_2026-05-01.md: 35 — Session Handoff 2026-05-01 | What Was Done This Session | Exact State Right Now
  36_Session_Handoff_2026-05-02.md: 36 — Session Handoff 2026-05-02 | What Was Done This Session | Exact State Right Now
  37_Phase7_Postmortem.md: 37 — Phase 7 Postmortem: Agent Identity Extraction | What Was Built | Bugs Caught in Review (pre-run
  38_Session_Handoff_2026-05-02.md: 38 — Session Handoff 2026-05-02 (Phase 7 Backend Complete) | Current State — v1.7 | How to Start the
  39_Frontend_Session_Prompt.md: 39 — Phase 7 Frontend Session Prompt | Skills to Activate (type `/` in Claude Desktop) | Context Blo
  CODEBASE_MAP.md: CODEBASE MAP | Pipeline Flow | Backend God Nodes
  CONTEXT.md: PROJECT CONTEXT — AI Call Quality & Agent Performance Analytics System | 1. Who is Building This | 2
  GRAPH_REPORT.md: GRAPH REPORT — AI Call Quality Analytics System | GOD NODES (highest connectivity) | PIPELINE (seque
  GRAPH_REPORT_LINK.md: GRAPH_REPORT — see N:\projects\docs\GRAPH_REPORT.md | tags: [graph, knowledge-graph, token-efficienc
  INVARIANTS.md: INVARIANTS — AI Call Quality Analytics System | Stack (frozen — no deviations) | Column Names (exact
  LOG.md: LOG — Daily Session Notes | 2026-05-02 — Phase 7 backend complete. Migration 006 applied locally (ag
  PROJECT_ROADMAP_1.md: AI Call Quality & Agent Performance Analytics System | Project Master Roadmap & Architectural Specif
  PROMPTING_GUIDE.md: PROMPTING_GUIDE — AI Call Quality Analytics System | 1. Model Routing Matrix | 2. The Rules Block (p
  ROADMAP.md: ROADMAP — AI Call Quality & Agent Performance Analytics System | Completed Phases | Planned Phases (
  STARTUP_HYBRID.md: STARTUP — Hybrid Mode (Azure B2s + Local RTX 3060 Ti) | Prerequisites | Critical Warning
  STARTUP_LOCAL.md: STARTUP — Local Mode (All Services on Local Machine) | Prerequisites | Critical Warning
  demo-readiness.md: Demo Readiness — 2026-04-19 | System Status | Pre-Demo Checklist (run in order)
  ui-audit-latest.md: UI Audit — Latest (2026-04-19) | A) Claims Extracted | B) Verification Table
  ui-polish-overview-agents-callhistory.md: UI Polish Changelog — Overview, Agents, Call History, Call Detail | CallList.tsx | CallDetailPanel.t

---

## INVARIANTS (never violate)

1. Audio → MinIO only (minio_audio_path), never PostgreSQL
2. Raw transcript → never DB, Presidio-redacted only
3. pii_redacted=TRUE before run_groq_inference
4. run_whisperx → gpu_queue ONLY, concurrency=1
5. JWT → Zustand sessionStorage, never localStorage
6. Groq model: llama-3.3-70b-versatile (never 3.1)
7. MinIO hostname: cq-minio:9000 (hyphens — underscores break botocore)
8. DATABASE_URL: postgresql+asyncpg:// for API, postgresql:// for workers
9. Score: stored 0-10, displayed ×10 as % in UI
10. Zero code comments — ever

---

## SUGGESTED QUESTIONS FOR THIS GRAPH

1. Why does worker_gpu use host.docker.internal instead of cq_redis?
2. What happens if pii_redacted is False when run_groq_inference fires?
3. How does talk_balance_score reach write_scores given run_groq_inference uses .si()?
4. Why is numpy<2 the last pip install step in Dockerfile.gpu?
5. What prevents the SSH tunnel port conflict with local cq_redis?
