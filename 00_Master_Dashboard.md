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

## Immediate Pre-Demo Checklist

- [ ] Full demo dry-run
- [ ] `git pull` + `docker restart cq_worker_io` on Azure VM
- [ ] `reset_and_seed.py` on Azure VM
- [ ] Verify `http://20.228.184.111:8000/health` responds
- [ ] Re-upload bpo_inbound_1, confirm `<ZIP_CODE>` + `<SSN>` in transcript

---

## Demo Start Sequence

```
1. nvidia-smi → memory.free > 5000 MiB
2. scripts/tunnel.bat → SSH connects silently
3. docker compose -f infra/docker-compose.hybrid.yml up -d worker_gpu
4. docker logs cq_worker_gpu --tail 5 → "sync with worker_io"
5. cd frontend && npm run dev
6. http://localhost:5173 → admin@callquality.demo / admin1234
7. Upload tech_support.mp3 → Reports page → wait for toast
```

**Never run local cq_redis + tunnel.bat simultaneously. Port 6379 conflict.**

---

## Real Audio Test Results

| File | Score | Duration | Demo use |
|---|---|---|---|
| tech_support.mp3 | 88.2% | 3m 24s | Primary demo file |
| billing_dispute.mp3 | 88.3% | 1m 27s | Backup |
| irate_customer.mp3 | 71.0% | 12m 17s | Needs trim |
| bpo_inbound_1.mp3 | 75.1% | 2m 18s | Labels swapped |

Full analysis: [[26_Audio_Testing_Postmortem]]

---

## FYP Future Phases

See [[ROADMAP]] for full detail and [[06_Urdu_ASR_Research]] for Phase 5 research.

| Phase | Description |
|---|---|
| 5 | Urdu/English code-switched ASR via QLoRA — [[06_Urdu_ASR_Research]] |
| 6 | Real-time streaming transcription |
| 7 | Advanced analytics + automated coaching reports |
| 8 | Multi-tenancy |
| 9 | Mobile supervisor app |

---

## Architecture Summary

```
Browser → Vite proxy → Azure B2s (FastAPI + PG + Redis + MinIO + worker_io)
                            ↕ Celery gpu_queue via SSH tunnel
                       Local RTX 3060 Ti (worker_gpu · WhisperX large-v2)
```

See [[01_Master_Architecture]] for full spec · [[11_Azure_Deployment]] for runbooks · [[10_GPU_Infrastructure]] for GPU details.

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

---

## Vault Index

| File | Purpose |
|---|---|
| [[CONTEXT]] | Universal LLM context — paste into any chat |
| [[ROADMAP]] | FYP phases beyond the demo |
| [[01_Master_Architecture]] | Stack manifest, pipeline, scoring formula |
| [[02_Database_Schema]] | PostgreSQL schema |
| [[03_API_Contract]] | All endpoint shapes + TypeScript interfaces |
| [[04_Demo_Execution_Plan]] | Original demo checklist |
| [[06_Urdu_ASR_Research]] | Research for Phase 5 Urdu ASR |
| [[10_GPU_Infrastructure]] | CUDA, Docker, cache paths |
| [[11_Azure_Deployment]] | B2s runbook, SSH tunnel, budget |
| [[15_Design_System]] | Original design tokens |
| [[20_New_Design_System]] | Light parchment design system |
| [[19_Future_Transcript_Audio_Sync]] | Deferred audio sync feature |
| [[22_Session_Handoff]] | Operational state for new sessions |
| [[25_Architecture_Diagram]] | System diagram reference |

---

## Post-Mortems

[[07_Phase1_Postmortem]] → [[08_Phase2.1_Postmortem]] → [[09_Phase2.2_Postmortem]] → [[11_Phase2.3_Postmortem]] → [[12_Phase2.4_Postmortem]] → [[13_Phase2_E2E_Postmortem]] → [[14_Audit_Fixes]] → [[16_Phase3A_Read_Endpoints]] → [[17_Phase3_Frontend]] → [[21_UI_Redesign_Postmortem]] → [[23_Phase4_Postmortem]] → [[24_Hybrid_Architecture_Postmortem]] → [[26_Audio_Testing_Postmortem]] → [[27_Presidio_Extension_Postmortem]]
