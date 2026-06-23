---
tags: [phase-2, e2e, pipeline, docker, chain]
date: 2026-04-11
status: complete
---

> Previous: [[12_Phase2.4_Postmortem]] · Next: [[14_Audit_Fixes]] · Index: [[00_Master_Dashboard]]

## What Was Built

Full end-to-end pipeline verified with real synthesized audio.
`test_call.wav` — 13-turn billing dispute conversation generated via edge-tts + ffmpeg.
Complete chain: upload → MinIO → WhisperX → Presidio → talk_balance → Groq → write_scores → notify_websocket → status=complete.

## End-to-End Result

```
call_id:        9f2e972a-cf1d-4c10-a0e1-b1f14371c5ec
status:         complete
score:          8.72 / 10
pii_redacted:   true
issue_category: billing_dispute
resolved:       true
```

## Bugs Encountered & Resolutions

| Bug | Root Cause | Fix |
|---|---|---|
| Chain never dispatched after upload | `api` service had no volume mount — running stale built image | Added `../backend:/app` volume to `api` + full rebuild |
| `pydub` ImportError on Python 3.14 | pydub incompatible with Python 3.14 | Bypassed with direct ffmpeg subprocess |
| `ValueError: Invalid salt` on login | Password hashes were placeholder values from schema seed | Ran `update_passwords.py` to generate real bcrypt hashes |
| Groq HTTP 400 on inference | `llama-3.1-70b-versatile` deprecated | Updated to `llama-3.3-70b-versatile` |

## Invariants Confirmed

- `pii_redacted = TRUE` on every completed call ✅
- `calls.status = complete` set only after atomic DB write ✅
- Audio binary never in DB ✅
- Score within valid range 0.0–10.0 ✅

## Phase 2 Exit Gate — All Met

- ✅ Real audio → complete scored result in DB
- ✅ `pii_redacted = TRUE` for every completed call
- ✅ Groq returns valid JSON — OpenRouter fallback functional
- ✅ All 7 pipeline stages visible in Flower
- ✅ Zero raw PII in `transcript_redacted` column
