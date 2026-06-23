---
tags: [phase-4, pdf-export, playwright, reseed, minio-volume, cors]
date: 2026-04-16
status: complete
---

> Previous: [[21_UI_Redesign_Postmortem]] · Next: [[24_Hybrid_Architecture_Postmortem]] · Index: [[00_Master_Dashboard]]
> See [[11_Azure_Deployment]] for B2s runbook

## What Was Built

DB reset+reseed script replacing both `seed_data.py` and `update_passwords.py` in one command.
Playwright PDF export at `POST /reports/export` — self-contained HTML report with metadata grid,
score badge, metrics bar chart, coaching summary, and redacted transcript.
MinIO named volume (`minio_data:/data`) — audio survives container restarts.
CORS wildcard replaced with `allow_origins=["http://localhost:5173"]`.
Azure B2s + deployment runbook written to [[11_Azure_Deployment]].

## Bugs Encountered & Resolutions

| Bug | Root Cause | Fix |
|---|---|---|
| `psycopg2.OperationalError: could not translate host name "cq_postgres"` | `.env` DATABASE_URL uses Docker-internal hostname | `.replace("@cq_postgres:", "@localhost:")` + strip `asyncpg` prefix |
| Double-insert of Sarah Chen | Pre-loop INSERT ran before agent loop also inserted `AGENTS[0]` | Removed pre-loop insert — single loop only |
| Playwright browser not found as non-root | Default install path `/root/.cache` not readable by `appuser` | `ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright` + `chmod -R 755` |

## Architecture Decisions

- `reset_and_seed.py` — one-command demo reset: TRUNCATE + bcrypt passwords + 200 clean calls
- DATABASE_URL host rewrite at script level — no separate `.env` for local vs Docker
- PDF from self-contained HTML rendered by Playwright — no dependency on frontend URL
- Only MinIO gets a named volume — everything else ephemeral

## Validated Outputs

- `reset_and_seed.py` printed 5-agent breakdown, 200 calls inserted
- `POST /reports/export` → valid PDF with layout, bar charts, score badge ✅
- E2E retest: `test_call.mp3` → `score=92%`, WebSocket toast fired ✅

## Invariants Confirmed

- `pii_redacted = TRUE` on all 200 seeded calls
- `minio_audio_path` — never `audio_path`
- PDF endpoint returns binary — exempt from `ApiResponse` envelope
- `bcrypt` rounds=12 for demo user passwords
