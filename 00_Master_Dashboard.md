---
tags: [moc, dashboard, fyp]
status: active
created: 2026-04-11
updated: 2026-04-17
---

# 00 — Master Dashboard

> Single entry point for the entire knowledge vault.
> Read this first at the start of any working session.
> For LLM sessions: paste [[CONTEXT]] for full project context.

---

## Project Identity

| Property | Value |
|---|---|
| System | AI Call Quality & Agent Performance Analytics System |
| Type | Final Year Project (FYP) — Bahria University Islamabad |
| Student | Adeen — BSCS 6th semester |
| Repo | https://github.com/Malik-Adeen/call-quality-analytics |
| Local path | N:\projects\call-quality-analytics |
| Vault | N:\projects\docs |
| Azure B2s | 20.228.184.111 East US |
| Initial demo | Week of April 21, 2026 |

---

## Build State — v1.4

| Phase | Description | Status | Postmortem |
|---|---|---|---|
| 1 | Foundation — Auth, Upload, Docker, Celery | ✅ | [[07_Phase1_Postmortem]] |
| 2.1 | WhisperX GPU + Pyannote diarization | ✅ | [[08_Phase2.1_Postmortem]] |
| 2.2 | Presidio PII redaction gate | ✅ | [[09_Phase2.2_Postmortem]] |
| 2.3 | Groq LLM inference | ✅ | [[11_Phase2.3_Postmortem]] |
| 2.4 | Scoring + chain + WebSocket | ✅ | [[12_Phase2.4_Postmortem]] |
| 2 E2E | Full pipeline end-to-end verified | ✅ | [[13_Phase2_E2E_Postmortem]] |
| Audit | Security fixes | ✅ | [[14_Audit_Fixes]] |
| 3A | Backend read endpoints | ✅ | [[16_Phase3A_Read_Endpoints]] |
| 3 | React dashboard — 6 pages | ✅ | [[17_Phase3_Frontend]] |
| UI | Light parchment redesign | ✅ | [[21_UI_Redesign_Postmortem]] |
| 4 | PDF + Azure B2s + Hybrid SSH tunnel | ✅ | [[23_Phase4_Postmortem]] |
| Hybrid | SSH tunnel + WAN Celery tuning | ✅ | [[24_Hybrid_Architecture_Postmortem]] |
| Audio | 5 real call recordings verified | ✅ | [[26_Audio_Testing_Postmortem]] |
| PII+ | Extended Presidio recognizers | ✅ | [[27_Presidio_Extension_Postmortem]] |
| **Dry-run** | Solo demo rehearsal | 🔲 | — |
| **Phase 5** | Urdu/English ASR fine-tuning | 🔲 | [[ROADMAP]] |

---

## Startup Runbooks

| Mode | When to use | Runbook |
|---|---|---|
| **Hybrid** | Azure B2s running, local GPU for inference | [[STARTUP_HYBRID]] |
| **Local** | Offline / all services on local machine | [[STARTUP_LOCAL]] |

---

## Pre-Demo Checklist

- [ ] Full demo dry-run — see [[STARTUP_HYBRID]]
- [ ] `git pull` + `docker restart cq_worker_io` on Azure VM
- [ ] `reset_and_seed.py` on Azure VM
- [ ] Verify `http://20.228.184.111:8000/health` responds
- [ ] Re-upload bpo_inbound_1, confirm `<ZIP_CODE>` + `<SSN>` in transcript

---

## FYP Future Phases

See [[ROADMAP]] · Phase 5 research: [[06_Urdu_ASR_Research]]

---

## Architecture Summary

```
Browser → Vite proxy → Azure B2s (FastAPI + PG + Redis + MinIO + worker_io)
                            ↕ Celery gpu_queue via SSH tunnel
                       Local RTX 3060 Ti (worker_gpu · WhisperX large-v2)
```

Full spec: [[01_Master_Architecture]] · Azure runbooks: [[11_Azure_Deployment]] · GPU: [[10_GPU_Infrastructure]]

---

## Critical Invariants

1. Audio → MinIO only (`minio_audio_path`), never PostgreSQL
2. Raw transcript → never DB, Presidio-redacted only
3. `pii_redacted = TRUE` before any downstream task
4. `run_whisperx` → `gpu_queue`, concurrency=1
5. JWT → sessionStorage, never localStorage
6. Groq model: `llama-3.3-70b-versatile`
7. MinIO endpoint: `cq-minio:9000` (hyphens, not underscores)
8. Score: stored 0–10, displayed as % (×10)
9. Zero code comments

Full rules: [[INVARIANTS]]

---

## LLM Workflow

See [[PROMPTING_GUIDE]] for model routing, prompt templates, and token efficiency.
See [[INVARIANTS]] for the 500-token rules block to paste into Qwen/Gemini.

---

## Vault Index

| File | Purpose |
|---|---|
| [[CONTEXT]] | Universal LLM context — paste into any chat |
| [[INVARIANTS]] | 500-token rules block for Qwen/Gemini sessions |
| [[PROMPTING_GUIDE]] | Model routing, templates, token efficiency |
| [[ROADMAP]] | FYP phases beyond the demo |
| [[STARTUP_HYBRID]] | Azure B2s + local GPU startup runbook |
| [[STARTUP_LOCAL]] | All-local Docker startup runbook |
| [[LOG]] | Daily one-line session notes |
| [[01_Master_Architecture]] | Stack manifest, pipeline, scoring formula |
| [[02_Database_Schema]] | PostgreSQL schema |
| [[03_API_Contract]] | All endpoint shapes + TypeScript interfaces |
| [[10_GPU_Infrastructure]] | CUDA, Docker, cache paths |
| [[11_Azure_Deployment]] | B2s + SSH tunnel runbook |
| [[20_New_Design_System]] | Light parchment design tokens |
| [[19_Future_Transcript_Audio_Sync]] | Deferred audio sync feature |

---

## Post-Mortems

[[07_Phase1_Postmortem]] → [[08_Phase2.1_Postmortem]] → [[09_Phase2.2_Postmortem]] → [[11_Phase2.3_Postmortem]] → [[12_Phase2.4_Postmortem]] → [[13_Phase2_E2E_Postmortem]] → [[14_Audit_Fixes]] → [[16_Phase3A_Read_Endpoints]] → [[17_Phase3_Frontend]] → [[21_UI_Redesign_Postmortem]] → [[23_Phase4_Postmortem]] → [[24_Hybrid_Architecture_Postmortem]] → [[26_Audio_Testing_Postmortem]] → [[27_Presidio_Extension_Postmortem]]
