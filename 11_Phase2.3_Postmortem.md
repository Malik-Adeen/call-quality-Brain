---
tags: [phase-2, groq, llm, inference, celery]
date: 2026-04-11
status: complete
---

## What Was Built

`llm_client.py` — Groq primary / OpenRouter fallback inference chain using httpx.
`run_groq_inference` Celery task on `io_queue` replacing the stub.
MD5 transcript cache — skips re-inference on duplicate uploads.
Pydantic `InferenceResult` model — validates all 9 fields and ranges on every response.
Full test confirmed: task dispatched against seeded call, 9-field dict returned, Flower shows SUCCESS on `worker_io`.

## Bugs Encountered & Resolutions

| Bug | Root Cause | Fix |
| --- | --- | --- |
| `llama-3.1-70b-versatile` returns HTTP 400 | Model deprecated by Groq | Updated to `llama-3.3-70b-versatile` in `llm_client.py` and both `01_Master_Architecture.md` copies |
| `run_inference("")` did not raise | Empty transcript guard missing — Groq returned scores for empty input | Added `if not transcript or not transcript.strip(): raise ValueError` at top of `run_inference` |
| `seed_data.py` crashed with `TypeError: unsupported format string passed to NoneType` | Verification print used `:<N>` format spec directly on psycopg2 `Decimal`/`None` values | Wrapped all row values in `str()` before f-string formatting |
| DB had 401 calls instead of 200 | Previous partial seed run left duplicate agents and ~201 rows | Noted for demo-day cleanup — wipe DB and re-run seed before final demo |
| `worker_io` had no volume mount | `../backend:/app` was missing from compose — worker ran stale built image | Added volume mount to `worker_io` in `docker-compose.yml` before Phase 2.3 started |
| `MINIO_ENDPOINT=cq_minio:9000` in `.env` | Underscores rejected by botocore RFC validation | Corrected to `cq-minio:9000` in `.env` |

## Architecture Decisions

- `llm_client.py` uses `os.environ.get()` directly — never imports from `config.py` to avoid pydantic-settings validation errors inside Celery workers
- Fallback triggers on HTTP 429 and 503 only — not on parse errors or validation failures
- `InferenceResult` Pydantic model validates ranges before returning — out-of-range scores raise `ValueError` and trigger retry on next provider
- MD5 cache is process-local (module-level dict) — resets on worker restart, sufficient for demo lifetime
- `run_groq_inference` returns a full dict — Phase 2.4 `write_scores` receives this as Celery chain pipe input
- Model: `llama-3.1-70b-versatile` on Groq — never `llama-3.1-8b-instant`

## Invariants Confirmed

- `run_groq_inference` routes to `io_queue` exclusively — never `gpu_queue`
- Groq fallback triggers on 429/503 only
- OpenRouter is fallback only — never called if Groq succeeds
- All float scores validated within declared ranges before task returns
- Raw transcript read from DB — never logged, only passed to inference

## Test Result

```python
{
  'call_id': '59ab08c8-a967-4ae1-8d4a-eb47bb22639a',
  'politeness_score': 0.85,
  'clarity_score': 0.92,
  'resolution_score': 0.78,
  'sentiment_delta': 0.42,
  'coaching_summary': "Agent could have empathized more with the customer's frustration and provided a clearer explanation of the billing process. Additionally, the agent should have offered a more concrete solution to resolve the issue.",
  'issue_category': 'billing_dispute',
  'resolved': True,
  'sentiment_start': -0.65,
  'sentiment_end': -0.23
}
```

Flower: SUCCESS on `worker_io@086696510e9e`

## Next Phase Entry Conditions

- `run_groq_inference` returns valid 9-field dict on 10 consecutive calls
- Phase 2.4 ready to wire: `compute_talk_balance` + `write_scores` + `notify_websocket` + full chain
- DB cleanup required before demo: wipe duplicate agents and calls, re-seed fresh 200 rows
