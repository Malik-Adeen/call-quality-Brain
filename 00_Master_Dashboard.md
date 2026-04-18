---
tags: [moc, dashboard, fyp]
status: active
created: 2026-04-11
updated: 2026-04-18
---

# 00 — Master Dashboard

> Single entry point for the entire knowledge vault.
> Read this first at the start of any working session.
> For LLM sessions: Claude reads [[GRAPH_REPORT]] via filesystem (fastest) or paste [[INVARIANTS]] (500 tokens).

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

## LLM Context Loading (fastest to slowest)

| Method | Tokens | How |
|---|---|---|
| `GRAPH_REPORT.md` via filesystem | ~1,100 | Claude reads directly — no paste needed |
| `INVARIANTS.md` paste | ~500 | For Qwen/Gemini sessions |
| `CONTEXT.md` paste | ~2,500 | Full architecture for complex decisions |
| Full vault paste | ~30,000 | Gemini 1.5 Pro only (free, 1M context) |

Update graph after code changes: `python scripts/build_graph.py`

---

## Startup Runbooks

| Mode | When | Runbook |
|---|---|---|
| Hybrid | Azure B2s running, local GPU | [[STARTUP_HYBRID]] |
| Local | Offline, all services local | [[STARTUP_LOCAL]] |

---

## Pre-Demo Checklist

- [ ] Full demo dry-run — see [[STARTUP_HYBRID]]
- [ ] `git pull` + `docker restart cq_worker_io` on Azure VM
- [ ] `reset_and_seed.py` on Azure VM
- [ ] Verify `http://20.228.184.111:8000/health` responds
- [ ] `python scripts/build_graph.py` — refresh GRAPH_REPORT.md

---

## FYP Future Phases

See [[ROADMAP]] · Phase 5 research: [[06_Urdu_ASR_Research]]

---

## Architecture

```
Browser → Vite proxy → Azure B2s (FastAPI + PG + Redis + MinIO + worker_io)
                            ↕ Celery gpu_queue via SSH tunnel
                       Local RTX 3060 Ti (worker_gpu · WhisperX large-v2)
```

Full spec: [[01_Master_Architecture]] · Azure: [[11_Azure_Deployment]] · GPU: [[10_GPU_Infrastructure]]

---

## Critical Invariants (full list: [[INVARIANTS]])

1. Audio → `minio_audio_path`, never PostgreSQL
2. Raw transcript → never DB, Presidio-redacted only
3. `pii_redacted=TRUE` before `run_groq_inference`
4. `run_whisperx` → `gpu_queue`, concurrency=1
5. JWT → sessionStorage, never localStorage
6. Groq: `llama-3.3-70b-versatile`
7. MinIO: `cq-minio:9000` (hyphens)
8. Score: stored 0–10, displayed ×10 as %
9. Zero code comments

---

## Vault Index

| File | Purpose |
|---|---|
| [[GRAPH_REPORT]] | Auto-generated knowledge graph — Claude reads this via filesystem |
| [[CONTEXT]] | Universal LLM context — paste into any chat |
| [[INVARIANTS]] | 500-token rules block for Qwen/Gemini |
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
| [[06_Urdu_ASR_Research]] | Phase 5 Urdu ASR research |

---

## Post-Mortems

[[07_Phase1_Postmortem]] → [[08_Phase2.1_Postmortem]] → [[09_Phase2.2_Postmortem]] → [[11_Phase2.3_Postmortem]] → [[12_Phase2.4_Postmortem]] → [[13_Phase2_E2E_Postmortem]] → [[14_Audit_Fixes]] → [[16_Phase3A_Read_Endpoints]] → [[17_Phase3_Frontend]] → [[21_UI_Redesign_Postmortem]] → [[23_Phase4_Postmortem]] → [[24_Hybrid_Architecture_Postmortem]] → [[26_Audio_Testing_Postmortem]] → [[27_Presidio_Extension_Postmortem]]
