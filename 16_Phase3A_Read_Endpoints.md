---
tags: [phase-3, backend, api, read-endpoints]
date: 2026-04-11
status: complete
---

## What Was Built

Three read endpoints completing the backend API surface:

- `GET /calls` — paginated call list with 8 filter params (agent_id, status, resolved, score_min/max, date_from/to, issue_category), sorting by created_at/score/duration
- `GET /calls/{id}` — full call detail including metrics, sentiment timeline, presigned MinIO audio URL
- `GET /agents/{id}/scores` — agent summary aggregates + 30-day score history + team average

## Bugs Encountered & Resolutions

| Bug | Root Cause | Fix |
| --- | --- | --- |
| `GET /agents/{id}/scores` 500 error | asyncpg stricter than psycopg2 — `created_at` must appear in GROUP BY when used in ORDER BY | Replaced SQLAlchemy ORM query with raw `text()` SQL for history query |
| `User not found` on all endpoints | DB reseeded — JWT contained old user UUID | Re-ran `update_passwords.py` to regenerate hashes for new user rows |
| `get_presigned_url` AttributeError | Method is named `generate_presigned_url` in MinioClient | Fixed import reference in calls.py |

## Verified Results

```
GET /calls?page_size=3
  → total_count: 200, total_pages: 67 ✅

GET /calls/{id}
  → score: 7.04, status: complete
  → metrics: politeness 0.8267, clarity 0.501, resolution 0.9475 ✅

GET /agents/e4b4043b/scores?days=30
  → avg_score: 6.69, total_calls: 43, resolved_count: 30
  → score_history: 16 data points ✅
```

## Architecture Decisions

- History query uses raw `text()` SQL — asyncpg GROUP BY strictness makes ORM version fragile
- Presigned MinIO URLs generated at request time — 1-hour expiry, fails gracefully (returns null) if MinIO unreachable
- `diarized_segments` always returns empty list — WhisperX segments not persisted to DB in current pipeline (Phase 3 enhancement if needed)
- Agent scores Pydantic models defined inline in agents.py — not added to shared schemas.py to keep read-only models local

## Next Phase Entry Conditions

- Frontend scaffold: `npm create vite@latest frontend -- --template react-ts`
- Install: `tailwindcss recharts axios react-router-dom zustand lucide-react`
- Design tokens from `15_Design_System.md` applied from first component
- API base URL: `http://localhost:8000`
