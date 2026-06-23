---
tags:
  - handoff
  - session-starter
date: '2026-06-22'
status: active
---

# 62 — Session Handoff (Next Chat) — 2026-06-22

> Load CONTEXT.md + LOG.md + this file at session start. Supersedes 52_Session_Handoff_Next.md.

---

## Current Repo State

- **Branch:** master
- **Head commit:** `95b3b5b` — chore: remove stale agent skills, add gitignore entry, parameterize minio tag
- **Remote:** up to date with origin/master
- **Uncommitted (unstaged, do not commit blindly):**
  - `infra/docker-compose.app.yml` — MINIO_IMAGE_TAG parameterised (`${MINIO_IMAGE_TAG}`), not yet committed
  - `infra/.env` and `infra/.env.prod` — password/endpoint fixes from prior sessions, not yet committed
  - `.agents/skills/` deletions + `.gitignore` edit — `.agent/` directory cleanup, unrelated to app, safe to discard or commit separately
- **Alembic head:** `20260526_platform_rls_bypass` (8 migrations applied, always run inside `cq_api` container)

---

## What Was Done This Session

### Dead code deletions — commit `3262912`
Five items confirmed 0 callers via GitNexus `impact()` before deletion:
1. `MinioClient.download_file` — `minio_client.py` (pipeline uses boto3 `download_file` directly)
2. `ConnectionManager.send` — `ws.py` (only `broadcast` is used; `send` had zero callers)
3. `Settings.redis_password` — `config.py` (password is embedded in `REDIS_URL`; separate field was unused)
4. `test_phase23.py` — standalone script importing two symbols deleted in a prior session; would crash on import
5. `update_passwords.py` — one-off migration script for 3 pre-multi-tenancy users; incompatible with current RLS schema

`detect_changes` after deletion: 0 changed symbols, 4 changed files, risk LOW.

### Full backend code review (report only, no fixes that session)
Triage result:

| Severity | ID | Finding |
|---|---|---|
| HIGH | H1 | `upload_audio` key includes bucket name as prefix → presigned URLs 404 |
| HIGH | H2 | `chain().apply_async()` outside try block in both ingestion paths → calls orphaned in "pending" on Redis outage |
| HIGH | H3 | `get_db_with_tenant` GUC lost after `db.commit()` → `db.refresh()` in `users.py` + `agents.py` runs without RLS context |
| MEDIUM | M1 | `/reports/export` launches full Chromium per request, no rate limit → DoS vector |
| MEDIUM | M2 | `create_tenant` uses `get_db` not `get_db_platform` → `db.refresh()` after commit runs without platform bypass |
| MEDIUM | M3 | `WHISPER_MODEL` not enforced — defaults to `"base"` if env var missing; CLAUDE.md requires `large-v2` |
| MEDIUM | M4 | Transcript injected into LLM prompt with XML demarcation — breakable, prompt injection possible |
| MEDIUM | M5 | Speaker role heuristic assigns AGENT to first speaker chronologically — wrong if customer speaks first |
| LOW | L1–L6 | `JWT_EXPIRY_SECONDS` ignored at auth.py:48; `is_active == True` vs `.is_(True)` style; no email format validation on register; coaching_summary not validated as non-empty; issue_category not validated against enum; no max-length on `external_agent_id` |

`upload_call` duplicate demo risk assessed: **LOW** — UUID filename prevents re-click duplicates; IntegrityError guard on `minio_audio_path` handles webhook replay; demo is supervised single-tenant.

### H1 + H2 fixes — commit `c5d8452`
**H1** (`minio_client.py:28`): Removed `"audio-uploads/"` prefix from `object_key` in `upload_audio`. Object is now stored at `Key="{agent_id}/{date_path}/{filename}"` — consistent across `put_object`, `download_file`, and `generate_presigned_url`.

**H2** (`calls.py:414`, `minio_event.py:103`): Wrapped `chain().apply_async()` in `try/except` in both ingestion paths. On failure: `calls.py` sets `call.status = "failed"` + commits + re-raises (client gets error). `minio_event.py` sets `call.status = "failed"` in a new transaction with tenant context + returns HTTP 200 (webhook invariant preserved).

### M4 + duplicate Call dedup — commit `9aa70a5`

**M4** (`llm_client.py`): Added `_UNSAFE_TAG_PATTERN = re.compile(r"</?(?:transcript|system|prompt|instruction|context|command|human|assistant|user)\b[^>]*>", re.IGNORECASE)` and `sanitize_transcript(text: str) -> str` which applies the regex to strip XML/LLM-context injection tags. Called inside `run_inference()` immediately after the empty-string guard — before transcript reaches `INFERENCE_PROMPT.format()`. Sanitization runs after pii_redacted gate (enforced at task level by `run_groq_inference`). Added `import re` to llm_client.py imports.

**Duplicate Call dedup** (`calls.py`): Replaced `filename = f"{uuid.uuid4().hex}{ext}"` with `file_hash = hashlib.sha256(file_bytes).hexdigest()[:16]` + `filename = f"{file_hash}_{file.filename}"`. `file_bytes` is already in memory from the earlier `await file.read()` — no `seek(0)` needed. Wrapped `db.add(call) / await db.commit()` in `try/except IntegrityError`: on duplicate, rolls back, re-sets `app.current_tenant` GUC (mandatory — after rollback a new autobegin transaction starts without RLS context), queries existing Call by `(tenant_id, minio_audio_path)`, returns HTTP 200 with the existing call's data. No second pipeline chain fired. Added `hashlib`, `from sqlalchemy.exc import IntegrityError`, and `text` to `calls.py` imports. GitNexus impact: both targets LOW. detect_changes: 2 logic-changed symbols.

### H3 + M1 + M2 + M3 + M5 fixes — commit `b331932`

**H3** — GUC re-set after `db.commit()` applied to all four affected routes: `invite_user` (users.py:106), `create_agent` (agents.py:363), `update_agent` (agents.py:427), `deactivate_agent` (agents.py:470 — additional site not in brief, same bug). Each route now re-executes `SELECT set_config('app.current_tenant', :tid, true)` between `db.commit()` and `db.refresh()`. Added `text` import to users.py.

**M1** — `@limiter.limit("5/minute")` added to `export_call_pdf` (reports.py). Imports `limiter` from `app.limiter`, matching the pattern on `/auth/login`.

**M2** — `create_tenant` (platform.py) now uses `Depends(get_db_platform)`. `get_db_platform` wraps the entire request in `session.begin()` with `SET LOCAL app.platform_bypass = 'true'` already active, so the manual `async with db.begin()` block and redundant `SET LOCAL` were removed. `db.flush()` + `db.refresh(tenant)` now both execute inside that same open transaction with bypass in effect. `get_db` import removed.

**M3** — `WHISPER_MODEL` hardcoded to `large-v2` in `docker-compose.gpu.yml` (was `${WHISPER_MODEL:-large-v2}`) and `docker-compose.prod.yml` (was `${WHISPER_MODEL}` with no fallback). `docker-compose.app.yml` skipped — no GPU worker defined there.

**M5** — `_remap_speakers` (whisper_service.py) now assigns AGENT to the speaker with the **longest total speaking duration** across all segments. Accumulates `end - start` per speaker, uses `max()`. Single-speaker edge case naturally handled (one key → that speaker → AGENT).

### Vault updates
- LOG.md: two entries added (dead code session + full session summary)
- CONTEXT.md: Known Limitations presigned URL row updated (backend fixed, frontend still disabled for CORS); new Build State row for c5d8452 fixes
- `Lessons/runpod-canada-region-unverified.md` created: RunPod Canada region claim unverified between two conflicting sources, deferred until approaching real Canadian-data-residency customer

---

## Infrastructure Decisions Made This Session

| Decision | Rationale |
|---|---|
| **Azure abandoned for now** | NC4as_T4_v3 quota 0 by default (1–3 day approval), B4ms alone can't run WhisperX large-v2, cost overhead unjustified before first paying customer |
| **Demo runs on Fahad's laptop** | RTX 5060 8GB VRAM, 64GB RAM — enough for all services + GPU worker on one machine; no cloud dependency for demo |
| **VPS at first paying customer** | RunPod or OVHcloud as target providers (GPU cloud, hourly billing, no quota gates). Azure remains an option post-revenue. |
| **Dynamic DNS as connectivity** | Expose Fahad's laptop to demo attendees/trial users via DDNS instead of a fixed IP or cloud VM |
| **MinIO webhook model unchanged** | `mc mirror --watch` + `/internal/minio-event` stays; no BatchAgent, no polling |
| **RunPod Canada region** | Claim unverified — two sources contradict each other. Deferred. Do not promise Canadian data residency until confirmed. |

---

## Tomorrow's Immediate Plan (in order)

### 1. Dockerfile.gpu Blackwell compatibility check
Fahad's laptop has an **RTX 5060 (GB206, Blackwell architecture)**. Current `Dockerfile.gpu` uses CUDA 12.1 base image (`nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04`). Blackwell requires CUDA 12.4+ for full support.

**Check before anything else:**
- Does `nvidia/cuda:12.4.0-cudnn9-runtime-ubuntu22.04` exist on Docker Hub?
- Does PyTorch have Blackwell-compatible wheels for CUDA 12.4?
- Does WhisperX + Pyannote 3.1 install cleanly against that PyTorch?
- Does `ctranslate2` (used by WhisperX faster-whisper backend) have Blackwell/CUDA 12.4 wheels?

If CUDA 12.1 + RTX 5060 works (some Blackwell cards have partial 12.1 support via forward compat), defer the base image bump. If it fails, update `Dockerfile.gpu` base image before attempting to start the GPU worker.

### 2. Dynamic DNS setup on Fahad's laptop
Fahad's Windows laptop is the demo machine. Need DDNS so the app is reachable at a stable hostname during demo/trial without a static IP.

Context from video: [add the specific DDNS provider + method from the video Adeen watched — e.g. No-IP, DuckDNS, Cloudflare Tunnel — fill this in before next session]

Steps expected:
- Install DDNS client on Fahad's Windows laptop
- Point a subdomain (e.g. `demo.callquality.app` or similar) at the laptop's public IP
- Ensure CORS_ORIGINS in `.env` includes that domain
- Update nginx.conf if needed for the new hostname
- Test from a different network

### 3. Commit the pending infra changes
Before deploying on Fahad's laptop, commit the three files with unstaged changes:
- `infra/docker-compose.app.yml` — MINIO_IMAGE_TAG parameterisation
- `infra/.env` / `infra/.env.prod` — endpoint + password fixes
These have been sitting uncommitted across multiple sessions.

---

## Deferred Items — Explicit Triggers

| Item | Trigger (do it when...) |
|---|---|
| **L4–L6** — Minor low findings (coaching_summary validation, issue_category enum, external_agent_id max-length) | Before first external customer trial — none are blockers for demo. |
| **M4** — Prompt injection via transcript XML demarcation | Fixed in `9aa70a5` — `sanitize_transcript()` strips injection tags before LLM prompt interpolation. No longer a demo risk. |
| **Commit `.agent/` cleanup + `.gitignore` + `docker-compose.app.yml`** | Next commit session — low priority but keeps working tree clean. |
| **RunPod Canada region verification** | Before approaching any customer who mentions Canadian data residency requirements. |
| **Audio playback in frontend** | After CORS config confirmed on Fahad's laptop + DDNS hostname is stable. Backend presigned URL bug already fixed (H1, `c5d8452`). Just needs frontend re-enable + CORS header. |
| **ElevenLabs priya_payment stand-in** | When ElevenLabs monthly credits reset — regenerate with the correct billing_dispute script from 52_ElevenLabs_Demo_Scripts.md |

---

## Known Demo Risks

| Risk | Severity | Mitigation |
|---|---|---|
| **M5 — Speaker inversion** | Low (fixed) | `_remap_speakers` now uses longest-duration heuristic (`b331932`). Still good practice to control demo audio so agent speaks first as a backup. |
| **M4 — Prompt injection via transcript** | Closed | Fixed in `9aa70a5` — `sanitize_transcript()` in `run_inference()`. |
| **Redis outage during demo** | Low (now fixed) | H2 fix ensures failed chains mark call as "failed" instead of orphaning — visible in UI. |
| **Presigned URL 404 on audio playback** | Low (partially fixed) | H1 backend fix applied. Frontend playback still disabled. Don't demo audio playback until CORS confirmed. |
| **Blackwell CUDA incompatibility** | Medium | Check tomorrow before demo prep. If CUDA 12.1 fails on RTX 5060, bump Dockerfile.gpu base image before starting GPU worker. |

---

## Demo Tenant Credentials

| Role | Email | Password |
|---|---|---|
| TENANT_ADMIN | admin@callquality.demo | admin1234 |
| SUPERVISOR | supervisor@callquality.demo | admin1234 |

---

## Vault Reference

| Doc | Purpose |
|---|---|
| CONTEXT.md | Full architecture — read at every session start |
| LOG.md | Session log — read at every session start |
| 62_Session_Handoff_2026-06-22.md | This file |
| 52_ElevenLabs_Demo_Scripts.md | All 5 demo call scripts |
| 04_Demo_Execution_Plan.md | Demo walkthrough script |
| 11_Azure_Deployment.md | Azure runbook (on hold — not current path) |
| Lessons/runpod-canada-region-unverified.md | RunPod Canada region status |
