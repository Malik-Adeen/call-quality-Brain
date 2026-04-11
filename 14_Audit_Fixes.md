---
tags: [audit, security, bugfix, pipeline]
date: 2026-04-11
status: complete
---

## Source

GPT-5 Copilot audit of backend codebase post Phase 2 completion.
3 CRITICAL · 7 WARNING · 1 INFO identified.
5 fixes actioned immediately. 3 deferred to demo-day hardening.

## Fix Tracker

| # | Severity | Issue | File | Status |
| --- | --- | --- | --- | --- |
| 1 | CRITICAL | WS user_id not validated against token sub | ws.py | ✅ Fixed |
| 2 | CRITICAL | talk_balance_score never reaches write_scores | tasks.py + calls.py | ✅ Fixed |
| 3 | WARNING | Raw segments persist in Redis result backend | celery_app.py | ✅ Fixed — result_expires=300 |
| 4 | WARNING | No pii_redacted gate before Groq inference | tasks.py | ✅ Fixed |
| 5 | WARNING | VRAM retry too narrow — misses CUDA OOM variants | tasks.py | ✅ Fixed |
| 6 | WARNING | LLM fallback triggers on non-429/503 HTTP errors | llm_client.py | ✅ Fixed |

## Deferred

| # | Severity | Issue | Reason |
| --- | --- | --- | --- |
| D1 | WARNING | CORS wildcard + allow_credentials | Demo project — fix on demo day |
| D2 | WARNING | JWT in WS query param | API contract specifies ?token= — cannot change |
| D3 | INFO | agents.py + reports.py stubs | Phase 3 read endpoints — intentionally empty |

## Fix Details

### Fix 1 — WS user_id validation
**File:** `backend/app/routers/ws.py`
**Issue:** Any valid JWT can bind to any user_id path param.
**Fix:** Add `if str(payload.get("sub")) != user_id: close(4001)`
**Status:** 🔲

### Fix 2 — talk_balance_score propagation
**File:** `backend/app/pipeline/tasks.py` + `backend/app/routers/calls.py`
**Issue:** `run_groq_inference.si()` ignores piped result from `compute_talk_balance`. `talk_balance_score` defaults to 0.5 in `write_scores`.
**Fix:** `compute_talk_balance` stores `talk_balance_score` in DB. `write_scores` reads it from DB instead of expecting it via pipe.
**Status:** 🔲

### Fix 3 — Raw segments in Redis
**File:** `backend/app/pipeline/tasks.py`
**Issue:** `run_whisperx` and `redact_pii` return transcript data that persists in Redis result backend.
**Fix:** Add `ignore_result=True` to `run_whisperx` and `redact_pii` task decorators.
**Status:** 🔲

### Fix 4 — pii_redacted gate
**File:** `backend/app/pipeline/tasks.py` — `run_groq_inference`
**Issue:** Task reads transcript without confirming PII redaction completed.
**Fix:** Check `call.pii_redacted is True` before inference, raise if False.
**Status:** 🔲

### Fix 5 — VRAM retry coverage
**File:** `backend/app/pipeline/tasks.py` — `run_whisperx`
**Issue:** Only retries on exact string "Insufficient VRAM" — misses CUDA OOM variants.
**Fix:** Broaden to also catch "CUDA out of memory" and `torch.cuda.OutOfMemoryError`.
**Status:** 🔲

### Fix 6 — LLM fallback scope
**File:** `backend/app/services/llm_client.py`
**Issue:** Non-429/503 HTTP errors (e.g. 401, 404) fall through to OpenRouter instead of failing fast.
**Fix:** Only break to next provider on 429/503. All other HTTP errors raise immediately.
**Status:** 🔲

## Test Plan

After all fixes — run existing test suites:
```
docker exec cq_worker_io python /app/tests/test_phase23.py
docker exec cq_worker_io python /app/tests/test_phase24.py
```

Plus one new targeted test for Fix 2 (talk_balance_score propagation):
- Dispatch full chain on a seeded call
- Verify `call_metrics.talk_balance_score != 0.5` in DB

## Post-Fix Status
- [ ] test_phase23.py — 31/31
- [ ] test_phase24.py — 26/26
- [ ] talk_balance propagation verified in DB
- [ ] End-to-end upload confirms score uses real talk_balance
