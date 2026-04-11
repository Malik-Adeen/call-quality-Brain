---
tags: [phase-4, planning, demo, azure, deployment]
date: 2026-04-11
status: active
---

# 18 — Phase 4 Plan: Demo Hardening & Azure Deployment

## Overview

Phase 4 converts the locally-verified system into a demo-ready deployment on Azure. No new AI features. Focus is stability, clean data, and the live demo experience.

---

## Task List

### 4.1 — PDF Export (Playwright)

The `reports.py` router is a stub. Needs real implementation.

**What to build:**
- `POST /reports/export` — accepts `{ call_id: uuid }`
- Fetch call detail from DB
- Render HTML template with call data (score, transcript, metrics, coaching summary)
- Playwright headless Chromium renders HTML → PDF bytes
- Return as `application/pdf` binary response

**Architecture notes:**
- Playwright must be installed in the API container (`playwright install chromium`)
- HTML template must render Recharts-equivalent charts as static SVGs (Recharts needs a browser — use static `<svg>` in the template instead)
- Return `Content-Disposition: attachment; filename="call_report_{call_id}.pdf"`
- Error code `PDF_SERVICE_UNAVAILABLE` (503) if Playwright fails

---

### 4.2 — DB Cleanup + Fresh Reseed

Current DB has duplicate agents from multiple seed runs (401 calls, agents duplicated).

**Steps:**
```powershell
docker exec cq_postgres psql -U callquality -d callquality -c "TRUNCATE calls, call_metrics, sentiment_timeline, agents, users RESTART IDENTITY CASCADE;"
python N:\projects\call-quality-analytics\scripts\seed_data.py
python N:\projects\call-quality-analytics\backend\scripts\update_passwords.py
```

**Verify:**
```powershell
docker exec cq_postgres psql -U callquality -d callquality -c "SELECT COUNT(*) FROM calls; SELECT COUNT(*) FROM agents;"
```
Expected: 200 calls, 5 agents.

---

### 4.3 — Azure B2s Deployment (Always-On Demo Server)

- Provision Azure `B2s` VM — Ubuntu 22.04 LTS — ~$0.05/hr
- Install Docker + Docker Compose (`apt`)
- Copy repo + `.env` to VM via `scp`
- Run `docker compose up -d` — verify all 7 services healthy
- Run `seed_data.py` + `update_passwords.py` on VM
- Access dashboard via VM public IP — verify all 5 modules load
- Note VM public IP — this is the always-on demo URL

---

### 4.4 — Azure NC4as_T4_v3 GPU VM (Live Pipeline Demo Only)

- Provision `NC4as_T4_v3` — Ubuntu 22.04 LTS — $0.53/hr
- Install NVIDIA Container Toolkit
- Uncomment `deploy.resources` block in `docker-compose.yml` for `worker_gpu`
- Set in `.env`: `WHISPER_DEVICE=cuda`, `WHISPER_MODEL=large-v2`
- Start VM exactly 20 minutes before live demo segment
- **Stop and deallocate immediately after demo**

---

### 4.5 — Demo Day Hardening Checklist

- [ ] Change `FLOWER_PASSWORD` from `flower_dev` in production `.env`
- [ ] Restrict CORS `allow_origins` from `["*"]` to frontend origin
- [ ] Verify all 5 dashboard modules load with seeded data (no empty states)
- [ ] Prepare 2–3 real audio files (3–5 min each) for live upload demo
- [ ] Test full pipeline end-to-end on Azure GPU VM before demo
- [ ] Verify Flower dashboard accessible — show both workers during demo
- [ ] Verify WebSocket toast fires within 3 seconds of upload completing

---

### 4.6 — Demo Script Order

1. KPI Overview — show stats, sparklines, explain the pipeline
2. Call List — filter by agent, show score colour coding
3. Call Detail — coaching summary, sentiment timeline, component scores
4. Agent View — score history, team benchmark, strengths/weaknesses
5. Live Upload — upload real audio, watch Flower, WebSocket toast appears

---

## Budget Tracking

| Item | Estimated Cost |
|---|---|
| Azure B2s (always-on) ~8 hours | ~$0.40 |
| Azure NC4as_T4_v3 ~4 hours | ~$2.12 |
| OpenRouter fallback inference | < $0.01 |
| **Total** | **< $3 of $85 budget** |

---

## Entry Conditions (before starting Phase 4)

- ✅ All 5 dashboard modules rendering correctly
- ✅ End-to-end pipeline verified locally
- ✅ All tests passing (31/31 Phase 2.3, 30/30 Phase 2.4)
- ✅ Git tagged at v0.9-phase3-frontend-complete
- 🔲 DB cleaned and reseeded with 200 fresh calls
- 🔲 PDF export implemented
