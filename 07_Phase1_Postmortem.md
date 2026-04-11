---
tags: [phase-1, auth, upload, celery, docker]
date: 2026-03-13
status: complete
---

## What Was Built

Full foundation layer for the Call Quality Analytics System. Seven Docker
services brought up on cq_network. JWT authentication implemented with
bcrypt password hashing. File upload pipeline wired to MinIO object storage.
Celery queue isolation verified with hardware-pinned gpu_queue and io_queue.

## Bugs Encountered & Resolutions

| Bug                                                | Root Cause                                          | Fix                                                                                |
| -------------------------------------------------- | --------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `audio_path` column not found                      | Seed script used wrong column name                  | Renamed to `minio_audio_path` throughout                                           |
| Pydantic ValidationError on worker startup         | MinIO fields were required in config.py             | Made `minio_endpoint`, `minio_access_key`, `minio_secret_key` Optional[str] = None |
| VIEWER role returning HTTP 200 on forbidden upload | In-body soft check instead of dependency            | Replaced with `Depends(require_role("ADMIN", "SUPERVISOR"))`                       |
| File bytes read before size check                  | Size guard ran after `file.read()`                  | Added `file.size` pre-check before reading body                                    |
| Bandit B106 false positive                         | `token_type="bearer"` flagged as hardcoded password | Added `# nosec B106` inline suppression                                            |
| Named volumes persisting data                      | `postgres_data` and `minio_data` volumes created    | Removed all named volumes — ephemeral by design                                    |
| `version: "3.9"` warning                           | Obsolete compose attribute                          | Removed version line entirely                                                      |
| postgres image wrong version                       | `postgres:15-alpine` pulled                         | Fixed to `postgres:16-alpine`                                                      |

## Architecture Decisions

- Ephemeral containers — no named volumes, no backup cron jobs
- `depends_on: condition: service_started` throughout — no healthcheck stanzas
- `DATABASE_URL` uses `postgresql+asyncpg://` in API, `postgresql://` in workers
- `backend/scripts/update_passwords.py` generates real bcrypt hashes for demo users
- `02_Database_Schema.sql` mounted to `/docker-entrypoint-initdb.d/` for auto-init

## Invariants Confirmed

- Column name `minio_audio_path` — never `audio_path`
- Audio binary never written to database
- `pii_redacted=False` on every new call insert
- JWT never in localStorage — Zustand in-memory only
- VIEWER role returns HTTP 403 before any file bytes are read

## QA Audit Results

- Bandit: 0 issues
- Copilot: 9/9 checks passed
- N+1 risk: none (no read endpoints yet)

## Next Phase Entry Conditions

- All 7 containers Up
- `POST /auth/login` returns correct envelope
- `POST /calls/upload` creates MinIO object and pending DB row
- Both Celery workers registered in Flower
- Seed data: 200 calls, 5 agents inserted