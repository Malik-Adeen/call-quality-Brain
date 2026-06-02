# Pre-Deployment Security Audit — 2026-05-10

Codebase: `E:\projects\call-quality-analytics`
Graph: `graphify-out/graph.json`
Method: 5 parallel agents via graphify query + static analysis + live curl probes

---

## AGENT 1 — ROLE ENFORCEMENT

**PASS**
- `backend/app/routers/calls.py:345` — POST /calls/upload — `require_role("TENANT_ADMIN","SUPERVISOR")` blocks VIEWER
- `backend/app/routers/agents.py:89` — POST /agents/sync — blocks VIEWER
- `backend/app/routers/agents.py:404` — PATCH /agents/{id} — blocks VIEWER
- `backend/app/routers/agents.py:494` — DELETE /agents/{id} — blocks VIEWER
- `backend/app/routers/users.py:29` — GET /users — `require_role("TENANT_ADMIN")` only
- `backend/app/routers/users.py:65` — POST /users/invite — `require_role("TENANT_ADMIN")` only
- `backend/app/routers/users.py:147` — DELETE /users/{id} — `require_role("TENANT_ADMIN")` only

**FAIL**
- `backend/app/routers/agents.py:344` — POST /agents — SUPERVISOR is permitted; audit rule requires TENANT_ADMIN-only. SUPERVISOR can create agents. Policy disagreement or code bug — must be confirmed with product owner.
- `backend/app/routers/reports.py:152` — POST /reports/export — `Depends(get_current_user)` only, **no role check**. VIEWER with valid JWT can export full PDF (redacted transcript + coaching summary) for any call in their tenant. **Hard security defect.**

CURL_TESTS: SERVER_UNREACHABLE (live DB users unavailable; code-path analysis substituted)

---

## AGENT 2 — RLS ENFORCEMENT

**PASS**
- `backend/alembic/versions/20260501_enable_rls_and_update_roles.py:41-84` — RLS ENABLE + tenant isolation policies on all 5 tables (users, agents, calls, call_metrics, sentiment_timeline). Policy uses `NULLIF(current_setting('app.current_tenant', true), '')::uuid` — empty-string tolerant.
- `backend/alembic/versions/20260501_force_rls.py:20-21` — FORCE ROW LEVEL SECURITY on all 5 tables; superuser/table-owner also subject to policy.
- All Celery pipeline tasks (`tasks.py:33,84,217,247,280,311,324,347,410,456,475`) — SET LOCAL inside explicit `with db.begin():`. Per-transaction scope correct throughout pipeline.
- `backend/app/routers/calls.py:67-386` — All /calls endpoints use `get_db_with_tenant`; ORM queries double-filter by `tenant_id == current_user.tenant_id`.
- `backend/app/routers/agents.py:169-432` — All /agents endpoints use `get_db_with_tenant`; all queries bind `tenant_id` from authenticated user.
- `backend/app/routers/reports.py:156-183` — export_call_pdf filters Call, Agent, CallMetrics by `current_user.tenant_id`.
- `backend/app/routers/users.py:32` — list_users filters by `current_user.tenant_id`.
- `backend/app/routers/users.py:167-172` — delete_user filters by `current_user.tenant_id`.

**FAIL**
- `backend/app/database.py:55-62` — **CRITICAL** — `get_db_with_tenant` calls `SET LOCAL app.current_tenant = :tid` outside an active transaction. AsyncSession (asyncpg autobegin) does not open a PostgreSQL transaction until first DML/query. `SET LOCAL` issued before any query has no active transaction, and silently degrades to session-level `SET` on some asyncpg versions. Tenant context may persist across pooled connections → cross-tenant data leakage. Fix: wrap SET LOCAL inside `async with db.begin():` or ensure a transaction is explicitly started first.
- `backend/app/routers/users.py:112` — Email uniqueness check `select(User).where(User.email == email)` has no `tenant_id` filter. With the SET LOCAL timing bug, RLS may not be active at query time → cross-tenant email oracle. Also blocks valid registration if the same email exists in another tenant.

**LOW / INFO**
- `backend/app/auth/dependencies.py:27` — `get_current_user` uses bare `get_db` (no tenant context). Users table has FORCE RLS. Works only if the DB role has BYPASSRLS — meaning the same credential bypasses RLS everywhere. Should be verified: if BYPASSRLS is granted to the app role, RLS is purely application-layer.

CROSS_TENANT_TEST: FAIL (MISCONFIGURED_JWT — live two-tenant test not possible read-only)

---

## AGENT 3 — PIPELINE INVARIANTS

**PASS**
- `backend/app/routers/calls.py:415-421` — CHAIN_ORDER matches invariant exactly:
  `run_whisperx → extract_agent_identity → redact_pii → compute_talk_balance → run_groq_inference → write_scores → notify_websocket`
  `extract_agent_identity` (line 416) confirmed before `redact_pii` (line 417).
- `backend/app/pipeline/tasks.py:351-352` — PII_GATE: `run_groq_inference` raises `ValueError("Call {call_id} pii_redacted is False - refusing inference")` if `pii_redacted` is not True.
- `backend/app/pipeline/tasks.py:437-452` — WRITE_SCORES_IDEMPOTENCY: DELETE of CallMetrics + DELETE of SentimentTimeline before INSERT, all inside single `db.begin()` transaction. No UPSERT.
- `backend/app/pipeline/tasks.py:307` — TALK_BALANCE_FORMULA: `round(1.0 - abs(agent_ratio - 0.5) * 2, 4)` — algebraically identical to `1 - 2 * abs(agent_ratio - 0.5)`. PASS.
- `backend/app/pipeline/tasks.py:24` / `infra/docker-compose.yml:127` — GPU_QUEUE: `queue="gpu_queue"`, worker launched with `--concurrency=1 --max-tasks-per-child=1`. Belt-and-suspenders route in `backend/app/celery_app.py:13`.

**ADVISORY (non-blocking)**
- `scripts/build_graph.py:154-162` — Stage list omits `extract_agent_identity` (jumps run_whisperx → redact_pii). Documentation drift only; live chain is correct. Update script to insert stage and renumber.

CHAIN_ORDER: PASS | PII_GATE: PASS | WRITE_SCORES_IDEMPOTENCY: PASS | TALK_BALANCE_FORMULA: PASS | GPU_QUEUE: PASS

---

## AGENT 4 — FRONTEND ROLE GATES

**PASS**
- `frontend/src/store/auth.ts:29` — JWT stored via Zustand persist with `createJSONStorage(() => sessionStorage)`. Not localStorage.
- `frontend/src/api/client.ts:9` — Token read from Zustand store state. No localStorage read.
- `frontend/src/components/Sidebar.tsx:38` — /agents/manage sidebar link hidden for VIEWER (`isAdmin = TENANT_ADMIN || SUPERVISOR`).
- `frontend/src/components/Sidebar.tsx:39` — /users sidebar link hidden for non-TENANT_ADMIN.
- localStorage only contains `'theme'` key (Sidebar.tsx:22,25) — no auth/token data.

**FAIL**
- `frontend/src/components/Sidebar.tsx:139` — "NEW ANALYSIS" button navigates to /upload with no role check. VIEWER sees and can use it.
- `frontend/src/App.tsx:71` — /upload route has no role guard. `ProtectedLayout` checks token presence only, not role.
- `frontend/src/App.tsx:69` — /agents/manage route has no role guard. VIEWER can navigate directly to URL and access AgentManagement.tsx fully.
- `frontend/src/App.tsx:70` — /users route has no role guard. Non-TENANT_ADMIN can navigate directly to URL and access UserManagement.tsx fully.

JWT_STORAGE: sessionStorage — PASS
UPLOAD_GATE: FAIL — Sidebar.tsx:139, App.tsx:71
AGENTS_MANAGE_GATE: FAIL (route) — App.tsx:69
USERS_GATE: FAIL (route) — App.tsx:70
LOCALSTORAGE_VIOLATIONS: NONE (theme only)

Note: All three protected pages rely solely on sidebar link hiding. No `<RoleGuard>` or role-checked wrappers exist on routes in App.tsx. Backend RBAC is last line of defense — it appears sound, but frontend provides no route-level enforcement.

---

## AGENT 5 — BATCHAGENT

**PASS**
- `batch_agent/main.py:41-49` — DEDUP_SHA256: SHA-256 via 64 KB chunk reads, hex digest stored in `/data/{tenant}_checksums.json`. Duplicate check at line 164 before upload; hash persisted only on HTTP 202 success (line 190-191).
- `batch_agent/main.py:15,94` — RETRY_LOGIC: Fixed delays `[5, 30, 120]` seconds, 3 attempts max. 401 → token refresh + immediate continue. 400/422 → no retry (correct). Startup auth: 10-attempt schedule.
- `batch_agent/main.py:13-14` — FILE_VALIDATION (extensions + size): Allowed `{.wav, .mp3, .m4a}`, 100 MB limit enforced at line 154.
- `batch_agent/main.py:237` / `main.py:223` — SEMAPHORE_LIMIT: `asyncio.Semaphore(4)` per tenant (env default 4).

**FAIL**
- `batch_agent/main.py:179-185` — AGENT_ID_ABSENT: FormData posted to `/calls/upload` contains only `"file"` field. Neither `agent_id` nor `needs_agent_review` is ever sent. Spec (CLAUDE.md) states: when agent_id absent, `needs_agent_review=True, agent_id=NULL` must be passed. Backend must compensate entirely — batch agent spec violated.
- `batch_agent/main.py:184` — FILE_VALIDATION (magic bytes): No MIME/magic-byte check. `content_type` hardcoded to `application/octet-stream`. A file named `evil.wav` with non-audio content passes all client-side checks.
- `batch_agent/tenants.json:5,11` — **HARDCODED CREDENTIALS**: Plaintext passwords (`admin1234`, `bpo1234`) committed to repo. File not in `.gitignore`. `docker-compose.yml:185` mounts it as live credential source. **Rotate immediately. Add to `.gitignore`. Move to Docker secrets or env-injected file outside repo.**

**INFO**
- Checksum store is flat JSON, not SQLite as CLAUDE.md states. Spec drift — no security impact.
- `RETRY_DELAYS[2] = 120` is defined but unreachable (dead value).
- Semaphore is per-tenant; with N tenants, effective global concurrency = 4 × N, not 4.

DEDUP_SHA256: PASS | RETRY_LOGIC: PASS | FILE_VALIDATION: FAIL (no magic bytes) | AGENT_ID_ABSENT: FAIL | SEMAPHORE_LIMIT: PASS | HARDCODED_CREDS: FAIL — tenants.json:5,11

---

## Consolidated Risk Register

| Severity | Agent | Location | Issue |
|----------|-------|----------|-------|
| CRITICAL | 2 | database.py:55-62 | SET LOCAL outside transaction → tenant context leaks across pooled connections |
| CRITICAL | 5 | tenants.json:5,11 | Plaintext passwords committed to repo |
| HIGH | 1 | reports.py:152 | POST /reports/export — no role check — VIEWER can export full call PDFs |
| HIGH | 5 | main.py:179-185 | agent_id / needs_agent_review never sent by batch agent |
| HIGH | 5 | main.py:184 | No magic-byte file validation — non-audio accepted |
| MEDIUM | 1 | agents.py:344 | POST /agents allows SUPERVISOR — policy ambiguity |
| MEDIUM | 2 | users.py:112 | Email uniqueness check missing tenant_id filter — cross-tenant oracle |
| MEDIUM | 4 | App.tsx:69,70,71 | /upload, /agents/manage, /users routes have no role guards |
| MEDIUM | 4 | Sidebar.tsx:139 | Upload button visible to VIEWER |
| LOW | 2 | auth/dependencies.py:27 | get_current_user uses bare get_db — relies on BYPASSRLS |
| LOW | 3 | scripts/build_graph.py:154-162 | Stage list missing extract_agent_identity |
| INFO | 5 | main.py:15 | RETRY_DELAYS[2] = 120 unreachable |
| INFO | 5 | tenants.json / CLAUDE.md | Checksum store is JSON, spec says SQLite |

---

## Required Actions Before Deploy

1. **BLOCK**: Fix `database.py` SET LOCAL timing — wrap inside explicit transaction begin.
2. **BLOCK**: Add `require_role("TENANT_ADMIN","SUPERVISOR")` to `POST /reports/export`.
3. **BLOCK**: Rotate `tenants.json` credentials, add to `.gitignore`, move to secrets.
4. **BLOCK**: Add `needs_agent_review` / `agent_id=NULL` to batch agent upload POST.
5. **HIGH**: Add `<RoleGuard role="non-VIEWER">` wrapper to `/upload` route in App.tsx.
6. **HIGH**: Add `<RoleGuard>` to `/agents/manage` and `/users` routes in App.tsx.
7. **HIGH**: Add magic-byte/MIME validation in batch_agent before upload.
8. **MEDIUM**: Clarify SUPERVISOR agent-create policy; update `require_role` at agents.py:344 accordingly.
9. **MEDIUM**: Add `tenant_id` filter to email uniqueness query at users.py:112.
10. **LOW**: Fix build_graph.py stage list to include extract_agent_identity.
