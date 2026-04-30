---
tags: [planning, saas, roadmap]
date: 2026-04-30
status: active
---

# ROADMAP — AI Call Quality & Agent Performance Analytics System

> B2B SaaS product roadmap. Project has transitioned from FYP demo to commercial product.
> See [[00_Master_Dashboard]] for current build state.
> See [[30_SaaS_Pivot_Plan]] for full pivot analysis, research findings, and implementation details.

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

## Planned Phases (B2B SaaS)

> Full analysis for all phases in [[30_SaaS_Pivot_Plan]].

### Phase 5 — Multi-Tenancy
**Goal:** Convert single-tenant system to isolated multi-tenant SaaS.

Architecture decision: Shared tables + PostgreSQL Row-Level Security (not schema-per-tenant — catalog bloat at scale kills Alembic migration speed).

Tasks:
- New `tenants` table with `settings JSONB` for per-tenant config
- Add `tenant_id UUID NOT NULL` to all tenant-scoped tables
- PostgreSQL RLS policies with `FORCE ROW LEVEL SECURITY`
- JWT gets `tenant_id` claim at login — all requests auto-scoped
- `SET LOCAL app.current_tenant` per transaction (not SET SESSION)
- `contextvars.ContextVar` in FastAPI for async-safe propagation
- MinIO paths: `{tenant_id}/{call_id}.mp3` (currently flat)
- `PLATFORM_ADMIN` role above `TENANT_ADMIN`
- Tenant signup / onboarding flow

### Phase 6 — Agent Integration
**Goal:** Live agent roster sync from HR/workforce systems instead of manual seed data.

Tasks:
- Add `external_id TEXT`, `is_active BOOLEAN`, `email TEXT` to `agents` table
- `POST /agents/sync` — bulk upsert by `external_id` within tenant (idempotent)
- Soft-delete support for departed agents

### Phase 7 — Agent Identity Extraction from Audio
**Goal:** Automatically resolve `agent_id` from transcript — eliminate manual dropdown on upload.

Decision: Groq API transcript parsing (zero VRAM, already in pipeline). No local LLM (OOM risk). No voice biometrics (GDPR Article 9).

Tasks:
- Add name extraction pass in `run_groq_inference`: prompt Groq to extract agent self-introduction
- Fuzzy-match extracted name against `agents` table for the tenant
- Add `needs_agent_review BOOLEAN`, `agent_name_extracted TEXT` to `calls` table
- Make `agent_id` nullable on upload — auto-resolve post-transcription
- Dashboard "Needs Review" flag for unresolved calls

### Phase 8 — CRM Integration
**Goal:** Pull customer data at upload; push quality scores back to CRM after scoring.

Priority: Zendesk first (28% call center market share), Salesforce second, HubSpot third.

Tasks:
- Abstract `CRMAdapter` base class + `ZendeskAdapter` implementation
- New `tenant_integrations` table (OAuth tokens, encrypted)
- New `customers` table (CRM-synced customer data cached locally)
- Add `customer_id`, `customer_tier` to `calls` table
- `sync_crm_customer` Celery task — runs at upload time
- `push_score_to_crm` Celery task — runs after `write_scores`
- `POST /webhooks/crm/{crm_type}` — HMAC-validated webhook receiver

### Phase 9 — High / Low Priority Customers
**Goal:** Surface high-value customer calls prominently; alert supervisors on risk calls.

Formula (adapted from NICE CXone Dynamic Delivery):
```
Base Priority = (0.35 × tier_score) + (0.40 × severity_score) + (0.15 × fcr_failure_score) + (0.10 × frequency_score)
Dynamic Priority = Base Priority + (wait_seconds × tier_acceleration_rate)
```

Tasks:
- Add `customer_priority TEXT`, `base_priority_score NUMERIC` to `calls` table
- PostgreSQL trigger computes base priority on INSERT
- Overview dashboard re-sorts "Requires Attention" panel by priority × agent score
- Call list priority badge column

---

## Dropped Scope

### ~~Phase 5 — Urdu/English Code-Switched ASR~~
**Dropped.** No code was written. Research archived at [[06_Urdu_ASR_Research]].
Project has pivoted to B2B SaaS. ASR quality improvements are a future premium feature once tenant call data is available for fine-tuning.

---

## Deferred Phases

### Real-Time Streaming Transcription
WebSocket audio chunk receiver. WhisperX streaming mode (2-second chunk inference). Live transcript word-by-word. Post Phase 9.

### Advanced Analytics
30/60/90 day trend charts. Team comparison. Automated weekly PDF coaching reports. Issue category clustering. Post Phase 9.

### Mobile Supervisor App
React Native. Push notifications for low-scoring calls. Mobile call detail view. Post Phase 9.

---

## Pricing Reference

| Tier | Agents | Per-agent/month |
|---|---|---|
| SMB | 20–100 | $15–$80 |
| Mid-market | 100–500 | $80–$300+ |

Table stakes (all tiers): auto-scoring, ASR, sentiment, QA dashboards — current build covers these.
Premium (gated): CRM integration, custom scoring weights, customer priority, generative coaching.
