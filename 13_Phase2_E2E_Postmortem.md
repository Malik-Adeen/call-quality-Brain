---
tags: [phase-2, e2e, pipeline, docker, chain]
date: 2026-04-11
status: complete
---

## What Was Built

Full end-to-end pipeline verified with real synthesized audio.
`test_call.wav` — 13-turn billing dispute conversation generated via edge-tts + ffmpeg.
Complete chain confirmed: upload → MinIO → WhisperX → Presidio → talk_balance → Groq → write_scores → notify_websocket → status=complete.

## End-to-End Result

```
call_id:       9f2e972a-cf1d-4c10-a0e1-b1f14371c5ec
status:        complete
score:         8.72 / 10
pii_redacted:  true
issue_category: billing_dispute
resolved:      true
coaching_summary: "The agent handled the call professionally and provided a
  clear resolution to the customer's issue. However, they could have offered
  an explanation for the renewal fee and the notification process earlier in
  the call. The agent's proactive approach to adding a note for future renewals
  was a positive touch."
```

## Bugs Encountered & Resolutions

| Bug | Root Cause | Fix |
| --- | --- | --- |
| Chain never dispatched after upload | `api` service had no volume mount — running stale built image without chain code | Added `../backend:/app` volume to `api` in `docker-compose.yml` + rebuild |
| `api` still running old code after volume mount + restart | Uvicorn loaded old module from built image layers before volume mount took effect | Full `docker compose build api && up -d api` rebuild required |
| `de94327f` and `d19d3cb6` stuck at pending | Uploaded before API rebuild — chain was never dispatched for these | Expected — these are orphaned rows, cleaned up on next DB wipe |
| `pydub` ImportError on Python 3.14 | pydub incompatible with Python 3.14 | Bypassed with direct ffmpeg subprocess — `merge_test_audio.py` |
| `ValueError: Invalid salt` on login | Password hashes were placeholder values from schema seed | Ran `backend/scripts/update_passwords.py` to generate real bcrypt hashes |
| Groq returning HTTP 400 on inference | `llama-3.1-70b-versatile` deprecated | Updated to `llama-3.3-70b-versatile` — OpenRouter fallback handled it in interim |

## Architecture Decisions

- All three services (`api`, `worker_io`, `worker_gpu`) now have `../backend:/app` live volume mount
- API rebuild required any time `calls.py` or router imports change — volume mount alone is insufficient on first deploy
- `test_call.wav` — 16kHz mono WAV, ~90s, generated via edge-tts neural voices (en-US-GuyNeural agent, en-US-JennyNeural customer)
- `generate_test_audio.py` + `merge_test_audio.py` kept in `scripts/` for demo day re-generation if needed

## Invariants Confirmed

- `pii_redacted = TRUE` on every completed call ✅
- `calls.status = complete` set only after atomic DB write ✅
- Audio binary never in DB — only `minio_audio_path` stored ✅
- Full chain runs end-to-end without manual intervention ✅
- Score within valid range 0.0–10.0 ✅

## Phase 2 Exit Gate — All Conditions Met

- ✅ Real audio file → complete scored result in DB
- ✅ `pii_redacted = TRUE` for every completed call
- ✅ Groq returns valid JSON — OpenRouter fallback functional
- ✅ All 7 pipeline stages visible in Flower task history
- ✅ Zero raw PII in `transcript_redacted` column

## Next Phase Entry Conditions

- DB cleanup: `TRUNCATE` all tables, reseed 200 clean rows, re-run `update_passwords.py`
- Phase 3: React dashboard — 5 modules against live API
- Read endpoints (`GET /calls`, `GET /calls/{id}`, `GET /agents/{id}/scores`) needed before frontend build
