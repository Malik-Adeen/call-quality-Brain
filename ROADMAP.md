---
tags: [planning, fyp, roadmap]
date: 2026-04-17
status: active
---

# ROADMAP — AI Call Quality & Agent Performance Analytics System

> FYP extended roadmap. See [[00_Master_Dashboard]] for current build state.
> See [[CONTEXT]] for full project architecture.

---

## Completed Phases

### Phase 1 — Foundation
[[07_Phase1_Postmortem]]
7-service Docker stack. JWT auth. MinIO audio upload. Celery queue isolation.

### Phase 2 — AI Pipeline
[[08_Phase2.1_Postmortem]] · [[09_Phase2.2_Postmortem]] · [[11_Phase2.3_Postmortem]] · [[12_Phase2.4_Postmortem]] · [[13_Phase2_E2E_Postmortem]]
WhisperX + Pyannote diarization. Presidio PII gate. Groq inference. Atomic scoring. WebSocket.

### Phase 3 — React Dashboard
[[16_Phase3A_Read_Endpoints]] · [[17_Phase3_Frontend]] · [[21_UI_Redesign_Postmortem]]
6 pages. Light parchment design system. Recharts. Slide-in panels.

### Phase 4 — Production Hardening
[[23_Phase4_Postmortem]] · [[24_Hybrid_Architecture_Postmortem]] · [[26_Audio_Testing_Postmortem]] · [[27_Presidio_Extension_Postmortem]]
Playwright PDF. Azure B2s. SSH tunnel hybrid architecture. Extended Presidio PII.

---

## Planned Phases

### Phase 5 — Urdu/English Code-Switched ASR
**Research:** [[06_Urdu_ASR_Research]]
**Goal:** Reduce WER on Pakistani call center audio from ~35% to <10%.

Core approach: QLoRA fine-tuning of WhisperX on narrowband 8kHz Urdu-English data.
VRAM feasibility: RTX 3060 Ti (8GB) with 4-bit quantization — confirmed feasible.

Tasks:
- Collect 15-20 hours labeled Urdu/English telephonic audio
- QLoRA fine-tune WhisperX base (4-bit, LoRA rank 16)
- Benchmark WER before/after on held-out test set
- Replace model loading in `whisper_service.py` with fine-tuned checkpoint

### Phase 6 — Real-Time Streaming Transcription
**Goal:** Transcribe calls live as they happen, not post-call.

Tasks:
- WebSocket audio chunk receiver on FastAPI
- WhisperX streaming mode (2-second chunk inference)
- Live transcript in UI word-by-word
- Speaker diarization on streaming chunks

### Phase 7 — Advanced Analytics
**Goal:** Supervisors get automated weekly coaching reports and trend analysis.

Tasks:
- 30/60/90 day agent performance trend charts
- Team comparison analytics
- Automated weekly PDF emails to supervisors
- Issue category clustering
- Coaching effectiveness tracking

### Phase 8 — Multi-Tenancy
**Goal:** Multiple call centers as isolated tenants.

Tasks:
- Row-level DB security or schema-per-tenant
- Tenant admin panel
- Per-tenant LLM prompt customization
- Per-tenant scoring weight configuration

### Phase 9 — Mobile Supervisor App
**Goal:** Call review and alerts on mobile.

Tasks:
- React Native (code-share with existing TypeScript types from [[03_API_Contract]])
- Push notifications for low-scoring calls
- Mobile call detail view

---

## Research Directions

### Urdu ASR Improvement
Primary reference: [[06_Urdu_ASR_Research]]
- QLoRA fine-tuning on CHiPSAL dataset
- 8kHz telephony bandwidth gap bridging
- Code-switching dual-lexicon language model

### PII Detection Improvements
Current gaps from [[27_Presidio_Extension_Postmortem]]:
- Pakistani CNIC numbers (XXXXX-XXXXXXX-X)
- Pakistani mobile numbers (+92 3XX XXXXXXX)
- 4-digit PINs without context
- Account numbers without "account" keyword

### Scoring Model Improvement
Current: entirely Groq LLM output.
Future: lightweight classifier trained on labeled call data to validate/override LLM scores.

---

## Academic Deliverables

| Deliverable | Description | Due |
|---|---|---|
| Initial Demo | University final presentation | Week of April 21, 2026 |
| FYP Report | Full technical report | TBD |
| Research Paper | Urdu ASR fine-tuning results (Phase 5) | TBD |
