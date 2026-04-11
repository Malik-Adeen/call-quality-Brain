---
tags: [phase-2, pipeline, celery, chain, websocket, scoring]
date: 2026-04-11
status: complete
---

## What Was Built

`compute_talk_balance` — word count ratio from diarized segments, no model. Scores 0.5 on empty segments.
`write_scores` — atomic transaction applying the invariant scoring formula. Deletes existing `call_metrics` and `sentiment_timeline` rows before inserting fresh ones (idempotent).
`notify_websocket` — broadcasts `call_complete` event to all connected clients via `ConnectionManager`.
`ws.py` — WebSocket endpoint at `/ws/{user_id}?token=<jwt>`. JWT validated at connection time via `decode_access_token`.
Full 6-stage chain wired in `calls.py` upload endpoint: `run_whisperx → redact_pii → compute_talk_balance → run_groq_inference → write_scores → notify_websocket`.

## Bugs Encountered & Resolutions

| Bug | Root Cause | Fix |
| --- | --- | --- |
| `politeness_score written` test failed | Seeded call already had a `call_metrics` row — `fetchone()` returned the old seeded row | Added `DELETE FROM call_metrics WHERE call_id = ?` inside the atomic transaction before inserting new row |
| `clarity_score written` test failed | Same root cause as above | Same fix |
| `calls.status = failed` test failed | `float("not_a_number")` raised before entering the `try` block — except handler never ran | Moved all float conversions inside the `try` block so every exception triggers the `status = failed` rollback |
| `ws.py` imported non-existent `decode_token` | Function is named `decode_access_token` in `app.auth.jwt` | Fixed import before any restart |
| `calls.py` chain edit matched wrong location | `str_replace` matched first `return ApiResponse(` instead of the last one | Rewrote entire `calls.py` file cleanly |

## Architecture Decisions

- `compute_talk_balance` receives `redacted_segments` as first arg — piped from `redact_pii` via Celery chain
- `run_groq_inference` uses `.si()` (immutable signature) — ignores piped result from `compute_talk_balance`, reads transcript fresh from DB
- `write_scores` uses `.s()` — receives `inference_result` dict piped from `run_groq_inference`, plus `call_id` as explicit arg
- `notify_websocket` uses `.s()` — receives `write_result` dict piped from `write_scores`
- `write_scores` is fully idempotent — deletes existing metrics and timeline before every write
- `ConnectionManager` is a module-level singleton in `ws.py` — imported by `notify_websocket` task at call time
- WebSocket uses `asyncio.get_event_loop()` with `new_event_loop()` fallback — Celery workers have no running event loop

## Chain Signature Map

```
run_whisperx.si(call_id)           → returns: [segments]
redact_pii.s(call_id)              → receives: segments  — returns: [redacted_segments]
compute_talk_balance.s(call_id)    → receives: redacted_segments  — returns: {call_id, talk_balance_score, redacted_segments}
run_groq_inference.si(call_id)     → ignores pipe, reads DB  — returns: {9-field inference dict}
write_scores.s(call_id)            → receives: inference_result  — returns: {call_id, score}
notify_websocket.s(call_id)        → receives: write_result  — broadcasts call_complete event
```

## Invariants Confirmed

- Scoring formula weights unchanged: 0.25 politeness + 0.20 sentiment_delta_norm + 0.20 resolution + 0.15 talk_balance + 0.20 clarity
- `calls.status = complete` set only inside the same atomic transaction as score write
- `calls.status = failed` set on ANY exception anywhere in `write_scores`
- `call_metrics` and `sentiment_timeline` writes are atomic with `calls` update — single `db.commit()`
- WebSocket auth via JWT at connection time — unauthenticated connections closed with code 4001

## Test Results

26/26 passing — `tests/test_phase24.py`

## Next Phase Entry Conditions

- Full end-to-end test: upload real audio → pipeline runs → `calls.status = complete` in DB → WebSocket `call_complete` event fires
- DB cleanup: wipe duplicate agents/calls from seed runs, reseed 200 clean rows
- Phase 3: React dashboard — 5 modules against live API
