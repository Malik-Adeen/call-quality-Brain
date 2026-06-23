---
tags: [planning, saas, roadmap, implementation]
date: 2026-04-30
status: active
instructor-confirmed: 2026-04-30
---

# 33 — SaaS Implementation Plan (Confirmed Scope)

> Instructor confirmation received: 2026-04-30
> Multi-tenancy: APPROVED — high priority
> CRM integration (Phase 8): DEFERRED — do not build yet
> Customer priority scoring (Phase 9): DEFERRED — depends on CRM data, skip for now
> Active phases: 5 → 6 → 7

---

## Confirmed Scope (3 Phases)

```
Phase 5: Multi-Tenancy     ← load-bearing, must go first
    ↓
Phase 6: Agent Integration ← roster sync, real agent rosters
    ↓
Phase 7: Agent Identity    ← auto-resolve agent from transcript
```

Phases 8 (CRM) and 9 (Priority Scoring) are **parked**. Their specs remain in [[30_SaaS_Pivot_Plan]] but no code will be written until instructed.

---

## Phase 5 — Multi-Tenancy

**Goal:** Convert the single-tenant system into an isolated multi-tenant SaaS. Every other SaaS feature depends on `tenant_id` existing in the schema first.

**Estimated effort:** Large — touches DB schema, all API endpoints, JWT, MinIO paths, and frontend auth flow.

### 5.1 — Database Changes

**New table: `tenants`**
```sql
CREATE TABLE tenants (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name       TEXT        NOT NULL,
    slug       TEXT        UNIQUE NOT NULL,
    plan_tier  TEXT        NOT NULL DEFAULT 'smb'
                           CHECK (plan_tier IN ('smb', 'midmarket', 'enterprise')),
    settings   JSONB       NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

`settings` JSONB houses per-tenant overrides. Initial key: `scoring_weights` (optional, falls back to global formula if absent).

**Add `tenant_id` to all tenant-scoped tables:**
```sql
ALTER TABLE users            ADD COLUMN tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE;
ALTER TABLE agents           ADD COLUMN tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE;
ALTER TABLE calls            ADD COLUMN tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE;
ALTER TABLE call_metrics     ADD COLUMN tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE;
ALTER TABLE sentiment_timeline ADD COLUMN tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE;
```

**Row-Level Security — every table:**
```sql
ALTER TABLE users             ENABLE ROW LEVEL SECURITY;
ALTER TABLE agents            ENABLE ROW LEVEL SECURITY;
ALTER TABLE calls             ENABLE ROW LEVEL SECURITY;
ALTER TABLE call_metrics      ENABLE ROW LEVEL SECURITY;
ALTER TABLE sentiment_timeline ENABLE ROW LEVEL SECURITY;

ALTER TABLE users             FORCE ROW LEVEL SECURITY;
ALTER TABLE agents            FORCE ROW LEVEL SECURITY;
ALTER TABLE calls             FORCE ROW LEVEL SECURITY;
ALTER TABLE call_metrics      FORCE ROW LEVEL SECURITY;
ALTER TABLE sentiment_timeline FORCE ROW LEVEL SECURITY;

-- Policy pattern (repeat for each table)
CREATE POLICY tenant_isolation ON users
    USING (tenant_id = current_setting('app.current_tenant')::uuid);
```

**Seed data migration:**
- Insert one `demo_tenant` row
- Update all 200 existing calls, agents, users to reference `demo_tenant.id`
- Update `reset_and_seed.py` to be tenant-aware

### 5.2 — Role Changes

| Old Role | New Role | Scope |
|---|---|---|
| `ADMIN` | `TENANT_ADMIN` | One tenant only |
| _(new)_ | `PLATFORM_ADMIN` | All tenants — superuser |
| `SUPERVISOR` | `SUPERVISOR` | One tenant |
| `VIEWER` | `VIEWER` | One tenant |

Update `users.role` CHECK constraint to include `PLATFORM_ADMIN` and `TENANT_ADMIN`.

### 5.3 — Alembic Migration Plan

```
migrations/
├── 001_add_tenants_table.py
├── 002_add_tenant_id_to_all_tables.py
├── 003_enable_rls_policies.py
└── 004_seed_demo_tenant_migrate_data.py
```

Run in order. Never merge into a single migration — rollback granularity matters.

### 5.4 — JWT Changes

**Current JWT payload:**
```json
{ "sub": "user_id", "role": "ADMIN", "exp": ... }
```

**New JWT payload:**
```json
{ "sub": "user_id", "tenant_id": "uuid", "role": "TENANT_ADMIN", "exp": ... }
```

Changes needed:
- `POST /auth/login` — inject `tenant_id` from user record into token
- All protected endpoints — validate `tenant_id` from token matches request context
- `PLATFORM_ADMIN` tokens carry `tenant_id: null` (cross-tenant access)

### 5.5 — FastAPI Middleware

```python
tenant_context: ContextVar[UUID] = ContextVar("tenant_context")

# Middleware extracts tenant_id from JWT and sets ContextVar
# Every DB session uses SET LOCAL app.current_tenant before executing queries
# ContextVar — never thread-local (asyncpg is async, thread-locals are unsafe)
```

Pattern per endpoint:
```python
async with db.begin():
    await db.execute(text("SET LOCAL app.current_tenant = :tid"), {"tid": str(tenant_id)})
    # all queries inside this transaction are automatically RLS-scoped
```

### 5.6 — MinIO Path Change

| State | Path format |
|---|---|
| Current (single-tenant) | `{call_id}.mp3` |
| Phase 5+ (multi-tenant) | `{tenant_id}/{call_id}.mp3` |

Update `ingest_upload` task and any presigned URL generation. Existing 200 seeded files stay at flat paths — migration script moves them under `demo_tenant_id/` prefix.

### 5.7 — Tenant Onboarding

For now: **admin-created tenants only** (no public signup, no Stripe). One API endpoint:

```
POST /platform/tenants
  Body: { name, slug, plan_tier }
  Auth: PLATFORM_ADMIN only
  Returns: tenant record + first TENANT_ADMIN user invite
```

Public self-serve signup is deferred — out of scope until Phase 8+ revenue model is needed.

### 5.8 — Deliverables Checklist

```
[ ] tenants table DDL + Alembic migration 001
[ ] tenant_id columns on all 5 tables + migration 002
[ ] RLS policies + migration 003
[ ] Demo tenant seed + data migration + migration 004
[ ] JWT payload updated (login endpoint)
[ ] FastAPI tenant middleware (ContextVar + SET LOCAL)
[ ] MinIO path updated to {tenant_id}/{call_id}.mp3
[ ] POST /platform/tenants endpoint (PLATFORM_ADMIN only)
[ ] Update reset_and_seed.py to be tenant-aware
[ ] Role CHECK constraint updated (PLATFORM_ADMIN, TENANT_ADMIN)
[ ] All existing tests pass under demo_tenant context
```

---

## Phase 6 — Agent Integration

**Goal:** Replace static seed agents with a live roster sync API. Real call centers have hundreds of agents that change — static seeds don't scale.

**Depends on:** Phase 5 complete (`tenant_id` on `agents` table).

### 6.1 — Database Changes

```sql
ALTER TABLE agents ADD COLUMN external_id TEXT;
ALTER TABLE agents ADD COLUMN is_active   BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE agents ADD COLUMN email       TEXT;

-- Unique per tenant — same external_id can exist across tenants
CREATE UNIQUE INDEX agents_external_id_tenant_idx ON agents(tenant_id, external_id)
    WHERE external_id IS NOT NULL;
```

### 6.2 — New Endpoint

```
POST /agents/sync
  Auth: TENANT_ADMIN
  Body: [{ name, team, external_id, email }]
  Behavior: Upsert by (tenant_id, external_id). Idempotent — safe to call from webhooks.
  Returns: { created: N, updated: N, unchanged: N }
```

### 6.3 — Soft Delete

- `is_active = FALSE` for departed agents — never hard delete (call history references them)
- `GET /agents` — filter `is_active = TRUE` by default, `?include_inactive=true` for full list
- Upload form agent dropdown — only shows active agents

### 6.4 — Deliverables Checklist

```
[ ] external_id, is_active, email columns + migration
[ ] Unique index on (tenant_id, external_id)
[ ] POST /agents/sync endpoint (upsert logic)
[ ] GET /agents — filter by is_active, support include_inactive param
[ ] Upload form dropdown — exclude inactive agents
[ ] Update seed_data.py to include external_id on seeded agents
```

---

## Phase 7 — Agent Identity Extraction from Audio

**Goal:** Automatically resolve which agent handled a call from their spoken self-introduction. Eliminates the manual agent dropdown on upload.

**Depends on:** Phase 5 (tenant_id), Phase 6 (agents have external_id + clean roster).

### 7.1 — How It Works

After `redact_pii` completes and before scoring begins, a new extraction pass runs:

1. Groq receives the first ~500 words of the redacted transcript
2. Prompt asks it to extract the agent's stated name from self-introduction ("Hi, this is Sarah from support")
3. Groq returns `{ "agent_name": "Sarah", "confidence": "high" }`
4. Fuzzy-match against `agents` table for the tenant (case-insensitive, partial match using `rapidfuzz`)
5. High-confidence match → `agent_id` set automatically
6. Null or low confidence → `needs_agent_review = TRUE`, supervisor notified

### 7.2 — Database Changes

```sql
ALTER TABLE calls ADD COLUMN needs_agent_review  BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE calls ADD COLUMN agent_name_extracted TEXT;

-- agent_id becomes nullable (was NOT NULL)
ALTER TABLE calls ALTER COLUMN agent_id DROP NOT NULL;
```

### 7.3 — Pipeline Change

The extraction runs as a new `io_queue` Celery task: `extract_agent_identity`.

**Updated chain:**
```
ingest_upload
    → run_whisperx         (gpu_queue)
    → redact_pii           (io_queue)
    → extract_agent_identity  (io_queue)  ← NEW
    → compute_talk_balance (io_queue)
    → run_groq_inference   (io_queue)
    → write_scores         (io_queue)
    → notify_websocket     (io_queue)
```

### 7.4 — Groq Prompt (exact)

```
Extract the call center agent's stated name from the transcript below.
Agents typically introduce themselves near the start of the call.
Return JSON only, no other text:
{"agent_name": "<name or null>", "confidence": "high|medium|low"}
If no agent self-introduction is found: {"agent_name": null, "confidence": "low"}

TRANSCRIPT:
{first_500_words}
```

### 7.5 — Upload Form Change

- Agent dropdown becomes **optional**, not required
- New label: "Agent (leave blank for auto-detection)"
- Calls with `needs_agent_review = TRUE` show a yellow "Needs Review" badge in the call list
- Supervisor can manually assign agent from the call detail panel

### 7.6 — Deliverables Checklist

```
[ ] needs_agent_review + agent_name_extracted columns + migration
[ ] agent_id made nullable on calls table + migration
[ ] extract_agent_identity Celery task (io_queue)
[ ] Groq prompt for name extraction
[ ] rapidfuzz matching against agents table (threshold: 85+ score = high confidence)
[ ] Pipeline chain updated to include new task
[ ] Upload form — agent dropdown made optional
[ ] Call list — Needs Review badge for unresolved calls
[ ] Call detail panel — manual agent assignment for supervisor
[ ] Store raw Groq JSON in agent_name_extracted for audit trail
```

---

## Implementation Order Summary

| Phase | First task to start | Blocking dependency |
|---|---|---|
| 5 | Write `tenants` DDL + migration 001 | None — start here |
| 6 | Add `external_id` column + migration | Phase 5 complete |
| 7 | Add `needs_agent_review` column + migration | Phase 6 complete |

### Do not start Phase 6 until:
- `tenant_id` exists on `agents` table
- RLS policies are active and tested
- JWT carries `tenant_id` claim

### Do not start Phase 7 until:
- Agents have `external_id` and clean roster data exists
- `agent_id` on `calls` has been made nullable

---

## Parked (Instructor approval required before touching)

| Phase | Feature | Reason parked |
|---|---|---|
| 8 | CRM Integration (Zendesk first) | Instructor said defer |
| 9 | High / Low Priority Customers | Depends on Phase 8 customer data |

Full specs for both remain in [[30_SaaS_Pivot_Plan]]. No code, no migrations, no endpoints.

---

## Document Checklist (create as each phase starts)

```
[ ] 34_Phase5_MultiTenancy_Postmortem.md   — after Phase 5 ships
[ ] 35_Phase6_AgentIntegration_Postmortem.md
[ ] 36_Phase7_AgentIdentity_Postmortem.md
```
