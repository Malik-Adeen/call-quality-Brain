---
tags: [phase-2, groq, llm, inference, celery]
date: 2026-04-11
status: complete
---

> Previous: [[09_Phase2.2_Postmortem]] · Next: [[12_Phase2.4_Postmortem]] · Index: [[00_Master_Dashboard]]
> See [[01_Master_Architecture]] for LLM provider chain spec

## What Was Built

`llm_client.py` — Groq primary / OpenRouter fallback inference chain using httpx.
`run_groq_inference` Celery task on `io_queue` replacing the stub.
MD5 transcript cache — skips re-inference on duplicate uploads.
Pydantic `InferenceResult` model — validates all 9 fields and ranges on every response.
Full test confirmed: task dispatched against seeded call, 9-field dict returned, Flower shows SUCCESS on `worker_io`.

## Bugs Encountered & Resolutions

| Bug | Root Cause | Fix |
|---|---|---|
| `llama-3.1-70b-versatile` returns HTTP 400 | Model deprecated by Groq | Updated to `llama-3.3-70b-versatile` |
| `run_inference("")` did not raise | Empty transcript guard missing | Added `if not transcript or not transcript.strip(): raise ValueError` |
| `seed_data.py` crashed with `TypeError` | Verification print used format spec on psycopg2 `Decimal`/`None` values | Wrapped all row values in `str()` before f-string formatting |
| DB had 401 calls instead of 200 | Previous partial seed run left duplicate agents | Noted for demo-day cleanup — wipe DB and re-run seed |
| `MINIO_ENDPOINT=cq_minio:9000` in `.env` | Underscores rejected by botocore | Corrected to `cq-minio:9000` |

## Architecture Decisions

- `llm_client.py` uses `os.environ.get()` directly — never imports from `config.py` to avoid pydantic-settings errors in Celery workers
- Fallback triggers on HTTP 429 and 503 only
- `InferenceResult` validates ranges before returning — out-of-range scores raise `ValueError` and trigger retry on next provider
- MD5 cache is process-local (module-level dict) — resets on worker restart
- Model: `llama-3.3-70b-versatile` — never `llama-3.1-70b-versatile` (deprecated)

## Invariants Confirmed

- `run_groq_inference` routes to `io_queue` exclusively
- Groq fallback triggers on 429/503 only — OpenRouter never called if Groq succeeds
- All float scores validated within declared ranges before task returns
- Raw transcript never logged — only passed to inference

## Test Result

```python
{
  'call_id': '59ab08c8-...',
  'politeness_score': 0.85,
  'clarity_score': 0.92,
  'resolution_score': 0.78,
  'sentiment_delta': 0.42,
  'coaching_summary': "Agent could have empathized more...",
  'issue_category': 'billing_dispute',
  'resolved': True,
  'sentiment_start': -0.65,
  'sentiment_end': -0.23
}
```

Flower: SUCCESS on `worker_io@086696510e9e`
