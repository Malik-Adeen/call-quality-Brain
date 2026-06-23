---
tags: [future, enhancement, audio, transcript, pipeline]
date: 2026-04-11
status: deferred
priority: medium
---

# Future Implementation: Transcript Audio Sync

## What It Is

When WhisperX transcribes audio it produces two outputs:

1. **Full transcript text** — currently stored in DB as `transcript_redacted` ✅
2. **Diarized segments with timestamps** — e.g. `AGENT said "Hello" from 0.0s to 1.2s` — currently thrown away ❌

Storing the timestamps would allow clicking any transcript bubble in Call Detail to jump the audio player to that exact moment in the recording.

## Current Behaviour

- Transcript displays as AGENT/CUSTOMER chat bubbles ✅
- Clicking a bubble does nothing to the audio ❌
- Audio player appears but has no seek-on-click functionality ❌

## Desired Behaviour

- Click any transcript bubble → audio jumps to `segment.start` seconds
- Active bubble highlights as audio plays through it
- Word-level highlight (every 100ms, compare `currentTime` to `word.start`/`word.end`)

## What Needs to Change

### Backend — Pipeline (tasks.py)

`redact_pii` already has the full segment list including timestamps. It currently builds `transcript_redacted` as plain text and throws the segments away. Need to:

1. Add a `diarized_segments` table to DB schema (or store as JSONB on `calls` table)
2. In `redact_pii` — after redacting text, serialize segments to JSON and write to DB
3. In `GET /calls/{id}` — return segments from DB in `diarized_segments` field

### DB Schema Change

Option A — New table (clean, queryable):
```sql
CREATE TABLE diarized_segments (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    call_id    UUID NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
    speaker    TEXT NOT NULL,
    start_sec  NUMERIC(8,3) NOT NULL,
    end_sec    NUMERIC(8,3) NOT NULL,
    text       TEXT NOT NULL,
    seq        INTEGER NOT NULL
);
```

Option B — JSONB column on calls table (simpler, no migration):
```sql
ALTER TABLE calls ADD COLUMN diarized_segments_json JSONB;
```

Option B is faster to implement for the demo.

### Frontend — CallDetail.tsx

Already has full audio sync logic written — `audioRef`, `currentTime` tracking every 100ms, `activeSegIdx` state, `TranscriptSegment` component with `onClick={() => audioRef.current.currentTime = seg.start}`.

Currently shows plain text fallback because `call.diarized_segments` is always `[]`.

Once backend stores segments, frontend needs zero changes — it already handles both cases.

## When to Do This

- Requires real call audio data to test properly
- `test_call.wav` (synthetic TTS) works but edge cases are hard to verify
- Recommended: implement after getting real call recordings
- Estimated effort: 1 session (pipeline change + DB column + read endpoint update)

## Dependency

- MinIO audio must be accessible from browser (hostname fix already done ✅)
- Audio player must be rendering (audioAvailable check already in place ✅)
- WhisperX segments already contain all required fields (`speaker`, `start`, `end`, `text`, `words`)
