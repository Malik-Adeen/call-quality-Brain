---
tags: [status, demo, readiness]
date: 2026-04-19
verdict: READY
---

# Demo Readiness — 2026-04-19

Audit basis: `ui-audit-latest.md` (2026-04-19)
Demo date: Week of April 21, 2026

---

## System Status

| Layer | Status | Notes |
|---|---|---|
| Azure B2s (API, DB, Redis, MinIO) | LIVE | 20.228.184.111:8000 |
| Local RTX 3060 Ti (worker_gpu) | READY | Start via tunnel.bat + docker compose hybrid |
| React Frontend | READY | npm run dev, Vite proxy to Azure |
| 7-Stage Pipeline | VERIFIED | Best score 88.3% on billing_dispute.mp3 |
| PDF Export | WORKING | Playwright confirmed |
| Extended Presidio PII | WORKING | zip, SSN-last4, account numbers |
| WebSocket toast on call_complete | WORKING | |

---

## Pre-Demo Checklist (run in order)

- [ ] `git pull` on Azure VM
- [ ] `python3 scripts/reset_and_seed.py` on Azure VM (ensures ≥5 calls per agent for dashboard roster)
- [ ] `docker restart cq_worker_io` on Azure VM
- [ ] Check VRAM: `nvidia-smi --query-gpu=memory.free --format=csv` — must be >5000 MiB
- [ ] Start `tunnel.bat` (keep terminal open for entire session)
- [ ] Start local GPU worker: `docker compose -f infra/docker-compose.hybrid.yml up -d worker_gpu`
- [ ] Verify worker sync: `docker logs cq_worker_gpu --tail 5` — must show sync
- [ ] Start frontend: `cd frontend && npm run dev`
- [ ] Open http://localhost:5173, login admin@callquality.demo / admin1234
- [ ] Verify Overview loads all 6 panels
- [ ] Verify Agents tab shows Δ7d chips and correct worst-first sort
- [ ] Do one dry-run upload of tech_support.mp3, wait for toast, confirm new call appears

---

## Known Issues (non-blocking)

| Issue | Impact | Workaround |
|---|---|---|
| "Evaluated at" = "Call time" in drawer | Visual, no crash | If asked: "pipeline completion timestamp not stored separately in v1.4" |
| Agents with <5 calls excluded from Requires Attention | Only affects fresh agents | reset_and_seed.py ensures all seeded agents have ≥5 calls |
| ComposedChart has no legend | Minor readability | Describe verbally during demo: "bars = volume, line = score" |
| Call List does not auto-refresh after processing | Requires manual nav | Navigate away and back after upload toast fires |
| AGENT/CUSTOMER labels can swap on pre-announcement audio | Expected limitation | Acknowledge as known Pyannote limitation in Q&A |

---

## Residual Risk Summary (Top 5)

1. **SSH tunnel drops during live upload** — tunnel.bat auto-reconnects but there is a ~5s gap; upload may fail if fired during reconnect. Mitigation: test tunnel stability before demo starts.
2. **VRAM insufficient for live upload** — if RTX 3060 Ti has <5GB free, WhisperX will OOM. Mitigation: check nvidia-smi before demo, close all GPU-intensive apps.
3. **Azure B2s cold API response** — first request after idle may be slow (DB connection pool). Mitigation: hit /health endpoint once before demo to warm up.
4. **reset_and_seed.py not run** — Overview roster may be empty or agent data stale. Mitigation: run it the morning of the demo.
5. **Panel Q&A on "Evaluated at"** — minor misrepresentation in drawer metadata. Mitigation: answer is in Known Issues above.
