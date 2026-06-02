---
tags: [planning, roadmap]
date: 2026-05-26
status: active
---

# ROADMAP — AI Call Quality & Agent Performance Analytics

> Updated post v1.9 (May 2026).
> Development workflow: Claude.ai = architect + auditor. Claude Code = executor. Antigravity = React gen.

---

## Completed Phases

### Phase 1 — Foundation
7-service Docker stack. JWT auth. MinIO upload. Celery queue isolation. [[07_Phase1_Postmortem]]

### Phase 2 — AI Pipeline
WhisperX + Pyannote. Presidio PII gate. Groq inference. Atomic scoring. WebSocket. [[13_Phase2_E2E_Postmortem]]

### Phase 3 — React Dashboard
6 pages. Recharts. Slide-in panels. PDF export. [[21_UI_Redesign_Postmortem]]

### Phase 4 — Production Hardening
Playwright PDF. Extended Presidio PII. [[23_Phase4_Postmortem]]

### Phase 5 — Multi-Tenancy
Migrations 001–004. JWT tenant_id. Celery explicit tenant_id. [[35_Session_Handoff_2026-05-01]]

### Phase 6 — Agent Integration
Migration 005. POST /agents/sync. GET /agents. [[36_Session_Handoff_2026-05-02]]

### Phase 7 — Agent Identity Extraction
Migration 006. extract_agent_identity task. PATCH /assign-agent. [[37_Phase7_Postmortem]]

### Phase 8A — Architecture Review Fixes
talk_balance formula, write_scores idempotency, Redis AOF. [[41_Architecture_Review_Synthesis]]

### Phase 8B — Waaqi GRC UI Redesign
14 files via Antigravity. Dark mode. Teal design system. [[44_Session_Handoff_Next]]

### Phase 8C — Auth Pages
Register.tsx + POST /auth/register (single transaction: tenant + user). 

### Phase 8D/E — Management GUIs
AgentManagement.tsx + UserManagement.tsx + backend routes.

### Phase 8F — MinIO Webhook Upload Model
Replaced BatchAgent entirely. mc mirror --watch (Dropbox model).
POST /internal/minio-event → Call row → Celery chain.
No polling, no SQLite, no watchdog container. [[59_Session_Handoff_2026-05-18]]

### Phase 8G — PLATFORM_ADMIN + Tenant Management
TenantManagement.tsx. GET/POST /platform/tenants. PLATFORM_ADMIN role seeded.

### Phase 8H — Pre-Azure Security Audit
PyJWT (replaced python-jose CVE), Redis requirepass, slowapi rate limiting, 
write_scores scoped DELETE, CORS from env, image pins. [[61_Pre_Azure_Security_Audit]]

### Phase 8I — UI P0+P1 Accessibility
Contrast fixes (WCAG AA), text-[9px]→[10px], dark mode token gaps, ARIA labels,
score badge semantic colors, PDF export button in drawer, transcript fallback.

### Phase 8J/K — PLATFORM_ADMIN Dashboard + RLS Bypass
5 pages: PlatformOverview, SystemHealth, UsageAnalytics, CallMonitor, Tenants.
Migration 008: app.platform_bypass session variable in all RLS policies.
get_db_platform dependency. Figma AI design → Antigravity build.

### Phase 8L — Azure Deployment Prep
frontend/Dockerfile (multi-stage Node→nginx), infra/nginx.conf,
infra/docker-compose.prod.yml, backend/Dockerfile spaCy wheel fix.

---

## Phase 9 — Azure Canada Central Deployment (IN PROGRESS)

**Region:** Canada Central — PIPEDA compliance
**Architecture:** Single VM + Docker Compose (GPU on same machine)

### Checklist
- [x] All deployment files written
- [x] spaCy wheel downloaded locally (DNS timeout workaround)
- [ ] Docker prod build passes
- [ ] Local smoke test (Playwright)
- [ ] .env.prod secrets rotation
- [ ] PLATFORM_ADMIN password rotation
- [ ] MinIO image pinned
- [ ] Azure VM provisioned (Canada Central, ports 80/443)
- [ ] Deploy + E2E test

---

## Phase 10 — ROI Reporting (Post-Azure)

South Asian enterprise buyers need a business case before committing.
Build a one-page ROI report from real processed calls:
- "Your manual QA caught X of the 5 worst calls. Here are 3 that were missed."
- Processing cost per call vs manual review cost per call
- Score distribution over time (agent improvement trend)

This is the sales tool, not a feature. Build it from real customer calls.

---

## Phase 11 — Agentic AI Assistant (Post-ROI)

NL query layer over PostgreSQL.
"Show me agents who declined more than 20% this month"
"Which issue categories have the worst resolution rates?"

Channel TBD: web widget, WhatsApp, or Slack integration.

---

## Phase 12 — Urdu/English ASR (Post-Revenue)

Language ID router at segment level (fastText):
- English segments → WhisperX large-v2
- Urdu segments → dedicated Urdu ASR model
- Code-switched → Meta SeamlessM4T

QLoRA fine-tuning deferred until 50+ hours of BPO audio available.

---

## Deferred / Cancelled

| Item | Status | Reason |
|---|---|---|
| BatchAgent watchdog container | Cancelled | Replaced by MinIO webhook model (May 2026) |
| Azure B2s (original) | Cancelled | Credits exhausted. New VM being provisioned. |
| Scoring weights configurable per tenant | Backlog | Post-first-customer |
| LLM score variance testing (run same call 20x) | Backlog | Pre-production |
| CRM integration | Deferred | Post-first-customer |
| Mobile supervisor app | Deferred | Post-revenue |
| Stitch UI overhaul | Deferred | Design received, not prioritised |

---

## Pricing Note

$15–20/agent/month is South Asian market pricing.
Canadian/Western B2B SaaS: $50–150/seat is normal.
Revisit before first non-South-Asian pitch.
South Asia sales motion: relationship-based, not self-serve.
Build ROI report from real calls before adding any features.
