---
tags: [phase-3, backend, api, read-endpoints]
date: 2026-04-11
status: complete
---

> Previous: [[14_Audit_Fixes]] · Next: [[17_Phase3_Frontend]] · Index: [[00_Master_Dashboard]]
> See [[03_API_Contract]] for full endpoint shapes

## What Was Built

Three read endpoints completing the backend API surface:

- `GET /calls` — paginated list with 8 filter params (agent_id, status, resolved, score_min/max, date_from/to, issue_category)
- `GET /calls/{id}` — full call detail including metrics, sentiment timeline, presigned MinIO audio URL
- `GET /agents/{id}/scores` — agent summary aggregates + 30-day score history + team average

## Bugs Encountered & Resolutions

| Bug | Root Cause | Fix |
|---|---|---|
| `GET /agents/{id}/scores` 500 error | asyncpg stricter — `created_at` must appear in GROUP BY when used in ORDER BY | Replaced ORM query with raw `text()` SQL for history query |
| `User not found` on all endpoints | DB reseeded — JWT contained old user UUID | Re-ran `update_passwords.py` |
| `get_presigned_url` AttributeError | Method is named `generate_presigned_url` in MinioClient | Fixed import reference |

## Verified Results

```
GET /calls?page_size=3        → total_count: 200, total_pages: 67 ✅
GET /calls/{id}               → score: 7.04, status: complete ✅
GET /agents/{id}/scores       → avg_score: 6.69, total_calls: 43 ✅
```

## Architecture Decisions

- History query uses raw `text()` SQL — asyncpg GROUP BY strictness makes ORM version fragile
- Presigned MinIO URLs generated at request time — 1-hour expiry, fails gracefully (returns null)
- `diarized_segments` always returns empty list — WhisperX segments not persisted to DB
- Agent scores Pydantic models defined inline in agents.py — local to read-only endpoint
