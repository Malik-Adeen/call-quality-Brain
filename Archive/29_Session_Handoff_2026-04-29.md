---
tags: [handoff, session-starter]
date: 2026-04-29
---

# Session Handoff — 2026-04-29

Paste INVARIANTS.md + this file to start any new session.

---

## System State: v1.4 — DEMO READY

- Azure B2s: `20.228.184.111` (always-on, API/DB/Redis/MinIO/worker_io)
- Local RTX 3060 Ti: worker_gpu via SSH tunnel
- Frontend: React 18 + Vite, runs on laptop via `npm run dev`
- 200 seeded calls in Azure PostgreSQL
- Pipeline verified: 88.3% billing_dispute, 88.2% tech_support

---

## What Was Done This Session

### UI — Overview.tsx (sea-level dashboard)
Full command-center rebuild. 5 StatCards (Total, AvgScore, Resolution, AtRisk, LatestDay).
4 panels: ComposedChart (volume+score), Requires Attention roster, Issue Impact ScatterChart (vol vs res%), Hourly BarChart (Cell-colored by score), Sentiment Diverging Bar (per agent, start→end delta).
Data: 3-page fetch (/calls?page_size=100, pages 1-3). Zero /calls/{id} calls.
File: `frontend/src/pages/Overview.tsx`

### UI — Bug Fixes
- `UploadResponse` added to `frontend/src/types/api.ts`
- Radar `Math.abs(sentiment_delta)` → `(val+1)/2` normalization fix in `CallDetailPanel.tsx`

### Audit Docs Written
- `N:\projects\docs\changelogs\ui-polish-overview-agents-callhistory.md`
- `N:\projects\docs\audits\ui-audit-latest.md` — PASS verdict, 0 critical, 2 major (non-blocking)
- `N:\projects\docs\status\demo-readiness.md` — full pre-demo checklist

### WhisperX Debug System Design
- Architecture spec written: `N:\projects\docs\28_WhisperX_Debug_System.md`
- Loop: AUDIT→DEBUG→PATCH→TEST→EVAL→LEARN
- Groq free (llama-3.3-70b) primary, Ollama qwen2.5-coder:7b offline fallback
- Obsidian vault as active memory: read at start, keyword-query mid-session, structured write after
- Key insight: "Do Not Repeat" field in vault prevents fix rediscovery loops
- TEST stage requires subprocess: `docker restart cq_worker_gpu` + 30-line log capture

---

## Pre-Demo Checklist (Tuesday)

- [ ] `git pull` on Azure VM
- [ ] `python3 scripts/reset_and_seed.py` on Azure VM
- [ ] `docker restart cq_worker_io` on Azure VM
- [ ] Check VRAM >5000 MiB free before demo
- [ ] Start `tunnel.bat` (keep open)
- [ ] `docker compose -f infra/docker-compose.hybrid.yml up -d worker_gpu`
- [ ] `docker logs cq_worker_gpu --tail 5` — verify sync
- [ ] `cd frontend && npm run dev`
- [ ] Login: admin@callquality.demo / admin1234
- [ ] Verify all 6 Overview panels load
- [ ] One dry-run upload of tech_support.mp3

---

## Known Non-Blocking Issues

| Issue | Workaround |
|---|---|
| "Evaluated at" = "Call time" in drawer | Same `created_at` field — explain if asked |
| Agents <5 calls excluded from roster | reset_and_seed.py fixes this |
| ComposedChart has no legend | Say verbally: "bars=volume, line=score" |
| Call List no auto-refresh | Navigate away and back after upload toast |

---

## Key File Paths

| File | Purpose |
|---|---|
| `frontend/src/pages/Overview.tsx` | Sea-level dashboard |
| `frontend/src/pages/Agents.tsx` | Agent performance |
| `frontend/src/pages/CallList.tsx` | Call history |
| `frontend/src/components/CallDetailPanel.tsx` | Drawer |
| `frontend/src/types/api.ts` | TypeScript contracts |
| `infra/docker-compose.hybrid.yml` | Hybrid startup |
| `scripts/tunnel.bat` | SSH tunnel |
| `N:\projects\docs\28_WhisperX_Debug_System.md` | Debug system spec |
| `N:\projects\docs\INVARIANTS.md` | Hard rules — always load |
