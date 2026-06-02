---
tags: [batch-agent, multi-tenancy, roadmap]
date: 2026-05-08
status: planned — do after single-tenant live test passes
---

# 46 — BatchAgent Multi-Tenancy Evolution Plan

> Single-tenant BatchAgent is built and audited (doc 44).
> This doc covers the evolution to multi-tenant.
> Do NOT start this until single-tenant live test passes end-to-end.

---

## Current State (Single-Tenant)

File: batch_agent/main.py

- One BATCH_AGENT_TOKEN (JWT) in .env
- One BATCH_WATCH_DIR in .env
- One PollingObserver watching one folder
- All uploads go to one tenant (derived from JWT)
- JWT expires in 8 hours — silent failure overnight

Limitation: one container = one tenant. 10 tenants = 10 containers.
Not scalable. JWT expiry is a production blocker.

---

## Target State (Multi-Tenant)

One container. Unlimited tenants. Each fully isolated.
No restarts needed to onboard a new tenant.

```
cq_batch_agent container
├── /watch/demo_tenant    → Demo Tenant API key
├── /watch/acme_corp      → Acme Corp API key
└── /watch/new_tenant     → New Tenant API key (added via config, no restart)
```

---

## Step 1 — API Keys (prerequisite, unblocks production use)

**Problem:** JWT expires in 8 hours. BatchAgent is a long-running daemon.
After 8 hours all uploads silently fail with 401.

**Solution:** Long-lived API keys stored in DB, never expiring unless revoked.

### DB change — new table

```sql
CREATE TABLE tenant_api_keys (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id     UUID         NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    key_hash      TEXT         NOT NULL UNIQUE,
    label         TEXT         NOT NULL,
    created_at    TIMESTAMPTZ  DEFAULT NOW(),
    last_used_at  TIMESTAMPTZ,
    revoked       BOOLEAN      DEFAULT FALSE
);
```

### API changes

New endpoints (TENANT_ADMIN only):
- POST /api-keys — generate new key, returns raw key once (hash stored in DB)
- GET /api-keys — list keys for tenant (shows label + last_used_at, never raw key)
- DELETE /api-keys/{id} — revoke key

### Auth changes

Update dependencies.py to accept either:
- Authorization: Bearer <JWT> (existing users, dashboard)
- X-API-Key: <raw_key> (BatchAgent, long-running services)

API key auth: hash the incoming key → lookup in tenant_api_keys → derive tenant_id.
Same RLS enforcement as JWT path. No special privileges.

### Alembic migration

New migration: 20260801_tenant_api_keys.py

### Dashboard change

Add "API Keys" section to UserManagement or Settings page.
TENANT_ADMIN can generate/revoke keys with labels (e.g. "BatchAgent - Server 1").

---

## Step 2 — Multi-Tenant Config File

Replace 4 flat .env vars with a JSON config file mounted into the container.

### Config file format

Path inside container: /config/batch_config.json

```json
[
  {
    "tenant": "demo_tenant",
    "api_key": "bak_live_abc123...",
    "watch_dir": "/watch/demo_tenant",
    "semaphore_limit": 4
  },
  {
    "tenant": "acme_corp",
    "api_key": "bak_live_xyz789...",
    "watch_dir": "/watch/acme_corp",
    "semaphore_limit": 2
  }
]
```

### docker-compose.yml changes

```yaml
cq_batch_agent:
  volumes:
    - ./batch_config.json:/config/batch_config.json:ro
    - ${DEMO_WATCH_DIR}:/watch/demo_tenant:ro
    - ${ACME_WATCH_DIR}:/watch/acme_corp:ro
    - batch_checksums:/data
```

### main.py changes

- Load config from /config/batch_config.json at startup
- For each entry: create one PollingObserver + one asyncio.Semaphore
- Each observer uploads with its own api_key via X-API-Key header
- Separate checksum store per tenant: /data/{tenant}_checksums.json
- Remove all BATCH_AGENT_TOKEN / BATCH_WATCH_DIR env var reads

---

## Step 3 — Config Reload Without Restart

Watch the config file itself for changes using a separate PollingObserver.

On config file change:
1. Load new config from disk
2. Diff against running observers
3. Stop observers for tenants removed from config
4. Start new observers for tenants added to config
5. Leave unchanged tenants running (no interruption)

Onboarding a new tenant = add entry to batch_config.json.
The agent picks it up within the polling interval (~1 second).
No container restart. No downtime for existing tenants.

---

## Implementation Order

1. Step 1 (API keys) — do first, standalone value even without multi-tenant config
2. Step 2 (config file) — do after API keys are live and tested
3. Step 3 (config reload) — do last, polish feature

Estimated effort per step: 2-3 days each.
Total: ~1 week for full multi-tenant BatchAgent.

---

## Codex Prompts (write when ready)

Prompt order:
1. Alembic migration for tenant_api_keys table
2. API key auth in dependencies.py (alongside JWT)
3. POST/GET/DELETE /api-keys endpoints in new router api_keys.py
4. main.py rewrite for multi-tenant config file
5. Config reload watchdog addition to main.py
6. docker-compose.yml volume mount update
7. Dashboard API keys UI in UserManagement.tsx or new Settings.tsx

Each prompt to be written by Claude.ai chat, generated by Codex, audited by Claude.ai.
