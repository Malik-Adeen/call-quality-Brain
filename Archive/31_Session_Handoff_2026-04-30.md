---
tags: [session-handoff, pivot, saas]
date: 2026-04-30
status: active
---

# 31 — Session Handoff — 2026-04-30

> Continuation of session from [[29_Session_Handoff_2026-04-29]].
> This session: B2B SaaS pivot analysis + second brain updates.

---

## What Happened This Session

### Pivot Declared
Project has officially transitioned from FYP demo phase to B2B SaaS product.
- FYP demo: completed week of April 21, 2026
- Urdu ASR (was Phase 5): **dropped entirely**. No code was ever written for it. Clean drop.
- New direction: multi-tenant call center analytics SaaS

### Feature Scope Defined
Five features identified for the B2B product (in implementation order):

1. **Multi-tenancy** — PostgreSQL RLS, `tenants` table, `tenant_id` on all tables, JWT tenant claim, MinIO path prefix isolation
2. **Agent integration** — roster sync API, `external_id` field, soft-delete for departed agents
3. **Agent identity extraction from audio** — Groq transcript parsing to resolve agent name automatically from self-introduction ("Hi, this is Sarah from support"), eliminates manual agent dropdown on upload
4. **CRM integration** — Zendesk first, adapter pattern, customer data enrichment at upload, score push-back after processing
5. **High / low priority customers** — priority scoring formula (CRM tier + severity + FCR history + call frequency), PostgreSQL trigger, dashboard surfacing

### Research Conducted
External research stored in `N:\projects\Transition\`. Six sources were read and synthesized:
- GLM 5.1 + Kimi: agent identity extraction — both confirm Groq API is the right approach (no local LLM — VRAM OOM risk; no voice biometrics — GDPR Article 9)
- Gemini Research (×2): multi-tenancy deep dive (RLS wins over schema-per-tenant at scale) + customer priority scoring (NICE CXone Dynamic Delivery formula)
- Perplexity (×2): CRM integration architecture (Strategy pattern, Zendesk-first) + B2B SaaS pricing ($15–$80/agent/month for SMB)

### Second Brain Updates Made

| File | Change |
|---|---|
| `30_SaaS_Pivot_Plan.md` | **Created** — pivot declaration, all 5 feature specs, research archive, pricing reference |
| `ROADMAP.md` | **Rewritten** — Urdu ASR dropped, 5 new SaaS phases added with full task lists |
| `00_Master_Dashboard.md` | **Updated** — project type changed to B2B SaaS, new phases in build state table, vault index updated |
| `INVARIANTS.md` | **Updated** — multi-tenancy invariants added, scoring weights note updated (per-tenant override allowed), Urdu ASR references removed |
| `CONTEXT.md` | **Updated** — section 1 reflects pivot, roadmap section reflects new phases, schema section includes Phase 5–8 future tables |

---

## Current System State

- Azure B2s `20.228.184.111` — still running, all services up
- Codebase: single-tenant, v1.4, 200 seeded calls
- No code has been written yet for any of the 5 new features
- All research is analysis-only — implementation not started

---

## Next Session — Where to Start

**Start Phase 5: Multi-Tenancy.**

This is the load-bearing change. CRM integration, agent identity extraction, and priority scoring all require `tenant_id` to exist in the schema before they can be built.

### Suggested starting point: DB schema migration

Create `32_Phase5_MultiTenancy_Plan.md` and spec out:

1. `tenants` table DDL (full columns including `settings JSONB`)
2. Alembic migration that adds `tenant_id UUID NOT NULL` to all 5 tables
3. PostgreSQL RLS policy SQL for each table
4. JWT changes — add `tenant_id` claim to login response and token payload
5. FastAPI middleware — `contextvars.ContextVar`, `SET LOCAL app.current_tenant`
6. MinIO path convention change — `{tenant_id}/{call_id}.mp3`
7. Seed data update — wrap existing 200 calls under a `demo_tenant`

### Key architectural decision already made (from research):
- **Shared tables + RLS** — not schema-per-tenant
- `SET LOCAL` not `SET SESSION` for tenant context
- `contextvars.ContextVar` for async safety (not thread-locals)
- Prefix-based MinIO isolation (not bucket-per-tenant)
- Full details in [[30_SaaS_Pivot_Plan]] → Phase 5 section

---

## Open Questions for Next Session

- What will the tenant onboarding flow look like? (signup form, or admin-created?)
- Do you want a `PLATFORM_ADMIN` superuser panel in the UI, or just API-level?
- Target: one demo tenant or multiple tenants from day one in seed data?
- The "also" feature you started to mention and deferred — what was it?

---

## Files to Load at Session Start

```
N:\projects\docs\INVARIANTS.md          (500 tokens — paste into LLM)
N:\projects\docs\30_SaaS_Pivot_Plan.md  (full pivot spec)
N:\projects\docs\02_Database_Schema.sql (current schema — starting point for Phase 5 migration)
```
