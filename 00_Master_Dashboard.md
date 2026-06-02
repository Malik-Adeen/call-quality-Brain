---
tags: [moc, dashboard]
status: active
created: 2026-04-11
updated: 2026-05-26 (session 10)
---

# 00 — Master Dashboard

> Single entry point for the entire knowledge vault.
> Read this first at the start of any working session.
> For LLM sessions: paste [[CONTEXT]] or [[INVARIANTS]] (500 tokens).

---

## Project Identity

| Property | Value |
|---|---|
| System | AI Call Quality & Agent Performance Analytics System |
| Type | B2B SaaS product (pivoted from FYP — April 30, 2026) |
| Builder | Malik Adeen — BSCS, Bahria University Islamabad |
| Repo | https://github.com/Malik-Adeen/call-quality-analytics |
| Local path | E:\projects\call-quality-analytics |
| Vault | E:\projects\docs |
| Cloud | Azure Canada Central — deployment in progress |
| FYP demo | Completed — week of April 21, 2026 |

---

## Build State — v1.9

| Phase | Description | Status | Notes |
|---|---|---|---|
| 1 | Foundation — Auth, Upload, Docker, Celery | ✅ | [[07_Phase1_Postmortem]] |
| 2 | AI Pipeline — WhisperX, Presidio, Groq, WebSocket | ✅ | [[13_Phase2_E2E_Postmortem]] |
| 3 | React Dashboard — 6 pages | ✅ | [[17_Phase3_Frontend]] |
| 4 | PDF export (Playwright) | ✅ | [[23_Phase4_Postmortem]] |
| 5 | Multi-Tenancy — RLS, JWT tenant claim, Celery tenant_id | ✅ | [[35_Session_Handoff_2026-05-01]] |
| 6 | Agent Integration — migration 005, /agents routes | ✅ | [[36_Session_Handoff_2026-05-02]] |
| 7 | Agent Identity Extraction from audio | ✅ | [[37_Phase7_Postmortem]] |
| 8A | Architecture review P0 fixes (talk balance, idempotency, Redis AOF) | ✅ | [[41_Architecture_Review_Synthesis]] |
| 8B | Waaqi GRC UI redesign (14 files, dark mode, teal design system) | ✅ | [[44_Session_Handoff_Next]] |
| 8C | Register page + POST /auth/register | ✅ | |
| 8D | Agent Management GUI (CRUD) | ✅ | |
| 8E | User Management GUI (invite, roles) | ✅ | |
| 8F | MinIO webhook upload model (replaced BatchAgent) | ✅ | [[59_Session_Handoff_2026-05-18]] |
| 8G | PLATFORM_ADMIN role + TenantManagement page | ✅ | |
| 8H | Pre-Azure security audit — 9 findings fixed | ✅ | [[61_Pre_Azure_Security_Audit]] |
| 8I | UI P0+P1 accessibility audit — contrast, fonts, dark mode | ✅ | |
| 8J | PLATFORM_ADMIN dashboard — 5 pages (Figma AI → Antigravity) | ✅ | |
| 8K | RLS bypass migration 008 — get_db_platform dependency | ✅ | |
| 8L | Azure deployment prep — frontend/Dockerfile, nginx.conf, prod compose | ✅ | |
| 9 | Azure Canada Central deploy | 🔄 In progress — build phase |
| 10 | ROI reporting | 🔲 Post-Azure |
| 11 | Agentic AI assistant (NL query layer) | 🔲 Post-Azure |

---

## Alembic State

| Migration | Revision ID | Status |
|---|---|---|
| 001 Create tenants | `20260501_create_tenants` | ✅ Applied |
| 002 Add tenant_id | `20260501_add_tenant_id` | ✅ Applied |
| 003 RLS + roles | `20260501_enable_rls` | ✅ Applied |
| 004 FORCE RLS | `20260501_force_rls` | ✅ Applied |
| 005 Agent sync columns | `20260601_add_agent_sync_columns` | ✅ Applied |
| 006 Agent identity extraction | `20260701_agent_identity` | ✅ Applied |
| 007 Indexes + constraints | `20260513_indexes_and_constraints` | ✅ Applied |
| 008 Platform RLS bypass | `20260526_platform_rls_bypass` | ✅ Applied |

**Current head:** `20260526_platform_rls_bypass` (migration 008)

---

## Azure Deploy Checklist

- [x] frontend/Dockerfile written (multi-stage Node → nginx)
- [x] infra/nginx.conf written (SPA + /api/ + /ws/ proxy)
- [x] infra/docker-compose.prod.yml written
- [x] backend/Dockerfile fixed (spaCy local wheel, DNS timeout workaround)
- [x] en_core_web_lg-3.8.0-py3-none-any.whl downloaded (400MB)
- [x] .gitignore updated (.env.prod + *.whl protected)
- [ ] Docker prod build passes cleanly
- [ ] Local smoke test: http://localhost loads, login, /api/, WebSocket
- [ ] .env.prod secrets rotation
- [ ] platform@callquality.internal password rotated from platform1234
- [ ] MinIO image pinned to real tag
- [ ] Azure VM provisioned (Canada Central, ports 80/443)
- [ ] docker compose -f docker-compose.prod.yml up -d on VM
- [ ] E2E test on Azure: upload audio → score appears

---

## PLATFORM_ADMIN Pages (v1.9)

| Route | Page | Status |
|---|---|---|
| /platform/overview | PlatformOverview.tsx | ✅ Live — shows KPIs, chart, infra status |
| /tenants | TenantManagement.tsx | ✅ Live — create tenant, plan badges |
| /platform/health | SystemHealth.tsx | ✅ Live — workers, queue depths, errors |
| /platform/usage | UsageAnalytics.tsx | ✅ Live — per-tenant chart + summary |
| /platform/calls | CallMonitor.tsx | ✅ Live — cross-tenant call list, 200 records |

All use `get_db_platform` → `SET LOCAL app.platform_bypass = 'true'` (migration 008).

---

## Design System — Waaqi GRC Tokens (v1.8+)

Full spec: `WAAQI_TOKENS.md` at project root.

| Token | Value | Usage |
|---|---|---|
| Primary | `#00a99d` | CTAs, active states, chart lines |
| Sidebar bg | `#0f1924` | Dark navy |
| Page bg | `#f5f6f8` | Off-white surface |
| Text tertiary | `#6b778c` | WCAG AA 4.57:1 (fixed from #98a2b3) |
| Success bg/text | `#d1fadf` / `#027a48` | Score badges >80% |
| Error bg/text | `#fee4e2` / `#b42318` | Score badges <60% |

TailwindCSS v4 custom spacing: `--spacing-46/50/54` for chart heights.

---

## Upload Model (MinIO Webhook)

Files land in MinIO via mc mirror --watch (Dropbox model).
MinIO fires POST /internal/minio-event → FastAPI creates Call row → Celery chain fires.
**No BatchAgent. No polling. No SQLite manifest.**

---

## Seeded Accounts

| Email | Password | Role | Notes |
|---|---|---|---|
| platform@callquality.internal | platform1234 | PLATFORM_ADMIN | ⚠️ Rotate before production |
| admin@callquality.demo | admin1234 | TENANT_ADMIN | Demo tenant |
| supervisor@callquality.demo | supervisor1234 | SUPERVISOR | Demo tenant |
| viewer@callquality.demo | viewer1234 | VIEWER | Demo tenant |

---

## Startup (Dev)

```powershell
cd E:\projects\call-quality-analytics\infra
docker compose up -d
cd E:\projects\call-quality-analytics\frontend
npm run dev
```

---

## LLM Context Loading

| Method | Tokens | When to use |
|---|---|---|
| `INVARIANTS.md` paste | ~600 | Quick tasks, Qwen/Gemini |
| `CONTEXT.md` paste | ~2,500 | New sessions, architecture decisions |
| `LOG.md` paste | ~300 | Check what was done last session |

---

## Vault Index

| File | Purpose |
|---|---|
| [[CONTEXT]] | Universal LLM session starter |
| [[INVARIANTS]] | 600-token rules block |
| [[LOG]] | One-line session history |
| [[ROADMAP]] | B2B SaaS phase planning |
| [[61_Pre_Azure_Security_Audit]] | Latest security audit findings |
| [[41_Architecture_Review_Synthesis_2026-05-03]] | Multi-LLM architecture review |
| [[WAAQI_TOKENS]] | Design token spec (at project root) |
