---
tags: [moc, dashboard]
status: active
created: 2026-04-11
updated: 2026-04-17
---

# 00 — Master Dashboard

> Single entry point for the entire vault. Always read this first.

---

## Project Identity

| Property | Value |
|---|---|
| **System** | AI Call Quality & Agent Performance Analytics System |
| **Purpose** | University final-year demo |
| **Demo Date** | Tuesday/Wednesday/Thursday — week of April 21, 2026 |
| **Repo** | github.com/Malik-Adeen/call-quality-analytics |
| **Local path** | N:\projects\call-quality-analytics |
| **Vault** | N:\projects\docs |
| **Azure B2s** | `20.228.184.111` — East US — always-on |

---

## Current Build State — v1.3 DEMO READY

| Phase | Status |
|---|---|
| Phase 1 — Foundation | ✅ |
| Phase 2 — Full AI Pipeline | ✅ |
| Phase 3 — React Dashboard | ✅ |
| Phase 4 — PDF + Azure + Hybrid | ✅ |
| Real audio testing (3 calls verified) | ✅ |
| **Demo dry-run** | 🔲 Next |

---

## Real Audio Test Results

| File | Score | Duration | Status |
|---|---|---|---|
| billing_dispute.mp3 | 88.3% | 1m 27s | ✅ Clean |
| irate_customer.mp3 | 71.0% | 12m 17s | ⚠️ Needs trim (YouTube tutorial included) |
| bpo_inbound_1.mp3 | 75.1% | 2m 18s | ✅ Clean (labels swapped — expected) |

---

## Pre-Demo Checklist

- [ ] Full demo dry-run
- [ ] `git pull` + `reset_and_seed.py` on Azure VM
- [ ] Trim `irate_customer.mp3` — remove YouTube tutorial
- [ ] Prepare 2-3 clean 2-3 min audio files for live demo
- [ ] Verify `http://20.228.184.111:8000/health` responds
- [ ] Confirm Azure dashboard loads 200 seeded calls

---

## Demo Day Start Sequence

```
1. nvidia-smi → confirm VRAM < 3GB
2. tunnel.bat → verify silent SSH connect
3. docker compose -f infra/docker-compose.hybrid.yml up -d worker_gpu
4. docker logs cq_worker_gpu --tail 5 → verify sync with worker_io
5. cd frontend && npm run dev
6. http://localhost:5173 → login
7. Upload ONE file → Reports page → wait for toast
```

---

## Azure Infrastructure

| Resource | Status |
|---|---|
| B2s `20.228.184.111` | ✅ Running |
| NC4as_T4_v3 GPU | ❌ Quota disabled on Student account |

**GPU plan:** Local RTX 3060 Ti handles all live demo processing via SSH tunnel.

---

## Critical Invariants

1. Audio → MinIO only, never DB
2. Raw transcript → never DB, Presidio-redacted only
3. `pii_redacted = TRUE` before downstream tasks
4. `run_whisperx` → `gpu_queue`, concurrency=1
5. JWT → Zustand sessionStorage, never localStorage
6. Groq model: `llama-3.3-70b-versatile`
7. MinIO endpoint: `cq-minio:9000`
8. Score display: 0–10 × 10 = %
9. Zero code comments

---

## Post-Mortems

- [[07_Phase1_Postmortem]]
- [[08_Phase2.1_Postmortem]]
- [[09_Phase2.2_Postmortem]]
- [[11_Phase2.3_Postmortem]]
- [[12_Phase2.4_Postmortem]]
- [[13_Phase2_E2E_Postmortem]]
- [[14_Audit_Fixes]]
- [[16_Phase3A_Read_Endpoints]]
- [[17_Phase3_Frontend]]
- [[21_UI_Redesign_Postmortem]]
- [[23_Phase4_Postmortem]]
- [[24_Hybrid_Architecture_Postmortem]]
- [[26_Audio_Testing_Postmortem]]

---

## Reference Docs

- [[01_Master_Architecture]] — stack, banned tools, scoring formula
- [[03_API_Contract]] — API shapes, TypeScript interfaces
- [[11_Azure_Deployment]] — B2s runbook, budget
- [[22_Session_Handoff]] — session starter for new Claude chats
