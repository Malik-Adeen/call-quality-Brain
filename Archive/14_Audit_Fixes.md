---
tags: [audit, security, bugfix, pipeline]
date: 2026-04-11
status: complete
---

> Previous: [[13_Phase2_E2E_Postmortem]] · Next: [[16_Phase3A_Read_Endpoints]] · Index: [[00_Master_Dashboard]]

## Source

GPT-5 Copilot audit of backend codebase post Phase 2. 3 CRITICAL · 7 WARNING · 1 INFO.
5 fixes actioned immediately. 3 deferred.

## Fix Tracker

| # | Severity | Issue | Status |
|---|---|---|---|
| 1 | CRITICAL | WS user_id not validated against token sub | ✅ Fixed |
| 2 | CRITICAL | talk_balance_score never reaches write_scores | ✅ Fixed |
| 3 | WARNING | Raw segments persist in Redis result backend | ✅ Fixed — result_expires=300 |
| 4 | WARNING | No pii_redacted gate before Groq inference | ✅ Fixed |
| 5 | WARNING | VRAM retry too narrow — misses CUDA OOM variants | ✅ Fixed |
| 6 | WARNING | LLM fallback triggers on non-429/503 HTTP errors | ✅ Fixed |
| D1 | WARNING | CORS wildcard + allow_credentials | ✅ Fixed in [[23_Phase4_Postmortem]] |
| D2 | WARNING | JWT in WS query param | ⚠️ Deferred — API contract specifies ?token= |
| D3 | INFO | agents.py + reports.py stubs | ✅ Completed in [[16_Phase3A_Read_Endpoints]] |

## Key Fix Details

**Fix 2 — talk_balance_score propagation:**
`run_groq_inference.si()` ignores piped result. `compute_talk_balance` stores score in DB.
`write_scores` reads from DB instead of expecting via pipe.

**Fix 4 — pii_redacted gate:**
`run_groq_inference` checks `call.pii_redacted is True` before inference. Raises if False.

**Fix 5 — VRAM retry:**
Broadened to catch "CUDA out of memory" and `torch.cuda.OutOfMemoryError` variants.
