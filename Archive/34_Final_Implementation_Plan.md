---
tags: [planning, saas, implementation, phase5, phase6, phase7]
date: 2026-04-30
status: active
research-complete: true
---

# 34 — Final Implementation Plan (Research-Complete)

> All 4 research gaps filled. Sources: Codex 5.4, DeepSeek, Gemini Research, GLM 5.1, Kimi, Perplexity.
> Instructor confirmed scope: Phase 5 → 6 → 7 only. CRM + Priority parked.
> My role in this project: code review, bug catching, debugging. Codex/Copilot writes the code.

---

## How We Work

- **Codex / Copilot** writes the code
- **I (Claude)** review every file before it runs — catching bugs, RLS violations, invariant breaks, and logic errors
- **You** paste the generated code here for review before committing

Do not run any migration or deploy any task change without a review pass first.

---

## Phase 5 — Multi-Tenancy

### What Gets Built
New `tenants` table. `tenant_id UUID NOT NULL` on all 5 tables. PostgreSQL RLS. JWT `tenant_id` claim. FastAPI ContextVar middleware. Celery worker tenant injection. MinIO path change.

---

### 5A — Database: 3 Alembic Migrations

**Critical rule:** 3 separate migrations, never merged. Rollback granularity matters.

#### Migration 001 — Create `tenants` table

Codex prompt: create Alembic migration to add tenants table with columns: id UUID PK gen_random_uuid(), name TEXT NOT NULL, slug TEXT UNIQUE NOT NULL, plan_tier TEXT NOT NULL DEFAULT 'smb' CHECK IN ('smb','midmarket','enterprise'), settings JSONB NOT NULL DEFAULT '{}', created_at TIMESTAMPTZ DEFAULT NOW()

**Review checklist for this migration:**
- [ ] `server_default=sa.text("gen_random_uuid()")` — not Python-side default
- [ ] `slug` has `UNIQUE` constraint
- [ ] `settings` column is `JSONB` not `JSON`
- [ ] `plan_tier` CHECK constraint has all 3 values
- [ ] `down_revision` points to actual current head, not placeholder

---

#### Migration 002 — Add `tenant_id` to all tables + backfill

**The backfill pattern matters.** DeepSeek's approach: INSERT demo tenant with RETURNING id, use that UUID to backfill. Do NOT hardcode a UUID.

Order inside the migration:
1. Add column as nullable
2. INSERT demo tenant, capture its UUID via RETURNING
3. UPDATE all rows with that UUID
4. ALTER column to NOT NULL
5. Add FK constraint and index

Tables: `users`, `agents`, `calls`, `call_metrics`, `sentiment_timeline`

**Review checklist:**
- [ ] Column added as nullable FIRST — never add NOT NULL without backfill first
- [ ] Demo tenant inserted with RETURNING id, not hardcoded UUID
- [ ] All 5 tables backfilled before NOT NULL is set
- [ ] FK constraint created: `fk_{table}_tenant_id_tenants`
- [ ] Composite index created: `ix_{table}_tenant_id`
- [ ] `downgrade()` reverses in correct order (drop FK before drop column)
- [ ] No raw f-string SQL injection — use `.bindparams()` for the UUID value

---

#### Migration 003 — Enable RLS + Isolation Policies

**Critical: the `true` second argument in `current_setting()`**
This is the most common RLS bug. Without it, any query that runs before SET LOCAL is called crashes with "unrecognized configuration parameter". With it, it safely returns NULL and the policy blocks access (fail-closed).

Correct policy expression:
```sql
tenant_id = NULLIF(current_setting('app.current_tenant', true), '')::uuid
```

Wrong (will crash on unset):
```sql
tenant_id = current_setting('app.current_tenant')::uuid
```

Do NOT add `FORCE ROW LEVEL SECURITY` yet — only add it once the migrator role is confirmed to have BYPASSRLS or the migration runs as the table owner.

**Review checklist:**
- [ ] `current_setting('app.current_tenant', true)` — second arg `true` is present on EVERY policy
- [ ] `NULLIF(..., '')` wraps the result — handles both NULL and empty string
- [ ] `::uuid` cast is present
- [ ] Both `USING` and `WITH CHECK` clauses exist on every policy
- [ ] Policy name pattern: `{table}_tenant_isolation`
- [ ] `ENABLE ROW LEVEL SECURITY` present on all 5 tables
- [ ] `FORCE ROW LEVEL SECURITY` is NOT added in this migration (deferred)
- [ ] `downgrade()` does DROP POLICY then DISABLE RLS (correct order)

---

#### Migration 004 — env.py bypass

The Alembic migration runner must bypass RLS or migrations block themselves.

Pattern: attach a `connect` event listener that executes `SET row_security = off` on every connection the Alembic engine opens.

```python
# in env.py run_migrations_online():
from sqlalchemy import event

def set_rls_bypass(dbapi_connection, connection_record):
    cursor = dbapi_connection.cursor()
    try:
        cursor.execute("SET row_security = off")
    finally:
        cursor.close()

event.listen(connectable.engine, 'connect', set_rls_bypass)
```

**Review checklist for env.py:**
- [ ] `event.listen` is attached BEFORE `connectable.connect()` is called
- [ ] The listener uses `dbapi_connection` (raw DBAPI), not a SQLAlchemy connection
- [ ] The cursor is closed in `finally` block
- [ ] The `run_migrations_online` function is using sync engine (psycopg2), not asyncpg

---

### 5B — FastAPI: JWT + ContextVar + SET LOCAL

#### JWT Changes

New token payload:
```json
{ "sub": "user_uuid", "tenant_id": "tenant_uuid", "role": "TENANT_ADMIN", "exp": ... }
```

**Transition strategy (from Codex + DeepSeek — both agree):**
Use server-side fallback during rollout. Old tokens without `tenant_id` are still accepted — the server looks up `user.tenant_id` from the DB as fallback. New logins always get the new token shape.

Feature flag: `ALLOW_LEGACY_TOKENS_WITHOUT_TENANT_ID = True` in config. Flip to False after all old tokens have expired (= after max session TTL passes). Because you use Zustand sessionStorage, tokens die on tab close — migration window is naturally short.

**Security rule:** If a token HAS `tenant_id` but it doesn't match `user.tenant_id` in the DB → reject immediately. Never silently prefer the token over the DB.

**Review checklist for JWT dependency:**
- [ ] `token_tenant_id` present → validate it matches `user.tenant_id` → reject if mismatch
- [ ] `token_tenant_id` absent + legacy flag True → use `user.tenant_id` from DB
- [ ] `token_tenant_id` absent + legacy flag False → raise 401
- [ ] `resolved_tenant_id` is set on `request.state.tenant_id` for middleware to pick up
- [ ] New `create_access_token()` always includes `tenant_id` in payload
- [ ] `PLATFORM_ADMIN` tokens: `tenant_id` = null (cross-tenant access) — handle this case separately

#### ContextVar + SET LOCAL

ContextVar defined at module level:
```python
from contextvars import ContextVar
tenant_context: ContextVar[str] = ContextVar("tenant_context")
```

FastAPI dependency chain:
1. JWT dependency extracts + validates → sets `request.state.tenant_id`
2. DB session dependency reads `request.state.tenant_id` → calls `SET LOCAL app.current_tenant = :tid`

**Review checklist:**
- [ ] `ContextVar` — never `threading.local()` (async code, thread-locals unsafe)
- [ ] `SET LOCAL` not `SET SESSION` — transaction-scoped, auto-clears on commit
- [ ] `expire_on_commit=False` on the async session factory — mandatory
- [ ] Session dependency uses `yield` (not return) — FastAPI manages teardown
- [ ] Background tasks create their OWN session — never pass the request session in
- [ ] `PLATFORM_ADMIN` bypasses SET LOCAL (no tenant context, admin queries all data)

---

### 5C — Celery Workers: Tenant Context

**Passing tenant_id:** Use task message headers, not task arguments.

```python
# Sending from API layer:
process_call_task.apply_async(args=(call_id,), headers={'tenant_id': str(tenant_id)})

# Inside task:
tenant_id = self.request.headers.get('tenant_id')
```

**Applying SET LOCAL in sync session:**
```python
with SyncSession() as session:
    with session.begin():
        session.execute(text("SET LOCAL app.current_tenant = :tid"), {"tid": tenant_id})
        # all queries here are RLS-scoped
    # transaction commits → SET LOCAL auto-cleared → connection returned clean
```

`SET LOCAL` clears automatically on commit/rollback. No manual cleanup needed.

**Review checklist for every Celery task file:**
- [ ] `tenant_id = self.request.headers.get('tenant_id')` — reads from headers not args
- [ ] Task raises/retries if `tenant_id` is None — never silently proceeds without tenant context
- [ ] `SET LOCAL` is the FIRST execute call inside `session.begin()`
- [ ] `SET LOCAL app.current_tenant` — same GUC name as FastAPI, not `app.current_tenant_id`
- [ ] Workers use sync engine `postgresql://` not `postgresql+asyncpg://` — never asyncpg in workers
- [ ] `with session.begin():` wraps all task DB logic in one transaction

---

### 5D — MinIO Path Change

| Before | After |
|---|---|
| `{call_id}.mp3` | `{tenant_id}/{call_id}.mp3` |

Changed in `ingest_upload` task and any presigned URL generation.

Migration script needed: move 200 existing seeded files from flat path to `{demo_tenant_id}/` prefix. Script uses MinIO SDK copy-then-delete pattern.

**Review checklist:**
- [ ] `minio_audio_path` column stores the new `{tenant_id}/{call_id}.mp3` path format
- [ ] `ingest_upload` task reads `tenant_id` from headers before constructing the path
- [ ] No hardcoded `cq-minio:9000` references use underscores (botocore rejects — must be hyphens)
- [ ] Migration script verifies copy succeeded before deleting original
- [ ] `reset_and_seed.py` updated to use new path format

---

### 5E — New Roles + Endpoints

UPDATE `users.role` CHECK constraint:
```sql
CHECK (role IN ('PLATFORM_ADMIN', 'TENANT_ADMIN', 'SUPERVISOR', 'VIEWER'))
```
Old value `'ADMIN'` → `'TENANT_ADMIN'`. Needs a data migration too.

New endpoint: `POST /platform/tenants` — PLATFORM_ADMIN only. Creates tenant + first TENANT_ADMIN user invite.

**Review checklist:**
- [ ] `PLATFORM_ADMIN` check in route guard — not just `TENANT_ADMIN`
- [ ] Existing seed users with role `'ADMIN'` updated to `'TENANT_ADMIN'` in migration
- [ ] `PLATFORM_ADMIN` bypasses RLS policies — verified by testing cross-tenant query
- [ ] `POST /platform/tenants` does NOT require `tenant_id` in session (platform-level endpoint)

---

## Phase 6 — Agent Integration

**Dependency:** Phase 5 fully deployed and tested first.

### What Gets Built
`external_id`, `is_active`, `email` on `agents`. Unique index per tenant. `POST /agents/sync` bulk upsert endpoint.

### Migration 005 — Agent table columns

```sql
ALTER TABLE agents ADD COLUMN external_id TEXT;
ALTER TABLE agents ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE agents ADD COLUMN email TEXT;

CREATE UNIQUE INDEX agents_external_id_tenant_idx
    ON agents(tenant_id, external_id)
    WHERE external_id IS NOT NULL;
```

**Review checklist:**
- [ ] Unique index is PARTIAL (`WHERE external_id IS NOT NULL`) — agents without external_id should not collide
- [ ] `is_active` is NOT NULL with DEFAULT TRUE — not nullable
- [ ] Index includes `tenant_id` first — same `external_id` can exist in different tenants
- [ ] `downgrade()` drops the index before dropping the columns

### POST /agents/sync endpoint

Idempotent bulk upsert. Upsert key: `(tenant_id, external_id)`.

**Review checklist:**
- [ ] Upserts by `(tenant_id, external_id)` — not just `external_id` alone
- [ ] Returns `{ created: N, updated: N, unchanged: N }` counts
- [ ] Agents with no `external_id` in the payload are skipped (not upserted)
- [ ] Soft-delete: agents in DB but absent from payload are NOT deleted — only flagged if explicit
- [ ] `is_active` can be set to FALSE by the sync payload (departed agents)
- [ ] Auth guard: `TENANT_ADMIN` or `SUPERVISOR` only — not `VIEWER`

### GET /agents

- Default: `WHERE is_active = TRUE`
- `?include_inactive=true` → all agents
- Upload form agent dropdown: only active agents

---

## Phase 7 — Agent Identity Extraction

**Dependency:** Phase 6 fully deployed. Agents have `external_id` and clean roster data.

### What Gets Built
New `extract_agent_identity` Celery task. `needs_agent_review` + `agent_name_extracted` columns on `calls`. `agent_id` made nullable. Optional telephony metadata field on upload. rapidfuzz matching. Groq name extraction prompt.

### Migration 006 — calls table changes

```sql
ALTER TABLE calls ALTER COLUMN agent_id DROP NOT NULL;
ALTER TABLE calls ADD COLUMN needs_agent_review BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE calls ADD COLUMN agent_name_extracted TEXT;
```

**Review checklist:**
- [ ] `agent_id` is made nullable — not dropped. Existing rows keep their values.
- [ ] `needs_agent_review` is NOT NULL DEFAULT FALSE
- [ ] `agent_name_extracted` is nullable TEXT (stores raw Groq JSON output)

### Updated Pipeline Chain

```
ingest_upload
    → run_whisperx         (gpu_queue)
    → redact_pii           (io_queue)
    → extract_agent_identity  (io_queue)   ← NEW
    → compute_talk_balance (io_queue)
    → run_groq_inference   (io_queue)
    → write_scores         (io_queue)
    → notify_websocket     (io_queue)
```

`extract_agent_identity` runs on `io_queue` — no GPU needed.

### Telephony Metadata First

Upload form gets an optional field: `external_agent_id` (agent's telephony system ID).

Logic in `extract_agent_identity`:
1. If `external_agent_id` provided → look up agent by `(tenant_id, external_id)` → set `agent_id`, done
2. If not provided → run Groq extraction → fuzzy match → set `agent_id` or flag

**Review checklist:**
- [ ] Telephony metadata path does NOT call Groq (zero API cost when metadata available)
- [ ] Groq path only runs when `external_agent_id` is absent
- [ ] Task reads `tenant_id` from headers before any DB query (RLS)

### Groq Extraction Prompt

```
Extract the call center agent's stated name from the transcript below.
Agents typically introduce themselves near the start of the call.
Return JSON only, no other text:
{"agent_name": "<name or null>", "confidence": "high|medium|low"}
If no agent self-introduction is found: {"agent_name": null, "confidence": "low"}

TRANSCRIPT:
{first_500_words}
```

**Review checklist:**
- [ ] Only first 500 words sent to Groq — not full transcript (cost + latency)
- [ ] Response parsed as JSON — if JSON parse fails, treat as null/low confidence
- [ ] `agent_name_extracted` stores the raw Groq JSON string (for audit trail)
- [ ] Groq failures (429, 503) trigger OpenRouter fallback — same as rest of pipeline

### rapidfuzz Matching (from DeepSeek research)

Scorer: `token_set_ratio` (handles partial name extractions — "Sarah" matches "Sarah Johnson" at 100)

Confidence thresholds:
| Score | Confidence | Action |
|---|---|---|
| ≥ 90 | High | Auto-assign `agent_id` |
| 75–89 | Medium | Auto-assign if no second candidate within 5 points |
| 60–74 | Low | Always flag for review |
| < 60 | None | `needs_agent_review = TRUE`, `agent_id` = NULL |

Ambiguity rule: if top two candidates are within 5 points of each other → flag regardless of absolute score.

Pre-processing before matching: lowercase, strip titles (Mr/Mrs/Dr), strip punctuation, collapse spaces.

Nickname map included: Mike→Michael, Jon→John/Jonathan, Liz→Elizabeth, Bill→William, etc.

**Review checklist:**
- [ ] `token_set_ratio` used — not `ratio`, `partial_ratio`, or `token_sort_ratio`
- [ ] Pre-processing applied to BOTH extracted name AND DB agent names
- [ ] Nickname expansion runs before scoring
- [ ] Ambiguity check: abs(top_score - second_score) <= 5 → flag even if top_score >= 90
- [ ] `score_cutoff=55` in `process.extract()` call — lower bound before threshold logic
- [ ] Match is against `(tenant_id, agent.cleaned_name)` — never cross-tenant agent names
- [ ] Low confidence match still stores `agent_name_extracted` — do not discard

### Upload Form Changes

- Agent dropdown: optional (not required)
- New field: `external_agent_id` (optional, text)
- New label: "Agent (leave blank for auto-detection)"
- If `needs_agent_review = TRUE` → yellow "Needs Review" badge in call list
- Supervisor can manually assign from call detail panel

---

## Invariants That Never Change (cross-phase)

These apply to every line of code in every phase. If Codex generates code that violates any of these, flag immediately:

| Invariant | What to catch |
|---|---|
| `minio_audio_path` | Never `audio_path` |
| `transcript_redacted` | Never `transcript` |
| `cq-minio:9000` | Never `cq_minio:9000` (underscores rejected by botocore) |
| `run_whisperx` → `gpu_queue` only | Never routed to `io_queue` |
| `postgresql+asyncpg://` for FastAPI | Never in Celery workers |
| `postgresql://` for Celery | Never asyncpg in workers |
| `SET LOCAL` | Never `SET SESSION` |
| `ContextVar` | Never `threading.local()` in async code |
| Zero code comments | Self-documenting names only |
| `llama-3.3-70b-versatile` | Never `3.1` (deprecated, 400 error) |
| JWT → sessionStorage | Never localStorage |
| `expire_on_commit=False` | Required on async session factory |
| `current_setting('app.current_tenant', true)` | The `true` arg must be present |

---

## Review Session Protocol

When you paste code for review, tell me:
- Which phase and section it belongs to (e.g. "Phase 5 — Migration 002")
- Which tool generated it (Codex / Copilot)

I will check against the relevant checklist above, flag any invariant violations, and catch edge cases the generators typically miss (RLS bypass, async/sync mix-ups, missing backfill ordering, etc.)
