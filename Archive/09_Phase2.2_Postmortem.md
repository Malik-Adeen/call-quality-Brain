---
tags: [phase-2, presidio, pii, celery, chain]
date: 2026-04-11
status: complete
---

> Previous: [[08_Phase2.1_Postmortem]] · Next: [[11_Phase2.3_Postmortem]] · Index: [[00_Master_Dashboard]]
> Extended Presidio recognizers added later: [[27_Presidio_Extension_Postmortem]]

## What Was Built

Presidio PII redaction gate wired as Stage 3 in the pipeline.
8 entity types redacted with typed tokens.
Full chain verified: run_whisperx → redact_pii.
pii_redacted flag set to TRUE in DB after successful redaction.

## Bugs Encountered & Resolutions

| Bug | Root Cause | Fix |
|---|---|---|
| `minio_init` compose validation error | Service block placed outside `services:` | Moved inside services block |
| `ModuleNotFoundError: presidio_analyzer` on worker_gpu | Top-level import forced GPU worker to load Presidio | Moved import inside redact_pii function body |
| `ValueError: dictionary update sequence element #0` | Celery chain pipes return value as first arg | Changed signature to `(segments, call_id)` |
| `TypeError: redact_pii() got multiple values for call_id` | Passing call_id as kwargs while Celery piped positionally | Changed to positional args in chain |
| `worker_io` rebuild not picking up changes | No volume mount — running stale image | Added `../backend:/app` volume mount |
| worker_io DATABASE_URL using asyncpg | Sync worker cannot use async driver | Fixed to `postgresql://` scheme |

## Architecture Decisions

- `redact_pii` signature: `(segments: list, call_id: str)` — segments first to receive Celery pipe
- Presidio import is lazy — inside function body, not module level
- Both worker_io and worker_gpu have `../backend:/app` live volume mount

## Invariants Confirmed

- Raw transcript never written to database
- `pii_redacted = TRUE` set only after successful redaction
- `redact_pii` routes to io_queue exclusively

## Chain Timing

- run_whisperx: ~50s (warm cache, large-v2)
- redact_pii: 5.0s (Presidio init included)
- Total chain: ~55s
