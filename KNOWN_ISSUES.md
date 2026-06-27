# KNOWN ISSUES — AI Call Quality Analytics System

> Authoritative issue tracker for the SaaS product. Updated after each audit session.
> Last updated: 2026-06-25 (Fahad demo deployment). Active branch: deploy/fahad-demo.

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
