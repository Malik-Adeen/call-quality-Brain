---
tags: [audit, pre-deployment, claude-code, sub-agents]
date: 2026-05-08
status: pending — do after BatchAgent live test passes
---

# 45 — Pre-Deployment Role-Based Audit Plan

> Final quality gate before Azure deployment.
> Do NOT run until BatchAgent live test is confirmed passing.
> Orchestrated via Claude Code sub-agents in terminal.

---

## Trigger Condition

All of the following must be true before running this audit:
- BatchAgent live test passes (8-step checklist in doc 44)
- Full local stack confirmed running (all 8 containers healthy)
- reset_and_seed.py run successfully (200 calls, 2 tenants)
- git status clean (everything committed)

---

## What Gets Audited (5 domains)

### 1. Role Enforcement — API Layer
Every endpoint tested against every role.

| Endpoint | TENANT_ADMIN | SUPERVISOR | VIEWER |
|---|---|---|---|
| POST /calls/upload | ✓ allowed | ✓ allowed | ✗ 403 |
| POST /agents | ✓ allowed | ✗ 403 | ✗ 403 |
| PATCH /agents/{id} | ✓ allowed | ✗ 403 | ✗ 403 |
| DELETE /agents/{id} | ✓ allowed | ✗ 403 | ✗ 403 |
| GET /users | ✓ allowed | ✗ 403 | ✗ 403 |
| POST /users/invite | ✓ allowed | ✗ 403 | ✗ 403 |
| DELETE /users/{id} | ✓ allowed | ✗ 403 | ✗ 403 |
| GET /calls | ✓ allowed | ✓ allowed | ✓ allowed |
| GET /calls/{id} | ✓ allowed | ✓ own team | ✓ allowed |
| POST /reports/export | ✓ allowed | ✓ allowed | ✗ 403 |
| Unauthenticated | ✗ 401 all routes | ✗ 401 | ✗ 401 |

### 2. RLS Enforcement — Database Layer
Tenant A JWT actively attempts to retrieve Tenant B data.
RLS must block at DB level even if application layer passes it through.

- GET /calls — Tenant A token requesting Tenant B call IDs
- GET /calls/{id} — Tenant A token with known Tenant B UUID
- GET /agents/{id}/scores — cross-tenant agent UUID
- GET /users — must return only Tenant A users

Expected: 404 or empty result. Never 200 with Tenant B data.

### 3. Pipeline Invariants
- extract_agent_identity runs BEFORE redact_pii
- pii_redacted=TRUE set before run_groq_inference executes
- run_whisperx only dispatched to gpu_queue
- write_scores is idempotent — safe to call twice, no duplicate metrics
- Talk balance formula: 1 - 2 * abs(agent_ratio - 0.5)
- Score stored 0-10, displayed x10 in UI

### 4. Frontend Role Gates
- Upload button absent for VIEWER role
- AgentManagement route returns 403 redirect for SUPERVISOR
- UserManagement route returns 403 redirect for SUPERVISOR and VIEWER
- Register page accessible only when unauthenticated
- JWT confirmed in sessionStorage, absent from localStorage

### 5. BatchAgent
- SHA-256 dedup: same file dropped twice = silent skip in logs
- Bad extension (.txt, .pdf) = immediate skip, no retry, no checksum save
- File >100MB = immediate skip, error log, no retry
- Retry delays: 5s → 30s → 120s on API failure
- Health endpoint: GET http://localhost:8080/health returns 200 "ok"
- agent_id absent from upload POST (confirmed in network logs)

---

## Claude Code Sub-Agent Structure

Run from project root inside Claude Code session:

```
Orchestrator prompt:

You are running a pre-deployment audit of this codebase.
Spawn 5 parallel sub-agents. Each audits one domain and returns
a structured pass/fail report with file and line references for failures.

Agent 1 — Role Enforcement
  Read backend/app/routers/*.py and backend/app/auth/dependencies.py.
  Verify every endpoint has correct role decorators.
  Test against live stack at localhost:8000 using curl with JWT tokens
  for each role (TENANT_ADMIN, SUPERVISOR, VIEWER).
  Return: PASS or list of endpoints with wrong/missing role checks.

Agent 2 — RLS Enforcement
  Read backend/app/database.py and backend/app/pipeline/tasks.py.
  Verify SET LOCAL app.current_tenant is called per transaction.
  Test cross-tenant data access using Tenant A JWT against Tenant B UUIDs.
  Return: PASS or list of data leakage paths found.

Agent 3 — Pipeline Invariants
  Read backend/app/pipeline/tasks.py.
  Verify chain order, pii gate, idempotency, talk balance formula.
  Return: PASS or list of invariant violations with line numbers.

Agent 4 — Frontend Role Gates
  Read frontend/src/App.tsx, frontend/src/pages/*.tsx,
  frontend/src/store/auth.ts.
  Verify role-conditional rendering and JWT storage location.
  Return: PASS or list of missing gates with component names.

Agent 5 — BatchAgent
  Read batch_agent/main.py.
  Verify dedup logic, retry delays, file validation order,
  absence of agent_id in upload call.
  Drop test files into watch folder and verify behaviour in logs.
  Return: PASS or list of spec violations with line numbers.

Collate all 5 reports into audit_report_YYYYMMDD.md in E:\projects\docs\.
```

---

## Research Round (run before building orchestrator)

Paste to each model when ready:

**Perplexity**
"What does a standard pre-deployment security audit checklist look like
for a B2B SaaS app with RBAC hosted on Azure PostgreSQL?
What do multi-tenant apps typically miss before first production deployment?"

**DeepSeek + GLM**
Paste: backend/app/routers/calls.py + pipeline/tasks.py + models/orm.py
Ask: "Review for security gaps, missing role checks, RLS bypasses,
pipeline ordering issues. Specific file and line numbers only."

**Gemini**
"Generate edge case test scenarios for a multi-tenant call quality system
with TENANT_ADMIN, SUPERVISOR, VIEWER roles. Focus on cross-tenant
data leakage and role escalation attempts."

**Codex**
"Write pytest test suite covering role enforcement for these FastAPI
endpoints. Each test uses a separate JWT per role.
Assert correct HTTP status codes and response shapes."
(paste 03_API_Contract.md as context)

---

## Pass Criteria

All 5 agents return zero failures.
Any failure = fix before deployment. No exceptions.
Audit report saved to E:\projects\docs\audit_report_YYYYMMDD.md.
Share with supervisor as evidence of pre-deployment quality gate.
