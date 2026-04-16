---
tags: [phase-4, pdf-export, playwright, reseed, minio-volume, cors]
date: 2026-04-16
status: complete
---

## What Was Built

DB reset+reseed script replacing both `seed_data.py` and `update_passwords.py` in one command.
Playwright PDF export at `POST /reports/export` — self-contained HTML report with metadata grid,
score badge, metrics bar chart, coaching summary, and redacted transcript.
MinIO named volume (`minio_data:/data`) added so audio survives container restarts.
CORS wildcard replaced with `allow_origins=["http://localhost:5173"]`.
Azure B2s + NC4as_T4_v3 deployment runbook written to `11_Azure_Deployment.md`.

## Bugs Encountered & Resolutions

| Bug | Root Cause | Fix |
|---|---|---|
| `psycopg2.OperationalError: could not translate host name "cq_postgres"` | `.env` DATABASE_URL uses Docker-internal hostname; script runs on host machine | `.replace("@cq_postgres:", "@localhost:")` + strip `asyncpg` prefix before connecting |
| Double-insert of Sarah Chen in original `seed_data.py` | Pre-loop INSERT ran before agent loop also inserted `AGENTS[0]` | Removed pre-loop insert — single loop through all 5 agents only |
| Playwright browser not found running as non-root | Default install path `/root/.cache` not readable by `appuser` | `ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright` + `chmod -R 755` after install; env var forwarded in compose |

## Architecture Decisions

- `reset_and_seed.py` is one-command demo reset: TRUNCATE + real bcrypt passwords + 200 clean calls
- DATABASE_URL host rewrite at script level — no separate `.env` for local vs Docker
- PDF built from self-contained HTML string rendered by Playwright — no dependency on frontend URL or CORS
- Only MinIO gets a named volume — all other data stays ephemeral by design
- CORS locked to `http://localhost:5173` for dev; update to Azure B2s public IP before demo day

## Validated Outputs

- `reset_and_seed.py` printed 5-agent breakdown table, 200 calls inserted
- `POST /reports/export` returned valid PDF — layout, bar charts, score badge, coaching summary all correct
- Full E2E pipeline retest: `test_call.mp3` → `score=92%`, `status=complete`, WebSocket toast fired, Call Detail panel populated

## Invariants Confirmed

- `pii_redacted = TRUE` on all 200 seeded calls
- `minio_audio_path` column name used throughout — never `audio_path`
- PDF endpoint returns `StreamingResponse` binary — exempt from `ApiResponse` envelope per `03_API_Contract.md`
- `bcrypt` rounds=12 for all demo user passwords
- Audio binary never in DB — seed uses fake path strings only
- CORS no longer wildcard

## Next Phase Entry Conditions (Azure Deploy)

- `docker compose up -d` on Azure B2s brings all 8 services up in < 3 minutes
- `reset_and_seed.py` runs cleanly on VM
- Dashboard loads at public IP with 200 seeded calls
- CORS origin updated to Azure B2s public IP before going live
- `NC4as_T4_v3` GPU worker passes `nvidia-smi` and `torch.cuda.is_available()` checks
- Live upload completes end-to-end in < 90 seconds on T4
