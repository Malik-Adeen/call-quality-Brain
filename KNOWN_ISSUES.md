# KNOWN ISSUES — AI Call Quality Analytics System

> Authoritative issue tracker for the SaaS product. Updated after each audit session.
> Last updated: 2026-07-15 (uv/model migration, master). Active branch: deploy/fahad-demo.

---

## P0 — Fixed

| Finding | Description | Commit |
|---|---|---|
| H1 | `upload_audio` object key included bucket name as prefix — all presigned URLs 404'd | c5d8452 |
| H2 | `chain().apply_async()` unguarded after `db.commit()` — Redis outage orphaned calls in "pending" forever | c5d8452 |
| H3 | `get_db_with_tenant` GUC lost after `db.commit()` — `db.refresh()` in users.py + agents.py (4 routes) ran without RLS context | b331932 |
| M1 | `/reports/export` launched full Chromium per request with no rate limit — DoS vector | b331932 |
| M2 | `create_tenant` used `get_db` not `get_db_platform` — `db.refresh()` ran without platform bypass | b331932 |
| M3 | `WHISPER_MODEL` not enforced in compose files — defaulted to `"base"` if env var missing | b331932 |
| M4 | Transcript injected into LLM prompt with XML demarcation — `</transcript>` escape breakable | 9aa70a5 |
| M5 | Speaker role heuristic assigned AGENT to first speaker by appearance — wrong if customer speaks first | b331932 |
| Dedup | `upload_call` used random UUID filename — same file produced new Call row on every upload | 9aa70a5 |
| L1 | `expires_in` in login/register response hardcoded to 28800 — `JWT_EXPIRY_SECONDS` env var ignored | eff0683 |
| L2a | No email format validation on `/auth/register` or `POST /users/invite` | eff0683 |
| L2b | Email uniqueness check in `invite_user` lacked `tenant_id` filter — cross-tenant oracle | Already fixed (prior session) |
| L3 | `== True` / `== False` in SQLAlchemy filter expressions (3 sites) | eff0683 |
| L4 | `InferenceResult.coaching_summary` had no non-empty validator — LLM could store `""` silently | 4b3a84a |
| L5 | `InferenceResult.issue_category` was untyped `str` — LLM hallucinated categories stored without validation | 4b3a84a |
| Auth RLS at login | Pre-existing RLS bug: login endpoint has no tenant context → RLS filters all users → 401 after full container restart | deploy/fahad-demo auth.py |
| CT2 cuDNN mismatch (Blackwell) | CT2 4.4.0 linked cuDNN 8; CUDA 12.8 base image ships cuDNN 9 → SIGABRT | deploy/fahad-demo Dockerfile.gpu.blackwell |
| PyTorch 2.7 weights_only | `torch.load` defaults changed to `weights_only=True`; pyannote omegaconf types blocked | deploy/fahad-demo whisper_service.py |

---

## Found 2026-07-12 — Test Suite Audit (Untriaged)

- **Webhook route hardening (possible PROD bug)** — `/internal/minio-event` calls `async with db.begin()` assuming a fresh session — robust in prod (fresh DI session) but same shape as the 2026-05-10 audit CRITICAL (premature begin / SET LOCAL timing). The DB-write path was UNTESTED until this session (empty MINIO_WEBHOOK_SECRET made auth always fail, masking it). Candidate fix: begin_nested / in_transaction() guard. Decision pending — route vs harness.
- **Test harness session-sharing flaw** (root of 3 failing tests) — `conftest.py`'s `db_session` fixture hands ONE transaction-active async session to both the test body and the route-under-test via `dependency_overrides`, diverging from production (routes get a fresh DI session; Celery workers use SYNC sessions). See 68_Session_Handoff_2026-07-12.md for full symptom breakdown.
- **av/FFmpeg scoping CORRECTION**: prior claim "confined to Dockerfile.cpu, unrelated to resolver" is WRONG. av 11.0.0 is sdist-only (no wheels, any platform), forced by faster-whisper==1.0.0; blocks `uv lock` on any FFmpeg>=7 host. Resolved via `tool.uv.dependency-metadata`.
- **Stale mock_self test bug class** (3 instances; 1 unfixed) — redundant `mock_self` passed as a 5th arg to `bind=True` Celery tasks in tests; Celery already auto-injects `self`. 2 fixed (write_scores tests), 1 unfixed (test_pii_gate_blocks_groq_when_not_redacted). PII gate itself was never exercised by the failing test — not a safety-guard failure.

---

## Found 2026-07-15 — uv/model migration session

- **agent_identity.py has no Pydantic validation** — uses raw `json.loads` on the Groq response with no schema/validator, unlike llm_client.py's Pydantic-validated `InferenceResult` path. More fragile under a reasoning model (gpt-oss-120b) than the validated path. Structured-output hardening deliberately deferred.
- **Two hand-rolled httpx LLM callers with duplicated fallback logic + divergent parsing** — llm_client.py and agent_identity.py each reimplement their own Groq/OpenRouter HTTP call, retry, and parse logic. Real tech debt; should be one shared client. Not refactored this session — out of scope.
- **CI will be RED on first master run** — 4 known test failures (see 69_Session_Handoff_2026-07-15.md for root cause). Expected, not a regression; ci.yml's `main→master` branch fix means this is the first time push CI has ever actually fired on master.

---

## P1 — Before First Paying Customer

- **API key separation + ZDR confirmation** — single shared Groq API key; no per-tenant key isolation; Zero Data Retention not confirmed with Groq for customer audio transcripts
- **Presidio South Asian PII** — CNIC numbers, Urdu names, Pakistani phone formats not in Presidio recognizer set; call centers in Pakistan/India will leak these
- **Scoring weights tenant-configurable** — currently hardcoded (0.25/0.20/0.20/0.15/0.20); enterprise customers will want to adjust weights per use case
- **Redis AOF persistence verification** — AOF enabled in compose but not verified in deployment; Redis restart without AOF = silent task queue loss

---

## P1 — Before First Unsupervised External Trial

- **M5 speaker inversion edge case** — duration heuristic is robust but can still invert if customer dominates call (complaint calls). Control demo audio as mitigation; fix requires two-pass diarization alignment.

---

## P2 — Before GA

- **L6 — external_agent_id max-length** — `AgentCreateRequest.external_id` and `AgentSyncItem.external_id` have no `max_length`; unbounded text on an indexed column degrades at scale. Fix: `Field(None, max_length=100)` in both Pydantic models + optional DB migration. Two-liner.
- **Playwright browser pool** — one Chromium process per PDF export request; rate-limited to 5/min as mitigation; move to Celery `io_queue` task before concurrent export load becomes real.
- **dedup constraint removed in deploy/fahad-demo** — `uq_calls_tenant_audio_path` dropped for demo usability. Same file can now create multiple Call rows. Must re-evaluate before first paying customer — either re-add constraint with proper UI duplicate handling, or implement soft dedup in application layer.
- **auth.py RLS bypass scope** — `platform_bypass=true` covers the full login transaction. Correct long-term fix: `get_db_no_rls` dependency scoped to auth endpoints only.
- **infra/.env secret management** — `infra/.env` contains live secrets and must not be committed. Verify `.gitignore` coverage. Both `.env` and `.env.prod` must stay in sync for every secret rotation — `.env` silently wins on docker compose when both files are present.

---

## Accepted / Won't Fix

| Item | Reason |
|---|---|
| **D2 — JWT in WebSocket URL** (`?token=`) | Explicitly deferred in two separate audits (GPT-5 April 2026, consolidated May 2026). Low risk over HTTPS. Sec-WebSocket-Protocol workaround is non-standard. Accepted for v1. |
| **PERF3 — Playwright per-request pool** | Deferred to Azure deploy. Rate limit (5/min) is the mitigation at current scale. |
| **Raw transcript sent to Groq in `extract_agent_identity`** | BY DESIGN — `extract_agent_identity` must precede `redact_pii`. Agent names would be redacted as `<PERSON>` if Presidio ran first. Accepted tradeoff. |
| **Whisper model loaded fresh per call** | CORRECT by design — `--max-tasks-per-child=1` restarts GPU worker after each task to prevent VRAM leaks. Cross-task model caching is impossible and undesirable. |

---

## Demo Risks (Controlled)

| Risk | Status | Mitigation |
|---|---|---|
| M4 prompt injection via transcript | Fixed (`9aa70a5`) | `sanitize_transcript()` strips XML injection tags before LLM prompt |
| Upload dedup — double-click creates duplicate calls | Fixed (`9aa70a5`) | SHA-256 filename + IntegrityError handler returns existing Call |
| Speaker label inversion | Active — controlled | Use demo audio where agent speaks first AND longer; duration heuristic handles it |
| RTX 5060 Blackwell CUDA compatibility | Resolved | CT2 4.8.0 + CUDA 12.8 base image + PyTorch monkeypatch. Full pipeline working. See 64_Fahad_Demo_Deployment_Postmortem.md. |
| WhisperX large-v2 first-run model download (~3 GB) | Active — timing risk | Budget 10-15 min for first container start; pre-pull on demo machine the night before |
| Audio playback broken in frontend | Active | H1 backend fix applied; frontend disabled due to CORS. Do not demo audio playback until CORS confirmed on demo hostname. |
