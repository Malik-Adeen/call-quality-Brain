---
tags: [moc, dashboard]
status: active
created: 2026-04-11
updated: 2026-04-30
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
| Type | B2B SaaS product (pivoted from FYP — April 30, 2026) |
| Builder | Adeen — BSCS, Bahria University Islamabad |
| Repo | https://github.com/Malik-Adeen/call-quality-analytics |
| Local path | N:\projects\call-quality-analytics |
| Vault | N:\projects\docs |
| Cloud | None — Azure resources deleted (credits exhausted). Building cloud-agnostic locally. |
| FYP demo | Completed — week of April 21, 2026 |

---

## Build State — v1.4 (Demo Complete, Pre-SaaS)

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
| 4 | PDF + Azure B2s + Hybrid SSH tunnel | ✅ (Azure deleted) | [[23_Phase4_Postmortem]] |
| Hybrid | SSH tunnel + WAN Celery tuning | ✅ (Azure deleted) | [[24_Hybrid_Architecture_Postmortem]] |
| Audio | 5 real call recordings verified | ✅ | [[26_Audio_Testing_Postmortem]] |
| PII+ | Extended Presidio recognizers | ✅ | [[27_Presidio_Extension_Postmortem]] |
| **Phase 5** | **Multi-Tenancy (RLS + tenant table)** | 🔲 | [[30_SaaS_Pivot_Plan]] |
| **Phase 6** | **Agent Integration (roster sync)** | 🔲 | [[30_SaaS_Pivot_Plan]] |
| **Phase 7** | **Agent Identity Extraction from Audio** | 🔲 | [[30_SaaS_Pivot_Plan]] |
| **Phase 8** | **CRM Integration (Zendesk first)** | 🔲 | [[30_SaaS_Pivot_Plan]] |
| **Phase 9** | **High / Low Priority Customers** | 🔲 | [[30_SaaS_Pivot_Plan]] |

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

## Startup Runbook

All services run locally. Hybrid/Azure runbooks are historical — Azure VM deleted.

```
docker compose -f infra/docker-compose.yml up -d
```

GPU worker runs in the same compose stack locally (no SSH tunnel needed).

---

## Architecture (current — all local)

```
Browser → Vite dev server → FastAPI (local Docker)
                                ↕ Celery queues (local Redis)
                           Local RTX 3060 Ti (worker_gpu · WhisperX large-v2)
                           Local PostgreSQL + MinIO (Docker)
```

Full spec: [[01_Master_Architecture]] · GPU: [[10_GPU_Infrastructure]]
Azure / SSH tunnel docs are historical reference: [[11_Azure_Deployment]] · [[STARTUP_HYBRID]]

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
10. Multi-tenant (Phase 5+): `SET LOCAL app.current_tenant` per transaction, never `SET SESSION`

---

## Vault Index

| File | Purpose |
|---|---|
| [[GRAPH_REPORT]] | Auto-generated knowledge graph |
| [[CONTEXT]] | Universal LLM context — paste into any chat |
| [[INVARIANTS]] | 500-token rules block for Qwen/Gemini |
| [[PROMPTING_GUIDE]] | Model routing, templates, token efficiency |
| [[ROADMAP]] | B2B SaaS phase planning |
| [[30_SaaS_Pivot_Plan]] | **Pivot declaration, feature specs, research synthesis** |
| [[STARTUP_LOCAL]] | All-local Docker startup runbook (current mode) |
| [[STARTUP_HYBRID]] | Historical — Azure + local GPU (Azure deleted) |
| [[LOG]] | Daily one-line session notes |
| [[01_Master_Architecture]] | Stack manifest, pipeline, scoring formula |
| [[02_Database_Schema]] | PostgreSQL schema |
| [[03_API_Contract]] | All endpoint shapes + TypeScript interfaces |
| [[10_GPU_Infrastructure]] | CUDA, Docker, cache paths |
| [[11_Azure_Deployment]] | Historical — Azure runbook (Azure deleted) |
| [[20_New_Design_System]] | Light parchment design tokens |
| [[19_Future_Transcript_Audio_Sync]] | Deferred audio sync feature |
| [[06_Urdu_ASR_Research]] | Urdu ASR — historical reference only (dropped scope) |

---

## Post-Mortems

[[07_Phase1_Postmortem]] → [[08_Phase2.1_Postmortem]] → [[09_Phase2.2_Postmortem]] → [[11_Phase2.3_Postmortem]] → [[12_Phase2.4_Postmortem]] → [[13_Phase2_E2E_Postmortem]] → [[14_Audit_Fixes]] → [[16_Phase3A_Read_Endpoints]] → [[17_Phase3_Frontend]] → [[21_UI_Redesign_Postmortem]] → [[23_Phase4_Postmortem]] → [[24_Hybrid_Architecture_Postmortem]] → [[26_Audio_Testing_Postmortem]] → [[27_Presidio_Extension_Postmortem]]
