---
tags: [architecture, batch-agent, multi-tenant]
date: 2026-05-09
status: planned — implement post-demo
---

# 50 — BatchAgent Multi-Tenant Architecture

## Problem with Current Design

One container = one tenant. 10 tenants = 10 containers. Not scalable.
JWT token expires every 8 hours — silently breaks overnight uploads with no alert.

## Target Architecture (3 steps)

### Step 1 — API Keys (replace JWT)

Replace BATCH_AGENT_EMAIL + BATCH_AGENT_PASSWORD auth with long-lived API keys.
- API key stored in DB (new table: `api_keys`)
- Never expires unless manually revoked by ADMIN
- Agent sends `X-API-Key: <key>` header instead of `Authorization: Bearer <jwt>`
- Backend validates key, extracts tenant_id, scopes upload to that tenant

Schema addition:
```sql
CREATE TABLE api_keys (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID        NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    key_hash    TEXT        NOT NULL UNIQUE,
    label       TEXT        NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    revoked_at  TIMESTAMPTZ
);
```

### Step 2 — JSON Config File (replace single env var)

Replace single BATCH_AGENT_EMAIL/PASSWORD with a JSON config file.
Each entry = one tenant watcher. Agent spins up one PollingObserver per entry.

Config format (`/config/tenants.json`):
```json
[
  {
    "tenant": "acme_corp",
    "api_key": "cqa_live_xxxxxxxxxxxx",
    "watch_dir": "/watch/acme_corp"
  },
  {
    "tenant": "globex",
    "api_key": "cqa_live_yyyyyyyyyyyy",
    "watch_dir": "/watch/globex"
  }
]
```

One container handles N tenants. Each tenant has isolated:
- Watch folder
- API key (scoped to their tenant_id)
- Checksum store (keyed by tenant name in shared JSON)

### Step 3 — Hot Reload (no restarts for onboarding)

Agent watches `/config/tenants.json` for changes using a second PollingObserver.
On change:
- Diff new config against running watchers
- Start new PollingObserver for added tenants
- Stop PollingObserver for removed tenants
- No container restart required

Onboarding a new tenant = add entry to tenants.json = agent picks it up within poll interval.

## Implementation Order

| Step | Dependency | When |
|---|---|---|
| Step 1 — API keys | New DB table + API endpoint + agent update | Post-demo Phase |
| Step 2 — JSON config | Step 1 complete | Post-demo Phase |
| Step 3 — Hot reload | Step 2 complete | Post-demo Phase |

## Demo Approach (current)

Single-tenant agent is sufficient for FYP demo.
BATCH_AGENT_EMAIL + BATCH_AGENT_PASSWORD approach works for demo duration.
Token auto-refresh on 401 already implemented — no 8-hour expiry risk.

## Docker Compose End State (Step 2+3)

```yaml
cq_batch_agent:
  volumes:
    - ./batch_config/tenants.json:/config/tenants.json:ro
    - /mnt/watch:/watch:ro
    - batch_checksums:/data
  environment:
    - API_URL=${API_URL}
    - CONFIG_PATH=/config/tenants.json
```

No BATCH_AGENT_EMAIL or BATCH_AGENT_PASSWORD in env at all.
