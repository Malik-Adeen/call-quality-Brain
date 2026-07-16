# KNOWN ISSUES — AI Call Quality Analytics System

> Authoritative issue tracker for the SaaS product. Updated after each audit session.
> Last updated: 2026-07-16 (Cloudflare Tunnel deployment, Fahad demo machine). Active branch: deploy/fahad-demo.

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

## Found 2026-07-15 (session 2) — Fahad demo machine (Groq key fix, gpt-oss model port, batch upload)

All items below exist on master too — fixed (or mitigated) only on deploy/fahad-demo this session.

- **`run_inference` retry loop is dead code** — introduced by `9143a8e`. The loop logs "retrying" then `break`s to the next provider — `max_retries` never applied. Fix: `continue` before the `break` when `attempt < max_retries - 1`. Needs a scoped port to master.
- **gpt-oss + `response_format` strict:true + `reasoning_effort:"low"` → ~40% `json_validate_failed`** — measured 2/5 failures on identical input. Model emits literal `0. nine` instead of `0.9`; Groq's schema validator rejects it. `reasoning_effort:"low"` is the suspect (added untested by `9143a8e`). `medium` is untested — all 5 probes hit 429 (TPM exhausted). Retest on the dev box. Current mitigation is `max_retries=4` → ~2.6% residual failure — a mitigation, not a fix.
- **`temperature:0.0` is actively harmful with this failure mode** — greedy decoding makes the fumble deterministic, so retries don't help (one call failed 4/4 identically). Reverted to 0.2. Promoted to INVARIANTS.md: retry-based recovery requires nonzero temperature.
- **`OPENROUTER_API_KEY` invalid on the demo machine** (401) — no fallback leg. Every `json_validate_failed` that exhausts retries is a hard call failure. Fix before demo.
- **CORRECTED — "diarization collapse on Blackwell" was a gTTS test-fixture defect, not a Blackwell/pyannote bug.** Originally logged here as highest-priority/demo-blocking. Re-examined: same worker, same GPU, same run — `agent_identity_priya.mp3` diarized correctly (AGENT and CUSTOMER both present) while `agent_identity_marcus.mp3` collapsed to all-AGENT. Per-file, not per-machine — Blackwell is exonerated. Root cause: `scripts/generate_test_audio.py` generates fixtures with gTTS using accent variants only (`tld="com"` agent, `tld="com.au"` customer) — same synthesis engine, same underlying voice; pyannote's speaker embeddings cannot reliably separate them, so reporting one speaker on these fixtures is correct behavior, not a bug. The `std(): degrees of freedom is <= 0` pyannote warning is a symptom of single-speaker input, not a cause. Real customer audio (two humans) will not reproduce this — not a production bug. Moved to test-data known-issues below; see also Demo Risks table for the actual risk this exposed (talk_balance_score masking).
- **Test-data limitation — gTTS fixtures cannot exercise two-speaker diarization.** `scripts/generate_test_audio.py` synthesizes both AGENT and CUSTOMER fixture audio from the same gTTS engine and voice, varying only the `tld` accent parameter (`com` vs `com.au`). Pyannote's speaker-embedding model cannot reliably distinguish these as two speakers and will legitimately collapse some fixture files (e.g. `agent_identity_marcus.mp3`) to a single AGENT label. This is a fixture-generation gap, not a pipeline defect — real two-human call audio is unaffected. Fix would require distinct TTS voices (different engine or speaker embedding) per role if two-speaker fixture tests are needed.
- **`UploadCall.tsx` hardcodes `MAX_FILE_SIZE = 50MB`** (3 call sites) vs. `calls.py:347`'s 100MB limit — frontend rejects files the backend accepts. `BatchUpload.tsx` (new this session) uses the correct 100MB; `UploadCall.tsx` not fixed.
- **Three different Groq API keys were live across containers simultaneously** on Fahad's box, because `docker-compose.app.yml` (`cq_api`, `cq_worker_io`) and `docker-compose.gpu.yml` (`cq_worker_gpu`) load env differently — see the corrected `infra/.env secret management` entry above. Root-caused and fixed this session; verify with `docker exec <container> printenv GROQ_API_KEY`, not by reading files.

## Found 2026-07-16 — Cloudflare Tunnel deployment (Fahad demo machine)

`call-qa.tech` is now live via Cloudflare Tunnel, replacing Tailscale Funnel as the public URL
(Tailscale Funnel was already off before this session — nothing to decommission). Full account
of the deployment: 70_Session_Handoff_2026-07-15.md, STEP 3.

- **`cloudflared` Windows service installs with no arguments and silently crash-loops** — no cause
  logged anywhere. Fixed via direct registry edit of the service's `ImagePath`; regresses on every
  reinstall/upgrade of the service. Promoted to INVARIANTS.md ("Windows Service Deployment —
  cloudflared") since it is a re-breakable rule, not a one-off finding.
- **Wrong-account `cert.pem` silently misroutes `tunnel route dns`** — Fahad's box had a leftover
  cert for a different Cloudflare account (`axion`/`harba.net`), so the first `route dns` attempt
  created `call-qa.tech.harba.net` instead of `call-qa.tech` with no error. Always check the CNAME
  in the `route dns` output. Orphan tunnel `call-qa` (`d568bb22`) left on the `harba.net` account —
  harmless, delete when convenient.
- **Docker Desktop 500s on port rebind** — `"ports are not available ... /forwards/expose returned
  unexpected status: 500"` when changing a published port on a running service; `compose up -d`
  alone doesn't clear it, needs `compose rm -sf <service>` then `up -d` (scoped to the one
  service, not `--force-recreate`).
- **CLOSED — internal ports on `0.0.0.0`.** `infra/docker-compose.app.yml:131` (nginx port 80),
  the last remaining `0.0.0.0`-bound port on the stack, moved to `127.0.0.1:80:80` (commit
  `28ee65d`). Closes the "(except nginx port 80)" exception that previously lived in
  INVARIANTS.md's port rule.
- **CLOSED — `CORS_ORIGINS` had a stray `http://localhost:5173` Vite-dev origin in
  `infra/.env.prod`.** Now `https://call-qa.tech` only.
- Unrelated finding, flagged not fixed: Fahad's machine also runs a Caddy instance
  (`D:\claude\axion\infrastructure\https\caddy.exe`) listening on `192.168.8.10:8000` with live
  external connections from non-LAN IPs. Belongs to a different project — flagged to Fahad, not
  touched here.

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
- **infra/.env secret management** — `infra/.env` contains live secrets and must not be committed. Verify `.gitignore` coverage. Both `.env` and `.env.prod` must stay in sync for every secret rotation. **CORRECTED 2026-07-15 (session 2):** the prior claim here — "`.env` silently wins on docker compose when both files are present" — is wrong for the app.yml stack. Precedence is per-invocation: whichever `--env-file` flag (if any) that container's compose command passes wins. On Fahad's box, `cq_api` and `cq_worker_io` (`docker-compose.app.yml --env-file infra/.env.prod`) read `.env.prod`; `cq_worker_gpu` (`docker-compose.gpu.yml`, no `--env-file` flag) reads `.env` by default. Editing one file does not reliably reach all containers. Always verify with `docker exec <container> printenv <VAR> | cut -c1-6`, never by reading files. See 70_Session_Handoff_2026-07-15.md.

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
| Audio playback broken in frontend | Active | H1 backend fix applied; frontend disabled due to CORS. Do not demo audio playback until CORS confirmed on demo hostname. **Note 2026-07-16:** `CORS_ORIGINS` is now scoped to `https://call-qa.tech`, the current demo hostname — the precondition this risk names may now be met, but audio playback itself was not re-tested this session. Verify before assuming resolved. |
| talk_balance_score is structurally meaningless on single-speaker diarization | Active — open, unfixed | When diarization legitimately yields one speaker (reproducible with current gTTS test fixtures, possible on any real call pyannote fails to split), `talk_balance_score` is 0.0 but the UI still renders a normal-looking overall score (76-82%) — the zero is indistinguishable from a genuine "agent dominated the call" finding. No detection or UI flag exists. See 70_Session_Handoff_2026-07-15.md. (Supersedes the retracted "diarization collapse on Blackwell" claim — that was a gTTS test-fixture defect, not a Blackwell/pyannote bug; see the corrected entry above.) **Confirmed 2026-07-16: not a pipeline-wide problem** — real calls through the Cloudflare Tunnel produced nonzero `talk_balance_score` (0.3196 / 0.5097 / 0.2903 observed). Risk is scoped to the single-speaker-diarization edge case only; product decision to leave unfixed stands. |
| gpt-oss `json_validate_failed` (~40% raw rate) on Groq | Active — mitigated, not fixed | `max_retries=4` → ~2.6% residual. No OpenRouter fallback available on demo machine (`OPENROUTER_API_KEY` is 401, no fallback leg) — any residual failure is a hard call failure. **HIGHEST remaining demo risk as of 2026-07-16** — Cloudflare Tunnel closed the networking/access risk category, leaving this as the top open item. |
| MODEL_CACHE_HF / MODEL_CACHE_TORCH undefined on demo machine | Fixed this session | Added to `infra/.env`. Previously in no env file (only `.env.example`), so the model cache was empty and WhisperX re-downloaded ~360MB per fresh container. |
| Public URL reachability / single point of network failure | Resolved 2026-07-16 | `call-qa.tech` live via Cloudflare Tunnel (free plan), verified end-to-end (login, WebSocket, call scoring survive a tunnel hop and a reboot). Replaces Tailscale Funnel, which was already off before this session. See 70_Session_Handoff_2026-07-15.md STEP 3. |
