---
tags: [phase-2, pipeline, celery, chain, websocket, scoring]
date: 2026-04-11
status: complete
---

> Previous: [[11_Phase2.3_Postmortem]] · Next: [[13_Phase2_E2E_Postmortem]] · Index: [[00_Master_Dashboard]]
> See [[01_Master_Architecture]] for scoring formula

## What Was Built

`compute_talk_balance` — word count ratio from diarized segments, no model.
`write_scores` — atomic transaction applying the invariant scoring formula. Idempotent — deletes existing metrics before inserting.
`notify_websocket` — broadcasts `call_complete` event to all connected clients.
`ws.py` — WebSocket endpoint at `/ws/{user_id}?token=<jwt>`.
Full 6-stage chain wired in `calls.py`: `run_whisperx → redact_pii → compute_talk_balance → run_groq_inference → write_scores → notify_websocket`.

## Bugs Encountered & Resolutions

| Bug                                          | Root Cause                                                                          | Fix                                                                          |
| -------------------------------------------- | ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `politeness_score written` test failed       | Seeded call already had a `call_metrics` row — `fetchone()` returned old seeded row | Added `DELETE FROM call_metrics WHERE call_id = ?` inside atomic transaction |
| `calls.status = failed` test failed          | `float("not_a_number")` raised before entering `try` block                          | Moved all float conversions inside the `try` block                           |
| `ws.py` imported non-existent `decode_token` | Function is named `decode_access_token` in `app.auth.jwt`                           | Fixed import                                                                 |
| `calls.py` chain edit matched wrong location | `str_replace` matched first `return ApiResponse(`                                   | Rewrote entire `calls.py` cleanly                                            |

## Chain Signature Map

```
run_whisperx.si(call_id)           → returns: [segments]
redact_pii.s(call_id)              → receives: segments → returns: [redacted_segments]
compute_talk_balance.s(call_id)    → receives: redacted_segments → returns: {talk_balance_score, ...}
run_groq_inference.si(call_id)     → ignores pipe, reads DB → returns: {9-field inference dict}
write_scores.s(call_id)            → receives: inference_result → returns: {call_id, score}
notify_websocket.s(call_id)        → receives: write_result → broadcasts call_complete
```

## Invariants Confirmed

- Scoring formula weights: 0.25 politeness + 0.20 sentiment_delta_norm + 0.20 resolution + 0.15 talk_balance + 0.20 clarity
- `calls.status = complete` set only inside the same atomic transaction as score write
- `calls.status = failed` set on ANY exception in `write_scores`
- `call_metrics` and `sentiment_timeline` writes are atomic with `calls` update
- WebSocket auth via JWT at connection time — unauthenticated connections closed with code 4001

## Test Results

26/26 passing — `tests/test_phase24.py`
