---
tags: [handoff, session-starter]
date: 2026-05-10
status: active
---

# 53 — Session Handoff (2026-05-10)

> Paste CONTEXT.md + this file at the start of any new session.

---

## What Was Completed This Session

### UI / Frontend
- Dark mode: CSS variable overrides, html.dark, theme persistence (inline script in index.html head)
- Register.tsx: min-h attributes fixed, bg-white/bg-rose-50 replaced with CSS vars
- UserManagement.tsx: AGENT→VIEWER everywhere, select dark mode, sidebar gate to TENANT_ADMIN
- TenantManagement.tsx: new page, plan badges, user count, create modal (no slug field)
- App.tsx: RoleGuard component, /upload + /agents/manage → TENANT_ADMIN+SUPERVISOR only, /users → TENANT_ADMIN only
- Sidebar.tsx: NEW ANALYSIS hidden for VIEWER and PLATFORM_ADMIN

### Backend
- GET/POST /platform/tenants: slug auto-generated, user count via subquery, PLATFORM_ADMIN gated
- reports.py: require_role("TENANT_ADMIN","SUPERVISOR") added to POST /reports/export
- users.py: email uniqueness filtered by tenant_id, role validation AGENT→VIEWER

### Infrastructure / Tooling
- PLATFORM_ADMIN user seeded: platform@callquality.internal / platform1234
- graphify installed: 501 nodes, 866 edges, 32 communities (E:\projects\call-quality-analytics\graphify-out\)
- cavemen installed: cavecrew, caveman, caveman-compress, caveman-stats, caveman-help
- Claude Code configured: --dangerously-skip-permissions for audit workflow
- Git: safe.directory fixed, private repo re-authenticated, 165 objects pushed

### Pre-Deployment Audit (5 domains — all PASS)
- Role Enforcement: PASS (after reports.py fix)
- RLS Enforcement: PASS (SET LOCAL timing theoretical concern, not blocking)
- Pipeline Invariants: PASS (idempotent write_scores, correct talk_balance, PII gate)
- Frontend Role Gates: PASS (after RoleGuard + NEW ANALYSIS fix)
- BatchAgent: PASS (agent_id absent is by design)
- Full report: E:\projects\docs\audit_report_20260510.md

### Architecture Review
- GPT + GLM consulted on full Azure cloud deployment
- Target market confirmed: Canada (not South Asia)
- Region locked: Azure Canada Central (Toronto)
- Key decisions documented below

---

## Azure Deployment Architecture (Locked Decisions)

| Decision | Choice | Reason |
|---|---|---|
| Region | Canada Central (Toronto) | Canadian customers, PIPEDA compliance |
| API VM | B2ms (2 vCPU, 8GB) | B2s too tight under load |
| GPU VM | NC4as_T4_v3 separate VM | Isolation, scale-to-zero |
| PostgreSQL | Azure Flexible Server B1ms (~$13/mo) | Off-VM, automated backups |
| Redis | Docker on B2ms | Managed Redis not worth cost at this stage |
| Storage | MinIO + 128GB managed data disk | Blob Storage migration later |
| SSL | Caddy | Auto-HTTPS, WebSocket native, simpler config |
| Secrets | .env files (chmod 600) | Key Vault after first paying customer |
| GPU scale-to-zero | cron + az cli on B2ms | Start when gpu_queue > 0, stop after 15min idle |
| Monthly cost | ~$235/month | B2ms + NC4as (6hr/day avg) + managed PG + disk |

## PIPEDA Compliance Actions (Before First Paying Customer)
- Enable Groq Zero Data Retention at console.groq.com
- Add Groq as subprocessor in pilot contract
- Note: extract_agent_identity sends first ~500 words to Groq pre-redaction (by design — known tradeoff)

## GPU Quota Warning
NC4as_T4_v3 has limited quota in Canada Central. Run before provisioning:
```powershell
az vm list-skus --location canadacentral --size Standard_NC --output table | findstr NC4as
```
Fallback: NVadsA10_v5 (~$1.10/hr) if T4 unavailable.

---

## What Is Left Before Azure Go-Live

### Step 1 — Process Demo Audio (local, ~1 hour)
ElevenLabs audio files on Desktop (demo_tenant/ folder):
- sarah_billing_dispute.mp3
- marcus_tech_support.mp3
- aisha_irate_customer.mp3
- david_cancellation.mp3
- priya_payment.mp3 (billing dispute stand-in)

```powershell
# Clear old checksums, restart batch agent, drop files into watch dir
docker restart cq_batch_agent
# Copy files to E:\projects\call-quality-analytics\batch_watch\demo_tenant\
# Watch Flower at localhost:5555 for pipeline completion
```

### Step 2 — Demo Dry Run
Per doc 04 (Demo_Execution_Plan.md). Full script rehearsal end-to-end. One file at a time.

### Step 3 — Azure Canada Central Provisioning
Order of operations:
1. Verify NC4as_T4_v3 quota in Canada Central (or request it)
2. Create Resource Group: callq-canada-prod
3. Create VNet: 10.0.0.0/16 with api-subnet + gpu-subnet
4. Provision B2ms VM (Ubuntu 22.04) — api-subnet
5. Provision NC4as_T4_v3 VM (Ubuntu 22.04 + NVIDIA GPU driver image) — gpu-subnet — NO public IP
6. Provision Azure Database for PostgreSQL Flexible Server B1ms — VNet injected
7. Attach 128GB Standard SSD to B2ms, mount at /mnt/data
8. Configure NSG rules (port 6379, 8000, 5555 from GPU VM to B2ms; 443 from internet to B2ms)
9. Assign managed identity to B2ms, grant Virtual Machine Contributor on GPU VM
10. Install Caddy on B2ms, configure domain
11. Deploy Docker Compose stack on B2ms
12. Deploy gpu_queue worker on GPU VM
13. Deploy gpu-vm-controller.sh cron on B2ms
14. Deploy gpu-idle-shutdown.sh cron on GPU VM
15. Run alembic upgrade head inside cq_api
16. Run reset_and_seed.py
17. Upload test call end-to-end

### Step 4 — Post-Deploy Verification
- redis-cli PING from GPU VM to B2ms (must get PONG)
- celery inspect ping (must see gpu worker)
- Upload test call, verify pipeline completes in ~30s
- Verify GPU VM auto-shuts after 15min idle
- Verify GPU VM auto-starts when call uploaded
- Check B2ms RAM under 70%

---

## Known Tech Debt (non-blocking)
- Call.agent_id FK uses ondelete=CASCADE but column is nullable — should be SET NULL for hard-delete support
- database.py SET LOCAL timing theoretical concern (asyncpg autobegin mitigates in practice)
- build_graph.py stage list missing extract_agent_identity (doc drift, not a code bug)
- RETRY_DELAYS[2] = 120 unreachable in batch_agent/main.py

---

## Key File Locations

| Purpose | Path |
|---|---|
| Project root | E:\projects\call-quality-analytics |
| Vault | E:\projects\docs |
| Demo audio | E:\projects\Audio-Recording (or Desktop\demo_tenant\) |
| graphify graph | E:\projects\call-quality-analytics\graphify-out\ |
| Audit report | E:\projects\docs\audit_report_20260510.md |
| PLATFORM_ADMIN creds | platform@callquality.internal / platform1234 |
| Repo | https://github.com/Malik-Adeen/call-quality-analytics (private) |
