---
tags: [pivot, saas, b2b, planning]
date: 2026-04-30
status: active
---

# 30 — B2B SaaS Pivot Plan

> Project has transitioned from FYP demo phase to B2B SaaS product.
> This document is the canonical reference for all pivot-related architectural decisions.
> Research sources: N:\projects\Transition\ (GLM 5.1, Kimi, Perplexity, Gemini Research)

---

## Pivot Declaration

| Property | Before | After |
|---|---|---|
| Phase | FYP demo | B2B SaaS product |
| Target | University presentation | Call center businesses |
| Users | Demo reviewers | Tenant admins, supervisors, agents |
| Deployment | Single-tenant Azure B2s | Multi-tenant cloud SaaS |
| Pricing model | Free (FYP) | Per-seat $15–$80/agent/month (SMB) |

**Dropped scope:** Urdu/English ASR fine-tuning (was Phase 5). No code was written for it. Drop is clean. `06_Urdu_ASR_Research.md` is retained as historical reference only.

---

## Features Roadmap (in implementation order)

### Phase 5 — Multi-Tenancy (load-bearing, must go first)

Everything else sits on top of this. Building CRM or agent identity on a single-tenant schema creates rework.

**DB changes:**
- New `tenants` table: `id, name, slug, plan_tier, settings JSONB, created_at`
- Add `tenant_id UUID NOT NULL` to: `users`, `agents`, `calls`, `call_metrics`, `sentiment_timeline`
- PostgreSQL Row-Level Security on all tenant-scoped tables
- `FORCE ROW LEVEL SECURITY` on every table — prevents table owner bypass

**Architecture decisions (from Gemini research):**
- **Shared tables + RLS** — not schema-per-tenant. Schema-per-tenant causes catalog bloat at 200 tenants and kills Alembic migration speed.
- `SET LOCAL app.current_tenant` (not `SET SESSION`) — scoped to transaction only, auto-clears on commit
- `contextvars.ContextVar` in FastAPI for async-safe tenant identity propagation (not thread-locals)
- MinIO paths: `{tenant_id}/{call_id}.mp3` — prefix-based isolation, not bucket-per-tenant
- JWT gets `tenant_id` claim at login — all API requests auto-scoped

**New roles:**
- `PLATFORM_ADMIN` — above `TENANT_ADMIN`, manages tenants, billing visibility
- `TENANT_ADMIN` — renamed from `ADMIN`, scoped to one tenant

**Scoring weights:**
- The global formula weights (0.25/0.20/0.20/0.15/0.20) remain the default invariant
- Per-tenant override stored in `tenants.settings JSONB` as `scoring_weights` key
- If no override present, global formula applies

---

### Phase 6 — Agent Integration

Agents are currently static seed data. Real call centers have HR-managed rosters.

**DB changes to `agents` table:**
- Add `external_id TEXT` — employee number, extension, CRM contact ID
- Add `is_active BOOLEAN DEFAULT TRUE` — soft delete for departed agents
- Add `email TEXT` — for future notifications
- Keep `team TEXT` for now; hierarchy (team → supervisor → division) deferred

**New endpoint:**
- `POST /agents/sync` — accepts bulk agent list, upserts by `external_id` within the tenant
- Idempotent — safe to call repeatedly from HR system webhooks or scheduled jobs

---

### Phase 7 — Agent Identity Extraction from Audio

**Goal:** Resolve `agent_id` automatically from transcript, eliminating the manual agent dropdown on upload.

**Decision (from GLM 5.1 + Kimi research):**

Primary method: Groq API name extraction (zero VRAM cost — Groq is already in the pipeline).
Fallback: Manual assignment if Groq returns null.
Avoided: Local LLM (OOM risk on 3060 Ti — WhisperX + Pyannote already ~6GB VRAM), Voice biometrics (GDPR Article 9 — biometric data requires explicit consent).

**Implementation:**

Add a pre-scoring pass inside `run_groq_inference` (or as a new `io_queue` task):

Prompt sent to Groq:
```
Extract the call center agent's stated name from this transcript.
Agents typically introduce themselves in the opening ("Hi, this is [Name] from support").
Return JSON only: {"agent_name": "<name or null>", "confidence": "high|medium|low"}
If no agent self-introduction is found, return {"agent_name": null, "confidence": "low"}
```

After extraction:
1. Fuzzy-match extracted name against `agents` table for that tenant (case-insensitive, partial match)
2. If high-confidence match found → set `agent_id` on the call record automatically
3. If null or low confidence → leave `agent_id` as null, flag `needs_agent_review = TRUE`

**DB change to `calls` table:**
- `agent_id` becomes nullable (was required)
- Add `needs_agent_review BOOLEAN DEFAULT FALSE`
- Add `agent_name_extracted TEXT` — stores raw Groq output for auditing

**Upload form change:**
- Agent dropdown becomes optional, not required
- If agent not selected at upload, system attempts auto-resolution post-transcription
- If auto-resolution fails, supervisor sees a "Needs Review" flag in the dashboard

---

### Phase 8 — CRM Integration

**Goal:** Pull customer data into calls at upload time; push quality scores back to CRM after scoring.

**Architecture decision (from Perplexity research):**
Strategy pattern — abstract `CRMAdapter` base class, concrete `ZendeskAdapter`, `SalesforceAdapter`, `HubSpotAdapter`. Start with **Zendesk first** (28% market share in support, purpose-built for call centers).

**New DB tables:**
```sql
CREATE TABLE tenant_integrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    integration_type TEXT NOT NULL CHECK (integration_type IN ('zendesk', 'salesforce', 'hubspot')),
    access_token TEXT,
    refresh_token TEXT,
    token_expires_at TIMESTAMPTZ,
    account_subdomain TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    external_crm_id TEXT NOT NULL,
    name TEXT,
    email TEXT,
    crm_tier TEXT,
    account_value NUMERIC(12,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Changes to `calls` table:**
- Add `customer_id UUID REFERENCES customers(id)` (nullable)
- Add `customer_tier TEXT` (cached from CRM at upload time)

**New Celery tasks (io_queue):**
- `sync_crm_customer` — pulls customer data at upload time by phone number or account ID
- `push_score_to_crm` — fires after `write_scores`, posts call quality result as CRM activity

**Token storage:** Encrypted using `cryptography.Fernet` with per-tenant keys derived from tenant master key stored in `.env`.

**Webhook receiver:**
- `POST /webhooks/crm/{crm_type}` — validates HMAC signature, enqueues idempotent Celery task, returns 200 immediately

---

### Phase 9 — High / Low Priority Customers

**Goal:** Surface calls involving high-value customers prominently in the dashboard.

**Priority scoring formula (from Gemini research — adapted from NICE CXone):**

```
Base Priority Score = (0.35 × crm_tier_score) + (0.40 × severity_score) + (0.15 × fcr_failure_score) + (0.10 × frequency_score)

Dynamic Priority = Base Priority Score + (wait_seconds × acceleration_rate)
```

Where acceleration_rate is tier-driven: VIP=2.0, Enterprise=1.5, Standard=0.5.

**DB change to `calls` table:**
- Add `customer_priority TEXT CHECK (customer_priority IN ('critical', 'high', 'normal', 'low'))`
- Add `base_priority_score NUMERIC(6,2)`
- Computed by PostgreSQL trigger on INSERT using customer tier + issue category

**Frontend change:**
- Overview "Requires Attention" panel re-sorted: low agent score + high customer priority surfaces first
- Call list adds priority badge column

---

## Research Archive

All external research stored in `N:\projects\Transition\`:

| File | Source | Topic |
|---|---|---|
| `Agent identity extraction from audio (GLM 5.1).txt` | GLM 5.1 | Agent identity — 3 approaches evaluated |
| `Agent identity extraction from audio (Kimi).txt` | Kimi | Agent identity — confirms GLM findings |
| `Multi-Tenant SaaS Architecture Comparison(GEMINI).md` | Gemini Research | RLS vs schema-per-tenant deep dive |
| `Customer priority scoring in call centers (for Gemini Research).md` | Gemini Research | Priority scoring formula + PostgreSQL triggers |
| `CRM integration architecture (for Perplexity).txt` | Perplexity | CRM adapter pattern + Zendesk-first recommendation |
| `B2B SaaS pricing for call center analytics (for Perplexity).txt` | Perplexity | Pricing models, tiers, table stakes vs premium |

---

## Pricing Reference

| Tier | Agents | Per-agent/month |
|---|---|---|
| SMB | 20–100 | $15–$80 |
| Mid-market | 100–500 | $80–$300+ |

**Table stakes** (all tiers): 100% auto-scoring, speech-to-text, sentiment, QA dashboards — we already have this.
**Premium** (gated): CRM integration, generative AI coaching, custom scoring weights, customer priority routing.

---

## Implementation Order

```
Phase 5: Multi-tenancy (DB + JWT + MinIO paths + RLS)
    ↓
Phase 6: Agent integration (roster sync API, external_id, soft-delete)
    ↓
Phase 7: Agent identity extraction (Groq transcript parse, fuzzy match)
    ↓
Phase 8: CRM integration (Zendesk first, adapter pattern, customer table)
    ↓
Phase 9: Customer priority (priority score, DB trigger, dashboard surfacing)
```
