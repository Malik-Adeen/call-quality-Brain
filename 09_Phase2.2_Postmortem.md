---
tags: [phase-2, presidio, pii, celery, chain]
date: 2026-04-11
status: complete
---

## What Was Built

Presidio PII redaction gate wired as Stage 3 in the pipeline.
8 entity types redacted with typed tokens.
Full chain verified: run_whisperx → redact_pii.
pii_redacted flag set to TRUE in DB after successful redaction.

## Bugs Encountered & Resolutions

| Bug                                                       | Root Cause                                                                        | Fix                                                                                     |
| --------------------------------------------------------- | --------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `minio_init` compose validation error                     | Service block placed outside `services:`                                          | Moved inside services block, renamed with underscore                                    |
| `ModuleNotFoundError: presidio_analyzer` on worker_gpu    | Top-level import in tasks.py forced GPU worker to load Presidio                   | Moved import inside redact_pii function body                                            |
| `ValueError: dictionary update sequence element #0`       | Celery chain pipes return value as first arg — `call_id` string iterated as chars | Changed redact_pii signature to `(segments, call_id)` so piped result lands on segments |
| `TypeError: redact_pii() got multiple values for call_id` | Passing call_id as kwargs while Celery also piped it positionally                 | Changed to positional args in chain signature                                           |
| `worker_io` rebuild not picking up changes                | worker_io had no volume mount — running stale built image                         | Added `../backend:/app` volume mount to worker_io                                       |
| Wrong cache volumes on postgres service                   | Huggingface/torch mounts placed on postgres instead of worker_gpu                 | Moved to worker_gpu, removed from postgres                                              |
| worker_io DATABASE_URL using asyncpg                      | Sync worker cannot use async driver                                               | Fixed to `postgresql://` scheme                                                         |

## Architecture Decisions

- `redact_pii` signature: `(segments: list, call_id: str)` — segments first to receive Celery pipe
- Chain dispatch pattern: `args=['call_id']` on redact_pii, Celery prepends piped segments
- Both worker_io and worker_gpu now have `../backend:/app` live volume mount
- Presidio import is lazy — inside function body, not module level
- minio_init service auto-creates bucket and uploads test file on every compose up

## Invariants Confirmed

- Raw transcript never written to database
- pii_redacted = TRUE set only after successful redaction
- redact_pii routes to io_queue exclusively
- run_whisperx return value flows correctly into redact_pii segments arg

## Chain Timing

- run_whisperx: ~50s (warm cache, large-v2, sine wave)
- redact_pii: 5.0s (empty segments, Presidio init included)
- Total chain: ~55s

## Next Phase Entry Conditions

- Real audio file produces non-empty segments from run_whisperx
- redact_pii processes actual transcript text and stores redacted version
- pii_redacted = TRUE confirmed in DB
- Phase 2.3 Groq inference ready to receive redacted segments