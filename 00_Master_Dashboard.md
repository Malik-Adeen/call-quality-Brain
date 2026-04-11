---
tags: [moc, dashboard]
status: active
created: 2026-04-11
---

# 00 — Master Dashboard

> **Second Brain MOC.** This is the single entry point for the entire vault.
> Navigate from here to any document. Check this file first when starting a new session.

---

## Project Identity

| Property | Value |
|---|---|
| **System** | AI Call Quality & Agent Performance Analytics System |
| **Purpose** | University final-year demo — GPU-accelerated transcription + LLM scoring pipeline |
| **Stack** | FastAPI · Celery · Redis · MinIO · PostgreSQL · WhisperX · Groq |
| **Deployment** | Local Docker → Azure GPU (demo day only) |

---

## Phase Status

| Phase | Description | Status |
|---|---|---|
| Phase 1 | Foundation — Auth, Upload, Docker, Celery | ✅ Complete |
| Phase 2.1 | GPU Worker — WhisperX + Pyannote ASR | ✅ Complete |
| Phase 2.2 | IO Worker — Presidio PII Redaction | ✅ Complete |
| Phase 2.3 | IO Worker — Groq LLM Inference | ✅ Complete |
| Phase 2.4 | IO Worker — Scoring, Chain Wiring, WebSocket | ✅ Complete |
| Phase 3 | Frontend — React Dashboard | 📋 Planned |
| Phase 4 | Fine-tuning — QLoRA Urdu ASR | 📋 Planned |

---

## Architecture & Design

- [[01_Master_Architecture]] — Master stack manifest & system identity (LLM anchor doc)
- [[03_API_Contract]] — FastAPI & WebSocket endpoint contracts (LLM anchor doc)
- `02_Database_Schema.sql` — PostgreSQL 16 schema definitions *(SQL file — open directly)*

---

## Planning

- [[PROJECT_ROADMAP_1]] — Master roadmap with full phase breakdown & Mermaid architecture diagram
- [[04_Demo_Execution_Plan]] — Step-by-step daily execution guide for demo day

---

## Research

- [[06_Urdu_ASR_Research]] — Urdu ASR limitations, QLoRA fine-tuning methodology, 8GB VRAM constraints

---

## Infrastructure

- [[10_GPU_Infrastructure]] — Host setup: RTX 3060 Ti · 8GB VRAM · CUDA 12.1 · WSL2 · Docker Desktop

---

## Post-Mortems

- [[07_Phase1_Postmortem]] — Phase 1: Auth, upload pipeline, 7-service Docker stack
- [[08_Phase2.1_Postmortem]] — Phase 2.1: WhisperX GPU worker, Pyannote diarization
- [[09_Phase2.2_Postmortem]] — Phase 2.2: Presidio PII redaction, Celery chain
- [[11_Phase2.3_Postmortem]] — Phase 2.3: Groq LLM inference, llama-3.3-70b-versatile, 31/31 tests
- [[12_Phase2.4_Postmortem]] — Phase 2.4: Scoring formula, full chain wiring, WebSocket notify
- [[13_Phase2_E2E_Postmortem]] — Phase 2 E2E: Full pipeline verified, score=8.72, status=complete

---

## Active Sprints

- Phase 3: React Dashboard — 5 modules against live API
